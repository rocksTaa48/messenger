<script lang="ts">
    // Иморты
    import { Search, X, FolderPlus, MessageSquare, Bot, ImageIcon, Sparkles, Plus  } from 'lucide-svelte';
    import AddCategoryModal from './AddCategoryModal.svelte';
    import { createEventDispatcher } from 'svelte';
    import { appState } from '../../stores/socketStore';
    import Chat from "./partials/Chat.svelte";
    import AddChatModal from "./AddChatModal.svelte";
    import WebApp from "@twa-dev/sdk";

    // Константы
    const dispatch = createEventDispatcher<{ selectChat: any }>();

    // Функция отклика (Вибро на iPhone)
    function handleMenuClick() {
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('light');
        console.log('Menu clicked');
    }

    // Функция открытия модалки нового чата
    let isNewChatModalOpen = false;
    function openCreateModal() {
        isNewChatModalOpen = true;
        appState.send("click:create_new_chat");
    }


    // Функция, которая следит за прокруткой контейнера
    let isLoadingMore = false;
    function handleScroll(e: Event) {
        const target = e.target as HTMLElement;

        // Считаем расстояние до дна (минус 60 пикселей буфера, чтобы подгрузка шла бесшовно)
        const isBottom = target.scrollHeight - target.scrollTop <= target.clientHeight + 60;

        // Если дошли до дна, сервер говорит, что чаты еще есть, и мы сейчас не в процессе загрузки
        if (isBottom && $appState.has_more_chats && !isLoadingMore) {
            isLoadingMore = true;

            // Отправляем сигнал на бэкенд
            appState.send("load_more_chats");
        }
    }

    // Как только стор обновился (прилетели новые чаты), снимаем блокировку загрузки
    $: if ($appState?.chats_list) {
        isLoadingMore = false;
    }






    // Логика переключения верхних категорий диалогов
    let activeCategory = 'All';
    let categories = ['All', 'Friends', 'Work'];

    // Переменная для отслеживания состояния строки поиска (скрыта по умолчанию)
    let isSearchOpen = false;
    let searchQuery = "";
    let isModalOpen = false;
    function handleAddCategory(event: CustomEvent<string>) {
        const name = event.detail;
        // Защита от дубликатов
        if (!categories.includes(name)) {
            categories = [...categories, name]; // Добавляем реактивно в массив
            activeCategory = name; // Сразу переключаем фокус на нее
        }
    }
</script>

<div class="flex flex-col h-full w-full bg-[#0f0f0f] rounded-[24px] p-2 text-white font-sans border border-white/5 shadow-2xl overflow-hidden">

    <!-- ЗАГОЛОВОК ОКНА -->
    <div class="px-2 pt-2">
        <div class="flex items-center justify-between mb-3 h-10">

            <!-- ACHTUNG! - Левая кнопка Edit скрывается, когда открыт поиск -->
            {#if !isSearchOpen}
                <!-- КНОПКА НОВОЙ ПАПКИ -->
                <button
                        on:click={() => isModalOpen = true}
                        class="flex-shrink-0 flex items-center justify-center w-18 h-18 text-gray-400 hover:text-[#2481cc]
                         transition-colors border-b-2 border-transparent pb-1 transition-transform active:scale-95"
                >
                    <FolderPlus size={22} />
                </button>
            {:else}
                <!-- Пустышка или кнопка отмены для сохранения разметки флекса -->
                <div class="w-8"></div>
            {/if}

            <!-- ЗАГОЛОВОК (скрывается, когда открыт поиск) -->
            {#if !isSearchOpen}
                <p class="text-[28px] font-semibold tracking-tight text-gray-900 dark:text-white transition-opacity duration-200">
                    Chats
                </p>
            {:else}
                <!-- Если поиск открыт, прямо по центру выкатывается инпут -->
                <div class="flex-1 relative mx-2 transition-all duration-300">
                <span class="absolute inset-y-0 left-0 flex items-center pl-3 pointer-events-none text-gray-400 dark:text-gray-500">
                    <Search size={16} />
                </span>
                    <input
                            type="text"
                            bind:value={searchQuery}
                            placeholder="Search chats..."
                            class="w-full pl-9 pr-8 py-1.5 bg-gray-100 dark:bg-[#242f3d] rounded-xl text-sm focus:outline-none placeholder-gray-400 dark:placeholder-gray-500 text-white border border-transparent focus:border-[#2481cc]/30"
                    />
                    <!-- Кнопка очистки / закрытия внутри инпута -->
                    {#if searchQuery.length > 0}
                        <button
                                on:click={() => searchQuery = ""}
                                class="absolute inset-y-0 right-0 flex items-center pr-2.5 text-gray-400 hover:text-white"
                        >
                            <X size={14} />
                        </button>
                    {/if}
                </div>
            {/if}

            <!-- ПЕРЕКЛЮЧАТЕЛЬ (Поиск / Отмена) -->
            <button
                    on:click={() => {
                isSearchOpen = !isSearchOpen;
                if (!isSearchOpen) searchQuery = ""; // Очищаем поиск при закрытии
            }}
                    class="text-[#2481cc] hover:opacity-80 transition-opacity p-1 transition-transform active:scale-95"
            >
                {#if !isSearchOpen}
                    <Search size={22} />
                {:else}
                    <span class="text-sm font-normal">Cancel</span>
                {/if}
            </button>
        </div>

        <!-- ЛЕНТА КАТЕГОРИЙ -->
        <div class="flex items-center w-full gap-3 px-4 mb-2 border-b border-gray-100 dark:border-[#101921]">

            <!-- Контейнер для вкладок -->
            <div class="flex items-center gap-6 overflow-x-auto whitespace-nowrap scrollbar-none flex-1 h-10">
                {#each categories as category}
                    {@const isActive = activeCategory === category}

                    <button
                            class="h-full px-1 text-xs font-semibold tracking-wide transition-all relative flex items-center justify-center pb-1 border-b-2
                    {isActive
                        ? 'border-[#2481cc] text-[#2481cc] dark:text-[#52a6e7]'
                        : 'border-transparent text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300'}"
                            on:click={() => activeCategory = category}
                    >
                        {category}

                        <!-- Мягкое неоновое свечение под активной вкладкой -->
                        {#if isActive}
                            <div class="absolute bottom-0 inset-x-0 h-[2px] bg-[#2481cc] blur-[2px] opacity-50"></div>
                        {/if}
                    </button>
                {/each}
            </div>
        </div>
    </div>

    <div   on:scroll={handleScroll}
           class="flex-1 overflow-y-auto pb-24 scrollbar-none space-y-2 px-2 w-full"
    >

        <button on:click={() => openCreateModal()}
                class="w-full flex items-center justify-center gap-3 text-gray-400 hover:text-[#2481cc] hover:bg-white/[0.05]
           transition-all border border-dashed border-white/10 py-4
           active:scale-95 bg-white/[0.02] rounded-[24px] font-semibold text-sm mb-4"
        >
            <span>New Chat</span>
            <Plus size={18} strokeWidth={2.5} />
        </button>

        <!-- Рендерим живой список из сокета Elixir -->
        {#if $appState && $appState.chats_list}
            {#each $appState.chats_list as chat (chat.id)}
                <!-- Обязательно передаем проп чата внутрь компонента -->
                <Chat {chat} />
            {/each}
            <!-- Красивый индикатор догрузки внизу списка -->
            {#if isLoadingMore}
                <div class="w-full text-center py-4 text-xs text-slate-500 animate-pulse">
                    Подгружаем старые переписки...
                </div>
            {/if}
        {:else}
            <p class="text-center text-xs text-slate-500 animate-pulse">Диалогов больше нет...</p>
        {/if}
    </div>

    <AddCategoryModal bind:isOpen={isModalOpen} on:add={handleAddCategory} />
    <AddChatModal bind:isOpen={isNewChatModalOpen} />
</div>

<style>
    /* Легкий глянец иконкам */
    .shadow-inner {
        box-shadow: inset 0 2px 4px rgba(255,255,255,0.2), 0 4px 10px rgba(0,0,0,0.3);
    }
    .scrollbar-hide::-webkit-scrollbar {
        display: none;
    }
    .scrollbar-hide {
        -ms-overflow-style: none;
        scrollbar-width: none;
    }
</style>
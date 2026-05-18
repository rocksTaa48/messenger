<script lang="ts">
    import { Search, X, FolderPlus, MessageSquare, Bot, ImageIcon, Sparkles, Plus  } from 'lucide-svelte';
    import AddCategoryModal from './AddCategoryModal.svelte';
    import { createEventDispatcher } from 'svelte';
    const dispatch = createEventDispatcher<{ selectChat: any }>();

    import WebApp from "@twa-dev/sdk";

    let chats = [
        {
            id: '1',
            theme: 'ChatGPT Assistant',
            body: 'Конечно! Я могу помочь вам спроектировать базу данных для Elixir...',
            status: 'unread',
            time: '14:28',
            unreadCount: 3,
            icon: Bot,
            iconColor: 'text-[#2481cc] bg-[#2481cc]/10'
        },
        {
            id: '2',
            theme: 'DALL-E 3 Generator',
            body: 'Изображение "Гусь в космосе с рогами" успешно сгенерировано',
            status: 'read',
            time: 'Вчера',
            unreadCount: 0,
            icon: ImageIcon,
            iconColor: 'text-purple-400 bg-purple-500/10'
        },
        {
            id: '3',
            theme: 'Бот-Почтальон Новости',
            body: 'Обновление системы: Добавлена поддержка горизонтальных вкладок',
            status: 'read',
            time: '2 мая',
            unreadCount: 0,
            icon: Sparkles,
            iconColor: 'text-[#d9ff00] bg-[#d9ff00]/10'
        },
        {
            id: '4',
            theme: 'Общий Чат (Тест)',
            body: 'Привет! Бот работает просто отлично, задержек вообще нет',
            status: 'read',
            time: '18.04',
            unreadCount: 0,
            icon: MessageSquare,
            iconColor: 'text-gray-400 bg-white/5'
        }
    ];


    function handleMenuClick() {
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('light');
        console.log('Menu clicked');
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

    <!-- СКРОЛЛ ЧАТОВ -->
    <div class="flex-1 overflow-y-auto pb-24 scrollbar-none space-y-2 px-2">


        <!-- КНОПКА НОВОГО ЧАТА (всегда прижата к верху списка?пока) -->
        <button
                class="w-full flex items-center justify-center gap-3 text-gray-400 hover:text-[#2481cc] hover:bg-white/[0.05]
                     transition-all border border-dashed border-white/10 py-4
                     active:scale-95 bg-white/[0.02] rounded-[24px] font-semibold text-sm mb-4"
        >
            <span>New Chat</span>
            <Plus size={18} strokeWidth={2.5} />
        </button>

        {#each chats as chat (chat.id)}
            <div         on:click={() => dispatch('selectChat', chat)}
                         class="flex items-center gap-4 p-3.5 bg-white/[0.03] border border-white/5
                         rounded-[24px] hover:bg-white/[0.06] cursor-pointer transition-all active:scale-[0.99]"
            >

                <!-- Иконка чата (Аватарка) -->
                <div class="w-12 h-12 rounded-2xl flex items-center justify-center flex-shrink-0 {chat.iconColor}">
                    <svelte:component this={chat.icon} size={24} />
                </div>

                <!-- Текстовый блок (Название и последнее сообщение) -->
                <div class="flex-1 min-w-0">
                    <div class="flex justify-between items-baseline mb-1">
                        <h3 class="text-sm font-bold text-white truncate pr-2">
                            {chat.theme}
                        </h3>
                        <span class="text-[10px] text-gray-500 font-medium whitespace-nowrap">
                        {chat.time}
                    </span>
                    </div>
                    <p class="text-xs text-gray-400 truncate pr-4">
                        {chat.body}
                    </p>
                </div>

                <!-- Правый блок: Статус и счетчик непрочитанных -->
                <div class="flex flex-col items-end justify-center flex-shrink-0 min-w-[20px]">
                    {#if chat.status === 'unread' && chat.unreadCount > 0}
                    <span class="bg-[#2481cc] text-white text-[10px] font-bold rounded-full h-4.5 min-w-[18px] flex items-center justify-center px-1 animate-pulse">
                        {chat.unreadCount}
                    </span>
                    {:else if chat.status === 'read'}
                        <!-- Иконка двойной галочки, если прочитано -->
                        <span class="text-[#2481cc] opacity-80">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7M5 13l4 4L19 7" />
                        </svg>
                    </span>
                    {/if}
                </div>

            </div>
        {/each}
    </div>

    <AddCategoryModal bind:isOpen={isModalOpen} on:add={handleAddCategory} />
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
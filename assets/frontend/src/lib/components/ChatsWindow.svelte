<script lang="ts">
    import { Search, X, Plus, Folder, FolderX, Trash2, Pencil, Pin, PinOff } from 'lucide-svelte';
    import AddCategoryModal from './AddCategoryModal.svelte';
    import AddChatModal from "./AddChatModal.svelte";
    import Chat from "./partials/Chat.svelte";
    import ChatContextMenu from './ChatContextMenu.svelte';
    import ChatsFoldersModal from './ChatsFoldersModal.svelte';
    import { createEventDispatcher } from 'svelte';
    import { appState } from '../../stores/socketStore';
    import { longPress } from '../actions/longPress';
    import RenameModal from './RenameModal.svelte'
    import WebApp from "@twa-dev/sdk";

    const dispatch = createEventDispatcher<{ selectChat: any }>();

    function handleMenuClick() {
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('light');
        console.log('Menu clicked');
    }

    let isNewChatModalOpen = false;

    function openCreateModal() {
        isNewChatModalOpen = true;
        appState.send("chat:click_new");
    }

    $: activeCategoryId = $appState.nav_context.params?.group_id || 'All'


    let isLoadingMore = false;
    function handleScroll(e: Event) {
        const target = e.target as HTMLElement;
        const isBottom = target.scrollHeight - target.scrollTop <= target.clientHeight + 60;

        if (isBottom && $appState.has_more_chats && !isLoadingMore) {
            isLoadingMore = true;
            appState.send("chat:load_more_chats", {group_id: activeCategoryId});
        }
    }

    $: if ($appState?.chats_list) {
        isLoadingMore = false;
    }

    let isSearchOpen = false;
    let searchQuery = "";
    let isModalOpen = false;
    let isFoldersModalOpen = false;
    let folderModalChatId: string | null = null;
    let folderModalChatTitle = '';

    $: if (isSearchOpen) {
        appState.send("chat:click_search_chats", { query: searchQuery });
    }

    function handleAddCategory(event: CustomEvent<string>) {
        const name = event.detail;
        appState.send("category:add", { name });
    }

    function scrollActiveIntoView(node, isActive) {
        const performScroll = (active) => {
            if (active) {
                setTimeout(() => {
                    node.scrollIntoView({
                        behavior: 'smooth',
                        block: 'nearest',
                        inline: 'center'
                    });
                }, 50);
            }
        };
        performScroll(isActive);
        return {
            update(newIsActive) {
                performScroll(newIsActive);
            }
        };
    }

    // Секция КОНТЕКСТНОГО МЕНЮ ДЛЯ КОНКРЕТНОГО ЧАТА
    let isContextMenuOpen = false;
    let contextMenuChatTitle = '';
    let contextMenuActions: any[] = [];
    let wasChatLongPress = false;

    function showContextMenu(chat: any) {
        // Haptic при появлении меню
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('medium');

        contextMenuChatTitle = chat.name || chat.title || 'Без названия';

        const isOnSpecificFolder = activeCategoryId && activeCategoryId !== 'All';


        contextMenuActions = [
            {
                id: 'folder',
                label: isOnSpecificFolder ? 'Убрать из папки' : 'Переместить в папку',
                icon: isOnSpecificFolder ? FolderX : Folder,
                isDanger: isOnSpecificFolder,
                onClick: () => {
                    if (isOnSpecificFolder) {
                        // Убираем из папки
                        appState.send("chat:click_update_chat_group", {
                            chat_id: chat.id?.toString(),
                            group_id: activeCategoryId,
                            action: "remove"
                        });
                        isContextMenuOpen = false;
                    } else {
                        // Открываем модалку выбора папки
                        folderModalChatId = chat.id?.toString() || null;
                        folderModalChatTitle = chat.name || chat.title || 'Без названия';
                        isContextMenuOpen = false;
                        isFoldersModalOpen = true;
                    }
                }
            },
            {
                id: 'pin',
                label: chat.is_pinned ? 'Открепить' : 'Закрепить',
                icon: chat.is_pinned ? PinOff : Pin,
                isDanger: chat.is_pinned, // Красная кнопка, если уже закреплен
                onClick: () => {
                    console.log(chat.is_pinned ? 'Unpinning chat:' : 'Pinning chat:', chat.id);

                    // Отправляем универсальный тоггл на умный бэкенд
                    appState.send("chat:click_pinned_toggle_chat", {
                        chat_id: chat.id?.toString(),
                        pinned_toggle: true
                    });

                    isContextMenuOpen = false;
                }
            },
            {
                id: 'rename',
                label: 'Переименовать',
                icon: Pencil,
                onClick: () => {
                    console.log('Rename chat:', chat.id);
                    isGroupContextMenuOpen = false;

                    // Настраиваем и открываем модалку переименования
                    renameItemId = chat.id.toString();
                    renameCurrentTitle = chat.title;
                    renameEventKey = "chat_id";
                    renameModalTitle = 'Переименовать чат';
                    renameEventType = 'chat:click_update_chat';
                    renameEventCode = "update_title";
                    isRenameModalOpen = true;
                }
            },
            {
                id: 'delete',
                label: 'Удалить чат',
                icon: Trash2,
                isDanger: true,
                onClick: () => {
                    if (confirm('Вы уверены, что хотите удалить этот чат? Это действие нельзя отменить.')) {
                        // Пока тут реализована система с отдачей от бэка стейта, мне пока так спокойнее
                        // на бэк я отдаю group_id или если это all то ничего, соответственно отдадуться все чаты
                        const payload = activeCategoryId !== 'All'
                            ? { chat_id: chat.id, group_id: activeCategoryId }
                            : { chat_id: chat.id };

                        console.log('Delete chat:', chat.id);
                        appState.send("chat:click_delete_chat", payload)
                    }
                }
            }
        ];

        isContextMenuOpen = true;
    }

    function handleChatLongPress(event: CustomEvent) {
        const { chat } = event.detail;
        showContextMenu(chat);
    }

    // Секция КОНТЕКСТНОЕ МЕНЮ ДЛЯ ПАПОК ЧАТОВ

    let isGroupContextMenuOpen = false;
    let groupContextMenuTitle = '';
    let groupContextMenuActions: any[] = [];

    $: if (!isGroupContextMenuOpen) wasGroupLongPress = false;
    $: if (!isContextMenuOpen) wasChatLongPress = false;

    // Флаг для защиты от перехода в папку после долгого нажатия
    let wasGroupLongPress = false;

    function handleGroupLongPress(event: CustomEvent, group: any) {
        wasGroupLongPress = true; // Блокируем последующий клик

        if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('medium');

        groupContextMenuTitle = group.title || 'Папка';

        groupContextMenuActions = [
            {
                id: 'rename',
                label: 'Переименовать',
                icon: Pencil,
                onClick: () => {
                    isGroupContextMenuOpen = false;

                    // Настраиваем и открываем модалку переименования
                    renameItemId = group.id.toString();
                    renameCurrentTitle = group.title;
                    renameEventKey = "group_id";
                    renameModalTitle = 'Переименовать папку';
                    renameEventType = 'chat:click_update_group';
                    renameEventCode = "update_title";
                    isRenameModalOpen = true;
                }
            },
            {
                id: 'delete',
                label: 'Удалить папку',
                icon: Trash2,
                isDanger: true,
                onClick: () => {
                    if (confirm(`Удалить папку "${group.title}"? Чаты не удалятся, а вернутся в "All".`)) {
                        const isCurrentGroup = activeCategoryId.toString() === group.id.toString();

                        // Отправляем запрос на удаление
                        appState.send("chat:click_remove_group", { group_id: group.id, action: "remove" });

                        // Если удаляем current группу, оптимистично переключаемся в 'All'
                        if (isCurrentGroup) {
                            appState.goTo({ screen: 'chats' });
                        }

                        isGroupContextMenuOpen = false;
                    }
                }
            }
        ];

        isGroupContextMenuOpen = true;
    }

    function handleGroupClick(group: any) {
        // Если только что был long press, игнорируем клик и сбрасываем флаг
        if (wasGroupLongPress) {
            wasGroupLongPress = false;
            return;
        }

        // Обычный быстрый клик — навигация
        appState.goTo({
            screen: 'chats',
            params: { group_id: group.id.toString() }
        });
    }

    // Реактивно скроллим активную вкладку при любом изменении списка групп
    $: if ($appState.groups && activeCategoryId !== 'All') {
        // Небольшая задержка, чтобы DOM успел перерисоваться
        setTimeout(() => {
            const activeButton = document.querySelector(`[data-group-id="${activeCategoryId}"]`);
            if (activeButton) {
                activeButton.scrollIntoView({
                    behavior: 'smooth',
                    block: 'nearest',
                    inline: 'center'
                });
            }
        }, 50);
    }

    // Переименование

    let isRenameModalOpen = false;
    let renameItemId: string | null = null;
    let renameCurrentTitle = '';
    let renameModalTitle = 'Переименовать папку';
    let renameEventType: string;
    let renameEventCode: string;
    let renameEventKey: string;

</script>

<div class="flex flex-col h-full w-full bg-[#0f0f0f] rounded-[24px] p-2 text-white font-sans border border-white/5 shadow-2xl overflow-hidden">

    <!-- ЗАГОЛОВОК ОКНА -->
    <div class="px-2 pt-2 select-none">
        <!-- ВЕРХНЯЯ ПАНЕЛЬ: ЗАГОЛОВОК / ПОИСК -->
        <div class="flex items-center justify-between mb-3 h-10">

            {#if !isSearchOpen}
                <button
                        on:click={() => isModalOpen = true}
                        class="w-10 h-10 text-gray-400 hover:text-[#2481cc]
                 transition-colors border-b-2 border-transparent pb-1 transition-transform active:scale-95"
                >
                    <Plus size={22} />
                </button>
            {:else}
                <div class="w-10"></div>
            {/if}

            {#if !isSearchOpen}
                <p class="text-[28px] font-semibold tracking-tight text-gray-900 dark:text-white transition-opacity duration-200">
                    Chats
                </p>
            {:else}
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

            <button on:click={() => {
                        isSearchOpen = !isSearchOpen;
                        if (!isSearchOpen) {
                            searchQuery = "";
                            if (activeCategoryId === 'All') {
                                appState.goTo({ screen: 'chats' });
                            } else {
                                appState.goTo({ screen: 'chats', params: { group_id: activeCategoryId } });
                            }
                        }
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

        <!-- ЛЕНТА ПАПОК ЧАТОВ -->
        <div class="flex items-center w-full gap-3 px-4 mb-2 border-b border-gray-100 dark:border-[#101921]">
            <div class="flex items-center gap-6 overflow-x-auto whitespace-nowrap scrollbar-none flex-1 h-10 touch-pan-x">
                <!-- КНОПКА ALL (системная, без long press) -->
                <button
                        class="h-full px-1 text-xs font-semibold tracking-wide transition-all relative flex items-center justify-center pb-1 border-b-2
                        {activeCategoryId === 'All'
                            ? 'border-[#2481cc] text-[#2481cc] dark:text-[#52a6e7]'
                            : 'border-transparent text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300'}"
                        on:click={() => appState.goTo({ screen: 'chats' })}
                >
                    All
                    {#if activeCategoryId === 'All'}
                        <div class="absolute bottom-0 inset-x-0 h-[2px] bg-[#2481cc] blur-[2px] opacity-50"></div>
                    {/if}
                </button>

                <!-- ДИНАМИЧЕСКИЕ ГРУППЫ прикручен long press -->
                {#if $appState && $appState.groups}
                    {#each $appState.groups as group (group.id)}
                        {@const isActive = activeCategoryId.toString() === group.id.toString()}

                        <button data-group-id={group.id}
                                use:longPress={{ duration: 500, callback: (e) => handleGroupLongPress(e, group) }}
                                use:scrollActiveIntoView={isActive}
                                on:click={() => handleGroupClick(group)}
                                class="h-full px-1 text-xs font-semibold tracking-wide transition-all relative flex items-center justify-center pb-1 border-b-2 select-none touch-pa
                                {isActive
                                ? 'border-[#2481cc] text-[#2481cc] dark:text-[#52a6e7]'
                                : 'border-transparent text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300'}"
                        >
                            {group.title}

                            {#if isActive}
                                <div class="absolute bottom-[0px] inset-x-0 h-[2px] bg-[#2481cc] blur-[2px] opacity-50"></div>
                            {/if}
                        </button>
                    {/each}
                {/if}

            </div>
        </div>

    </div>

    <div on:scroll={handleScroll}
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

        {#if $appState && $appState.chats_list}
            {#each $appState.chats_list as chat (chat.id)}
                <!-- обработчик события long press -->
                <Chat {chat}
                      on:chatLongPress={handleChatLongPress}
                />
            {/each}
            {#if isLoadingMore}
                <div class="w-full text-center py-4 text-xs text-slate-500 animate-pulse">
                    Подгружаем старые переписки...
                </div>
            {/if}
        {:else}
            <p class="text-center text-xs text-slate-500 animate-pulse">Диалогов больше нет...</p>
        {/if}
    </div>

    <!-- Модалки -->
    <AddCategoryModal bind:isOpen={isModalOpen} on:add={handleAddCategory} />
    <AddChatModal bind:isOpen={isNewChatModalOpen} />

    <!-- Модалка контекстного меню для конкретного чата -->
    <ChatContextMenu
            bind:isOpen={isContextMenuOpen}
            chatTitle={contextMenuChatTitle}
            actions={contextMenuActions}
    />
    <!-- Модалка контекстного меню для конкретного чата, с выбором перемещения в папку -->
    <ChatsFoldersModal
            bind:isOpen={isFoldersModalOpen}
            chatId={folderModalChatId}
            chatTitle={folderModalChatTitle}
    />
    <!-- Модалка контекстного меню для конкретной папки чатов -->
    <ChatContextMenu
            bind:isOpen={isGroupContextMenuOpen}
            chatTitle={groupContextMenuTitle}
            actions={groupContextMenuActions}
    />
    <!-- Модалка контекстного меню для переименования -->
    <RenameModal
            bind:isOpen={isRenameModalOpen}
            itemId={renameItemId}
            currentTitle={renameCurrentTitle}
            modalTitle={renameModalTitle}
            eventType={renameEventType}
            eventCode={renameEventCode}
            itemKey= {renameEventKey}
    />

</div>

<style>
    .shadow-inner {
        box-shadow: inset 0 2px 4px rgba(255,255,255,0.2), 0 4px 10px rgba(0,0,0,0.3);
    }
    .scrollbar-none::-webkit-scrollbar {
        display: none;
    }
    .scrollbar-none {
        -ms-overflow-style: none;
        scrollbar-width: none;
    }
</style>
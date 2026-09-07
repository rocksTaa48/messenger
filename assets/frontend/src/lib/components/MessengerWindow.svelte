<script lang="ts">
    import { onMount, onDestroy, tick, beforeUpdate, afterUpdate } from 'svelte';
    import { ChevronLeft, Paperclip, Mic, SendHorizontal, Settings, FileImage } from 'lucide-svelte';
    import { appState } from '../../stores/socketStore';
    import Message from "./partials/Message.svelte"

    // === Реактивные данные из стора ===
    $: activeChat = $appState.active_chat;
    $: messages = activeChat?.messages || [];
    $: isGenerating = messages.some(msg => msg.is_streaming === true) || false;

    $: currentChatInfo = $appState.chats_list.find(c =>
        c.id && activeChat?.id && String(c.id) === String(activeChat.id)
    );

    $: isThinking = messages.length > 0 && !activeChat?.title && !currentChatInfo?.title;

    $: chatName =
        activeChat?.title ||
        currentChatInfo?.title ||
        (isThinking ? "Придумываю название" : (activeChat ? "Новый чат" : "Ассистент"));

    // === DOM-рефы ===
    let scrollContainer: HTMLDivElement;
    let textareaElement: HTMLTextAreaElement;
    let topSentinel: HTMLDivElement;

    // === Состояние UI ===
    let newMessageText = "";
    let isAttachmentMenuOpen = false;

    // === Скролл / подгрузка ===
    let isLoadingMoreMessages = false;
    let isPaginationEnabled = false;
    let observer: IntersectionObserver | null = null;

    // 🚀 НОВЫЕ ФЛАГИ ДЛЯ ИДЕАЛЬНОГО СКРОЛЛА
    let hasInitialScrollDone = false; // Гарантирует скролл вниз ровно один раз при загрузке
    let isNearBottom = true;          // Отслеживает, читает ли пользователь историю

    let scrollState: {
        oldScrollHeight: number;
        oldScrollTop: number;
        expectedFirstId: string | number | null;
    } | null = null;

    let prevMessagesCount = 0;
    let prevLastId: string | number | null = null;

    // === Хелперы ===
    function formatTime(isoString: string): string {
        if (!isoString) return "";
        try {
            return new Date(isoString).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        } catch (e) {
            return "";
        }
    }

    function scrollToBottomImmediate() {
        if (scrollContainer) {
            scrollContainer.scrollTop = scrollContainer.scrollHeight;
        }
    }

    async function scrollToBottom() {
        await tick();
        scrollToBottomImmediate();
    }

    // 🚀 Отслеживаем позицию скролла (вернули это, это критически важно!)
    function handleScroll() {
        if (!scrollContainer) return;
        const distanceFromBottom = scrollContainer.scrollHeight - scrollContainer.scrollTop - scrollContainer.clientHeight;
        isNearBottom = distanceFromBottom < 150; // Если до низа меньше 150px, считаем что мы "внизу"
    }

    // === Intersection Observer ===
    function setupObserver() {
        if (!scrollContainer || !topSentinel || observer) return;

        observer = new IntersectionObserver(
            (entries) => {
                if (
                    entries[0].isIntersecting &&
                    isPaginationEnabled &&
                    !isLoadingMoreMessages &&
                    activeChat?.has_more_messages
                ) {
                    loadMoreMessages();
                }
            },
            {
                root: scrollContainer,
                rootMargin: '200px 0px 0px 0px',
                threshold: 0
            }
        );

        observer.observe(topSentinel);
    }

    // === Подгрузка старых сообщений ===
    async function loadMoreMessages() {
        if (!scrollContainer || !activeChat?.has_more_messages || !isPaginationEnabled) return;

        isLoadingMoreMessages = true;

        scrollState = {
            oldScrollHeight: scrollContainer.scrollHeight,
            oldScrollTop: scrollContainer.scrollTop,
            expectedFirstId: messages[0]?.id ?? null
        };

        // Защита от зависания
        const timeoutId = setTimeout(() => {
            if (isLoadingMoreMessages) {
                isLoadingMoreMessages = false;
                scrollState = null;
            }
        }, 10000);

        appState.send('chat:load_more_messages', { chat_id: activeChat.id })
            .receive('ok', async () => {
                clearTimeout(timeoutId);
                // Ждем отрисовки
                await tick();
                if (scrollContainer && scrollState) {
                    const heightDiff = scrollContainer.scrollHeight - scrollState.oldScrollHeight;
                    if (heightDiff > 0) {
                        scrollContainer.scrollTop = scrollState.oldScrollTop + heightDiff;
                    }
                }
                scrollState = null;
                isLoadingMoreMessages = false;
            })
            .receive('error', () => {
                clearTimeout(timeoutId);
                scrollState = null;
                isLoadingMoreMessages = false;
            });
    }

    // === Жизненный цикл ===
    onMount(() => {
        setupObserver();
        return () => {
            if (observer) observer.disconnect();
        };
    });

    // === beforeUpdate ===
    beforeUpdate(() => {
        prevMessagesCount = messages.length;
        prevLastId = messages[messages.length - 1]?.id ?? null;
    });

    // === afterUpdate: МОЗГ СКРОЛЛА ===
    afterUpdate(async () => {
        if (!scrollContainer) return;

        // 1. 🚀 ПЕРВИЧНЫЙ СКРОЛЛ ВНИЗ (Решает твою главную проблему!)
        // Если мы еще не скроллили при старте, и сообщения уже пришли -> скроллим вниз
        if (!hasInitialScrollDone && messages.length > 0) {
            await tick(); // Гарантируем, что DOM полностью отрисован с новыми сообщениями
            scrollToBottomImmediate();
            hasInitialScrollDone = true;
            isPaginationEnabled = true; // Включаем пагинацию только после того, как оказались внизу
            return;
        }

        // 2. Восстановление позиции при подгрузке старых сообщений
        if (isLoadingMoreMessages && scrollState && scrollContainer) {
            const currentFirstId = messages[0]?.id ?? null;
            if (currentFirstId !== scrollState.expectedFirstId) {
                const heightDiff = scrollContainer.scrollHeight - scrollState.oldScrollHeight;
                if (heightDiff > 0) {
                    scrollContainer.scrollTop = scrollState.oldScrollTop + heightDiff;
                }
                scrollState = null;
                isLoadingMoreMessages = false;
            }
            return; // Блокируем остальной код во время подгрузки
        }

        // 3. Автоскролл вниз при стриминге токенов (ТОЛЬКО если пользователь и так внизу)
        if (isGenerating && isNearBottom) {
            scrollToBottomImmediate();
            return;
        }

        // 4. Автоскролл вниз при новых сообщениях (ТОЛЬКО если пользователь и так внизу)
        if (
            !isLoadingMoreMessages &&
            messages.length > prevMessagesCount &&
            messages[messages.length - 1]?.id !== prevLastId &&
            isNearBottom
        ) {
            scrollToBottomImmediate();
        }
    });

    // === Закрываем меню вложений при вводе ===
    $: if (newMessageText.trim().length > 0) {
        isAttachmentMenuOpen = false;
    }

    // === Отправка сообщения ===
    function handleSend() {
        const text = newMessageText.trim();
        if (!text) return;

        appState.sendMessage(text);
        newMessageText = "";
        if (textareaElement) textareaElement.style.height = 'auto';

        // При ручной отправке мы ВСЕГДА хотим быть внизу
        isNearBottom = true;
        scrollToBottom();
    }

    function handleKeyDown(event: KeyboardEvent) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            handleSend();
        }
    }

    function toggleAttachmentMenu() {
        isAttachmentMenuOpen = !isAttachmentMenuOpen;
    }

    function autoGrow() {
        if (!textareaElement) return;
        textareaElement.style.height = 'auto';
        const newHeight = Math.min(textareaElement.scrollHeight, 120);
        textareaElement.style.height = `${newHeight}px`;
    }
</script>

<div class="flex flex-col h-full w-full min-w-0 bg-[#0f0f0f] rounded-[24px] text-white font-sans overflow-hidden">

    <!-- ШАПКА ЧАТА -->
    <header class="h-14 bg-white/[0.02] backdrop-blur-xl border-b border-white/5 flex items-center px-4 justify-between flex-shrink-0 z-10">
        <button on:click={() => appState.goBack()} class="text-[#2481cc] hover:opacity-80 transition-all p-1 -ml-1 flex items-center justify-center">
            <ChevronLeft size={24} strokeWidth={2.5} />
        </button>

        <div class="flex flex-col items-center flex-1 pr-6">
            <span class="text-sm font-bold tracking-tight transition-all duration-300 {isThinking ? 'text-[#2481cc]/80 animate-pulse' : 'text-white'}">
                {chatName}
                {#if isThinking}
                    <span class="inline-block animate-pulse">...</span>
                {/if}
            </span>
            <span class="text-[10px] font-medium transition-colors duration-300 {isGenerating ? 'text-[#2481cc]' : 'text-emerald-400/80'}">
                {#if isGenerating}
                    <span class="inline-flex items-center gap-1">
                        <span class="animate-pulse">typing</span>
                        <span class="flex gap-0.5">
                            <span class="w-1 h-1 bg-current rounded-full animate-bounce" style="animation-delay: 0s"></span>
                            <span class="w-1 h-1 bg-current rounded-full animate-bounce" style="animation-delay: 0.2s"></span>
                            <span class="w-1 h-1 bg-current rounded-full animate-bounce" style="animation-delay: 0.4s"></span>
                        </span>
                    </span>
                {:else}
                    online
                {/if}
            </span>
        </div>

        <div class="p-2 bg-white/5 rounded-xl text-gray-400 hover:text-white transition-colors flex items-center justify-center flex-shrink-0">
            <Settings size={24} strokeWidth={2.5} />
        </div>
    </header>

    <!-- ЗОНА СООБЩЕНИЙ -->
    <div
            bind:this={scrollContainer}
            on:scroll={handleScroll} class="flex-1 overflow-y-auto py-4 px-3 flex flex-col gap-2 scrollbar-none"
    >
    <div bind:this={topSentinel} class="h-2 w-full flex-shrink-0">
        {#if isLoadingMoreMessages && activeChat?.has_more_messages}
            <div class="flex justify-center py-3">
                <span class="text-gray-500 text-xs animate-pulse">Загрузка истории...</span>
            </div>
        {/if}
    </div>

    <Message {messages} {formatTime} />
</div>

    <!-- НИЖНЯЯ ПАНЕЛЬ ВВОДА -->
    <footer class="w-full p-2 bg-white/[0.02] backdrop-blur-xl border-t border-white/5 flex items-center gap-2 flex-shrink-0 pb-safe relative">

        {#if isAttachmentMenuOpen}
            <div class="absolute bottom-14 left-4 bg-[#121212]/95 backdrop-blur-xl border border-white/10 rounded-2xl p-1.5 flex flex-col gap-1 shadow-2xl z-50 transition-all">
                <button class="flex items-center gap-2.5 px-3 py-2 text-xs font-semibold text-gray-300 hover:text-white hover:bg-white/5 rounded-xl transition-colors">
                    <FileImage size={16} class="text-[#2481cc]" />
                    <span>Photo</span>
                </button>
                <button class="flex items-center gap-2.5 px-3 py-2 text-xs font-semibold text-gray-300 hover:text-white hover:bg-white/5 rounded-xl transition-colors">
                    <Paperclip size={16} class="text-emerald-400" />
                    <span>File</span>
                </button>
                <button class="flex items-center gap-2.5 px-3 py-2 text-xs font-semibold text-gray-300 hover:text-white hover:bg-white/5 rounded-xl transition-colors">
                    <Mic size={16} class="text-red-400" />
                    <span>Voice</span>
                </button>
            </div>
        {/if}

        <div class="flex-1 bg-white/[0.03] border border-white/5 rounded-[20px] px-3.5 py-2 flex items-center gap-2 focus-within:border-[#2481cc]/30 transition-all">
            <button
                    on:click={toggleAttachmentMenu}
                    class="text-gray-500 hover:text-[#2481cc] transition-colors flex items-center justify-center p-0.5 transform {isAttachmentMenuOpen ? 'rotate-45' : 'rotate-0'} transition-transform duration-200"
            >
                <Paperclip size={18} />
            </button>

            <textarea
                    bind:this={textareaElement}
                    bind:value={newMessageText}
                    on:input={autoGrow}
                    on:keydown={handleKeyDown}
                    rows="1"
                    placeholder="Message"
                    class="flex-1 bg-transparent text-base font-medium focus:outline-none placeholder-gray-600 text-white resize-none max-h-[120px] py-0.5 leading-relaxed scrollbar-none"
            ></textarea>
        </div>

        {#if newMessageText.trim().length > 0}
            <button on:click={handleSend} class="text-[#2481cc] hover:scale-105 active:scale-95 transition-all p-2 flex items-center justify-center flex-shrink-0">
                <SendHorizontal size={20} />
            </button>
        {:else}
            <button class="text-gray-500 hover:text-white transition-colors p-2 flex-shrink-0">
                <SendHorizontal size={20} />
            </button>
        {/if}
    </footer>

</div>

<style>
    .scrollbar-none::-webkit-scrollbar {
        display: none;
    }
    .scrollbar-none {
        -ms-overflow-style: none;
        scrollbar-width: none;
    }
    .pb-safe {
        padding-bottom: calc(0.5rem + env(safe-area-inset-bottom, 0px));
    }
</style>
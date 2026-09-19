<script lang="ts">
    import { onMount, tick, beforeUpdate, afterUpdate } from 'svelte';
    import { ChevronLeft, Paperclip, Mic, SendHorizontal, Loader2, Square, Settings, FileImage } from 'lucide-svelte';
    import { appState } from '../../stores/socketStore';
    import Message from "./partials/Message.svelte";
    import ChatSettingsModal from './ChatSettingsModal.svelte';
    import WebApp from "@twa-dev/sdk";

    let isChatSettingsOpen = false;

    // Локальный выбор пользователя до создания чата
    let pendingAiModelId: string | null = null;
    let pendingOverrides: {
        temperature: number;
        topP: number;
        frequencyPenalty: number;
        presencePenalty: number;
    } | null = null;

    // Реактивные значения: у pending, затем у активного чата, затем дефолт
    $: currentAiModelId = pendingAiModelId || $appState.active_chat?.ai_model_id || $appState.ai_model?.id || null;

    $: currentTemperature = pendingOverrides?.temperature ?? $appState.active_chat?.profile_overrides?.temperature ?? $appState.profile_overrides?.temperature ?? 0.7;
    $: currentTopP = pendingOverrides?.topP ?? $appState.active_chat?.profile_overrides?.top_p ?? $appState.profile_overrides?.top_p ?? 1.0;
    $: currentFrequencyPenalty = pendingOverrides?.frequencyPenalty ?? $appState.active_chat?.profile_overrides?.frequency_penalty ?? $appState.profile_overrides?.frequency_penalty ?? 0.0;
    $: currentPresencePenalty = pendingOverrides?.presencePenalty ?? $appState.active_chat?.profile_overrides?.presence_penalty ?? $appState.profile_overrides?.presence_penalty ?? 0.0;

    function handleAiModelSelect(event: CustomEvent<{
        aiModelId: string;
        temperature: number;
        topP: number;
        frequencyPenalty: number;
        presencePenalty: number;
    }>) {
        const { aiModelId, temperature, topP, frequencyPenalty, presencePenalty } = event.detail;
        const chatId = $appState.active_chat?.id;

        const overridesPayload = {
            temperature,
            top_p: topP,
            frequency_penalty: frequencyPenalty,
            presence_penalty: presencePenalty,
        };

        if (chatId) {
            // Чат существует — сразу шлём на бэк
            appState.send("chat:click_update_chat_insight", {
                chat_id: chatId,
                ai_model_id: aiModelId,
                profile_overrides: overridesPayload
            });
        } else {
            // Чата нет — запоминаем локально, чтобы передать при создании первого сообщения
            pendingAiModelId = aiModelId;
            pendingOverrides = { temperature, topP, frequencyPenalty, presencePenalty };
        }

        isChatSettingsOpen = false;
    }

    // =================================== Реактивные данные из стора ==================================================
    $: activeChat = $appState?.active_chat;
    $: messages = activeChat?.messages || [];
    $: isGenerating = messages.some(msg => msg.is_streaming === true) || false;
    $: lastStreamingAssistant = [...messages].reverse().find(
        m => m.role === 'assistant' && m.is_streaming === true
    );

    $: isAwaitingFirstToken = !!activeChat?.awaiting_response;

    $: isThink = !!lastStreamingAssistant && (lastStreamingAssistant.content || '').trim().length === 0;
    $: isTyping = !!lastStreamingAssistant && (lastStreamingAssistant.content || '').trim().length > 0;

    $: currentChatInfo = $appState?.chats_list.find(c =>
        c.id && activeChat?.id && String(c.id) === String(activeChat.id)
    );

    $: isThinking = messages.length > 0 && !activeChat?.title && !currentChatInfo?.title;
    $: chatName = activeChat?.title || currentChatInfo?.title || (isThinking ? "Придумываю название" : (activeChat ? "Новый чат" : "Ассистент"));

    // === Рефы ===
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
    let hasInitialScrollDone = false;
    let isNearBottom = true;

    let scrollState: { oldScrollHeight: number; expectedFirstId: string | number | null; } | null = null;
    let prevMessagesCount = 0;
    let prevLastId: string | number | null = null;

    // === Хелперы ===
    function formatTime(isoString: string): string {
        if (!isoString) return "";
        try { return new Date(isoString).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }); }
        catch (e) { return ""; }
    }

    function scrollToBottomImmediate() {
        if (scrollContainer) scrollContainer.scrollTop = scrollContainer.scrollHeight;
    }

    async function scrollToBottom() {
        await tick();
        scrollToBottomImmediate();
    }

    function handleScroll() {
        if (!scrollContainer) return;
        const distanceFromBottom = scrollContainer.scrollHeight - scrollContainer.scrollTop - scrollContainer.clientHeight;
        isNearBottom = distanceFromBottom < 150;
    }

    function setupObserver() {
        if (!scrollContainer || !topSentinel || observer) return;
        observer = new IntersectionObserver(
            (entries) => {
                if (entries[0].isIntersecting && isPaginationEnabled && !isLoadingMoreMessages && activeChat?.has_more_messages) {
                    loadMoreMessages();
                }
            },
            { root: scrollContainer, rootMargin: '720px 0px 0px 0px', threshold: 0 }
        );
        observer.observe(topSentinel);
    }

    function loadMoreMessages() {
        if (!scrollContainer || !activeChat?.has_more_messages || !isPaginationEnabled || isLoadingMoreMessages) return;
        isLoadingMoreMessages = true;
        scrollState = { oldScrollHeight: scrollContainer.scrollHeight, expectedFirstId: messages[0]?.id ?? null };

        const timeoutId = setTimeout(() => {
            if (isLoadingMoreMessages) { isLoadingMoreMessages = false; scrollState = null; }
        }, 10000);

        appState.send('chat:load_more_messages', { chat_id: String(activeChat.id) })
            .receive('ok', () => clearTimeout(timeoutId))
            .receive('error', () => { clearTimeout(timeoutId); scrollState = null; isLoadingMoreMessages = false; });
    }

    onMount(() => {
        setupObserver();
        return () => { if (observer) observer.disconnect(); };
    });

    beforeUpdate(() => {
        prevMessagesCount = messages.length;
        prevLastId = messages[messages.length - 1]?.id ?? null;
    });

    afterUpdate(() => {
        if (!scrollContainer) return;
        if (!hasInitialScrollDone && messages.length > 0) {
            scrollToBottomImmediate();
            hasInitialScrollDone = true;
            isPaginationEnabled = true;
            return;
        }
        if (isLoadingMoreMessages && scrollState) {
            const currentFirstId = messages[0]?.id ?? null;
            if (currentFirstId !== scrollState.expectedFirstId) {
                const heightDiff = scrollContainer.scrollHeight - scrollState.oldScrollHeight;
                if (heightDiff > 0) scrollContainer.scrollTop += heightDiff;
                scrollState = null;
                isLoadingMoreMessages = false;
            }
            return;
        }
        if (isGenerating && isNearBottom) { scrollToBottomImmediate(); return; }
        if (!isLoadingMoreMessages && messages.length > prevMessagesCount && messages[messages.length - 1]?.id !== prevLastId && isNearBottom) {
            scrollToBottomImmediate();
        }

        const lastMsg = messages[messages.length - 1];
        if (lastMsg?.error && isNearBottom) {
            scrollToBottomImmediate();
            return;
        }
    });

    $: if (newMessageText.trim().length > 0) { isAttachmentMenuOpen = false; }

    // ================================================= Отправка сообщения ============================================
    function handleSend() {
        const text = newMessageText.trim();
        if (!text) return;

        const chatId = $appState.active_chat?.id;

        // Собираем актуальные оверрайды: либо pending (если чат новый), либо текущие из стора
        const overridesToSend = pendingOverrides || {
            temperature: currentTemperature,
            topP: currentTopP,
            frequencyPenalty: currentFrequencyPenalty,
            presencePenalty: currentPresencePenalty
        };

        // Передаем 3 аргумента: текст, модель (только если чата нет), и оверрайды
        appState.sendMessage(text, chatId ? null : pendingAiModelId, overridesToSend);

        newMessageText = "";
        if (textareaElement) textareaElement.style.height = 'auto';
        isNearBottom = true;
        pendingOverrides = null;
        pendingAiModelId = null;
        scrollToBottom();
    }

    // ================================================= Стоп генерации модели =========================================

    function handleStop() {
        const chatId = $appState.active_chat?.id;

        if (!chatId || !isGenerating) return;

        if (WebApp.HapticFeedback) {
            WebApp.HapticFeedback.impactOccurred('medium');
        }

        appState.stopGeneration(chatId);
    }

    function handleKeyDown(event: KeyboardEvent) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            if (isGenerating) return;
            handleSend();
        }
    }

    function toggleAttachmentMenu() { isAttachmentMenuOpen = !isAttachmentMenuOpen; }

    function autoGrow() {
        if (!textareaElement) return;
        textareaElement.style.height = 'auto';
        const newHeight = Math.min(textareaElement.scrollHeight, 120);
        textareaElement.style.height = `${newHeight}px`;
    }

    function handleClose() { isChatSettingsOpen = false; }
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
                {#if isTyping}
                    <span class="inline-flex items-center gap-1">
                        <span class="animate-pulse">typing</span>
                        <span class="flex gap-0.5">
                            <span class="w-1 h-1 bg-current rounded-full animate-bounce" style="animation-delay: 0s"></span>
                            <span class="w-1 h-1 bg-current rounded-full animate-bounce" style="animation-delay: 0.2s"></span>
                            <span class="w-1 h-1 bg-current rounded-full animate-bounce" style="animation-delay: 0.4s"></span>
                        </span>
                    </span>
                {:else if isThink}
                    <span class="inline-flex items-center gap-1">
                        <span class="animate-pulse">thinking</span>
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

        <div
                on:click={() => {
               isChatSettingsOpen = true;
               if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('light');
            }}
                class="p-2 bg-white/5 rounded-xl text-gray-400 hover:text-white hover:bg-white/10 transition-all flex items-center justify-center flex-shrink-0 active:scale-95 cursor-pointer"
        >
            <Settings size={24} strokeWidth={2.5} />
        </div>
    </header>

    <!-- ЗОНА СООБЩЕНИЙ -->
    <div
            bind:this={scrollContainer}
            on:scroll={handleScroll}
            class="flex-1 py-4 px-3 flex flex-col gap-2 scrollbar-none {isLoadingMoreMessages ? 'overflow-y-hidden' : 'overflow-y-auto'}"
            style="overflow-anchor: none; overscroll-behavior-y: contain;"
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

        {#if isAwaitingFirstToken}
            <button
                    disabled
                    class="p-2 flex items-center justify-center flex-shrink-0 text-gray-500 cursor-not-allowed"
                    title="Ожидание ответа"
            >
                <Loader2 size={20} class="animate-spin" />
            </button>
        {:else if isGenerating}
            <button
                    on:click={handleStop}
                    class="p-2 flex items-center justify-center flex-shrink-0 transition-all
            {isTyping ? 'text-red-400 hover:text-red-300 hover:scale-105 active:scale-95' : 'text-gray-500 hover:text-gray-400'}"
                    title={isTyping ? "Остановить генерацию" : "Отменить запрос"}
            >
                <Square size={20} strokeWidth={2.5} fill={isTyping ? "currentColor" : "none"} />
            </button>
        {:else if newMessageText.trim().length > 0}
            <button on:click={handleSend} class="text-[#2481cc] hover:scale-105 active:scale-95 transition-all p-2 flex items-center justify-center flex-shrink-0">
                <SendHorizontal size={20} />
            </button>
        {:else}
            <button class="text-gray-500 p-2 flex-shrink-0 cursor-not-allowed" disabled>
                <SendHorizontal size={20} />
            </button>
        {/if}
    </footer>

    <!-- Шторка выбора ChatSettings -->
    <ChatSettingsModal
            bind:isOpen={isChatSettingsOpen}
            currentAiModelId={currentAiModelId}
            currentFrequencyPenalty={currentFrequencyPenalty}
            currentPresencePenalty={currentPresencePenalty}
            currentTopP={currentTopP}
            currentTemperature={currentTemperature}
            currentTier={$appState.user?.status || 'free'}
            on:apply={handleAiModelSelect}
            on:close={handleClose}
    />
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
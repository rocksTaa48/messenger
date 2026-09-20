<script lang="ts">
    import { onMount, onDestroy, tick, beforeUpdate, afterUpdate } from 'svelte';
    import { ChevronLeft, Mic, SendHorizontal, Loader2, Square, Settings, Play, Pause, X } from 'lucide-svelte';
    import { appState } from '../../stores/socketStore';
    import Message from "./partials/Message.svelte";
    import ChatSettingsModal from './ChatSettingsModal.svelte';
    import WebApp from "@twa-dev/sdk";

    let isChatSettingsOpen = false;

    let pendingAiModelId: string | null = null;
    let pendingOverrides: {
        temperature: number;
        topP: number;
        frequencyPenalty: number;
        presencePenalty: number;
    } | null = null;

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
            temperature, top_p: topP,
            frequency_penalty: frequencyPenalty,
            presence_penalty: presencePenalty,
        };
        if (chatId) {
            appState.send("chat:click_update_chat_insight", {
                chat_id: chatId, ai_model_id: aiModelId, profile_overrides: overridesPayload
            });
        } else {
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

    // === Скролл / подгрузка ===
    let isLoadingMoreMessages = false;
    let isPaginationEnabled = false;
    let observer: IntersectionObserver | null = null;
    let hasInitialScrollDone = false;
    let isNearBottom = true;
    let scrollState: { oldScrollHeight: number; expectedFirstId: string | number | null; } | null = null;
    let prevMessagesCount = 0;
    let prevLastId: string | number | null = null;

    // ================================================= АУДИОЗАПИСЬ ==================================================
    const MAX_RECORDING_SECONDS = 60;

    let isRecording = false;
    let mediaRecorder: MediaRecorder | null = null;
    let mediaStream: MediaStream | null = null;
    let audioChunks: Blob[] = [];
    let recordedAudioBlob: Blob | null = null;
    let recordedAudioUrl: string | null = null;
    let recordedDuration = 0;
    let recordingElapsed = 0;
    let recordingTimer: ReturnType<typeof setInterval> | null = null;

    // Воспроизведение
    let audioPlayer: HTMLAudioElement | null = null;
    let isPlaying = false;
    let playbackProgress = 0;
    let waveformBars: number[] = [];

    function generateWaveform() {
        waveformBars = Array.from({ length: 32 }, () => 20 + Math.random() * 80);
    }

    async function startRecording() {
        if (isRecording) return;
        try {
            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
            mediaStream = stream;

            let mimeType = 'audio/webm';
            if (typeof MediaRecorder !== 'undefined') {
                if (MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) mimeType = 'audio/webm;codecs=opus';
                else if (MediaRecorder.isTypeSupported('audio/mp4')) mimeType = 'audio/mp4';
            }

            mediaRecorder = new MediaRecorder(stream, { mimeType });
            audioChunks = [];

            mediaRecorder.ondataavailable = (e: BlobEvent) => {
                if (e.data.size > 0) audioChunks.push(e.data);
            };

            mediaRecorder.onstop = () => {
                const blob = new Blob(audioChunks, { type: mimeType });
                recordedAudioBlob = blob;
                recordedAudioUrl = URL.createObjectURL(blob);
                recordedDuration = Math.max(1, recordingElapsed);
                generateWaveform();
                audioChunks = [];
                stopTracks();
            };

            mediaRecorder.start();
            isRecording = true;
            recordingElapsed = 0;

            recordingTimer = setInterval(() => {
                recordingElapsed += 1;
                if (recordingElapsed >= MAX_RECORDING_SECONDS) stopRecording();
            }, 1000);

            if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('medium');
        } catch (e) {
            console.error('Recording error:', e);
            isRecording = false;
            stopTracks();
        }
    }

    function stopRecording() {
        if (recordingTimer) { clearInterval(recordingTimer); recordingTimer = null; }
        if (mediaRecorder && mediaRecorder.state !== 'inactive') mediaRecorder.stop();
        isRecording = false;
    }

    function stopTracks() {
        if (mediaStream) {
            mediaStream.getTracks().forEach(t => t.stop());
            mediaStream = null;
        }
    }

    function togglePlayback() {
        if (!recordedAudioUrl) return;
        if (!audioPlayer) {
            audioPlayer = new Audio(recordedAudioUrl);
            audioPlayer.addEventListener('timeupdate', () => {
                if (audioPlayer && audioPlayer.duration) {
                    playbackProgress = (audioPlayer.currentTime / audioPlayer.duration) * 100;
                }
            });
            audioPlayer.addEventListener('ended', () => {
                isPlaying = false;
                playbackProgress = 0;
                if (audioPlayer) audioPlayer.currentTime = 0;
            });
        }
        if (isPlaying) {
            audioPlayer.pause();
            isPlaying = false;
        } else {
            audioPlayer.play();
            isPlaying = true;
        }
    }

    function removeAudio() {
        if (audioPlayer) {
            audioPlayer.pause();
            audioPlayer.src = '';
            audioPlayer = null;
        }
        if (recordedAudioUrl) URL.revokeObjectURL(recordedAudioUrl);
        recordedAudioBlob = null;
        recordedAudioUrl = null;
        recordedDuration = 0;
        isPlaying = false;
        playbackProgress = 0;
        waveformBars = [];
    }

    function formatDuration(seconds: number): string {
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return `${m}:${s.toString().padStart(2, '0')}`;
    }

    // ================================================= Хелперы ======================================================
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

    onDestroy(() => {
        stopRecording();
        stopTracks();
        if (recordingTimer) clearInterval(recordingTimer);
        if (audioPlayer) { audioPlayer.pause(); audioPlayer = null; }
        if (recordedAudioUrl) URL.revokeObjectURL(recordedAudioUrl);
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
        if (isAwaitingFirstToken && isNearBottom) { scrollToBottomImmediate(); return; }
        if (isGenerating && isNearBottom) { scrollToBottomImmediate(); return; }
        if (!isLoadingMoreMessages && messages.length > prevMessagesCount && messages[messages.length - 1]?.id !== prevLastId && isNearBottom) {
            scrollToBottomImmediate();
        }
        const lastMsg = messages[messages.length - 1];
        if (lastMsg?.error && isNearBottom) { scrollToBottomImmediate(); return; }
    });

    function handleSend() {
        const text = newMessageText.trim();
        if (!text) return;
        const chatId = $appState.active_chat?.id;
        const overridesToSend = pendingOverrides || {
            temperature: currentTemperature,
            topP: currentTopP,
            frequencyPenalty: currentFrequencyPenalty,
            presencePenalty: currentPresencePenalty
        };
        appState.sendMessage(text, chatId ? null : pendingAiModelId, overridesToSend);
        newMessageText = "";
        if (textareaElement) textareaElement.style.height = 'auto';
        isNearBottom = true;
        pendingOverrides = null;
        pendingAiModelId = null;
        scrollToBottom();
    }

    function handleStop() {
        const chatId = $appState.active_chat?.id;
        if (!chatId || !isGenerating) return;
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('medium');
        appState.stopGeneration(chatId);
    }

    function handleKeyDown(event: KeyboardEvent) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            if (isGenerating) return;
            handleSend();
        }
    }

    function handleSendAudio() {
        if (!recordedAudioBlob) return;

        const chatId = $appState.active_chat?.id;

        const overridesToSend = pendingOverrides || {
            temperature: currentTemperature,
            topP: currentTopP,
            frequencyPenalty: currentFrequencyPenalty,
            presencePenalty: currentPresencePenalty
        };

        appState.sendVoiceMessage(
            recordedAudioBlob,
            chatId ? null : pendingAiModelId,
            overridesToSend
        );

        removeAudio();
        isNearBottom = true;
        pendingOverrides = null;
        pendingAiModelId = null;
        scrollToBottom();
    }

    function autoGrow() {
        if (!textareaElement) return;
        textareaElement.style.height = 'auto';
        const newHeight = Math.min(textareaElement.scrollHeight, 120);
        textareaElement.style.height = `${newHeight}px`;
    }

    function handleClose() { isChatSettingsOpen = false; }
</script>
<div class="relative flex flex-col h-full w-full min-w-0 bg-[#0f0f0f] rounded-[24px] text-white font-sans overflow-hidden">

    <!-- ШАПКА ЧАТА — -->
    <header class="absolute top-0 left-0 right-0 z-30 px-3 pt-3 pb-2 flex items-center gap-2 pointer-events-none">
        <div
                on:click={() => appState.goBack()}
                class="pointer-events-auto cursor-pointer w-11 h-11 rounded-full bg-[#0f0f0f]/60 backdrop-blur-xl border border-white/5 shadow-lg shadow-black/30 text-[#2481cc] hover:bg-[#2c2c2e]/80 active:scale-95 transition-all flex items-center justify-center flex-shrink-0"
        >
            <span class="mr-0.75 px-3.5 py-3.5">
                <ChevronLeft size={22} strokeWidth={2.5} />
            </span>
        </div>

        <div class="pointer-events-auto flex-1 min-w-0 h-11 rounded-full bg-[#0f0f0f]/60 backdrop-blur-xl border border-white/5 shadow-lg shadow-black/30 flex items-center justify-center px-5">
            <div class="flex flex-col items-center min-w-0 leading-tight">
                <span class="text-[13px] font-bold tracking-tight truncate max-w-full transition-all duration-300 {isThinking ? 'text-[#2481cc]/80 animate-pulse' : 'text-white'}">
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
        </div>

        <div
                on:click={() => {
                    isChatSettingsOpen = true;
                    if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('light');
                }}
                class="pointer-events-auto w-11 h-11 rounded-full bg-[#0f0f0f]/60 backdrop-blur-xl border border-white/5 shadow-lg shadow-black/30 text-gray-400 hover:text-white hover:bg-[#2c2c2e]/80 active:scale-95 transition-all flex items-center justify-center flex-shrink-0 cursor-pointer"
        >
            <Settings size={20} strokeWidth={2.5} />
        </div>
    </header>

    <!-- ЗОНА СООБЩЕНИЙ -->
    <div
            bind:this={scrollContainer}
            on:scroll={handleScroll}
            class="flex-1 scrollbar-none {isLoadingMoreMessages ? 'overflow-y-hidden' : 'overflow-y-auto'}"
            style="overflow-anchor: none; overscroll-behavior-y: contain;"
    >
        <!-- pt-[68px] — под хедер; pb-[...] — под футер (его высота + safe-area) -->
        <div class="px-3 pt-[68px] pb-[calc(72px+env(safe-area-inset-bottom,0px))] flex flex-col gap-2">
            <div bind:this={topSentinel} class="h-2 w-full flex-shrink-0">
                {#if isLoadingMoreMessages && activeChat?.has_more_messages}
                    <div class="flex justify-center py-3">
                        <span class="text-gray-500 text-xs animate-pulse">Загрузка истории...</span>
                    </div>
                {/if}
            </div>

            <Message {messages} {formatTime} />
        </div>
    </div>

    <!-- ФУТЕР -->
    <footer class="absolute bottom-0 left-0 right-0 z-30 w-full px-3 pt-2 pb-2 bg-[#0f0f0f]/60 backdrop-blur-xl border-t border-white/5 flex items-end gap-2 pb-safe">

        <div class="flex-1 bg-[#121212]/30 border border-white/5 rounded-[20px] px-3.5 py-2 flex items-center gap-2 focus-within:border-[#2481cc]/30 transition-all min-h-[44px]">

            {#if isRecording}
                <div class="flex-1 flex items-center gap-2 h-7 select-none">
                    <div class="w-2 h-2 bg-red-500 rounded-full animate-pulse flex-shrink-0"></div>
                    <span class="text-red-400 text-sm font-medium whitespace-nowrap flex-shrink-0">Запись</span>
                    <span class="text-white text-sm font-mono ml-auto flex-shrink-0">{formatDuration(recordingElapsed)}</span>
                    <span class="text-gray-500 text-xs flex-shrink-0">/ {formatDuration(MAX_RECORDING_SECONDS)}</span>
                </div>
            {:else if recordedAudioBlob}
                <div class="flex-1 flex items-center gap-2 h-7 select-none">
                    <button
                            on:click={togglePlayback}
                            class="w-7 h-7 rounded-full bg-[#2481cc] hover:bg-[#1f6fb0] active:scale-95 transition-all flex items-center justify-center flex-shrink-0 overflow-hidden"
                            title={isPlaying ? "Пауза" : "Прослушать"}
                    >
                        {#if isPlaying}
                            <span class="w-3.5 h-3.5 flex items-center justify-center">
                                <Pause size={12} fill="white" class="text-white" />
                            </span>
                        {:else}
                            <span class="w-3.5 h-3.5 flex items-center justify-center">
                                <Play size={12} fill="white" class="text-white" />
                            </span>
                        {/if}
                    </button>

                    <div class="flex-1 flex items-center gap-[2px] h-full overflow-hidden">
                        {#each waveformBars as h, i}
                            <div
                                    class="w-[2px] rounded-full transition-colors {(i / waveformBars.length) * 100 <= playbackProgress ? 'bg-[#2481cc]' : 'bg-white/25'}"
                                    style="height: {h}%"
                            ></div>
                        {/each}
                    </div>

                    <span class="text-[10px] text-gray-400 font-mono flex-shrink-0 whitespace-nowrap">
                        {formatDuration(recordedDuration)}
                    </span>

                    <button
                            on:click={removeAudio}
                            class="text-gray-500 hover:text-white transition-colors flex-shrink-0 p-1 flex items-center justify-center -mr-1"
                            title="Удалить"
                    >
                        <X size={14} />
                    </button>
                </div>
            {:else}
                <textarea
                        bind:this={textareaElement}
                        bind:value={newMessageText}
                        on:input={autoGrow}
                        on:keydown={handleKeyDown}
                        rows="1"
                        placeholder="Message"
                        class="flex-1 bg-transparent text-base font-medium focus:outline-none placeholder-gray-600 text-white resize-none h-7 max-h-[120px] py-0.5 leading-relaxed scrollbar-none block"
                ></textarea>
            {/if}
        </div>

        <div class="w-[40px] h-[40px] flex items-center justify-center flex-shrink-0 mb-[2px]">
            {#if isRecording}
                <button
                        on:click={stopRecording}
                        class="p-2 flex items-center justify-center active:scale-95 transition-all"
                        title="Остановить запись"
                >
                    <div class="w-6 h-6 bg-[#2481cc] rounded-md flex items-center justify-center shadow-lg shadow-[#2481cc]/30">
                        <div class="w-2.5 h-2.5 bg-white rounded-[2px]"></div>
                    </div>
                </button>
            {:else if recordedAudioBlob}
                <button
                        on:click={handleSendAudio}
                        class="text-[#2481cc] hover:scale-105 active:scale-95 transition-all p-2 flex items-center justify-center"
                        title="Отправить аудио"
                >
                    <SendHorizontal size={20} />
                </button>
            {:else if isAwaitingFirstToken}
                <button disabled class="p-2 flex items-center justify-center text-gray-500 cursor-not-allowed" title="Ожидание ответа">
                    <Loader2 size={20} class="animate-spin" />
                </button>
            {:else if isGenerating}
                <button
                        on:click={handleStop}
                        class="p-2 flex items-center justify-center transition-all
                {isTyping ? 'text-red-400 hover:text-red-300 hover:scale-105 active:scale-95' : 'text-gray-500 hover:text-gray-400'}"
                        title={isTyping ? "Остановить генерацию" : "Отменить запрос"}
                >
                    <Square size={20} strokeWidth={2.5} fill={isTyping ? "currentColor" : "none"} />
                </button>
            {:else if newMessageText.trim().length > 0}
                <button
                        on:click={handleSend}
                        class="text-[#2481cc] hover:scale-105 active:scale-95 transition-all p-2 flex items-center justify-center"
                        title="Отправить"
                >
                    <SendHorizontal size={20} />
                </button>
            {:else}
                <button
                        on:click={startRecording}
                        class="text-[#2481cc] hover:scale-105 active:scale-95 transition-all p-2 flex items-center justify-center"
                        title="Записать аудио"
                >
                    <Mic size={20} />
                </button>
            {/if}
        </div>
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
    .scrollbar-none::-webkit-scrollbar { display: none; }
    .scrollbar-none { -ms-overflow-style: none; scrollbar-width: none; }
    .pb-safe { padding-bottom: calc(0.5rem + env(safe-area-inset-bottom, 0px)); }
</style>
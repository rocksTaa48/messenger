<script lang="ts">
    import {MicVocal, Ban, RotateCw} from 'lucide-svelte';
    import { renderMarkdown } from '../../markdown';
    import Icons from './Icons.svelte';
    import { appState } from '../../../stores/socketStore';
    import {sendImageToTelegram} from '../../../stores/sockets/chat'
    import { createEventDispatcher } from 'svelte';


    export let messages: Array<{
        id: string | number;
        role: string;
        content: string;
        created_at: string;
        is_streaming?: boolean;
        is_audio?: boolean;
        is_aborted?: boolean;
        error?: boolean;
        is_pending?: boolean;
        temp_id?: string;
        ai_model_id: number | string;
        // image section
        image_url?: string;
        image_media_type?: string;
        image_error?: string;
        image_width?: number;
        image_height?: number;
    }>;
    export let aiModels: Array<any> = [];
    export let isImageSession: boolean = false;

    $: awaiting = $appState?.active_chat?.awaiting_response ?? false;
    $: activeModelId = $appState?.active_chat?.ai_model_id;
    $: lastErrorReason = $appState?.active_chat?.last_error_reason ?? null;

    // Единый источник правды для показа системного error-бабла.
    // Derived из структуры messages — работает одинаково при живом стриме и после перезахода.
    $: lastMsg = messages.length > 0 ? messages[messages.length - 1] : null;
    $: showRetryBubble = !awaiting
        && !isImageSession
        && !!lastMsg
        && lastMsg.role === 'user'
        && !lastMsg.is_pending
        && !String(lastMsg.id).startsWith('temp-');

    $: errorText = lastErrorReason === 'aborted_empty'
        ? '😕 Генерация прервана до ответа'
        : '😩 Не удалось получить ответ';

    $: errorTone = lastErrorReason === 'aborted_empty'
        ? 'text-yellow-400/80'
        : 'text-red-400/80';

    const dispatch = createEventDispatcher();

    function getProvider(modelId: number | string | undefined): string {
        if (!modelId) return 'default';
        const model = aiModels.find(m => String(m.id) === String(modelId));
        return model?.provider || 'default';
    }

    function handleRetryImage(messageId: string | number) {
        appState.retryImage(messageId);
    }

    function formatTime(isoString: string): string {
        if (!isoString) return "";
        try {
            const date = new Date(isoString);
            const day = date.getDate();
            const month = date.toLocaleString('ru-RU', { month: 'short' }).replace('.', '');
            const time = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
            return `${day} ${month}, ${time}`;
        } catch (e) {
            return "";
        }
    }

    function handleContentClick(event: MouseEvent) {
        const target = event.target as HTMLElement;
        const btn = target.closest('[data-copy-code]') as HTMLButtonElement | null;
        if (!btn) return;

        const container = btn.closest('.code-block, .copy-block');
        if (!container) return;

        const source = container.querySelector('pre code') || container.querySelector('[data-copy-source]');
        if (!source) return;

        const text = source.textContent || '';

        navigator.clipboard.writeText(text).then(() => {
            const label = btn.querySelector('span');
            const prev = label?.textContent ?? 'Копировать';
            if (label) label.textContent = 'Скопировано';
            btn.classList.add('is-copied');
            setTimeout(() => {
                if (label) label.textContent = prev;
                btn.classList.remove('is-copied');
            }, 1500);
        }).catch(e => console.warn('copy failed', e));
    }

    function handleRetry() {
        appState.retryLastMessage();
    }

    function handleSendToTelegram(msg: any) {
        sendImageToTelegram(msg.image_url);
    }

</script>

{#each messages as msg (msg.id)}
    {#if msg.role === 'assistant' && !msg.error}
        <div class="group flex w-full flex-col items-start max-w-[85%] mb-4">
            <!-- Аватарка модели -->
            <div class="w-8 h-8 rounded-full bg-[#2481cc] flex items-center justify-center text-white shadow-sm mb-2">
                <Icons provider={getProvider(msg.ai_model_id)} size={16} />
            </div>

            {#if msg.image_url}
                <div
                        class="relative w-full max-w-[280px] rounded-[20px] overflow-hidden border border-white/5 shadow-md bg-black/20"
                        style={msg.image_width && msg.image_height ? `aspect-ratio: ${msg.image_width} / ${msg.image_height};` : 'aspect-ratio: 1 / 1;'}
                >
                    <img
                            src={msg.image_url}
                            alt="Generated image"
                            loading="eager"
                            class="block w-full h-full object-cover animate-reveal"
                            on:load={() => dispatch('imageLoaded')}
                    />

                    <!-- Оверлей с временем -->
                    <div class="absolute bottom-2 left-2 right-2 flex items-center justify-between">
                        <!-- Время слева -->
                        <div class="px-2 py-1 rounded-full bg-black/40 backdrop-blur-md text-[9px] font-bold text-white/70">
                            {formatTime(msg.created_at)}
                        </div>

                        <!-- Кнопка скачивания справа (ДОРАБОТАЙ URL НА ОРИГИНАЛ!!!!!!) -->
                        {#if msg.image_url}
                            <button
                                    type="button"
                                    on:click={() => handleSendToTelegram(msg)}
                                    class="w-7 h-7 rounded-full bg-black/40 backdrop-blur-md flex items-center justify-center text-white/70 hover:text-white hover:bg-black/60 active:scale-95 transition-all flex-shrink-0"
                                    title="Отправить в Telegram"
                            >
                                <svg class="w-3.5 h-3.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                                </svg>
                            </button>
                        {/if}
                    </div>
                </div>

            {:else if msg.is_pending && isImageSession}
                <div
                        class="w-full max-w-[280px] rounded-[20px] border border-white/5 bg-white/[0.03] p-1.5 flex flex-col relative overflow-hidden"
                        style={msg.image_width && msg.image_height ? `aspect-ratio: ${msg.image_width} / ${msg.image_height};` : 'aspect-ratio: 1 / 1;'}
                >
                    <!-- Эффект бегущего диагонального градиента -->
                    <div class="absolute inset-0 -translate-x-full animate-shimmer bg-gradient-to-r from-transparent via-white/[0.04] to-transparent skew-x-12"></div>

                    <!-- Внутренняя рамка с иконкой -->
                    <div class="flex-1 bg-white/[0.02] rounded-[14px] flex items-center justify-center relative z-10">
                        <svg class="w-8 h-8 text-white/10" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 002-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                        </svg>
                    </div>
                </div>

            {:else if msg.image_error}
                <!-- 3. Произошла ошибка при генерации -->
                <div class="w-full px-4 py-2.5 text-xs font-medium border rounded-[20px] relative break-words shadow-md text-left bg-white/[0.03] border-white/5 text-gray-200 rounded-tl-sm">
                    <div class="leading-relaxed italic flex items-center justify-between gap-2">
                        <span class="text-red-400/80">{msg.image_error}</span>
                        <button
                                type="button"
                                on:click={() => handleRetryImage(msg.id)}
                                class="inline-flex items-center justify-center w-8 h-8 rounded-full bg-white/5 hover:bg-white/10 active:bg-white/15 text-gray-300 hover:text-white transition-colors shrink-0"
                                title="Повторить"
                        >
                            <RotateCw size={16} strokeWidth={2.5} />
                        </button>
                    </div>
                </div>

            {:else}
                <!-- 4. Фоллбэк: Обычный текстовый ответ (или стриминг) -->
                <div class="w-full px-4 py-2.5 text-xs font-medium border rounded-[20px] relative break-words shadow-md text-left bg-white/[0.03] border-white/5 text-gray-200 rounded-tl-sm">
                    <div class="message-content" on:click={handleContentClick}>
                        {#if msg.is_streaming}
                            <p class="leading-relaxed whitespace-pre-wrap">{msg.content}</p>
                        {:else}
                            {@html renderMarkdown(msg.content)}
                        {/if}
                    </div>

                    <div class="flex items-center justify-between gap-2 mt-1 select-none">
                        <span class="text-[9px] font-bold opacity-40">{formatTime(msg.created_at)}</span>
                        {#if msg.is_aborted}
                            <span class="text-[9px] font-bold opacity-40">
                                <Ban size={12} strokeWidth={2.5} />
                            </span>
                        {/if}
                    </div>
                </div>
            {/if}
        </div>

    {:else if msg.role === 'user'}
        <!-- Пользовательское сообщение (текст или аудио) -->
        <div class="group flex flex-col items-end w-full mb-4 gap-1">
            <div class="max-w-[85%] px-4 py-2.5 text-xs font-medium border rounded-[20px] relative break-words shadow-md text-left bg-[#2481cc]/20 border-[#2481cc]/30 text-white rounded-tr-sm">
                <div class="message-content" on:click={handleContentClick}>
                    <p class="leading-relaxed whitespace-pre-wrap">{msg.content}</p>
                </div>

                <div class="flex items-center justify-between gap-2 mt-1 select-none">
                    <span class="text-[9px] font-bold opacity-40">{formatTime(msg.created_at)}</span>
                    {#if msg.is_audio}
                        <span class="text-[9px] font-bold opacity-40">
                            <MicVocal size={12} strokeWidth={2.5} />
                        </span>
                    {/if}
                </div>
            </div>
        </div>
    {/if}
{/each}


<!-- ЕДИНЫЙ системный error-бабл слева: и при живом стриме, и на перезаходе -->
{#if showRetryBubble}
    <div class="group flex w-full flex-col items-start max-w-[85%] mb-4">
        <div class="w-8 h-8 rounded-full bg-[#2481cc] flex items-center justify-center text-white shadow-sm mb-2">
            <Icons provider={getProvider(activeModelId)} size={16} />
        </div>

        <div class="w-full px-4 py-2.5 text-xs font-medium border rounded-[20px] relative break-words shadow-md text-left bg-white/[0.03] border-white/5 text-gray-200 rounded-tl-sm">
            <div class="leading-relaxed italic flex items-center justify-between gap-2">
                <span class={errorTone}>{errorText}</span>
                <button
                        type="button"
                        on:click={handleRetry}
                        class="inline-flex items-center justify-center w-8 h-8 rounded-full bg-white/5 hover:bg-white/10 active:bg-white/15 text-gray-300 hover:text-white transition-colors shrink-0"
                        aria-label="Повторить"
                        title="Повторить"
                >
                    <span class="px-3 py-3">
                        <RotateCw size={16} strokeWidth={2.5} />
                    </span>
                </button>
            </div>
        </div>
    </div>
{/if}


<style>
    /* Сброс отступов по краям бабла — иначе первый/последний <p> раздувают пузырь */
    .message-content :global(> *:first-child) { margin-top: 0; }
    .message-content :global(> *:last-child)  { margin-bottom: 0; }

    .message-content :global(p) {
        margin: 0.35rem 0;
        line-height: 1.6;
    }

    .message-content :global(ul),
    .message-content :global(ol) {
        margin: 0.35rem 0;
        padding-left: 1.15rem;
    }
    .message-content :global(ul) { list-style: disc; }
    .message-content :global(ol) { list-style: decimal; }
    .message-content :global(li) { margin: 0.15rem 0; }
    .message-content :global(li > p) { margin: 0; }

    .message-content :global(code) {
        background: rgba(255,255,255,0.08);
        padding: 0.1rem 0.35rem;
        border-radius: 4px;
        font-size: 0.85em;
        font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    }
    .message-content :global(pre) {
        background: rgba(0,0,0,0.4);
        padding: 0.75rem 1rem;
        border-radius: 12px;
        overflow-x: auto;
        margin: 0.5rem 0;
        font-size: 0.8em;
    }
    .message-content :global(pre code) {
        background: transparent;
        padding: 0;
        font-size: 1em;
    }

    .message-content :global(a) {
        color: #4ea6ea;
        text-decoration: underline;
        text-underline-offset: 2px;
        word-break: break-all;
    }

    .message-content :global(blockquote) {
        border-left: 3px solid rgba(255,255,255,0.2);
        padding-left: 0.75rem;
        color: rgba(255,255,255,0.7);
        margin: 0.5rem 0;
    }

    .message-content :global(h1),
    .message-content :global(h2),
    .message-content :global(h3),
    .message-content :global(h4) {
        font-weight: 700;
        margin: 0.6rem 0 0.3rem;
        line-height: 1.3;
    }
    .message-content :global(h1) { font-size: 1.15em; }
    .message-content :global(h2) { font-size: 1.05em; }
    .message-content :global(h3) { font-size: 1em; }
    .message-content :global(h4) { font-size: 0.95em; }

    .message-content :global(hr) {
        border: none;
        border-top: 1px solid rgba(255,255,255,0.1);
        margin: 0.75rem 0;
    }

    .message-content :global(table) {
        border-collapse: collapse;
        margin: 0.5rem 0;
        font-size: 0.9em;
        display: block;
        overflow-x: auto;
        max-width: 100%;
    }
    .message-content :global(th),
    .message-content :global(td) {
        border: 1px solid rgba(255,255,255,0.15);
        padding: 0.35rem 0.6rem;
        text-align: left;
    }
    .message-content :global(th) {
        background: rgba(255,255,255,0.05);
        font-weight: 600;
    }

    .message-content :global(img) {
        max-width: 100%;
        border-radius: 8px;
        margin: 0.35rem 0;
    }

    .message-content :global(.code-block) {
        margin: 0.6rem 0;
        border: 1px solid rgba(255,255,255,0.08);
        border-radius: 12px;
        overflow: hidden;
        background: rgba(0,0,0,0.4);
    }

    .message-content :global(.code-block__header) {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 0.35rem 0.6rem;
        background: rgba(255,255,255,0.03);
        border-bottom: 1px solid rgba(255,255,255,0.06);
        font-size: 0.7em;
    }

    .message-content :global(.code-block__lang) {
        color: rgba(255,255,255,0.5);
        font-family: ui-monospace, monospace;
        text-transform: lowercase;
        letter-spacing: 0.02em;
    }

    .message-content :global(.code-block__copy) {
        display: inline-flex;
        align-items: center;
        gap: 0.35rem;
        padding: 0.2rem 0.5rem;
        border-radius: 6px;
        color: rgba(255,255,255,0.6);
        background: transparent;
        transition: background 120ms ease, color 120ms ease;
        cursor: pointer;
        font-size: 1em;
    }
    .message-content :global(.code-block__copy:hover) {
        background: rgba(255,255,255,0.08);
        color: #fff;
    }
    .message-content :global(.code-block__copy--ok) {
        color: #4ade80;
    }

    .message-content :global(.code-block pre) {
        margin: 0;
        border-radius: 0;
        background: transparent;
    }

    .message-content :global(.copy-block) {
        margin: 0.6rem 0;
        border: 1px solid rgba(255,255,255,0.08);
        border-radius: 12px;
        overflow: hidden;
        background: rgba(255,255,255,0.02);
    }

    .message-content :global(.copy-block__header) {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 0.35rem 0.6rem;
        background: rgba(255,255,255,0.03);
        border-bottom: 1px solid rgba(255,255,255,0.06);
        font-size: 0.7em;
    }

    .message-content :global(.copy-block__label) {
        color: rgba(255,255,255,0.5);
        letter-spacing: 0.04em;
        text-transform: uppercase;
        font-weight: 600;
    }

    .message-content :global(.copy-block__btn) {
        display: inline-flex;
        align-items: center;
        gap: 0.35rem;
        padding: 0.2rem 0.5rem;
        border-radius: 6px;
        color: rgba(255,255,255,0.6);
        background: transparent;
        transition: background 120ms ease, color 120ms ease;
        cursor: pointer;
        font-size: 1em;
    }
    .message-content :global(.copy-block__btn:hover) {
        background: rgba(255,255,255,0.08);
        color: #fff;
    }
    .message-content :global(.copy-block__btn.is-copied) {
        color: #4ade80;
    }

    /* Тело — обычный читаемый текст, не monospace */
    .message-content :global(.copy-block__body) {
        padding: 0.75rem 1rem;
        white-space: pre-wrap;
        word-break: break-word;
        line-height: 1.55;
        color: #e5e7eb;
        font-size: 1em;
        font-family: inherit;
    }

    .message-content :global(strong) { font-weight: 700; color: #fff; }
    .message-content :global(em) { font-style: italic; }

    @keyframes shimmer {
        100% {
            transform: translateX(200%) skewX(12deg);
        }
    }

    .animate-shimmer {
        /* Начинаем движение за пределами карточки слева */
        transform: translateX(-100%) skewX(12deg);
        animation: shimmer 1.6s infinite linear;
    }

    img {
        opacity: 0;
        filter: blur(8px);
        transform: scale(0.98);
        animation: revealImage 0.5s cubic-bezier(0.22, 1, 0.36, 1) forwards;
    }

    @keyframes revealImage {
        to {
            opacity: 1;
            filter: blur(0);
            transform: scale(1);
        }
    }
</style>
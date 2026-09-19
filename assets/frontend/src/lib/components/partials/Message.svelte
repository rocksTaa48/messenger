<script lang="ts">
    import { Copy, Check } from 'lucide-svelte';
    import { renderMarkdown } from '../../markdown';
    import Icons from './Icons.svelte';
    import { appState } from '../../../stores/socketStore';

    export let messages: Array<{
        id: string | number;
        role: string;
        content: string;
        created_at: string;
        is_streaming?: boolean;
        ai_model_id: number | string;
    }>;

    // Достаем массив моделей из стора
    $: aiModels = $appState?.ai_models || [];

    // Функция поиска провайдера по ID модели из стора
    function getProvider(modelId: number | string | undefined): string {
        if (!modelId) return 'default';
        const model = aiModels.find(m => String(m.id) === String(modelId));
        return model?.provider || 'default';
    }

    let copiedId: string | number | null = null;

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
</script>

{#each messages as msg (msg.id)}
    {#if msg.role === 'assistant'}
        <!-- ЛЕВАЯ СТОРОНА: Вертикальный стек (иконка сверху, текст снизу) -->
        <div class="group flex w-full flex-col items-start max-w-[85%] mb-4">

            <!-- Круглая иконка бота сверху, прижата к левому краю -->
            <div class="w-8 h-8 rounded-full bg-[#2481cc] flex items-center justify-center text-white shadow-sm mb-2">
                <Icons
                        provider={getProvider(msg.ai_model_id)}
                        size={16}
                />
            </div>

            <!-- Бабл с ответом под иконкой, выровнен по левому краю -->
            <div class="w-full px-4 py-2.5 text-xs font-medium border rounded-[20px] relative break-words shadow-md text-left bg-white/[0.03] border-white/5 text-gray-200 rounded-tl-sm">
                <div class="message-content" on:click={handleContentClick}>
                    {#if msg.error && msg.is_aborted}
                        <!-- Прерывание до получения ответа -->
                        <p class="leading-relaxed text-yellow-400/80 italic flex items-center gap-2">
                            <span>😕 Генерация прервана до ответа</span>
                        </p>
                    {:else if msg.error}
                        <!-- Обычная ошибка -->
                        <p class="leading-relaxed text-red-400/80 italic flex items-center gap-2">
                            <span>😩 Не удалось получить ответ</span>
                        </p>
                    {:else if msg.is_streaming}
                        <p class="leading-relaxed whitespace-pre-wrap">{msg.content}</p>
                    {:else}
                        {@html renderMarkdown(msg.content)}
                    {/if}
                </div>

                <div class="flex items-center justify-between gap-2 mt-1 select-none">
                    <span class="text-[9px] font-bold opacity-40">
                        {formatTime(msg.created_at)}
                    </span>
                </div>
            </div>
        </div>

    {:else}
        <!-- ПРАВАЯ СТОРОНА: Только бабл пользователя, прижат к правому краю -->
        <div class="group flex w-full justify-end mb-4">
            <div class="max-w-[85%] px-4 py-2.5 text-xs font-medium border rounded-[20px] relative break-words shadow-md text-left bg-[#2481cc]/20 border-[#2481cc]/30 text-white rounded-tr-sm">
                <div class="message-content" on:click={handleContentClick}>
                    <p class="leading-relaxed whitespace-pre-wrap">{msg.content}</p>
                </div>

                <div class="flex items-center justify-between gap-2 mt-1 select-none">
                    <span class="text-[9px] font-bold opacity-40">
                        {formatTime(msg.created_at)}
                    </span>
                </div>
            </div>
        </div>
    {/if}
{/each}

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
        font-family: inherit;   /* ← важно: sans, а не monospace */
    }

    .message-content :global(strong) { font-weight: 700; color: #fff; }
    .message-content :global(em) { font-style: italic; }
</style>
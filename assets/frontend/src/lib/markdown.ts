import { marked } from 'marked';
import DOMPurify from 'dompurify';

marked.setOptions({
    gfm: true,   // GitHub Flavored Markdown: таблицы, ~~strike~~, таск-листы, автолинки
    breaks: true // одиночный \n → <br>. В чатах это то, что ждёт юзер
});

// Иконка копирования — одинаковая для обоих блоков, вынесена в константу
const COPY_ICON = `
<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
    <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
    <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
</svg>`.trim();

// Теги-алиасы для «текстового» блока. Что напишет модель — то и сработает.
const COPY_FENCE_TAGS = new Set(['copy', 'text', 'draft']);

function escapeHtml(s: string): string {
    return s
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
}

// Кастомный рендер блоков: код (.code-block) и текст для копирования (.copy-block)
marked.use({
    renderer: {
        code({ text, lang }) {
            const language = (lang || '').trim().toLowerCase();
            const escaped = escapeHtml(text);

            // === Текстовый блок: ```copy / ```text / ```draft ===
            if (COPY_FENCE_TAGS.has(language)) {
                return `
<div class="copy-block" data-copy-block>
    <div class="copy-block__header">
        <span class="copy-block__label">Текст</span>
        <button type="button" class="copy-block__btn" data-copy-code>
            ${COPY_ICON}
            <span>Копировать</span>
        </button>
    </div>
    <div class="copy-block__body" data-copy-source>${escaped}</div>
</div>`.trim();
            }

            // === Обычный код ===
            return `
<div class="code-block" data-code-lang="${language}">
    <div class="code-block__header">
        <span class="code-block__lang">${language || 'code'}</span>
        <button type="button" class="code-block__copy" data-copy-code>
            ${COPY_ICON}
            <span>Копировать</span>
        </button>
    </div>
    <pre><code class="language-${language}">${escaped}</code></pre>
</div>`.trim();
        }
    }
});

export function renderMarkdown(text: string): string {
    if (!text) return '';
    const raw = marked.parse(text, { async: false }) as string;
    return DOMPurify.sanitize(raw, {
        ADD_ATTR: ['data-code-lang', 'data-copy-code', 'data-copy-block', 'data-copy-source', 'class'],
        ADD_TAGS: ['svg', 'path', 'rect'],
        FORBID_TAGS: ['style', 'iframe', 'form', 'input', 'script'],
        FORBID_ATTR: ['style', 'onerror', 'onload', 'onclick']
    });
}
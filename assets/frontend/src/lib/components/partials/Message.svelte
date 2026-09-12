<script>
    import { Copy, Check } from 'lucide-svelte';

    export let messages;

    // id скопированного сообщения — чтобы показать галочку на 1.5 сек
    let copiedId = null;

    function formatTime(isoString) {
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

    async function copyMessage(msg) {
        try {
            await navigator.clipboard.writeText(msg.content || "");
            copiedId = msg.id;
            setTimeout(() => {
                if (copiedId === msg.id) copiedId = null;
            }, 1500);
        } catch (e) {
            console.warn('Copy failed', e);
        }
    }
</script>

{#each messages as msg (msg.id)}
    <!-- Баббл сообщения: user — справа, assistant — слева -->
    <div
            data-message-id={msg.id}
            class="group flex w-full {msg.role === 'user' ? 'justify-end' : 'justify-start'}"
    >
        <div
                class="max-w-[85%] px-4 py-2.5 text-xs font-medium border rounded-[20px] relative break-words shadow-md
                {msg.role === 'user'
                    ? 'bg-[#2481cc]/20 border-[#2481cc]/30 text-white rounded-tr-sm'
                    : 'bg-white/[0.03] border-white/5 text-gray-200 rounded-tl-sm'}"
        >
            <!-- Текст сообщения -->
            <p class="leading-relaxed whitespace-pre-wrap">{msg.content}</p>

            <!-- Нижняя строка: время слева, иконка Copy справа -->
            <div class="flex items-center justify-between gap-2 mt-1 select-none">
                <span class="text-[9px] font-bold opacity-40">
                    {formatTime(msg.created_at)}
                </span>

                <button
                        type="button"
                        on:click|stopPropagation={() => copyMessage(msg)}
                        class="opacity-40 hover:opacity-100 active:opacity-100 transition-opacity
           {copiedId === msg.id ? 'text-emerald-400' : 'text-gray-400 hover:text-white'}"
                        title="Скопировать текст"
                >
                    {#if copiedId === msg.id}
                        <Check size={12} strokeWidth={2.5} />
                    {:else}
                        <Copy size={12} strokeWidth={2.5} />
                    {/if}
                </button>
            </div>
        </div>
    </div>
{/each}
<script>
    export let messages;
</script>
{#each messages as msg (msg.id)}
<!-- Роль system (наш системный промпт) выводим красивой плашкой по центру -->
    {#if msg.role === 'system'}
        <div class="w-full my-2 flex items-center justify-center">
            <div class="bg-white/[0.02] border border-white/5 max-w-[90%] px-4 py-2 rounded-2xl text-[11px] text-gray-400 font-medium text-center leading-relaxed shadow-sm">
                💡 <span class="font-bold text-gray-300">Инструкция:</span> {msg.text}
            </div>
        </div>
    {:else}
        <!-- Бабблы сообщений: пользователя (me) и нейросети (other) -->
        <div class="flex w-full {msg.role === 'me' ? 'justify-end' : 'justify-start'}">
            <div class="max-w-[85%] px-4 py-2.5 text-xs font-medium border rounded-[20px] relative break-words shadow-md
                {msg.role === 'me'
                    ? 'bg-[#2481cc]/20 border-[#2481cc]/30 text-white rounded-tr-sm'
                    : 'bg-white/[0.03] border-white/5 text-gray-200 rounded-tl-sm'}"
            >
                <p class="leading-relaxed whitespace-pre-wrap">{msg.text}</p>
                <span class="text-[9px] font-bold ml-2 mt-1 float-right select-none opacity-40">
                    {formatTime(msg.created_at)}
                </span>
            </div>
        </div>
    {/if}
{/each}
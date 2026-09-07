<script>
    export let messages;

    function formatTime(isoString) {
        if (!isoString) return "";
        try {
            const date = new Date(isoString);
            return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        } catch (e) {
            return "";
        }
    }
</script>
{#each messages as msg (msg.id)}
    <!-- Бабблы сообщений: пользователя (me) и нейросети (other) -->
    <div class="flex w-full {msg.role === 'user' ? 'justify-end' : 'justify-start'}">
        <div class="max-w-[85%] px-4 py-2.5 text-xs font-medium border rounded-[20px] relative break-words shadow-md
            {msg.role === 'user'
                ? 'bg-[#2481cc]/20 border-[#2481cc]/30 text-white rounded-tr-sm'
                : 'bg-white/[0.03] border-white/5 text-gray-200 rounded-tl-sm'}"
        >
            <p class="leading-relaxed whitespace-pre-wrap">{msg.content}</p>
            <span class="text-[9px] font-bold ml-2 mt-1 float-right select-none opacity-40">
                {msg.id}
            </span>
        </div>
    </div>
{/each}
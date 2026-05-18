<script lang="ts">
    import { createEventDispatcher, onMount, tick } from 'svelte';
    import { ChevronLeft, Paperclip, Smile, Mic, Camera, SendHorizontal, Play, FileImage } from 'lucide-svelte';

    interface Message {
        id: string;
        sender: 'me' | 'other';
        type: 'text' | 'image' | 'audio';
        content: string;
        time: string;
        isUnreadDivider?: boolean;
        audioDuration?: string;
    }

    export let chatName = "OpenAI Bot";
    export let isOnline = true;
    export let avatarUrl = "";
    export let messages: Message[] = [];

    let newMessageText = "";
    let scrollContainer: HTMLDivElement;
    const dispatch = createEventDispatcher<{ sendMessage: string; back: void }>();

    async function scrollToBottom() {
        await tick();
        if (scrollContainer) {
            scrollContainer.scrollTop = scrollContainer.scrollHeight;
        }
    }

    onMount(() => {
        scrollToBottom();
    });

    $: if (messages.length) {
        scrollToBottom();
    }

    function handleSend() {
        const text = newMessageText.trim();
        if (!text) return;
        dispatch('sendMessage', text);
        newMessageText = "";
    }

    function handleKeyDown(event: KeyboardEvent) {
        // Если нажат Enter и одновременно зажат Shift то отправляем сообщение
        if (event.key === 'Enter' && event.shiftKey) {
            event.preventDefault(); // Запрещаем перенос строки при отправке
            handleSend(); // Вызываем функцию отправки
        }
    }

    let isAttachmentMenuOpen = false;

    function toggleAttachmentMenu() {
        isAttachmentMenuOpen = !isAttachmentMenuOpen;
        triggerHaptic(); // Мягкий виброотклик при клике
    }

    // Закрываем меню, если пользователь начал вводить текст
    $: if (newMessageText.trim().length > 0) {
        isAttachmentMenuOpen = false;
    }

    let textareaElement: HTMLTextAreaElement;

    function autoGrow() {
        if (!textareaElement) return;

        // Сбрасываем высоту в ноль, чтобы она уменьшалась при удалении букв
        textareaElement.style.height = 'auto';

        // Выставляем высоту по реальному контенту, но ограничиваем в 120px
        const newHeight = Math.min(textareaElement.scrollHeight, 120);
        textareaElement.style.height = `${newHeight}px`;
    }
</script>

<div class="flex flex-col h-full w-full min-w-0 bg-[#0f0f0f] rounded-[24px] text-white font-sans overflow-hidden">

    <!-- ШАПКА ЧАТА -->
    <header class="h-14 bg-white/[0.02] backdrop-blur-xl border-b border-white/5 flex items-center px-4 justify-between flex-shrink-0 z-10">
        <button on:click={() => dispatch('back')} class="text-[#2481cc] hover:opacity-80 transition-all p-1 -ml-1 flex items-center justify-center">
            <ChevronLeft size={24} strokeWidth={2.5} />
        </button>

        <div class="flex flex-col items-center flex-1 pr-6">
            <span class="text-sm font-bold tracking-tight">{chatName}</span>
            <span class="text-[10px] font-medium {isOnline ? 'text-[#2481cc]' : 'text-gray-500'}">
                {isOnline ? 'typing...' : 'offline'}
            </span>
        </div>

        {#if avatarUrl}
            <div class="w-8 h-8 rounded-xl overflow-hidden bg-white/5 border border-white/10 flex-shrink-0">
                <img src={avatarUrl} alt={chatName} class="w-full h-full object-cover" />
            </div>
        {:else}
            <div class="w-8 h-8 rounded-xl bg-gradient-to-br from-[#2481cc] to-[#1d6fa0] text-white text-xs font-bold flex items-center justify-center flex-shrink-0">
                {chatName.substring(0, 2).toUpperCase()}
            </div>
        {/if}
    </header>

    <!-- ЗОНА СООБЩЕНИЙ -->
    <div
            bind:this={scrollContainer}
            class="flex-1 overflow-y-auto py-4 px-3 flex flex-col gap-2 scrollbar-none"
    >
        {#each messages as msg (msg.id)}
            {#if msg.isUnreadDivider}
                <div class="w-full my-3 flex items-center justify-center">
                    <div class="bg-[#2481cc]/10 border border-[#2481cc]/20 px-4 py-1 rounded-full text-[10px] text-[#2481cc] font-bold tracking-wider uppercase">
                        Unread messages
                    </div>
                </div>
            {/if}

            <div class="flex w-full {msg.sender === 'me' ? 'justify-end' : 'justify-start'}">
                {#if msg.type === 'text'}
                    <div class="max-w-[85%] px-4 py-2.5 text-xs font-medium border rounded-[20px] relative break-words shadow-md
                        {msg.sender === 'me'
                            ? 'bg-[#2481cc]/20 border-[#2481cc]/30 text-white rounded-tr-sm'
                            : 'bg-white/[0.03] border-white/5 text-gray-200 rounded-tl-sm'}"
                    >
                        <p class="leading-relaxed">{msg.content}</p>
                        <span class="text-[9px] font-bold ml-2 mt-1 float-right select-none opacity-40">
                            {msg.time}
                        </span>
                    </div>
                {:else if msg.type === 'image'}
                    <div class="max-w-[85%] p-1 bg-white/[0.03] border border-white/5 rounded-[20px] overflow-hidden relative shadow-md
                        {msg.sender === 'me' ? 'rounded-tr-sm' : 'rounded-tl-sm'}"
                    >
                        <img src={msg.content} alt="AI" class="rounded-[16px] w-full max-h-60 object-cover" />
                        <div class="absolute bottom-2 right-3 bg-black/60 backdrop-blur-md px-2 py-0.5 rounded-full text-[9px] font-bold text-gray-300">
                            {msg.time}
                        </div>
                    </div>
                {:else}
                    <div class="max-w-[85%] px-4 py-3 border border-white/5 rounded-[20px] flex items-center gap-3 min-w-[240px] bg-white/[0.03]
                        {msg.sender === 'me' ? 'rounded-tr-sm' : 'rounded-tl-sm'}"
                    >
                        <button class="w-8 h-8 rounded-xl bg-[#2481cc] text-white flex items-center justify-center flex-shrink-0 active:scale-95 transition-transform">
                            <Play size={14} fill="currentColor" class="ml-0.5" />
                        </button>
                        <div class="flex-1 flex flex-col justify-center">
                            <div class="flex items-end gap-[2px] h-4 mb-1 opacity-40">
                                <div class="w-[2px] bg-white h-2 rounded-full"></div>
                                <div class="w-[2px] bg-white h-4 rounded-full"></div>
                                <div class="w-[2px] bg-white h-5 rounded-full"></div>
                            </div>
                            <div class="flex justify-between items-center text-[9px] text-gray-500 font-bold">
                                <span>{msg.audioDuration || '0:00'}</span>
                                <span>{msg.time}</span>
                            </div>
                        </div>
                    </div>
                {/if}
            </div>
        {/each}
    </div>

    <!-- НИЖНЯЯ ПАНЕЛЬ ВВОДА -->
    <footer class="w-full p-2 bg-white/[0.02] backdrop-blur-xl border-t border-white/5 flex items-center gap-2 flex-shrink-0 pb-safe relative">

        <!-- ВСПЛЫВАЮЩЕЕ МЕНЮ ВЛОЖЕНИЙ Pop-up -->
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

        <!-- ПОЛЕ ВВОДА Занимает всё доступное пространство от края до края -->
        <div class="flex-1 bg-white/[0.03] border border-white/5 rounded-[20px] px-3.5 py-2 flex items-center gap-2 focus-within:border-[#2481cc]/30 transition-all">

            <!-- Кнопка -->
            <button
                    on:click={toggleAttachmentMenu}
                    class="text-gray-500 hover:text-[#2481cc] transition-colors flex items-center justify-center p-0.5 transform {isAttachmentMenuOpen ? 'rotate-45' : 'rotate-0'} transition-transform duration-200"
            >
                <!-- Скрепка, оно же универсальный символ вложений -->
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

        <!-- Кнопка отправки активная -->
        {#if newMessageText.trim().length > 0}
            <button on:click={handleSend} class="text-[#2481cc] hover:scale-105 active:scale-95 transition-all p-2 flex items-center justify-center flex-shrink-0">
                <SendHorizontal size={20} />
            </button>
        {:else}
            <!-- Кнопка серая без текста -->
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
    /* Защита нижнего отступа для безрамочных экранов iPhone/Android */
    .pb-safe {
        padding-bottom: calc(0.5rem + env(safe-area-inset-bottom, 0px));
    }
</style>

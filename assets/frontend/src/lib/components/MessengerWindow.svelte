<script lang="ts">
    import { onMount, tick } from 'svelte';
    import { ChevronLeft, Paperclip, Mic, SendHorizontal, Settings, FileImage } from 'lucide-svelte';
    import { appState } from '../../stores/socketStore';
    import Message from "./partials/Message.svelte"

    // Вся информация реактивно извлекается из appState
    $: activeChat = $appState.active_chat;
    $: messages = activeChat?.messages || [];

    // Автоматически находим имя текущего чата в общем списке
    $: currentChatInfo = $appState.chats_list.find(c => c.id === activeChat?.id);
    $: chatName = currentChatInfo?.title || "Ассистент";

    let newMessageText = "";
    let scrollContainer: HTMLDivElement;
    let textareaElement: HTMLTextAreaElement;
    let isAttachmentMenuOpen = false;
    const currentGroupId = $appState.active_chat?.group_id;

    // Вспомогательная функция для вывода времени из ISO8601
    function formatTime(isoString: string): string {
        if (!isoString) return "";
        try {
            const date = new Date(isoString);
            return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        } catch (e) {
            return "";
        }
    }

    // Умный скролл вниз
    async function scrollToBottom() {
        await tick();
        if (scrollContainer) {
            scrollContainer.scrollTop = scrollContainer.scrollHeight;
        }
    }

    onMount(() => {
        scrollToBottom();
    });

    // Экран мягко уезжает вниз при получении новых сообщений или токенов от AI
    $: if (messages.length) {
        scrollToBottom();
    }

    // Закрываем меню вложений, если пользователь начал печатать текст
    $: if (newMessageText.trim().length > 0) {
        isAttachmentMenuOpen = false;
    }

    // Единственный метод отправки сообщения на бэкенд Phoenix
    function handleSend() {
        const text = newMessageText.trim();
        if (!text) return;

        // Отправляем ивент в Phoenix Channel
        appState.send("chat:click_submit_message", {
            chat_id: activeChat?.id || null,
            text: text
        });

        newMessageText = "";

        // Сбрасываем высоту инпута после отправки
        if (textareaElement) textareaElement.style.height = 'auto';
    }

    // Перехват нажатия клавиш внутри textarea
    function handleKeyDown(event: KeyboardEvent) {
        // Отправка строго по Enter без зажатого Shift
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault(); // Запрещаем перенос строки
            handleSend();
        }
    }

    function toggleAttachmentMenu() {
        isAttachmentMenuOpen = !isAttachmentMenuOpen;
    }

    // Автоматический рост высоты textarea в зависимости от количества строк
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

        <!-- Выполняем goBack -->
        <button on:click={() => appState.goBack()} class="text-[#2481cc] hover:opacity-80 transition-all p-1 -ml-1 flex items-center justify-center">
            <ChevronLeft size={24} strokeWidth={2.5} />
        </button>

        <div class="flex flex-col items-center flex-1 pr-6">
            <span class="text-sm font-bold tracking-tight">{chatName}</span>
            <span class="text-[10px] font-medium text-[#2481cc]">
            online
        </span>
        </div>

        <div class="p-2 bg-white/5 rounded-xl text-gray-400 hover:text-white transition-colors flex items-center justify-center flex-shrink-0">
            <Settings size={24} strokeWidth={2.5} />
        </div>
    </header>

    <!-- ЗОНА СООБЩЕНИЙ -->
    <div
            bind:this={scrollContainer}
            class="flex-1 overflow-y-auto py-4 px-3 flex flex-col gap-2 scrollbar-none"
    >
        <Message {messages} />
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

        <!-- ПОЛЕ ВВОДА -->
        <div class="flex-1 bg-white/[0.03] border border-white/5 rounded-[20px] px-3.5 py-2 flex items-center gap-2 focus-within:border-[#2481cc]/30 transition-all">
            <!-- Кнопка скрепки с поворотом при открытии -->
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

        <!-- Динамическая кнопка отправки -->
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
    /* Защита нижнего отступа для безрамочных экранов iPhone/Android */
    .pb-safe {
        padding-bottom: calc(0.5rem + env(safe-area-inset-bottom, 0px));
    }
</style>

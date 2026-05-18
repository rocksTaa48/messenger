<script lang="ts">
    import { createEventDispatcher, onMount, tick } from 'svelte';
    import { ChevronLeft } from 'lucide-svelte';

    interface Message {
        id: string;
        sender: 'me' | 'other';
        type: 'text' | 'image' | 'audio';
        content: string;
        time: string;
        isUnreadDivider?: boolean;
        audioDuration?: string;
    }

    export let chatName = "Sophia Patel";
    export let isOnline = true;
    export let avatarUrl = "";
    export let messages: Message[] = [];

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
                {isOnline ? 'online' : 'offline'}
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
    <h1 class="text-white">OOops!</h1>
    <p> Этот раздел еще в разработке</p>
</div>
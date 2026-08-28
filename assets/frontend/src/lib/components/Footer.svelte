<script>
    import { MessageCirclePlusIcon, MessageCircleMore, Settings2 } from 'lucide-svelte';
    import { createEventDispatcher } from "svelte";
    import WebApp from "@twa-dev/sdk";

    export let activeTab = 'Explore';

    const dispatch = createEventDispatcher();

    // Вкладки
    const tabs = [
        { label: 'Chats', icon: MessageCircleMore },
        { label: 'CreateChat', icon: MessageCirclePlusIcon },
        { label: 'Settings', icon: Settings2 }
    ];

    // Вкладки на которых мы скрываем футер, неважно есть они в массиве TABs или нет, скрываем
    const hiddenTabs = ['Messenger', 'CreateChat', 'ProfileEdit', 'CryptoPayment'];


    function handleMenuClick() {
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('light');
        console.log('Menu clicked');
    }

    // Логика
    function handleChange(label) {
        dispatch("change", label);
    }
</script>

<div class="fixed bottom-6 left-0 right-0 px-4 z-50 transition-all duration-300 transform
    {hiddenTabs.includes(activeTab) ? 'translate-y-28 opacity-0 pointer-events-none' : 'translate-y-0 opacity-100'}">

    <div class="max-w-md mx-auto bg-[#121212]/10 backdrop-blur-2xl border border-white/5 rounded-[32px] p-1 flex items-center justify-between shadow-2xl shadow-black/20">
        {#each tabs as tab}
            {@const isTabActive = activeTab === tab.label}

            <button
                    on:click={() => {handleChange(tab.label);
                                    handleMenuClick();}}
                    class="flex-1 relative flex flex-col items-center justify-center py-2 px-1 min-w-0 transition-all duration-300"
            >
                <!-- Синее свечение для активной вкладки -->
                {#if isTabActive}
                    <div class="absolute -inset-2 bg-[#2481cc]/20 blur-xl rounded-full"></div>
                {/if}

                <span class="mb-1 transition-colors
                    {isTabActive ? 'text-[#2481cc]' : 'text-gray-500'}">
                    <svelte:component
                            this={tab.icon}
                            size={26}
                            strokeWidth={isTabActive ? 2.2 : 1.8}
                    />
                </span>
            </button>
        {/each}
    </div>

</div>

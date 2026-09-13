<script lang="ts">
    import { slide, fade } from 'svelte/transition';
    import { AlertTriangle } from 'lucide-svelte';
    import { createEventDispatcher } from 'svelte';
    import WebApp from "@twa-dev/sdk";

    export let isOpen = false;
    export let title = "Подтверждение";
    export let message = "Вы уверены?";
    export let confirmText = "Подтвердить";
    export let cancelText = "Отмена";
    export let isDanger = true;

    const dispatch = createEventDispatcher<{ confirm: void; cancel: void }>();

    function close() {
        isOpen = false;
        dispatch('cancel');
    }

    function handleConfirm() {
        if (WebApp.HapticFeedback) {
            WebApp.HapticFeedback.impactOccurred('medium');
        }
        dispatch('confirm');
        isOpen = false;
    }

    function handleCancel() {
        if (WebApp.HapticFeedback) {
            WebApp.HapticFeedback.impactOccurred('light');
        }
        close();
    }
</script>

<svelte:body class:overflow-hidden={isOpen} class:touch-none={isOpen} />

{#if isOpen}
    <div class="fixed inset-0 z-[130] flex items-center justify-center p-5 pointer-events-auto">
        <!-- ЗАДНИЙ ФОН -->
        <div
                on:click={handleCancel}
                class="absolute inset-0 bg-black/70 backdrop-blur-sm"
                transition:fade={{ duration: 150 }}
        ></div>

        <!-- ОКНО -->
        <div
                class="relative z-10 w-full max-w-sm bg-[#1c1c1e] border border-white/10 rounded-[28px] shadow-2xl flex flex-col overflow-hidden overscroll-none"
                transition:slide={{ y: 40, duration: 250 }}
        >
            <!-- ШАПКА -->
            <div class="flex flex-col items-center px-6 pt-6 pb-2 flex-shrink-0">
                {#if isDanger}
                    <div class="w-12 h-12 rounded-full bg-red-500/10 flex items-center justify-center mb-4">
                        <AlertTriangle size={24} class="text-red-500" />
                    </div>
                {/if}
                <h3 class="text-xl font-bold text-white text-center">{title}</h3>
            </div>

            <!-- КОНТЕНТ -->
            <div class="px-6 py-4 flex-shrink-0">
                <p class="text-sm text-gray-400 text-center leading-relaxed">
                    {message}
                </p>
            </div>

            <!-- Разделитель -->
            <div class="h-px bg-white/5 mx-6"></div>

            <!-- НИЖНИЕ КНОПКИ -->
            <div class="px-6 pb-6 pt-4 flex-shrink-0 flex gap-3">
                <button
                        on:click={handleCancel}
                        class="flex-1 bg-white/5 text-white font-semibold py-3.5 rounded-2xl flex items-center justify-center gap-2 active:scale-[0.98] transition-all border border-white/5 hover:bg-white/10"
                >
                    {cancelText}
                </button>
                <button
                        on:click={handleConfirm}
                        class="flex-1 font-semibold py-3.5 rounded-2xl flex items-center justify-center gap-2 active:scale-[0.98] transition-all shadow-lg
                               {isDanger
                                   ? 'bg-red-500 text-white hover:bg-red-600 shadow-red-500/20'
                                   : 'bg-[#2481cc] text-white hover:bg-[#1a6bb5] shadow-[#2481cc]/20'}"
                >
                    {confirmText}
                </button>
            </div>
        </div>
    </div>
{/if}
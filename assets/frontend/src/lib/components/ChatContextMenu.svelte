<script lang="ts">
    import { slide, fade } from 'svelte/transition';
    import { X, Folder, Pencil, Trash2, Pin } from 'lucide-svelte';
    import { createEventDispatcher } from 'svelte';
    import {appState} from "../../stores/socketStore";

    export let isOpen = false;
    export let chatTitle = '';

    // Интерфейс действия, которое мы передаем из родителя
    export interface MenuAction {
        id: string;
        label: string;
        icon: any;
        isDanger?: boolean;
        onClick: () => void;
    }

    export let actions: MenuAction[] = [];

    const dispatch = createEventDispatcher();

    function close() {
        isOpen = false;
        dispatch('close');
    }

    function deleteChat() {
        appState.send("chat:click_new");
    }

    function triggerHaptic() {
        const tg = (window as any).Telegram?.WebApp;
        if (tg?.HapticFeedback) {
            tg.HapticFeedback.impactOccurred('light');
        }
    }

    function handleActionClick(action: MenuAction) {
        triggerHaptic();
        action.onClick();
        close();
    }
</script>

<svelte:body class:overflow-hidden={isOpen} class:touch-none={isOpen} />

{#if isOpen}
    <div class="fixed inset-0 z-[100] overflow-hidden pointer-events-auto">
        <!-- Задний фон -->
        <div
                on:click={close}
                class="absolute inset-0 bg-black/60 backdrop-blur-sm"
                transition:fade={{ duration: 150 }}
        ></div>

        <!-- Контейнер модального окна -->
        <div
                class="absolute bottom-0 left-0 right-0 bg-[#1c1c1e] border-t border-white/10 rounded-t-[32px] p-6 shadow-2xl flex flex-col overflow-hidden overscroll-none"
                style="max-height: 85dvh;"
                transition:slide={{ y: 500, duration: 300 }}
        >
            <!-- Полоска сверху -->
            <div class="w-12 h-1.5 bg-white/10 rounded-full mx-auto mb-5 flex-shrink-0"></div>

            <!-- Шапка -->
            <div class="flex justify-between items-center mb-6 flex-shrink-0">
                <h3 class="text-lg font-bold text-white truncate pr-4">
                    {chatTitle || 'Действия с чатом'}
                </h3>
                <button
                        on:click={() => { close(); triggerHaptic(); }}
                        class="p-2 bg-white/5 rounded-full text-gray-400 hover:text-white transition-colors active:scale-95 flex-shrink-0"
                >
                    <X size={20} />
                </button>
            </div>

            <!-- Список действий -->
            <div class="flex-1 min-h-0 relative overflow-hidden w-full overflow-y-auto scrollbar-none" style="-webkit-overflow-scrolling: touch;">
                <div class="flex flex-col gap-3 pb-4">
                    {#each actions as action (action.id)}
                        <button
                                on:click={() => handleActionClick(action)}
                                class="flex items-center gap-4 p-4 rounded-2xl border transition-all text-left w-full active:scale-[0.99]
                            {action.isDanger
                                ? 'bg-red-500/10 border-red-500/20 hover:bg-red-500/15'
                                : 'bg-white/[0.03] border-white/5 hover:bg-white/[0.06]'}"
                        >
                            <svelte:component
                                    this={action.icon}
                                    size={20}
                                    class={action.isDanger ? 'text-red-400' : 'text-gray-400'}
                            />
                            <span class="text-sm font-semibold {action.isDanger ? 'text-red-400' : 'text-white'}">
                                {action.label}
                            </span>
                        </button>
                    {/each}
                </div>
            </div>

            <div class="pt-2 flex-shrink-0 pb-safe">
                <button
                        on:click={() => { close(); triggerHaptic(); }}
                        class="w-full bg-white/5 text-white font-semibold py-4 rounded-2xl flex items-center justify-center gap-2 active:scale-[0.98] transition-all border border-white/5 hover:bg-white/10"
                >
                    Отмена
                </button>
            </div>
        </div>
    </div>
{/if}

<style>
    .scrollbar-none::-webkit-scrollbar {
        display: none;
    }
    .scrollbar-none {
        -ms-overflow-style: none;
        scrollbar-width: none;
    }
    .pb-safe {
        padding-bottom: max(16px, env(safe-area-inset-bottom));
    }
</style>
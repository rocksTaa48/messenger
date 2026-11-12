<script lang="ts">
    import { fade, slide } from 'svelte/transition';
    import { X, Check } from 'lucide-svelte';
    import { createEventDispatcher } from 'svelte';
    import WebApp from "@twa-dev/sdk";

    export let isOpen = false;
    export let title = "Выбор модели";
    export let models: any[] = [];
    export let selectedModelId: string | null = null;
    export let userStatus = 'free';

    const dispatch = createEventDispatcher<{
        select: string;
        close: void;
    }>();

    function close() {
        dispatch('close');
    }

    function isModelAccessible(modelTier: string): boolean {
        const tierOrder: Record<string, number> = { 'free': 0, 'premium': 1, 'ultimate': 2 };
        const userLevel = tierOrder[userStatus] || 0;
        const modelLevel = tierOrder[modelTier] || 0;
        return userLevel >= modelLevel;
    }

    function handleModelClick(model: any) {
        const isAccessible = isModelAccessible(model.tier);
        if (!isAccessible) {
            if (WebApp.HapticFeedback) WebApp.HapticFeedback.notificationOccurred('error');
            return;
        }

        dispatch('select', model.id);
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.selectionChanged();
    }
</script>

<svelte:body class:overflow-hidden={isOpen} class:touch-none={isOpen} />

{#if isOpen}
    <div class="fixed inset-0 z-[110] flex items-center justify-center p-5 pointer-events-auto">
        <!-- ЗАДНИЙ ФОН -->
        <div
                on:click={close}
                class="absolute inset-0 bg-black/60 backdrop-blur-sm"
                transition:fade={{ duration: 150 }}
        ></div>

        <!-- ОКНО -->
        <div
                class="relative z-10 w-full bg-[#1c1c1e] border border-white/10 rounded-[28px] shadow-2xl flex flex-col overflow-hidden overscroll-none"
                style="max-height: 70dvh;"
                transition:slide={{ y: 200, duration: 250 }}
        >
            <!-- ШАПКА -->
            <div class="flex justify-between items-center px-5 pt-5 pb-3 flex-shrink-0">
                <div class="min-w-0">
                    <h3 class="text-lg font-bold text-white flex items-center gap-2">
                        {title}
                    </h3>
                    <p class="text-xs text-gray-500 mt-0.5">Выберите подходящую конфигурацию</p>
                </div>
                <button
                        on:click={close}
                        class="p-2 bg-white/5 rounded-full text-gray-400 hover:text-white transition-colors active:scale-95 flex-shrink-0 ml-3"
                >
                    <X size={18} />
                </button>
            </div>

            <!-- Разделитель -->
            <div class="h-px bg-white/5 mx-5"></div>

            <!-- СПИСОК МОДЕЛЕЙ -->
            <div class="flex-1 min-h-0 overflow-y-auto scrollbar-none px-2 py-3 space-y-1" style="-webkit-overflow-scrolling: touch;">
                {#if models.length === 0}
                    <div class="text-center text-gray-500 py-8 text-sm">Нет доступных моделей</div>
                {:else}
                    {#each models as model}
                        {@const isAccessible = isModelAccessible(model.tier)}
                        {@const isSelected = selectedModelId === model.id}

                        <button
                                on:click={() => handleModelClick(model)}
                                disabled={!isAccessible}
                                class="w-full text-left p-3.5 flex items-center justify-between rounded-xl transition-colors overflow-hidden {isSelected ? 'bg-[#2481cc]/10 border border-[#2481cc]/20' : 'hover:bg-white/5 border border-transparent'} {!isAccessible ? 'opacity-60' : ''}"
                        >
                            <div class="flex flex-col min-w-0 flex-1 pr-3">
                                <span class="text-sm font-semibold text-white truncate block w-full">
                                    {model.display_name || model.model_name || 'Без имени'}
                                </span>
                                <span class="text-xs text-gray-400 truncate mt-0.5 block w-full">
                                    {model.display_description || 'Стандартная конфигурация'}
                                </span>
                            </div>

                            <div class="flex items-center gap-2 shrink-0">
                                {#if !isAccessible}
                                    <span class="text-[10px] font-bold uppercase tracking-wider text-amber-400 bg-amber-400/10 px-2.5 py-1 rounded-full border border-amber-400/20 whitespace-nowrap">
                                        Upgrade
                                    </span>
                                {:else if isSelected}
                                    <div class="w-6 h-6 rounded-full bg-[#2481cc] flex items-center justify-center shrink-0">
                                        <Check size={14} class="text-white" strokeWidth={3} />
                                    </div>
                                {/if}
                            </div>
                        </button>
                    {/each}
                {/if}
            </div>
        </div>
    </div>
{/if}

<style>
    .scrollbar-none::-webkit-scrollbar { display: none; }
    .scrollbar-none { -ms-overflow-style: none; scrollbar-width: none; }
</style>
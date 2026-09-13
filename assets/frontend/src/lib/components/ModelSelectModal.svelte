<script lang="ts">
    import { fade, scale } from 'svelte/transition';
    import { X, Check, Cpu } from 'lucide-svelte';
    import { createEventDispatcher } from 'svelte';
    import WebApp from "@twa-dev/sdk";

    export let isOpen = false;
    export let presetTitle = '';
    export let currentModelId: string | null = null;
    export let models: Array<{ id: string; name: string; description: string; tier: 'free' | 'premium' | 'ultimate' }> = [];

    const dispatch = createEventDispatcher<{ select: string }>();

    type Tier = 'free' | 'premium' | 'ultimate';
    let activeTab: Tier = 'free';
    let localSelectedModelId = currentModelId;

    // Реактивно подставляем вкладку на основе текущей модели при открытии
    $: if (isOpen) {
        localSelectedModelId = currentModelId;
        const currentModel = models.find(m => m.id === currentModelId);
        if (currentModel) {
            activeTab = currentModel.tier;
        } else if (models.length > 0) {
            // Если модель еще не выбрана, берем первую доступную из Free
            const firstFree = models.find(m => m.tier === 'free');
            if (firstFree) localSelectedModelId = firstFree.id;
        }
    }

    $: filteredModels = models.filter(m => m.tier === activeTab);

    function close() {
        isOpen = false;
    }

    function triggerHaptic() {
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('light');
    }

    function handleTabClick(tab: Tier) {
        activeTab = tab;
        triggerHaptic();
        // Автоматически выделяем первую модель в выбранном табе для удобства
        const firstInTab = models.find(m => m.tier === tab);
        if (firstInTab) localSelectedModelId = firstInTab.id;
    }

    function handleModelSelect(id: string) {
        localSelectedModelId = id;
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.selectionChanged();
    }

    function handleSave() {
        if (localSelectedModelId) {
            dispatch('select', localSelectedModelId);
        }
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('medium');
        close();
    }
</script>

<svelte:body class:overflow-hidden={isOpen} class:touch-none={isOpen} />

{#if isOpen}
    <div class="fixed inset-0 z-[110] flex items-center justify-center p-4 pointer-events-auto">
        <!-- Backdrop -->
        <div on:click={close} class="absolute inset-0 bg-black/70 backdrop-blur-md" transition:fade={{ duration: 150 }}></div>

        <!-- Окно выбора нейросети -->
        <div class="relative z-10 w-full max-w-sm bg-[#1c1c1e] border border-white/10 rounded-[28px] shadow-2xl flex flex-col overflow-hidden overscroll-none" style="max-height: 75dvh;" transition:scale={{ start: 0.95, duration: 200 }}>

            <!-- Шапка модалки -->
            <div class="flex justify-between items-center px-5 pt-5 pb-3 flex-shrink-0">
                <div class="min-w-0">
                    <h3 class="text-sm font-bold text-white flex items-center gap-1.5">
                        <Cpu size={15} class="text-[#2481cc]" />
                        Модель для: {presetTitle}
                    </h3>
                    <p class="text-xs text-gray-500 mt-0.5">Выберите базовый ИИ-движок</p>
                </div>
                <button on:click={() => { close(); triggerHaptic(); }} class="p-2 bg-white/5 rounded-full text-gray-400 hover:text-white transition-colors active:scale-95 flex-shrink-0">
                    <X size={16} />
                </button>
            </div>

            <!-- Разделитель -->
            <div class="h-px bg-white/5 mx-5"></div>

            <!-- Табы подписок -->
            <div class="px-5 pt-3 pb-2 flex-shrink-0">
                <div class="flex bg-white/5 p-1 rounded-xl border border-white/5">
                    {#each ['free', 'premium', 'ultimate'] as tier}
                        <button
                                type="button"
                                on:click={() => handleTabClick(tier as Tier)}
                                class="flex-1 text-center py-1.5 text-xs font-semibold rounded-lg transition-all capitalize
                            {activeTab === tier ? 'bg-[#2481cc] text-white shadow-sm' : 'text-gray-400 hover:text-white'}"
                        >
                            {tier}
                        </button>
                    {/each}
                </div>
            </div>

            <!-- Список моделей в выбранном табе -->
            <div class="flex-1 min-h-0 overflow-y-auto scrollbar-none px-4 py-2 space-y-2" style="-webkit-overflow-scrolling: touch;">
                {#each filteredModels as model (model.id)}
                    {@const isSelected = localSelectedModelId === model.id}

                    <button
                            type="button"
                            on:click={() => handleModelSelect(model.id)}
                            class="w-full flex items-center justify-between p-3 rounded-xl border text-left transition-all duration-150 active:scale-[0.99]
                           {isSelected ? 'bg-[#2481cc]/10 border-[#2481cc]/40' : 'bg-white/5 border-transparent hover:bg-white/10'}"
                    >
                        <div class="flex flex-col min-w-0 pr-2">
                            <span class="text-xs font-semibold text-white">{model.name}</span>
                            <span class="text-[11px] text-gray-400 mt-0.5 line-clamp-1">{model.description}</span>
                        </div>

                        <div class="w-4 h-4 rounded-full flex items-center justify-center flex-shrink-0 transition-all
                            {isSelected ? 'bg-[#2481cc] text-white' : 'bg-white/10 text-transparent'}">
                            <Check size={10} strokeWidth={3} />
                        </div>
                    </button>
                {:else}
                    <div class="text-center text-xs text-gray-500 py-6">
                        В этом плане пока нет моделей
                    </div>
                {/each}
            </div>

            <!-- Кнопка сохранения -->
            <div class="p-4 border-t border-white/5 bg-[#1c1c1e] flex-shrink-0">
                <button on:click={handleSave} class="w-full bg-[#2481cc] text-white font-bold py-2.5 rounded-xl flex items-center justify-center text-xs active:scale-[0.98] transition-all">
                    Выбрать модель
                </button>
            </div>
        </div>
    </div>
{/if}

<style>
    .scrollbar-none::-webkit-scrollbar { display: none; }
    .scrollbar-none { -ms-overflow-style: none; scrollbar-width: none; }
</style>

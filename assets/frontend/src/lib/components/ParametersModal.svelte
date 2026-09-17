<script lang="ts">
    import { slide, fade } from 'svelte/transition';
    import { X, Settings2 } from 'lucide-svelte';
    import { createEventDispatcher } from 'svelte';
    import WebApp from "@twa-dev/sdk";

    export let isOpen = false;
    export let initialTemperature = 0.7;
    export let initialTopP = 1.0;
    export let initialFrequencyPenalty = 0.0;
    export let initialPresencePenalty = 0.0;

    // Безопасные границы — синхронизированы с min/max слайдеров
    const TEMP_MIN = 0.0;
    const TEMP_MAX = 1.2;

    const TOP_P_MIN = 0.1;
    const TOP_P_MAX = 1.0;

    const PENALTY_MIN = 0.0;
    const PENALTY_MAX = 1.0;

    function clamp(v: number, min: number, max: number): number {
        if (!Number.isFinite(v)) return min;
        return Math.max(min, Math.min(max, v));
    }

    const dispatch = createEventDispatcher<{
        apply: { temperature: number; topP: number; frequencyPenalty: number; presencePenalty: number };
        close: void;
    }>();

    let temperature = initialTemperature;
    let topP = initialTopP;
    let frequencyPenalty = initialFrequencyPenalty;
    let presencePenalty = initialPresencePenalty;

    $: if (isOpen) {
        // Клампим, чтобы  значения вне диапазона не «вылезали» за слайдер
        temperature = clamp(initialTemperature, TEMP_MIN, TEMP_MAX);
        topP = clamp(initialTopP, TOP_P_MIN, TOP_P_MAX);
        frequencyPenalty = clamp(initialFrequencyPenalty, PENALTY_MIN, PENALTY_MAX);
        presencePenalty = clamp(initialPresencePenalty, PENALTY_MIN, PENALTY_MAX);
    }

    function close() {
        dispatch('close');
    }

    function handleApply() {
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('medium');
        // На всякий случай ещё раз клампим перед отправкой
        dispatch('apply', {
            temperature: clamp(temperature, TEMP_MIN, TEMP_MAX),
            topP: clamp(topP, TOP_P_MIN, TOP_P_MAX),
            frequencyPenalty: clamp(frequencyPenalty, PENALTY_MIN, PENALTY_MAX),
            presencePenalty: clamp(presencePenalty, PENALTY_MIN, PENALTY_MAX),
        });
    }

    function triggerHaptic() {
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('light');
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
                        <Settings2 size={18} class="text-[#2481cc]" />
                        Параметры генерации
                    </h3>
                    <p class="text-xs text-gray-500 mt-0.5">Настройте поведение модели</p>
                </div>
                <button
                        on:click={() => { close(); triggerHaptic(); }}
                        class="p-2 bg-white/5 rounded-full text-gray-400 hover:text-white transition-colors active:scale-95 flex-shrink-0 ml-3"
                >
                    <X size={18} />
                </button>
            </div>

            <!-- Разделитель -->
            <div class="h-px bg-white/5 mx-5"></div>

            <!-- КОНТЕНТ -->
            <div class="flex-1 min-h-0 overflow-y-auto scrollbar-none px-5 py-4 space-y-5" style="-webkit-overflow-scrolling: touch;">

                <!-- Temperature -->
                <div class="space-y-2">
                    <div class="flex justify-between items-center">
                        <label class="text-sm font-medium text-gray-300">Креативность</label>
                        <span class="text-sm font-mono font-bold text-[#2481cc] bg-[#2481cc]/10 px-2 py-0.5 rounded-md">
                            {temperature.toFixed(2)}
                        </span>
                    </div>
                    <input
                            type="range"
                            min={TEMP_MIN} max={TEMP_MAX} step="0.05"
                            bind:value={temperature}
                            class="w-full h-2 bg-white/10 rounded-lg appearance-none cursor-pointer slider-thumb"
                    />
                    <div class="flex justify-between text-[10px] text-gray-500 px-0.5">
                        <span>Точнее</span>
                        <span>Креативнее</span>
                    </div>
                </div>

                <!-- Top P -->
                <div class="space-y-2">
                    <div class="flex justify-between items-center">
                        <label class="text-sm font-medium text-gray-300">Разнообразие словаря</label>
                        <span class="text-sm font-mono font-bold text-[#2481cc] bg-[#2481cc]/10 px-2 py-0.5 rounded-md">
                            {topP.toFixed(2)}
                        </span>
                    </div>
                    <input
                            type="range"
                            min={TOP_P_MIN} max={TOP_P_MAX} step="0.05"
                            bind:value={topP}
                            class="w-full h-2 bg-white/10 rounded-lg appearance-none cursor-pointer slider-thumb"
                    />
                    <div class="flex justify-between text-[10px] text-gray-500 px-0.5">
                        <span>Узкий выбор</span>
                        <span>Широкий выбор</span>
                    </div>
                </div>

                <!-- Frequency Penalty -->
                <div class="space-y-2">
                    <div class="flex justify-between items-center">
                        <label class="text-sm font-medium text-gray-300">Штраф за повтор слов</label>
                        <span class="text-sm font-mono font-bold text-[#2481cc] bg-[#2481cc]/10 px-2 py-0.5 rounded-md">
                            {frequencyPenalty.toFixed(2)}
                        </span>
                    </div>
                    <input
                            type="range"
                            min={PENALTY_MIN} max={PENALTY_MAX} step="0.05"
                            bind:value={frequencyPenalty}
                            class="w-full h-2 bg-white/10 rounded-lg appearance-none cursor-pointer slider-thumb"
                    />
                    <div class="flex justify-between text-[10px] text-gray-500 px-0.5">
                        <span>Без штрафа</span>
                        <span>Сильный штраф</span>
                    </div>
                </div>

                <!-- Presence Penalty -->
                <div class="space-y-2">
                    <div class="flex justify-between items-center">
                        <label class="text-sm font-medium text-gray-300">Штраф за повтор тем</label>
                        <span class="text-sm font-mono font-bold text-[#2481cc] bg-[#2481cc]/10 px-2 py-0.5 rounded-md">
                            {presencePenalty.toFixed(2)}
                        </span>
                    </div>
                    <input
                            type="range"
                            min={PENALTY_MIN} max={PENALTY_MAX} step="0.05"
                            bind:value={presencePenalty}
                            class="w-full h-2 bg-white/10 rounded-lg appearance-none cursor-pointer slider-thumb"
                    />
                    <div class="flex justify-between text-[10px] text-gray-500 px-0.5">
                        <span>Без штрафа</span>
                        <span>Сильный штраф</span>
                    </div>
                </div>
            </div>

            <!-- Разделитель -->
            <div class="h-px bg-white/5 mx-5"></div>

            <!-- КНОПКА ПРИМЕНИТЬ -->
            <div class="px-5 pb-5 pt-4 flex-shrink-0">
                <button
                        on:click={handleApply}
                        class="w-full bg-[#2481cc] text-white font-bold py-3.5 rounded-2xl flex items-center justify-center gap-2 active:scale-[0.98] transition-all shadow-lg shadow-[#2481cc]/20"
                >
                    Применить
                </button>
            </div>
        </div>
    </div>
{/if}

<style>
    .scrollbar-none::-webkit-scrollbar { display: none; }
    .scrollbar-none { -ms-overflow-style: none; scrollbar-width: none; }

    .slider-thumb {
        -webkit-appearance: none;
        appearance: none;
        background: rgba(255, 255, 255, 0.1);
        border-radius: 999px;
        height: 6px;
    }

    .slider-thumb::-webkit-slider-thumb {
        -webkit-appearance: none;
        appearance: none;
        width: 22px;
        height: 22px;
        border-radius: 50%;
        background: #2481cc;
        cursor: pointer;
        border: 3px solid #1c1c1e;
        box-shadow: 0 2px 8px rgba(36, 129, 204, 0.5);
    }

    .slider-thumb::-moz-range-thumb {
        width: 22px;
        height: 22px;
        border-radius: 50%;
        background: #2481cc;
        cursor: pointer;
        border: 3px solid #1c1c1e;
        box-shadow: 0 2px 8px rgba(36, 129, 204, 0.5);
    }
</style>
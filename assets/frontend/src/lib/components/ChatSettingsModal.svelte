<script lang="ts">
    import { fly, fade } from 'svelte/transition';
    import { X, Check, Sparkles, ChevronDown, ChevronUp, Settings2, ChevronRight } from 'lucide-svelte';
    import { createEventDispatcher } from 'svelte';
    import WebApp from "@twa-dev/sdk";
    import { appState } from '../../stores/socketStore';

    import ParametersModal from './ParametersModal.svelte';
    import ConfirmModal from './ConfirmModal.svelte';

    export let isOpen = false;
    export let currentAiModelId: string | null = null;
    export let currentTemperature: number | null = null;
    export let currentTopP: number | null = null;
    export let currentFrequencyPenalty: number | null = null;
    export let currentPresencePenalty: number | null = null;
    export let currentTier: string = 'free';

    const dispatch = createEventDispatcher<{
        apply: {
            aiModelId: string;
            temperature: number;
            topP: number;
            frequencyPenalty: number;
            presencePenalty: number;
        };
        close: void;
    }>();

    let selectedAiModelId: string | null = null;
    let isDropdownOpen = false;

    // Локальные значения параметров (живут пока открыта модалка)
    let temperature = 0.7;
    let topP = 1.0;
    let frequencyPenalty = 0.0;
    let presencePenalty = 0.0;

    // Состояние вложенных модалок
    let isParamsOpen = false;
    let isWarningOpen = false;
    let pendingParams: { temperature: number; topP: number; frequencyPenalty: number; presencePenalty: number } | null = null;

    $: ai_models = $appState?.ai_models || [];
    $: userStatus = $appState?.user_status || currentTier;
    $: selectedModel = ai_models.find(m => m.id === selectedAiModelId);

    // При открытии инициализируем всё из пропсов
    $: if (isOpen) {
        selectedAiModelId = currentAiModelId;
        temperature = currentTemperature ?? 0.7;
        topP = currentTopP ?? 1.0;
        frequencyPenalty = currentFrequencyPenalty ?? 0.0;
        presencePenalty = currentPresencePenalty ?? 0.0;
        isDropdownOpen = false;
        isParamsOpen = false;
        isWarningOpen = false;
        pendingParams = null;
    }

    function isModelAccessible(modelTier: string): boolean {
        const tierOrder: Record<string, number> = { 'free': 0, 'premium': 1, 'ultimate': 2 };
        const userLevel = tierOrder[userStatus] || 0;
        const modelLevel = tierOrder[modelTier] || 0;
        return userLevel >= modelLevel;
    }

    function close() {
        isDropdownOpen = false;
        dispatch('close');
    }

    function handleModelClick(modelId: string, isAccessible: boolean) {
        if (!isAccessible) {
            if (WebApp.HapticFeedback) WebApp.HapticFeedback.notificationOccurred('error');
            return;
        }
        selectedAiModelId = modelId;
        isDropdownOpen = false;
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.selectionChanged();
    }

    function toggleDropdown() {
        isDropdownOpen = !isDropdownOpen;
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('light');
    }

    // --- Логика параметров ---
    function openParamsModal() {
        isParamsOpen = true;
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('light');
    }

    function handleParamsApply(event: CustomEvent) {
        pendingParams = event.detail; // Сохраняем новые значения во временную переменную
        isParamsOpen = false;         // Закрываем модалку параметров
        isWarningOpen = true;         // Открываем ворнинг
    }

    function handleWarningConfirm() {
        isWarningOpen = false;
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('medium');

        // Пользователь подтвердил — применяем новые значения локально
        if (pendingParams) {
            temperature = pendingParams.temperature;
            topP = pendingParams.topP;
            frequencyPenalty = pendingParams.frequencyPenalty;
            presencePenalty = pendingParams.presencePenalty;
        }
        pendingParams = null;
        // Остаемся в ChatSettingsModal!
    }

    function handleWarningCancel() {
        isWarningOpen = false;
        pendingParams = null; // Сбрасываем неподтвержденные изменения
        // Локальные переменные temperature, topP и т.д. остались прежними (откат)
        // Остаемся в ChatSettingsModal!
    }

    // Главная кнопка "Применить" — отправляем всё в родителя
    function handleMainApply() {
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('medium');
        if (selectedAiModelId) {
            dispatch('apply', {
                aiModelId: selectedAiModelId,
                temperature,
                topP,
                frequencyPenalty,
                presencePenalty
            });
        }
        close();
    }
</script>

{#if isOpen}
    <div class="fixed inset-0 z-[100] overflow-hidden pointer-events-auto">
        <div on:click={close} class="absolute inset-0 bg-black/60 backdrop-blur-sm" transition:fade={{ duration: 150 }}></div>

        <div class="absolute bottom-0 left-0 right-0 bg-[#1c1c1e] border-t border-white/10 rounded-t-[32px] shadow-2xl flex flex-col transition-all duration-300 ease-out {isDropdownOpen ? 'h-[90dvh]' : 'max-h-[85dvh]'}"
             transition:fly={{ y: '100%', duration: 300 }}
        >
            <div class="w-full flex justify-center pt-3 pb-1 flex-shrink-0">
                <div class="w-12 h-1.5 bg-white/10 rounded-full"></div>
            </div>

            <div class="flex justify-between items-center px-6 py-3 flex-shrink-0">
                <h3 class="text-xl font-bold text-white flex items-center gap-2">
                    <Sparkles size={20} class="text-[#2481cc]" />
                    Настройки ИИ
                </h3>
                <button on:click={close} class="p-2 bg-white/5 rounded-full text-gray-400 hover:text-white transition-colors active:scale-95">
                    <X size={20} />
                </button>
            </div>

            <div class="flex-1 overflow-y-auto px-6 pb-6 space-y-6 scrollbar-none">
                <!-- Model Dropdown -->
                <div class="space-y-2">
                    <label class="text-sm font-medium text-gray-400 ml-1">Модель</label>
                    <div class="relative">
                        <button on:click={toggleDropdown} class="w-full flex items-center justify-between p-4 rounded-2xl bg-white/5 border border-white/10 hover:bg-white/10 transition-all active:scale-[0.98]">
                            <div class="flex flex-col items-start min-w-0 flex-1">
                                <span class="text-base font-semibold text-white truncate w-full">
                                    {selectedModel ? (selectedModel.display_name || selectedModel.model_name) : 'Выберите модель'}
                                </span>
                                {#if selectedModel}
                                    <span class="text-xs text-gray-400 truncate mt-0.5 w-full">
                                        {selectedModel.display_description || 'Стандартная конфигурация'}
                                    </span>
                                {/if}
                            </div>
                            {#if isDropdownOpen}<ChevronUp size={20} class="text-gray-400 ml-3 shrink-0" />{:else}<ChevronDown size={20} class="text-gray-400 ml-3 shrink-0" />{/if}
                        </button>

                        {#if isDropdownOpen}
                            <div class="absolute top-full left-0 right-0 mt-2 bg-[#121212] border border-white/10 rounded-2xl max-h-60 overflow-y-auto z-20 shadow-xl scrollbar-none" transition:fly={{ y: -10, duration: 200 }}>
                                {#each ai_models as model}
                                    {@const isAccessible = isModelAccessible(model.tier)}
                                    {@const isSelected = selectedAiModelId === model.id}
                                    <button on:click={() => handleModelClick(model.id, isAccessible)} disabled={!isAccessible} class="w-full text-left p-3.5 flex items-center justify-between transition-colors border-b border-white/5 last:border-0 overflow-hidden {isSelected ? 'bg-[#2481cc]/10' : 'hover:bg-white/5'} {!isAccessible ? 'opacity-60' : ''}">
                                        <div class="flex flex-col min-w-0 flex-1 pr-3">
                                            <span class="text-sm font-semibold text-white truncate block w-full">{model.display_name || model.model_name || 'Без имени'}</span>
                                            <span class="text-xs text-gray-400 truncate mt-0.5 block w-full">{model.display_description || 'Стандартная конфигурация'}</span>
                                        </div>
                                        <div class="flex items-center gap-2 shrink-0">
                                            {#if !isAccessible}
                                                <span class="text-[10px] font-bold uppercase tracking-wider text-amber-400 bg-amber-400/10 px-2.5 py-1 rounded-full border border-amber-400/20 whitespace-nowrap">Upgrade</span>
                                            {:else if isSelected}
                                                <div class="w-6 h-6 rounded-full bg-[#2481cc] flex items-center justify-center shrink-0">
                                                    <Check size={14} class="text-white" strokeWidth={3} />
                                                </div>
                                            {/if}
                                        </div>
                                    </button>
                                {/each}
                            </div>
                        {/if}
                    </div>
                </div>

                <!-- КНОПКА ДОПОЛНИТЕЛЬНЫХ НАСТРОЕК -->
                <div class="space-y-2 pt-2">
                    <label class="text-sm font-medium text-gray-400 ml-1">Дополнительно</label>
                    <button
                            on:click={openParamsModal}
                            class="w-full flex items-center justify-between p-4 rounded-2xl bg-white/5 border border-white/10 hover:bg-white/10 transition-all active:scale-[0.98]"
                    >
                        <div class="flex items-center gap-3">
                            <div class="w-10 h-10 rounded-xl bg-[#2481cc]/10 flex items-center justify-center">
                                <Settings2 size={20} class="text-[#2481cc]" />
                            </div>
                            <div class="flex flex-col items-start">
                                <span class="text-sm font-semibold text-white">Параметры генерации</span>
                                <span class="text-xs text-gray-400">Temperature, Top P и штрафы</span>
                            </div>
                        </div>
                        <ChevronRight size={20} class="text-gray-500" />
                    </button>
                </div>
            </div>

            <div class="p-6 pt-2 border-t border-white/5 bg-[#1c1c1e] flex-shrink-0 pb-8 safe-area-bottom">
                <button on:click={handleMainApply} disabled={!selectedAiModelId} class="w-full bg-[#2481cc] disabled:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed text-white font-bold py-4 rounded-2xl flex items-center justify-center gap-2 active:scale-[0.98] transition-all shadow-lg shadow-[#2481cc]/20">
                    Применить
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- Вложенные модалки -->
<ParametersModal
        isOpen={isParamsOpen}
        initialTemperature={temperature}
        initialTopP={topP}
        initialFrequencyPenalty={frequencyPenalty}
        initialPresencePenalty={presencePenalty}
        on:apply={handleParamsApply}
        on:close={() => isParamsOpen = false}
/>

<ConfirmModal
        isOpen={isWarningOpen}
        title="Внимание!"
        message="Изменение этих параметров может сильно поменять поведение модели, сделать её более хаотичной или галлюцинирующей. Вы уверены, что хотите применить эти настройки?"
        confirmText="Применить"
        cancelText="Отмена"
        isDanger={true}
        on:confirm={handleWarningConfirm}
        on:cancel={handleWarningCancel}
/>

<style>
    .scrollbar-none::-webkit-scrollbar { display: none; }
    .scrollbar-none { -ms-overflow-style: none; scrollbar-width: none; }
    .safe-area-bottom { padding-bottom: max(2rem, env(safe-area-inset-bottom)); }
</style>
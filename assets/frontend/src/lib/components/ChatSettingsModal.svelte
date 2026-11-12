<script lang="ts">
    import { fly, fade } from 'svelte/transition';
    import { X, Sparkles, Settings2, ChevronRight } from 'lucide-svelte';
    import { createEventDispatcher } from 'svelte';
    import WebApp from "@twa-dev/sdk";
    import { appState } from '../../stores/socketStore';

    import ParametersModal from './ParametersModal.svelte';
    import ConfirmModal from './ConfirmModal.svelte';
    import AiModelSelectorModal from './AiModelSelectorModal.svelte'; // <-- ИМПОРТ НОВОЙ МОДАЛКИ

    export let isOpen = false;
    export let currentAiModelId: string | null = null;
    export let currentImageAiModelId: string | null = null;
    export let currentTemperature: number | null = null;
    export let currentTopP: number | null = null;
    export let currentFrequencyPenalty: number | null = null;
    export let currentPresencePenalty: number | null = null;
    export let isImageSession = false;
    export let currentTier: string = 'free';

    const dispatch = createEventDispatcher<{
        apply: {
            aiModelId: string | null;
            imageAiModelId: string | null;
            temperature: number;
            topP: number;
            frequencyPenalty: number;
            presencePenalty: number;
        };
        close: void;
    }>();

    let selectedAiModelId: string | null = null;
    let selectedImageAiModelId: string | null = null;

    let temperature = 0.7;
    let topP = 1.0;
    let frequencyPenalty = 0.0;
    let presencePenalty = 0.0;

    let isParamsOpen = false;
    let isWarningOpen = false;
    let pendingParams: { temperature: number; topP: number; frequencyPenalty: number; presencePenalty: number } | null = null;

    // Состояние для модалки выбора модели
    let isModelSelectorOpen = false;
    let selectorTarget: 'llm' | 'image' = 'llm';

    $: ai_models = $appState?.ai_models || [];
    $: llmAiModels = ai_models.filter(m => m.type === 'llm');
    $: imageAiModels = ai_models.filter(m => m.type === 'image');

    $: userStatus = $appState?.user_status || currentTier;
    $: selectedModel = ai_models.find(m => m.id === selectedAiModelId);
    $: selectedImageAiModel = imageAiModels.find(m => m.id === selectedImageAiModelId);

    // Динаические данные для модалки выбора
    $: selectorModels = selectorTarget === 'llm' ? llmAiModels : imageAiModels;
    $: selectorTitle = selectorTarget === 'llm' ? 'Модель оркестратора' : 'Модель генерации';
    $: selectorSelectedId = selectorTarget === 'llm' ? selectedAiModelId : selectedImageAiModelId;

    $: if (isOpen) {
        selectedAiModelId = currentAiModelId;
        selectedImageAiModelId = currentImageAiModelId;
        temperature = currentTemperature ?? 0.7;
        topP = currentTopP ?? 1.0;
        frequencyPenalty = currentFrequencyPenalty ?? 0.0;
        presencePenalty = currentPresencePenalty ?? 0.0;
        isParamsOpen = false;
        isWarningOpen = false;
        pendingParams = null;
        isModelSelectorOpen = false;
    }

    function close() {
        dispatch('close');
    }

    function openModelSelector(target: 'llm' | 'image') {
        selectorTarget = target;
        isModelSelectorOpen = true;
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('light');
    }

    function handleModelSelect(event: CustomEvent<string>) {
        const modelId = event.detail;
        if (selectorTarget === 'llm') {
            selectedAiModelId = modelId;
        } else {
            selectedImageAiModelId = modelId;
        }
        isModelSelectorOpen = false;
    }

    function openParamsModal() {
        isParamsOpen = true;
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('light');
    }

    function handleParamsApply(event: CustomEvent) {
        pendingParams = event.detail;
        isParamsOpen = false;
        isWarningOpen = true;
    }

    function handleWarningConfirm() {
        isWarningOpen = false;
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('medium');
        if (pendingParams) {
            temperature = pendingParams.temperature;
            topP = pendingParams.topP;
            frequencyPenalty = pendingParams.frequencyPenalty;
            presencePenalty = pendingParams.presencePenalty;
        }
        pendingParams = null;
    }

    function handleWarningCancel() {
        isWarningOpen = false;
        pendingParams = null;
    }

    function handleMainApply() {
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('medium');

        const isValid = selectedAiModelId && (!isImageSession || selectedImageAiModelId);

        if (isValid) {
            dispatch('apply', {
                aiModelId: selectedAiModelId,
                imageAiModelId: selectedImageAiModelId,
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

        <div class="absolute bottom-0 left-0 right-0 bg-[#1c1c1e] border-t border-white/10 rounded-t-[32px] shadow-2xl flex flex-col transition-all duration-300 ease-out max-h-[85dvh]"
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

                <!-- 1. Модель оркестратора (ВСЕГДА видна, открывает модалку) -->
                <div class="space-y-2">
                    <label class="text-sm font-medium text-gray-400 ml-1">Модель оркестратора</label>
                    <button
                            on:click={() => openModelSelector('llm')}
                            class="w-full flex items-center justify-between p-4 rounded-2xl bg-white/5 border border-white/10 hover:bg-white/10 transition-all active:scale-[0.98]"
                    >
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
                        <ChevronRight size={20} class="text-gray-500 shrink-0" />
                    </button>
                </div>

                <!-- 2. Модель генерации (ТОЛЬКО если isImageSession, открывает модалку) -->
                {#if isImageSession}
                    <div class="space-y-2">
                        <label class="text-sm font-medium text-gray-400 ml-1">Модель генерации</label>
                        <button
                                on:click={() => openModelSelector('image')}
                                class="w-full flex items-center justify-between p-4 rounded-2xl bg-white/5 border border-white/10 hover:bg-white/10 transition-all active:scale-[0.98]"
                        >
                            <div class="flex flex-col items-start min-w-0 flex-1">
                                <span class="text-base font-semibold text-white truncate w-full">
                                    {selectedImageAiModel ? (selectedImageAiModel.display_name || selectedImageAiModel.model_name) : 'Выберите модель'}
                                </span>
                                {#if selectedImageAiModel}
                                    <span class="text-xs text-gray-400 truncate mt-0.5 w-full">
                                        {selectedImageAiModel.display_description || 'Стандартная конфигурация'}
                                    </span>
                                {/if}
                            </div>
                            <ChevronRight size={20} class="text-gray-500 shrink-0" />
                        </button>
                    </div>
                {/if}

                <!-- 3. Дополнительные настройки (СКРЫТЫ если isImageSession) -->
                {#if !isImageSession}
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
                {/if}
            </div>

            <div class="p-6 pt-2 border-t border-white/5 bg-[#1c1c1e] flex-shrink-0 pb-8 safe-area-bottom">
                <button
                        on:click={handleMainApply}
                        disabled={!selectedAiModelId || (isImageSession && !selectedImageAiModelId)}
                        class="w-full bg-[#2481cc] disabled:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed text-white font-bold py-4 rounded-2xl flex items-center justify-center gap-2 active:scale-[0.98] transition-all shadow-lg shadow-[#2481cc]/20"
                >
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

<AiModelSelectorModal
        isOpen={isModelSelectorOpen}
        title={selectorTitle}
        models={selectorModels}
        selectedModelId={selectorSelectedId}
        userStatus={userStatus}
        on:select={handleModelSelect}
        on:close={() => isModelSelectorOpen = false}
/>

<style>
    .scrollbar-none::-webkit-scrollbar { display: none; }
    .scrollbar-none { -ms-overflow-style: none; scrollbar-width: none; }
    .safe-area-bottom { padding-bottom: max(2rem, env(safe-area-inset-bottom)); }
</style>
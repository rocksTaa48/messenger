<script lang="ts">
    // Импорты
    import { slide, fade } from 'svelte/transition';
    import { X, PlusCircle } from 'lucide-svelte';
    import { appState } from '../../stores/socketStore';
    import Icons from './partials/Icons.svelte';

    // Состояние модалки
    export let isOpen = false;

    // Текущий шаг (окно выбора модели следом ввод промпта)
    let currentStep: 'select_model' | 'enter_prompt' = 'select_model';

    // Данные для бэкенда
    let selectedModelId = '';
    let systemPrompt = '';

    // Активная вкладка "Личные" или "Системные" модели
    let activeTab: 'global' | 'personal' = 'global';

    // Я специально не передаю в стор данные! Все остается стейт-лесс, так как это всего лишь шторка
    $: filteredProfiles = ($appState?.ai_profiles || []).filter(
        profile => profile.variant === activeTab
    );

    $: activeCategoryId = $appState.nav_context.params?.group_id || null


    function close() {
        isOpen = false;
        selectedModelId = '';
        systemPrompt = '';
        currentStep = 'select_model';
    }

    function handleSubmit() {
        if (!selectedModelId) return;

        appState.send("chat:click_submit", {
            ai_profile_id: selectedModelId,
            system_prompt: systemPrompt,
            group_id: activeCategoryId,
        });

        close();
    }

    function triggerHaptic() {
        const tg = (window as any).Telegram?.WebApp;
        if (tg?.HapticFeedback) {
            tg.HapticFeedback.impactOccurred('light');
        }
    }
</script>

<!-- Блокируем скролл фона, чтобы iOS не дергала экран при фокусе -->
<svelte:body class:overflow-hidden={isOpen} class:touch-none={isOpen} />

{#if isOpen}
    <div class="fixed inset-0 z-[100] overflow-hidden pointer-events-auto">
        <!-- Задний фон -->
        <div on:click={close}
             class="absolute inset-0 bg-black/60 backdrop-blur-sm"
             transition:fade={{ duration: 150 }}
        ></div>

        <!-- Контейнер модального окна -->
        <div
                class="absolute bottom-0 left-0 right-0 bg-[#1c1c1e] border-t border-white/10 rounded-t-[32px] p-6 shadow-2xl flex flex-col overflow-hidden overscroll-none"
                style="max-height: 92dvh; min-height: min(600px, 85dvh);"
                transition:slide={{ y: 500, duration: 300 }}
        >
            <!-- Полоска сверху -->
            <div class="w-12 h-1.5 bg-white/10 rounded-full mx-auto mb-5 flex-shrink-0"></div>

            <!-- Шапка -->
            <div class="flex justify-between items-center mb-5 flex-shrink-0">
                <div class="flex items-center gap-2">
                    {#if currentStep === 'enter_prompt'}
                        <button on:click={() => { currentStep = 'select_model'; triggerHaptic(); }}
                                class="p-2 bg-white/5 rounded-full text-gray-400 hover:text-white transition-colors active:scale-95 mr-1"
                        >
                            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 18-6-6 6-6"/></svg>
                        </button>
                    {/if}
                    <h3 class="text-xl font-bold text-white">
                        {currentStep === 'select_model' ? 'Новый ассистент' : 'Настройка'}
                    </h3>
                </div>

                <button on:click={() => { close(); triggerHaptic(); }}
                        class="p-2 bg-white/5 rounded-full text-gray-400 hover:text-white transition-colors active:scale-95"
                >
                    <X size={20} />
                </button>
            </div>

            <!-- Зона шагов -->
            <div class="flex-1 min-h-0 relative overflow-hidden w-full">
                {#key currentStep}
                    <div
                            in:slide={{ x: currentStep === 'select_model' ? -50 : 50, duration: 250 }}
                            out:slide={{ x: currentStep === 'select_model' ? 50 : -50, duration: 200 }}
                            class="absolute inset-0 flex flex-col overflow-y-auto pb-4 scrollbar-none overscroll-none"
                            style="-webkit-overflow-scrolling: touch;"
                    >
                        <!-- ЭКРАН - 1: ВЫБОР МОДЕЛИ -->
                        {#if currentStep === 'select_model'}
                            <div class="flex flex-col gap-2 h-full">
                                <!-- Переключатель Глобальные / Личные -->
                                <div class="bg-white/5 p-1 rounded-xl flex gap-1 flex-shrink-0 mb-2">
                                    <button type="button" on:click={() => { activeTab = 'global'; triggerHaptic(); }}
                                            class="flex-1 py-1.5 text-xs font-semibold rounded-lg transition-all duration-200 {activeTab === 'global' ? 'bg-[#2481cc] text-white shadow-md' : 'text-gray-400 hover:text-gray-200'}"
                                    >
                                        Глобальные
                                    </button>
                                    <button type="button" on:click={() => { activeTab = 'personal'; triggerHaptic(); }}
                                            class="flex-1 py-1.5 text-xs font-semibold rounded-lg transition-all duration-200 {activeTab === 'personal' ? 'bg-[#2481cc] text-white shadow-md' : 'text-gray-400 hover:text-gray-200'}"
                                    >
                                        Личные
                                    </button>
                                </div>

                                <!-- Список моделей -->
                                <div class="relative overflow-hidden w-full flex-1">
                                    {#key activeTab}
                                        <!-- Заменил fly на fade плавный. -->
                                        <div in:fade={{ duration: 150 }} out:fade={{ duration: 100 }}
                                             class="grid grid-cols-1 gap-2 w-full h-full content-start"
                                        >
                                            {#if $appState && $appState.ai_profiles}
                                                {#if filteredProfiles.length > 0}
                                                    {#each filteredProfiles as profile (profile.id)}
                                                        <button on:click={() => {
                                                                selectedModelId = profile.id;
                                                                currentStep = 'enter_prompt';
                                                                triggerHaptic();
                                                            }}
                                                                type="button"
                                                                class="flex items-center gap-4 p-3 rounded-2xl border transition-all text-left w-full active:scale-[0.99]
                                                                {selectedModelId === profile.id ? 'bg-[#2481cc]/10 border-[#2481cc]/50' : 'bg-white/[0.03] border-white/5'}"
                                                        >
                                                            <div class="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 {profile.color}">
                                                                <Icons {...{ [profile.provider]: true }} size={20} />
                                                            </div>
                                                            <div class="flex-1 min-w-0">
                                                                <h4 class="text-sm font-bold text-white truncate">{profile.name}</h4>
                                                                <p class="text-[10px] text-gray-500 truncate">ID: {profile.model}</p>
                                                            </div>
                                                        </button>
                                                    {/each}
                                                {:else}
                                                    <p class="text-xs text-center text-slate-500 p-4 w-full">
                                                        {activeTab === 'personal' ? 'У вас еще нет личных моделей' : 'Нет доступных глобальных моделей'}
                                                    </p>
                                                {/if}
                                            {:else}
                                                <p class="text-xs text-slate-500 p-2 animate-pulse w-full">Загрузка доступных моделей...</p>
                                            {/if}
                                        </div>
                                    {/key}
                                </div>
                            </div>
                        {/if}

                        <!-- ЭКРАН - 2: ВВОД ИНСТРУКЦИЙ -->
                        {#if currentStep === 'enter_prompt'}
                            <div class="flex flex-col gap-2 mt-2 h-full">
                                <label for="prompt-input" class="text-xs font-bold uppercase tracking-wider text-gray-400 pl-1">
                                    Инструкции (Промпт — Опционально)
                                </label>
                                <textarea id="prompt-input"
                                          bind:value={systemPrompt}
                                          placeholder="Например: Ты эксперт по крипте TON. Отвечай коротко и только по делу... Этот шаг можно пропустить"
                                          class="w-full h-40 px-4 py-3 bg-white/5 border border-white/5 rounded-2xl text-base text-white focus:outline-none focus:border-[#2481cc]/50 focus:bg-white/[0.07] transition-all placeholder-gray-600 resize-none"
                                          style="-webkit-appearance: none;"
                                ></textarea>
                            </div>
                        {/if}
                    </div>
                {/key}
            </div>

            <!-- НИЖНЯЯ КНОПКА -->
            <div class="pt-4 flex-shrink-0 pb-safe">
                {#if currentStep === 'enter_prompt'}
                    <div class="pt-4 flex-shrink-0 pb-safe">
                        <button on:click={() => { handleSubmit(); triggerHaptic(); }}
                                class="w-full bg-[#2481cc] text-white font-bold py-4 rounded-full flex items-center justify-center gap-2 active:scale-95 transition-all shadow-lg shadow-[#2481cc]/20 text-sm uppercase tracking-wider"
                        >
                            <PlusCircle size={18} />
                            Создать диалог
                        </button>
                    </div>
                {/if}
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
</style>
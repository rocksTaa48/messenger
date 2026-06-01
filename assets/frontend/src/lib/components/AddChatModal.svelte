<script lang="ts">
    // Импорты компонентов
    import { fly, fade } from 'svelte/transition';
    import { X, PlusCircle } from 'lucide-svelte';
    import { appState } from '../../stores/socketStore';
    import { onMount } from 'svelte';

    import Icons from './partials/Icons.svelte'

    // Состояние открытия самого по себе модальника
    export let isOpen = false;

    // Переменные (положим их сюда) которые мы передадим на бэк после 'Submitting'
    let selectedModelId = '';
    let systemPrompt = '';
    let textareaRef: HTMLTextAreaElement;
    let initialScrollPosition = 0;

    // Функция скроллинга экрана к вводу текста
    function handleFocus() {
        initialScrollPosition = window.scrollY;
        setTimeout(() => {
            if (textareaRef) {
                textareaRef.scrollIntoView({
                    behavior: 'smooth',
                    block: 'center'
                });
            }
        }, 100);
    }

    function handleBlur() {
        window.scrollTo({
            top: initialScrollPosition,
            behavior: 'smooth'
        });
    }

    function handleResize() {
        if (document.activeElement === textareaRef) {
            setTimeout(() => {
                textareaRef?.scrollIntoView({
                    behavior: 'smooth',
                    block: 'center'
                });
            }, 50);
        }
    }

    onMount(() => {
        window.addEventListener('resize', handleResize);
        return () => {
            window.removeEventListener('resize', handleResize);
        };
    });

    function close() {
        isOpen = false;
        selectedModelId = '';
        systemPrompt = '';
        if (textareaRef) {
            textareaRef.blur();
        }
    }

    // Функция 'Submit' пользователь нажал кнопку, инициировав CREATE
    function handleSubmit() {
        if (!selectedModelId) return;

        appState.send("click:submit_new_chat", {
            ai_profile_id: selectedModelId,
            system_prompt: systemPrompt
        });

        close();
    }

    // Виброотклик от кнопки
    function triggerHaptic() {
        const tg = (window as any).Telegram?.WebApp;
        if (tg?.HapticFeedback) {
            tg.HapticFeedback.impactOccurred('light');
        }
    }
</script>

{#if isOpen}
    <div class="fixed inset-0 z-[100] overflow-hidden pointer-events-auto">
        <div on:click={close}
             class="absolute inset-0 bg-black/60 backdrop-blur-sm"
             transition:fade={{ duration: 150 }}
        ></div>

        <div
                class="absolute bottom-0 left-0 right-0 bg-[#1c1c1e] border-t border-white/10 rounded-t-[32px] p-6 shadow-2xl flex flex-col"
                style="max-height: 85vh; min-height: 300px;"
                transition:fly={{ y: 550, duration: 250 }}
        >
            <div class="w-12 h-1.5 bg-white/10 rounded-full mx-auto mb-5 flex-shrink-0"></div>

            <div class="flex justify-between items-center mb-5 flex-shrink-0">

                <h3 class="text-xl font-bold text-white">Новый ассистент</h3>

                <button on:click={() => {
                    close();
                    triggerHaptic();
                }}
                        class="p-2 bg-white/5 rounded-full text-gray-400 hover:text-white transition-colors active:scale-95"
                >
                    <X size={20} />
                </button>
            </div>

            <div class="flex-1 overflow-y-auto space-y-5 pb-4 scrollbar-none" style="-webkit-overflow-scrolling: touch;">

                <div class="flex flex-col gap-2">
                    <label class="text-xs font-bold uppercase tracking-wider text-gray-400 pl-1">
                        Выберите нейросеть
                    </label>

                    <div class="grid grid-cols-1 gap-2">
                        {#if $appState && $appState.ai_profiles}
                            {#each $appState.ai_profiles as profile}
                                <button on:click={() => {
                                    selectedModelId = profile.id;
                                    triggerHaptic();
                                }}
                                        type="button"
                                        class="flex items-center gap-4 p-3 rounded-2xl border transition-all text-left w-full active:scale-[0.99]
                                    {selectedModelId === profile.id ? 'bg-[#2481cc]/10 border-[#2481cc]/50' : 'bg-white/[0.03] border-white/5'}"
                                >
                                    <div class="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 {profile.color}">
                                        <Icons {...{ [profile.icon]: true }} size={20} />
                                    </div>
                                    <div class="flex-1 min-w-0">
                                        <h4 class="text-sm font-bold text-white truncate">{profile.name}</h4>
                                        <p class="text-[10px] text-gray-500 truncate">ID: {profile.id}</p>
                                    </div>
                                </button>
                            {/each}
                        {:else}
                            <p class="text-xs text-slate-500 p-2 animate-pulse">Загрузка доступных моделей...</p>
                        {/if}
                    </div>
                </div>

                <div class="flex flex-col gap-1.5">
                    <label for="prompt-input" class="text-xs font-bold uppercase tracking-wider text-gray-400 pl-1">
                        Инструкции (Промпт — Опционально)
                    </label>
                    <textarea id="prompt-input"
                              bind:this={textareaRef}
                              bind:value={systemPrompt}
                              on:focus={handleFocus}
                              on:blur={handleBlur}
                              placeholder="Например: Ты эксперт по крипте TON. Отвечай коротко и только по делу..."
                              class="w-full h-24 px-4 py-3 bg-white/5 border border-white/5 rounded-2xl text-base text-white focus:outline-none focus:border-[#2481cc]/50 focus:bg-white/[0.07] transition-all placeholder-gray-600 resize-none"
                              style="-webkit-appearance: none;"
                    ></textarea>
                </div>
            </div>

            <div class="pt-2 flex-shrink-0 pb-safe">
                <button on:click={() => {
                    handleSubmit();
                    triggerHaptic();
                }}
                        disabled={!selectedModelId}
                        class="w-full bg-[#2481cc] disabled:bg-gray-700 disabled:opacity-40 disabled:cursor-not-allowed text-white font-bold py-4 rounded-full flex items-center justify-center gap-2 active:scale-95 transition-all shadow-lg shadow-[#2481cc]/20 text-sm uppercase tracking-wider"
                >
                    <PlusCircle size={18} />
                    Создать диалог
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
        padding-bottom: env(safe-area-inset-bottom, 0px);
    }
</style>
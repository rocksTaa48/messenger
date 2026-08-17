<script lang="ts">
    import { slide, fade } from 'svelte/transition';
    import { X, Check } from 'lucide-svelte';
    import { appState } from '../../stores/socketStore';
    import WebApp from "@twa-dev/sdk";

    // Пропсы для универсальности (подойдет и для папок, и для чатов)
    export let isOpen = false;
    export let itemId: string | null = null;       // сами айдишники сущностей #12 or #22 так далее
    export let currentTitle = '';                  // Текущее название для предзаполнения
    export let modalTitle = 'Переименовать';       // Заголовок модалки
    export let eventType: string;         // Событие для отправки на бэк так же определяем заранее
    export let itemKey: string; // group_id chat_id сам ключ что именно мы меняем
    export let eventCode: string;
    export let extraParams: Record<string, any> = {};


    let newTitle = '';
    let inputElement: HTMLInputElement;

    // При открытии модалки заполняем поле текущим названием и фокусируем его
    $: if (isOpen) {
        newTitle = currentTitle;
        // Небольшая задержка для гарантии фокуса в TMA после анимации
        setTimeout(() => {
            if (inputElement) {
                inputElement.focus();
                inputElement.select(); // Выделяем весь текст для удобной замены
            }
        }, 300);
    }

    function close() {
        isOpen = false;
        newTitle = '';
    }

    function triggerHaptic() {
        if (WebApp.HapticFeedback) {
            WebApp.HapticFeedback.impactOccurred('light');
        }
    }

    function handleSave() {
        const trimmedTitle = newTitle.trim();
        if (!trimmedTitle || !itemId) return;

        triggerHaptic();

        // Отправляем универсальный запрос на бэк
        appState.send(eventType, {
            [itemKey]: itemId, // динамически
            title: trimmedTitle,
            action: eventCode,
            ...extraParams
        });

        close();
    }

    function handleKeydown(event: KeyboardEvent) {
        if (event.key === 'Enter') {
            event.preventDefault();
            handleSave();
        }
    }
</script>

<svelte:body class:overflow-hidden={isOpen} class:touch-none={isOpen} />

{#if isOpen}
    <div class="fixed inset-0 z-[120] flex items-center justify-center p-5 pointer-events-auto">

        <!-- ЗАДНИЙ ФОН -->
        <div
                on:click={close}
                class="absolute inset-0 bg-black/60 backdrop-blur-sm"
                transition:fade={{ duration: 150 }}
        ></div>

        <!-- ОКНО В ОКНЕ -->
        <div
                class="relative z-10 w-full bg-[#1c1c1e] border border-white/10 rounded-[28px] shadow-2xl flex flex-col overflow-hidden overscroll-none"
                style="max-height: 70dvh;"
                transition:slide={{ y: 200, duration: 250 }}
        >

            <!-- ШАПКА -->
            <div class="flex justify-between items-center px-5 pt-5 pb-3 flex-shrink-0">
                <div class="min-w-0">
                    <h3 class="text-lg font-bold text-white">{modalTitle}</h3>
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

            <!-- КОНТЕНТ: ПОЛЕ ВВОДА -->
            <div class="flex-1 min-h-0 flex flex-col justify-center px-5 py-6">
                <input
                        bind:this={inputElement}
                        bind:value={newTitle}
                        on:keydown={handleKeydown}
                        type="text"
                        placeholder="Введите новое название..."
                        class="w-full px-4 py-3.5 bg-white/5 border border-white/10 rounded-2xl text-base text-white
                           focus:outline-none focus:border-[#2481cc] focus:bg-white/[0.07] transition-all
                           placeholder-gray-600"
                />
                <p class="text-xs text-gray-500 mt-2 px-1">
                    {newTitle.trim().length === 0 ? 'Название не может быть пустым' : `${newTitle.trim().length}/32 символов`}
                </p>
            </div>

            <!-- НИЖНИЕ КНОПКИ -->
            <div class="px-5 pb-5 pt-2 flex-shrink-0 flex gap-3">
                <button
                        on:click={() => { close(); triggerHaptic(); }}
                        class="flex-1 bg-white/5 text-white font-semibold py-3.5 rounded-2xl flex items-center justify-center gap-2 active:scale-[0.98] transition-all border border-white/5 hover:bg-white/10"
                >
                    Отмена
                </button>
                <button
                        on:click={handleSave}
                        disabled={newTitle.trim().length === 0}
                        class="flex-1 bg-[#2481cc] text-white font-semibold py-3.5 rounded-2xl flex items-center justify-center gap-2 active:scale-[0.98] transition-all
                               disabled:opacity-50 disabled:cursor-not-allowed shadow-lg shadow-[#2481cc]/20"
                >
                    <Check size={18} />
                    Сохранить
                </button>
            </div>

        </div>
    </div>
{/if}
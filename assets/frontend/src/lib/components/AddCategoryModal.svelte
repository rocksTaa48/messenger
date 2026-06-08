<script lang="ts">
    import { fly, fade } from 'svelte/transition';
    import { X, PlusCircle } from 'lucide-svelte';
    import { createEventDispatcher } from 'svelte';
    import {appState} from "../../stores/socketStore";

    export let isOpen = false;

    let newGroupName = ''; // Имя группы (надо ограничить 30 символами)

    const dispatch = createEventDispatcher<{ add: string }>();

    function close() {
        isOpen = false;
        newGroupName = "";
    }

    function handleSubmit() {
        if (!newGroupName) return;

        appState.send("chat:click_submit_chat_group", {
            new_group_name: newGroupName
        });

        close();
    }

    function handleKeyDown(event: KeyboardEvent) {
        if (event.key === 'Enter') {
            handleSubmit();
        }
    }

    // Фокус после того как шторка вылезет
    function focusAfterFly(node: HTMLInputElement) {
        setTimeout(() => {
            if (node) node.focus();
        }, 200); // 200мс чтобы шторка зафризила и клавиатура не подбросила её
    }

    function triggerHaptic() {
        const tg = (window as any).Telegram?.WebApp;
        if (tg?.HapticFeedback) {
            tg.HapticFeedback.impactOccurred('light');
        }
    }
</script>

{#if isOpen}
    <!-- ГЛАВНЫЙ ФИКСИРОВАННЫЙ КОНТЕЙНЕР НА ВЕСЬ ЭКРАН -->
    <div class="fixed inset-0 z-[100] overflow-hidden pointer-events-auto">

        <!-- Затемнение фона (Backdrop) -->
        <div
                class="absolute inset-0 bg-black/60 backdrop-blur-sm"
                on:click={close}
                transition:fade={{ duration: 150 }}
        ></div>

        <!-- ТЕЛО ШТОРКИ (привязано к низу экрана) -->
        <div
                class="absolute bottom-0 left-0 right-0 bg-[#1c1c1e] border-t border-white/10 rounded-t-[32px] p-6 shadow-2xl"
                transition:fly={{ y: 450, duration: 250 }}
        >
            <!-- Полоска для смахивания -->
            <div class="w-12 h-1.5 bg-white/10 rounded-full mx-auto mb-6"></div>

            <!-- Заголовок шторки -->
            <div class="flex justify-between items-center mb-6">
                <h3 class="text-xl font-bold text-white">New Category</h3>
                <button on:click={() => { close(); triggerHaptic(); }} class="p-2 bg-white/5 rounded-full text-gray-400 hover:text-white transition-colors">
                    <X size={20} />
                </button>
            </div>

            <!-- Контент: Форма ввода -->
            <div class="space-y-5">
                <div class="flex flex-col gap-1.5">
                    <label for="category-input" class="text-xs font-bold uppercase tracking-wider text-gray-400 pl-1">
                        Folder Name
                    </label>
                    <!-- focusAfterFly -->
                    <input
                            id="category-input"
                            type="text"
                            bind:value={newGroupName}
                            on:keydown={handleKeyDown}
                            placeholder="e.g. Work, Friends, AI Prompts..."
                            class="w-full px-5 py-4 bg-white/5 border border-white/5 rounded-2xl text-base text-white focus:outline-none focus:border-[#2481cc]/50 focus:bg-white/[0.07] transition-all placeholder-gray-600"
                            use:focusAfterFly
                    />
                </div>

                <!-- Кнопка Создать -->
                <button
                        on:click={() => { handleSubmit(); triggerHaptic(); }}
                        disabled={!newGroupName.trim()}
                        class="w-full bg-[#2481cc] disabled:bg-gray-700 disabled:opacity-40 disabled:cursor-not-allowed text-white font-bold py-4 rounded-full flex items-center justify-center gap-2 active:scale-95 transition-all shadow-lg shadow-[#2481cc]/20"
                >
                    <PlusCircle size={18} />
                    CREATE FOLDER
                </button>
            </div>

            <!-- Отступ снизу -->
            <div class="h-6"></div>
        </div>
    </div>
{/if}

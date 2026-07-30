<script lang="ts">
    // ============================================================
    // ИМПОРТЫ
    // ============================================================
    import { slide, fade } from 'svelte/transition';
    import { X, Folder } from 'lucide-svelte';
    import { appState } from '../../stores/socketStore';
    import WebApp from "@twa-dev/sdk";

    // ============================================================
    // ПРОПСЫ
    // ============================================================
    export let isOpen = false;
    export let chatId: string | null = null;
    export let chatTitle = '';

    // ============================================================
    // РЕАКТИВНЫЕ ДАННЫЕ
    // ============================================================
    $: groups = $appState?.groups || [];
    $: hasGroups = groups.length > 0;

    // ============================================================
    // ФУНКЦИИ
    // ============================================================
    function close() {
        isOpen = false;
    }

    function triggerHaptic() {
        if (WebApp.HapticFeedback) {
            WebApp.HapticFeedback.impactOccurred('light');
        }
    }

    function handleFolderSelect(groupId: string) {
        if (!chatId) return;
        triggerHaptic();

        appState.send("chat:click_update_chat_group", {
            chat_id: chatId,
            group_id: groupId,
            action: "add"
        });

        appState.goTo({
            screen: 'chats',
            params: { group_id: groupId }
        });

        close();
    }

</script>

<svelte:body class:overflow-hidden={isOpen} class:touch-none={isOpen} />

{#if isOpen}
    <div class="fixed inset-0 z-[110] flex items-center justify-center p-5 pointer-events-auto">

        <!-- 5 ЗАДНИЙ ФОН -->
        <div
                on:click={close}
                class="absolute inset-0 bg-black/60 backdrop-blur-sm"
                transition:fade={{ duration: 150 }}
        ></div>

        <!-- 6 ОКНО В ОКНЕ -->
        <div
                class="relative z-10 w-full bg-[#1c1c1e] border border-white/10 rounded-[28px] shadow-2xl flex flex-col overflow-hidden overscroll-none"
                style="max-height: 70dvh;"
                transition:slide={{ y: 200, duration: 250 }}
        >

            <!-- 7 ШАПКА -->
            <div class="flex justify-between items-center px-5 pt-5 pb-3 flex-shrink-0">
                <div class="min-w-0">
                    <h3 class="text-lg font-bold text-white">Выберите папку</h3>
                    <p class="text-xs text-gray-500 mt-0.5 truncate">{chatTitle}</p>
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

            <!-- 8 СПИСОК ПАПОК ИЛИ ПУСТОЕ СОСТОЯНИЕ -->
            <div class="flex-1 min-h-0 overflow-y-auto scrollbar-none px-2 py-2" style="-webkit-overflow-scrolling: touch;">

                {#if hasGroups}
                    {#each groups as group (group.id)}
                        <button
                                on:click={() => handleFolderSelect(group.id.toString())}
                                class="w-full flex items-center gap-3 px-4 py-3.5 rounded-2xl text-left
                                   text-[#52a6e7] text-[15px] font-medium
                                   hover:bg-white/5 active:bg-white/10 transition-colors"
                        >
                            <Folder size={18} class="text-gray-500 flex-shrink-0" />
                            <span class="truncate">{group.title}</span>
                        </button>
                    {/each}
                {:else}
                    <!-- Пустое состояние -->
                    <div class="flex flex-col items-center justify-center py-16 px-4 text-center">
                        <Folder size={32} class="text-gray-600 mb-3" />
                        <p class="text-sm text-gray-400 font-medium">Папок пока нет</p>
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
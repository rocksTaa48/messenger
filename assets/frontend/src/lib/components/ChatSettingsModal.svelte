<script lang="ts">
    import { fly, fade } from 'svelte/transition';
    import { X, Check, Sparkles, Crown, Zap, Lock } from 'lucide-svelte';
    import { createEventDispatcher } from 'svelte';
    import WebApp from "@twa-dev/sdk";
    import { appState } from '../../stores/socketStore';

    export let isOpen = false;

    const dispatch = createEventDispatcher<{ select: string }>();

    let selectedProfileId: string | null = null;
    let activeTab = 'free';

    $: profiles = $appState?.ai_profiles || [];
    $: userStatus = $appState?.user_status || 'free';

    // Fallback логика: сначала active_chat.ai_profile, потом дефолтный ai_profile
    $: currentProfileId = $appState?.active_chat?.ai_profile?.id || $appState?.ai_profile?.id || null;

    // Фильтрация по табу
    $: filteredProfiles = profiles.filter(profile => profile.tier === activeTab);

    // Сбрасываем выбор при открытии
    $: if (isOpen) {
        selectedProfileId = currentProfileId;
        activeTab = 'free';
    }

    // Проверка доступности профиля
    function isProfileAccessible(profileTier: string): boolean {
        const tierOrder = { 'free': 0, 'premium': 1, 'ultimate': 2 };
        const userLevel = tierOrder[userStatus] || 0;
        const profileLevel = tierOrder[profileTier] || 0;
        return userLevel >= profileLevel;
    }

    function close() {
        isOpen = false;
    }

    function handleProfileClick(profileId: string, isAccessible: boolean) {
        if (!isAccessible) {
            if (WebApp.HapticFeedback) WebApp.HapticFeedback.notificationOccurred('error');
            return;
        }
        selectedProfileId = profileId;
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.selectionChanged();
    }

    function handleTabClick(tab: string) {
        activeTab = tab;
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('light');
    }

    function handleApply() {
        if (WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('medium');
        dispatch('select', selectedProfileId);
        close();
    }
</script>

{#if isOpen}
    <div class="fixed inset-0 z-[100] overflow-hidden pointer-events-auto">
        <!-- Затемнение фона -->
        <div
                class="absolute inset-0 bg-black/60 backdrop-blur-sm"
                on:click={close}
                transition:fade={{ duration: 150 }}
        ></div>

        <!-- ТЕЛО ШТОРКИ: Зафиксируем высоту в 80% -->
        <div
                class="absolute bottom-0 left-0 right-0 h-[80dvh] bg-[#1c1c1e] border-t border-white/10 rounded-t-[32px] shadow-2xl flex flex-col"
                transition:fly={{ y: '100%', duration: 300 }}
        >
            <!-- Полоска -->
            <div class="w-full flex justify-center pt-3 pb-1 flex-shrink-0">
                <div class="w-12 h-1.5 bg-white/10 rounded-full"></div>
            </div>

            <!-- Заголовок -->
            <div class="flex justify-between items-center px-6 py-3 flex-shrink-0">
                <h3 class="text-xl font-bold text-white flex items-center gap-2">
                    <Sparkles size={20} class="text-[#2481cc]" />
                    Модель ИИ
                </h3>
                <button
                        on:click={() => { close(); if(WebApp.HapticFeedback) WebApp.HapticFeedback.impactOccurred('light'); }}
                        class="p-2 bg-white/5 rounded-full text-gray-400 hover:text-white transition-colors active:scale-95"
                >
                    <X size={20} />
                </button>
            </div>

            <!-- СПИСОК ПРОФИЛЕЙ -->
            <div class="flex-1 overflow-y-auto px-6 pb-6 space-y-3 scrollbar-none">

                <!-- ТАБЫ -->
                <div class="sticky top-0 z-10 -mx-6 px-6 py-3 mb-2">
                    <div class="rounded-[32px] overflow-hidden border border-white/5 bg-[#121212]/10 backdrop-blur-2xl">
                        <div class="flex items-center">
                            <button
                                    on:click={() => handleTabClick('free')}
                                    class="flex-1 px-4 py-2.5 text-[13px] font-semibold transition-all duration-200
                {activeTab === 'free'
                    ? 'bg-white/10 text-white'
                    : 'bg-white/5 text-gray-400 hover:bg-white/10 hover:text-white'}"
                            >
                                Free
                            </button>

                            <button
                                    on:click={() => handleTabClick('premium')}
                                    class="flex-1 px-4 py-2.5 text-[13px] font-semibold transition-all duration-200 flex items-center justify-center gap-1.5
                {activeTab === 'premium'
                    ? 'bg-amber-500/20 text-amber-300 border border-amber-500/30'
                    : 'bg-white/5 text-gray-400 hover:bg-white/10 hover:text-white border border-transparent'}"
                            >
                                <Crown size={12} />
                                Premium
                            </button>

                            <button
                                    on:click={() => handleTabClick('ultimate')}
                                    class="flex-1 px-4 py-2.5 text-[13px] font-semibold transition-all duration-200 flex items-center justify-center gap-1.5
                {activeTab === 'ultimate'
                    ? 'bg-purple-500/20 text-purple-300 border border-purple-500/30'
                    : 'bg-white/5 text-gray-400 hover:bg-white/10 hover:text-white border border-transparent'}"
                            >
                                <Zap size={12} />
                                Ultimate
                            </button>
                        </div>
                    </div>
                </div>

                {#if filteredProfiles.length === 0}
                    <div class="flex flex-col items-center justify-center py-8 text-gray-500">
                        <Sparkles size={32} class="mb-2 opacity-20" />
                        <p class="text-sm">В этой категории пока нет моделей</p>
                    </div>
                {:else}
                    {#each filteredProfiles as profile}
                        {@const isSelected = selectedProfileId === profile.id}
                        {@const isAccessible = isProfileAccessible(profile.tier)}

                        <button
                                on:click={() => handleProfileClick(profile.id, isAccessible)}
                                disabled={!isAccessible}
                                class="w-full text-left p-4 rounded-[32px] border transition-all duration-200 flex items-center justify-between group active:scale-[0.98] relative overflow-hidden
                            {isSelected
                                ? 'bg-[#2481cc]/10 border-[#2481cc]/50'
                                : isAccessible
                                    ? 'bg-white/5 border-white/5 hover:bg-white/10'
                                    : 'bg-white/[0.02] border-white/5 opacity-60 cursor-not-allowed'}"
                        >
                            <!-- UPGRADE PLAN -->
                            {#if !isAccessible}
                                <div class="absolute top-0 -left-10 w-28 h-28 rotate-[-35deg] bg-gradient-to-r from-amber-500 to-orange-500 flex items-center justify-end pr-2 shadow-lg z-10">
                                    <span class="text-[9px] font-extralight text-white uppercase tracking-wider whitespace-nowrap">
                                        Upgrade
                                    </span>
                                </div>
                            {/if}

                            <div class="flex flex-col flex-1 min-w-0 pr-3 {isAccessible ? '' : 'ml-8'}">
                                <div class="flex items-center gap-2">
                                    <span class="text-base font-semibold text-white truncate">{profile.display_name || profile.name}</span>
                                    {#if !isAccessible}
                                        <Lock size={14} class="text-amber-400 shrink-0" />
                                    {/if}
                                </div>
                                <span class="text-xs text-gray-400 mt-1 truncate">
                                    {profile.display_description || profile.description || 'Стандартная конфигурация'}
                                </span>
                            </div>

                            <div class="w-6 h-6 rounded-full flex items-center justify-center transition-all ml-2 shrink-0
                                {isSelected
                                    ? 'bg-[#2481cc] text-white'
                                    : isAccessible
                                        ? 'bg-white/10 text-transparent group-hover:bg-white/20'
                                        : 'bg-white/5 text-transparent'}">
                                <Check size={14} strokeWidth={3} />
                            </div>
                        </button>
                    {/each}
                {/if}
            </div>

            <!-- Кнопка Применить (flex-shrink-0 запрещает сжатие) -->
            <div class="p-6 pt-2 border-t border-white/5 bg-[#1c1c1e] flex-shrink-0 pb-8">
                <button
                        on:click={handleApply}
                        disabled={!selectedProfileId}
                        class="w-full bg-[#2481cc] disabled:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed text-white font-bold py-4 rounded-2xl flex items-center justify-center gap-2 active:scale-[0.98] transition-all shadow-lg shadow-[#2481cc]/20"
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
</style>
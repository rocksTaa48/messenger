<script lang="ts">
  import {
    Sun, Moon, Settings, ChevronRight, Shield,
    HelpCircle, MessageSquare, BarChart3, Coins
  } from 'lucide-svelte';
  import { fade } from 'svelte/transition';
  import { appState } from "../../stores/socketStore";
  import { initiateTonPay } from '../tma/tonpay';
  import PayMode from "./partials/PayMode.svelte"

  let isProcessing = false;
  let isPayModeOpen = false;

  $: currentUser = $appState?.user || [];

  type IconComponent = typeof BarChart3;
  type Row = { label: string; icon: IconComponent; onClick: () => void };
  type RawUsage = { ai_model_id: number | string; tokens: number };

  const PERIODS = [
    { value: '1_hour',  label: 'Last hour' },
    { value: '1_day',   label: 'Last 24h' },
    { value: '7_days',  label: 'Last 7 days' },
    { value: '1_month', label: 'Last 30 days' },
    { value: 'all',     label: 'All time' },
  ] as const;

  type Period = typeof PERIODS[number]['value'];

  let notificationsEnabled = true;
  let isDarkMode = true;
  let period: Period = '1_day';
  let credits = 1240;

  let rawUsage: RawUsage[] = [];
  let isLoading = false;
  let lastLoadedPeriod: Period | null = null;

  $: aiModelsById = Object.fromEntries(
          ($appState?.ai_models ?? []).map((m) => [String(m.id), m])
  );

  function loadUsage(p: Period) {
    const push = appState.send('user:click_show_user_usage', { period: p });
    if (!push) return;

    isLoading = true;

    push
            .receive('ok', ({ user_usage }: { user_usage: RawUsage[] }) => {
              if (period !== p) return;
              rawUsage = user_usage ?? [];
              isLoading = false;
            })
            .receive('error', () => {
              if (period !== p) return;
              rawUsage = [];
              isLoading = false;
            });
  }

  $: if ($appState?.status === 'connected' && period !== lastLoadedPeriod) {
    lastLoadedPeriod = period;
    loadUsage(period);
  }

  // Ключевое: id нужен, чтобы {#each} переиспользовал DOM по модели, а не по индексу.
  $: usage = rawUsage.map((u) => {
    const id = String(u.ai_model_id);
    const model = aiModelsById[id];
    return {
      id,
      name: model?.display_name ?? `Model #${u.ai_model_id}`,
      color: model?.display_color ? `#${model.display_color}` : '#888888',
      tokens: u.tokens,
    };
  });

  const CIRC = 2 * Math.PI * 40;
  const nf = new Intl.NumberFormat('en', { notation: 'compact', maximumFractionDigits: 1 });
  const fmt = (n: number) => nf.format(n);

  $: total = usage.reduce((s, m) => s + m.tokens, 0);

  $: segments = (() => {
    const gap = 2.5;
    let cursor = 0;
    return usage.map((m) => {
      const frac = total > 0 ? m.tokens / total : 0;
      const full = frac * CIRC;
      const seg = {
        ...m,
        frac,
        len: Math.max(0, full - gap),
        offset: -(cursor + gap / 2),
      };
      cursor += full;
      return seg;
    });
  })();

  const manageRows: Row[] = [
    { label: 'Statistics',         icon: BarChart3, onClick: () => console.log('Statistics') },
    { label: 'Preferences & Data', icon: Settings,  onClick: () => console.log('Preferences') },
  ];

  const supportRows: Row[] = [
    { label: 'Privacy Policy', icon: Shield,        onClick: () => console.log('Privacy') },
    { label: 'Help Center',    icon: HelpCircle,    onClick: () => console.log('Help') },
    { label: 'Send Feedback',  icon: MessageSquare, onClick: () => console.log('Feedback') },
  ];

  const onEditProfile  = () => console.log('Edit profile');

  async function handlePayRequest(event: CustomEvent<{ method: string }>) {
    const method = event.detail.method;
    if (method === 'tonpay') {
      isProcessing = true;
      try {
        const result = await initiateTonPay(10, 'TON');
        console.log('Платёж завершён:', result);
      } catch (error) {
        console.error('Оплата отменена или ошибка:', error);
      } finally {
        isProcessing = false;
      }
    } else if (method === 'stars') {
      console.log('Открываем Telegram Stars');
    }
  }
</script>

<div class="flex flex-col h-full w-full bg-[#0f0f0f] rounded-[24px] text-white font-sans border border-white/5 shadow-2xl overflow-hidden">

  <header class="px-3 pt-2 pb-1 shrink-0">
    <p class="text-[28px] font-semibold tracking-tight">Settings</p>
  </header>

  <div class="flex-1 overflow-y-auto pb-4 pb-24 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden space-y-4 px-3">

    <section>
      <h2 class="text-[10px] font-semibold uppercase tracking-wider text-gray-500 mb-1.5 px-1">Usage</h2>

      <div class="rounded-2xl bg-white/[0.03] border border-white/[0.06] p-3 space-y-3">

        <div class="flex items-center justify-between gap-2">
          <div class="text-sm font-medium">Tokens burned</div>
          <select
                  bind:value={period}
                  class="bg-white/[0.05] border border-white/[0.08] rounded-lg pl-2 pr-6 py-1 text-xs text-gray-300 outline-none cursor-pointer hover:bg-white/[0.08] focus:border-[#2481cc]/60 transition-colors appearance-none bg-[url('data:image/svg+xml;utf8,<svg xmlns=%22http://www.w3.org/2000/svg%22 width=%2210%22 height=%2210%22 viewBox=%220 0 24 24%22 fill=%22none%22 stroke=%22%239ca3af%22 stroke-width=%222%22 stroke-linecap=%22round%22 stroke-linejoin=%22round%22><polyline points=%226 9 12 15 18 9%22/></svg>')] bg-no-repeat bg-[right_0.4rem_center]"
          >
            {#each PERIODS as p}
              <option value={p.value} class="bg-[#1a1a1a] text-gray-200">{p.label}</option>
            {/each}
          </select>
        </div>

        <!-- Пустой стейт — только когда загрузились и данных нет.
             Пока грузимся — оставляем ring на месте, чтобы не было прыжка. -->
        <!-- Пустой стейт убран. Ring рисуется всегда.
             Если данных нет — серый круг + 0 в центре. -->
        <div class="flex items-center gap-4 transition-opacity duration-300"
             class:opacity-50={isLoading}>
          <div class="relative w-28 h-28 shrink-0">
            <svg viewBox="0 0 100 100" class="w-full h-full -rotate-90">
              <circle cx="50" cy="50" r="40" fill="none"
                      stroke="rgba(255,255,255,0.05)" stroke-width="12" />

              {#each segments as seg (seg.id)}
                <circle
                        cx="50" cy="50" r="40"
                        fill="none"
                        stroke={seg.color}
                        stroke-width="12"
                        stroke-dasharray="{seg.len} {CIRC - seg.len}"
                        stroke-dashoffset={seg.offset}
                        class="transition-all duration-700 ease-out"
                        in:fade={{ duration: 300 }}
                />
              {/each}
            </svg>

            <div class="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
      <span class="text-base font-semibold tabular-nums leading-none transition-all duration-500">
        {fmt(total)}
      </span>
              <span class="text-[9px] uppercase tracking-wider text-gray-500 mt-0.5">tokens</span>
            </div>
          </div>

          <div class="flex-1 min-w-0 space-y-1.5">
            {#each segments as seg (seg.id)}
              <div class="flex items-center gap-2 text-xs" in:fade={{ duration: 300 }}>
                <span class="w-2 h-2 rounded-full shrink-0" style="background:{seg.color}"></span>
                <span class="flex-1 text-gray-300 truncate">{seg.name}</span>
                <span class="text-gray-500 tabular-nums shrink-0">{fmt(seg.tokens)}</span>
              </div>
            {/each}
          </div>
        </div>

        <div class="flex items-center justify-between pt-3 border-t border-white/[0.06]">
          <div class="flex items-center gap-2">
            <Coins size={14} class="text-amber-400" />
            <span class="text-xs text-gray-400">Balance</span>
          </div>
          <div class="flex items-baseline gap-1">
            <span class="text-sm font-semibold tabular-nums">{credits.toLocaleString('en')}</span>
            <span class="text-[11px] text-gray-500">credits</span>
          </div>
        </div>
      </div>
    </section>

    <!-- ACCOUNT -->
    <section>
      <h2 class="text-[10px] font-semibold uppercase tracking-wider text-gray-500 mb-1.5 px-1">Account</h2>
      <div class="rounded-2xl bg-white/[0.03] border border-white/[0.06] overflow-hidden">

        <button on:click={onEditProfile} class="w-full flex items-center gap-3 px-3 py-2.5 text-left hover:bg-white/[0.04] active:bg-white/[0.07] transition-colors">
          {#if currentUser.photo_url}
            <img src={currentUser.photo_url} alt="{currentUser.first_name} {currentUser.last_name}"
                 class="w-9 h-9 rounded-full object-cover shrink-0" />
          {:else}
            <div class="w-9 h-9 rounded-full bg-gradient-to-br from-[#2481cc] to-[#1a5a8f] flex items-center justify-center text-white font-semibold text-xs shrink-0">
              {currentUser.first_name?.charAt(0) ?? ''}{currentUser.last_name?.charAt(0) ?? ''}
            </div>
          {/if}
          <div class="flex-1 min-w-0">
            <div class="text-sm font-medium truncate">{currentUser.username}</div>
            <div class="text-[11px] text-gray-500 truncate">{currentUser.role}</div>
          </div>
          <ChevronRight size={16} class="text-gray-500 shrink-0" />
        </button>

        <div class="h-px bg-white/[0.06] mx-3"></div>

        <button on:click={() => isPayModeOpen = true}
                class="w-full flex items-center justify-between px-3 py-2.5 hover:bg-white/[0.04] active:bg-white/[0.07] transition-colors">
          <span class="text-sm">Manage Subscription</span>
          <span class="px-2.5 py-0.5 rounded-full text-[11px] font-semibold bg-gradient-to-r from-purple-500 to-orange-400 shadow-md shadow-purple-500/20 shrink-0">
            Go PRO
          </span>
        </button>
      </div>
    </section>

    <section>
      <h2 class="text-[10px] font-semibold uppercase tracking-wider text-gray-500 mb-1.5 px-1">Preferences</h2>
      <div class="rounded-2xl bg-white/[0.03] border border-white/[0.06] overflow-hidden">
        <div class="flex items-center justify-between px-3 py-2.5">
          <span class="text-sm">Notifications</span>
          <button role="switch" aria-checked={notificationsEnabled}
                  on:click={() => (notificationsEnabled = !notificationsEnabled)}
                  class="relative inline-block h-6 w-11 shrink-0 rounded-full cursor-pointer transition-colors duration-200 {notificationsEnabled ? 'bg-[#2481cc]' : 'bg-white/10'}">
            <span class="absolute inset-y-0.5 left-0.5 w-5 rounded-full bg-white shadow-lg transition-transform duration-200 ease-out {notificationsEnabled ? 'translate-x-4.5' : 'translate-x-0'}"></span>
          </button>
        </div>

        <div class="h-px bg-white/[0.06] mx-3"></div>

        <div class="flex items-center justify-between px-3 py-2.5">
          <span class="text-sm">Theme</span>
          <button role="switch" aria-checked={isDarkMode}
                  on:click={() => (isDarkMode = !isDarkMode)}
                  class="relative inline-block h-6 w-11 shrink-0 rounded-full cursor-pointer transition-colors duration-200 {isDarkMode ? 'bg-[#2481cc]' : 'bg-white/10'}">
            <span class="absolute inset-y-0.5 left-0.5 flex w-5 items-center justify-center rounded-full bg-white shadow-lg transition-transform duration-200 ease-out {isDarkMode ? 'translate-x-4.5' : 'translate-x-0'}">
              {#if isDarkMode}
                <Moon size={12} class="text-[#2481cc]" strokeWidth={2.5} />
              {:else}
                <Sun size={12} class="text-amber-500" strokeWidth={2.5} />
              {/if}
            </span>
          </button>
        </div>
      </div>
    </section>

    <section>
      <h2 class="text-[10px] font-semibold uppercase tracking-wider text-gray-500 mb-1.5 px-1">Manage</h2>
      <div class="rounded-2xl bg-white/[0.03] border border-white/[0.06] overflow-hidden">
        {#each manageRows as item, i}
          {#if i > 0}<div class="h-px bg-white/[0.06] mx-3"></div>{/if}
          <button on:click={item.onClick} class="w-full flex items-center justify-between px-3 py-2.5 hover:bg-white/[0.04] active:bg-white/[0.07] transition-colors">
            <div class="flex items-center gap-2.5">
              <svelte:component this={item.icon} size={16} class="text-gray-400" />
              <span class="text-sm">{item.label}</span>
            </div>
            <ChevronRight size={16} class="text-gray-500 shrink-0" />
          </button>
        {/each}
      </div>
    </section>

    <section>
      <h2 class="text-[10px] font-semibold uppercase tracking-wider text-gray-500 mb-1.5 px-1">Support</h2>
      <div class="rounded-2xl bg-white/[0.03] border border-white/[0.06] overflow-hidden">
        {#each supportRows as item, i}
          {#if i > 0}<div class="h-px bg-white/[0.06] mx-3"></div>{/if}
          <button on:click={item.onClick} class="w-full flex items-center justify-between px-3 py-2.5 hover:bg-white/[0.04] active:bg-white/[0.07] transition-colors">
            <div class="flex items-center gap-2.5">
              <svelte:component this={item.icon} size={16} class="text-gray-400" />
              <span class="text-sm">{item.label}</span>
            </div>
            <ChevronRight size={16} class="text-gray-500 shrink-0" />
          </button>
        {/each}
      </div>
    </section>

  </div>
</div>

<PayMode bind:isOpen={isPayModeOpen} on:pay={handlePayRequest} />
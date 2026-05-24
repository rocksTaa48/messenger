<script lang="ts">
  import { onMount } from 'svelte';
  import { initSession, socketStatus, currentUser } from './stores/socketStore';
  import { initTMA, tmaTheme } from './lib/tma/init';
  import WebApp from "@twa-dev/sdk";

  let activeTab = 'Chats'; // Базовая активная вкладка

  onMount(() => {
    initTMA();
    const tgWebApp = (window as any).Telegram?.WebApp;
    const initData = tgWebApp?.initData || "test_init_data_for_dev";
    tgWebApp?.ready();

    initSession(initData);
  });

  // Переключалка табов
  function handleTabChange(e) {
    activeTab = e.detail;
  }


  // COMPONENTS----->
  import Footer from './lib/components/Footer.svelte';
  import Chats from './lib/components/ChatsWindow.svelte';
  import Messenger from './lib/components/MessengerWindow.svelte';
  import Agents from './lib/components/AgentsWindow.svelte';
  import Settings from './lib/components/SettingsWindow.svelte';

  // Включаем странички на которых будем ронять футер
  const scalingTabs = ['Messenger', 'Agents', 'ProfileEdit', 'CryptoPayment'];

</script>

<!-- Основной контейнер с системным фоном -->
<main class="fixed inset-0 flex flex-col bg-tg-bg text-tg-text overflow-hidden">
  {#if $socketStatus === 'connecting'}
    <!-- Эта плашка покажется при входе или переподключении -->
    <div class="flex flex-col items-center gap-3">
      <div class="animate-spin rounded-full h-10 w-10 border-b-2 border-indigo-500"></div>
      <p class="text-slate-400 animate-pulse">Соединение с экосистемой... Проверяем сеть...</p>
    </div>
  <!-- Если что то не так, упадет с ошибкой, подклюение не произошло -->
  {:else if $socketStatus === 'error'}
    <div class="text-red-400 bg-red-950/50 border border-red-900 p-4 rounded-xl text-center">
      <h2 class="font-bold text-lg mb-1">Ошибка авторизации</h2>
      <p class="text-sm opacity-90">Отклонен сервером.</p>
    </div>
  <!-- Если же все удачно, открываем сессию -->
  {:else}
    <div class="flex-1 flex flex-col min-h-0 px-2 pt-1 {scalingTabs.includes(activeTab) ? 'pb-2' : 'pb-24'}">
      <span class="w-2 h-2 bg-emerald-400 rounded-full animate-ping"></span>

      {#if activeTab === 'Chats'}
        <Chats on:selectChat={() => activeTab = 'Messenger'} />
      {/if}

      {#if activeTab === 'Messenger'}
        <Messenger on:back={() => activeTab = 'Chats'} />
      {/if}

      {#if activeTab === 'Agents'}
        <Agents on:back={() => activeTab = 'Chats'} />
      {/if}

      {#if activeTab === 'Settings'}
        <Settings on:back={() => activeTab = 'Settings'} />
      {/if}

    </div>
    <Footer {activeTab} on:change={(e) => activeTab = e.detail}/>
  {/if}
</main>
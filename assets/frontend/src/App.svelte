<script lang="ts">
  import { onMount } from 'svelte';
  // Импортируем наш единый подправленный монолит-стор
  import { appState } from './stores/socketStore';
  import { initTMA } from './lib/tma/init';

  // COMPONENTS----->
  import Footer from './lib/components/Footer.svelte';
  import Chats from './lib/components/ChatsWindow.svelte';
  import Messenger from './lib/components/MessengerWindow.svelte';
  import Agents from './lib/components/AgentsWindow.svelte';
  import Settings from './lib/components/SettingsWindow.svelte';

  onMount(() => {
    initTMA();
    const tgWebApp = (window as any).Telegram?.WebApp;
    const initData = tgWebApp?.initData || "test_init_data_for_dev";
    tgWebApp?.ready();

    // Запускаем сессию через наш новый стор
    appState.initSession(initData);
  });

  // Логика скрытия футера: читаем состояние экрана прямо из локального nav_context
  $: currentScreen = $appState.nav_context?.screen || 'chats';

  // Перехват кликов из Футера: теперь навигацией рулит клиент через goTo!
  function handleTabChange(e: CustomEvent<string>) {
    const targetTab = e.detail; // 'Chats', 'Agents', 'Settings'
    // Здесь надо подумать! переход к созданию чата CreateChat! как это выполнить, модалкой или полноценным окном?
    if (targetTab === 'Chats') appState.goTo({ screen: 'chats' });
    if (targetTab === 'CreateChat') appState.goTo({ screen: 'inside_chat', params: { chat_id: 'new_chat' } });
    if (targetTab === 'Settings') appState.goTo({ screen: 'settings' });
  }
</script>

<!-- Основной контейнер с системным фоном -->
<main class="fixed inset-0 flex flex-col bg-tg-bg text-tg-text overflow-hidden justify-center items-center">

  <!-- Сценарий 1: Подключение или реконнект -->
  {#if !$appState || $appState.status === 'connecting'}
    <div class="flex flex-col items-center gap-3">
      <div class="animate-spin rounded-full h-10 w-10 border-b-2 border-indigo-500"></div>
      <p class="text-slate-400 animate-pulse">Connecting... Проверяем сеть...</p>
    </div>

    <!-- Сценарий 2: Ошибка -->
  {:else if $appState.status === 'error'}
    <div class="text-red-400 bg-red-950/50 border border-red-900 p-4 rounded-xl text-center">
      <h2 class="font-bold text-lg mb-1">Ошибка авторизации</h2>
      <p class="text-sm opacity-90">Отклонен сервером.</p>
    </div>

    <!-- Сценарий 3: Полный коннект -->
  {:else}
    <!-- Скрываем отступы футера, если мы внутри чата (inside_chat) или настроек, если это нужно (было 'pb-2' : 'pb-24') -->
    <div class="w-full flex-1 flex flex-col min-h-0 px-2 pt-1 {currentScreen === 'inside_chat' ? 'pb-2' : 'pb-2'}">

      <!-- Индикатор живого real-time сокета -->
      <span class="w-2 h-2 bg-emerald-400 rounded-full animate-ping absolute top-2 right-2"></span>

      <!-- Список чатов -->
      {#if currentScreen === 'chats'}
        <Chats />
      {/if}

      <!-- Внутри конкретного диалога -->
      {#if currentScreen === 'inside_chat'}
        <!-- По кнопке Назад вызываем метод appState.goBack() -->
        <Messenger on:back={() => appState.goBack()} />
      {/if}

      <!-- Настройки -->
      {#if currentScreen === 'settings'}
        <Settings on:back={() => appState.goBack()} />
      {/if}

    </div>

    <!-- Футер. Передаем активную вкладку на основе локального стейта клиента -->
    {#if currentScreen !== 'inside_chat'}
      <Footer
              activeTab={currentScreen === 'settings' ? 'Settings' : 'Chats'}
              on:change={handleTabChange}
      />
    {/if}
  {/if}
</main>

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

  // Логика скрытия футера: проверяем экраны, которые прилетают с бэкенда
  // Мапим названия экранов из Elixir на логику отступов
  const scalingScreens = ['Messenger', 'Agents', 'ProfileEdit', 'CryptoPayment'];

  // Перехват кликов из Футера: тупо редиректим намерения на Elixir сервер
  function handleTabChange(e: CustomEvent<string>) {
    const targetTab = e.detail; // 'Chats', 'Agents', 'Settings'

    // Переводим название вкладки в экшен для бэкенда
    if (targetTab === 'Chats') appState.send("nav_chats");
    if (targetTab === 'Agents') appState.send("nav_agents");
    if (targetTab === 'Settings') appState.send("nav_settings");
  }
</script>

<!-- Основной контейнер с системным фоном -->
<main class="fixed inset-0 flex flex-col bg-tg-bg text-tg-text overflow-hidden justify-center items-center">

  <!-- Сценарий 1: Подключение или реконнект (смотрим поле status в едином сторе) -->
  {#if !$appState || $appState.status === 'connecting'}
    <div class="flex flex-col items-center gap-3">
      <div class="animate-spin rounded-full h-10 w-10 border-b-2 border-indigo-500"></div>
      <p class="text-slate-400 animate-pulse">Соединение с экосистемой... Проверяем сеть...</p>
    </div>

    <!-- Сценарий 2: Ошибка (сервер сделал reject в connect/3) -->
  {:else if $appState.status === 'error'}
    <div class="text-red-400 bg-red-950/50 border border-red-900 p-4 rounded-xl text-center">
      <h2 class="font-bold text-lg mb-1">Ошибка авторизации</h2>
      <p class="text-sm opacity-90">Отклонен сервером.</p>
    </div>

    <!-- Сценарий 3: Полный коннект, отрисовываем то, что сказал сервер -->
  {:else}

    <div class="w-full flex-1 flex flex-col min-h-0 px-2 pt-1 {scalingScreens.includes($appState.current_screen) ? 'pb-2' : 'pb-24'}">

      <!-- Индикатор живого real-time сокета потом доделаю =) -->
      <span class="w-2 h-2 bg-emerald-400 rounded-full animate-ping absolute top-2 right-2"></span>

      <!-- Список чатов -->
      {#if $appState.current_screen === 'chats'}
        <!-- Компонент чатов забирает данные прямо из стора, при клике на чат мы шлем событие на сервер -->
        <Chats on:selectChat={(e) => appState.send("click_open_chat", { chat_id: e.detail })} />
      {/if}

      <!-- Внутри конкретного диалога (Messenger) -->
      {#if $appState.current_screen === 'Messenger'}
        <!-- По кнопке " < " Назад - шлем команду бэкенду вернуться к списку чатов -->
        <Messenger on:back={() => appState.send("nav_chats")} />
      {/if}

      <!-- Агенты -->
      {#if $appState.current_screen === 'Agents'}
        <Agents on:back={() => appState.send("nav_chats")} />
      {/if}

      <!-- Настройки -->
      {#if $appState.current_screen === 'settings'}
        <Settings on:back={() => appState.send("nav_chats")} />
      {/if}

    </div>

    <!-- Наш Футер. Передаем ему текущий экран (чтобы подсветить нужную иконку) и слушаем клики -->
    <!-- Так как в футере у тебя вкладки называются с большой буквы, подгоняем под твой Footer.svelte интерфейс -->
    <Footer
            activeTab={$appState.current_screen === 'settings' ? 'Settings' : $appState.current_screen === 'chats' ? 'Chats' : $appState.current_screen}
            on:change={handleTabChange}
    />
  {/if}
</main>
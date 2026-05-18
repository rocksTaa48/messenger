<script lang="ts">
  import { onMount } from 'svelte';
  import { initTMA, tmaTheme } from './lib/tma/init';
  import WebApp from "@twa-dev/sdk";

  onMount(() => {
    initTMA();
  });

  // Переключалка табов
  function handleTabChange(e) {
    activeTab = e.detail;
  }

  // DEVELOPMENT Пример данных от пользователя из Telegram (если доступны) имя или еще что то
  const user = WebApp.initDataUnsafe?.user;

  let activeTab = 'Chats'; // Базовая активная вкладка

  // COMPONENTS----->
  import Footer from './lib/components/Footer.svelte';
  import Chats from './lib/components/ChatsWindow.svelte';
  import Messenger from './lib/components/MessengerWindow.svelte';
  import Agents from './lib/components/AgentsWindow.svelte';

  const scalingTabs = ['Messenger', 'Agents', 'ProfileEdit', 'CryptoPayment'];

</script>

<!-- Основной контейнер с системным фоном -->
<main class="fixed inset-0 flex flex-col bg-tg-bg text-tg-text overflow-hidden">
  <div class="flex-1 flex flex-col min-h-0 px-2 pt-1 {scalingTabs.includes(activeTab) ? 'pb-2' : 'pb-24'}">

    {#if activeTab === 'Chats'}
      <Chats on:selectChat={() => activeTab = 'Messenger'} />
    {/if}

    {#if activeTab === 'Messenger'}
      <Messenger on:back={() => activeTab = 'Chats'} />
    {/if}

    {#if activeTab === 'Agents'}
      <Agents on:back={() => activeTab = 'Chats'} />
    {/if}

  </div>
  <Footer {activeTab} on:change={(e) => activeTab = e.detail}/>
</main>
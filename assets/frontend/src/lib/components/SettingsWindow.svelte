<script lang="ts">
  import { appState } from '../../stores/socketStore';
</script>

<div class="min-h-screen bg-slate-900 text-white flex flex-col items-center justify-center p-4">

    {#if $appState.status === 'connecting'}
      <div class="flex flex-col items-center gap-3">
        <div class="animate-spin rounded-full h-10 w-10 border-b-2 border-indigo-500"></div>
        <p class="text-slate-400 animate-pulse">Авторизация в экосистеме...</p>
      </div>

    {:else}
      <div class="text-red-400 bg-red-950/50 border border-red-900 p-4 rounded-xl max-w-sm text-center">
        <h2 class="font-bold text-lg mb-1">Ошибка входа</h2>
        <p class="text-sm opacity-90">Watafa</p>
      </div>

    {:else}
      <div class="w-full max-w-md bg-slate-800 rounded-2xl p-6 shadow-xl border border-slate-700">
        <div class="flex items-center gap-4 mb-6">
          <div class="w-12 h-12 bg-indigo-600 rounded-full flex items-center justify-center font-bold text-xl uppercase">
            {$appState.user?.username?.substring(0, 2) || 'AI'}
          </div>
          <div>
            <h1 class="text-xl font-bold">Привет, @{$appState.user?.username || 'Пользователь'}!</h1>
            <p class="text-xs text-emerald-400 flex items-center gap-1">
              <span class="w-2 h-2 bg-emerald-400 rounded-full animate-ping"></span>
              Сессия активна (Роль: {$appState.user?.role})
            </p>
          </div>
        </div>

        <!-- Место для будущего списка чатов с AI агентами -->
        <div class="border-2 border-dashed border-slate-700 rounded-xl p-8 text-center text-slate-500">
          Здесь будет окно чатов с AI агентами
        </div>
      </div>
    {/if}

  </div>

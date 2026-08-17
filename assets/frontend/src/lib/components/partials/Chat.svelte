<script lang="ts">
    import { longPress } from '../../actions/longPress';
    import { createEventDispatcher } from 'svelte';
    // Импортируем наш стор
    import { appState } from '../../../stores/socketStore';
    import Icons from './Icons.svelte'
    import {Pin} from 'lucide-svelte'

    // Принимаем объект чата сверху от родителя
    export let chat: any;

    $: aiProfile = $appState.ai_profiles.find(p => String(p.id) === String(chat.ai_profile_id))

    const dispatch = createEventDispatcher();

    function handleLongPress(event: CustomEvent) {
        dispatch('chatLongPress', { chat, originalEvent: event.detail.originalEvent });
    }
</script>

<!-- ПРИ КЛИКЕ МЫ УПРАВЛЯЕМ НАВИГАЦИЕЙ НА КЛИЕНТЕ -->
<div
        use:longPress={{ duration: 500, callback: handleLongPress }}
        on:click={() => appState.goTo({
    screen: 'inside_chat',
    params: {
      chat_id: chat.id.toString(),
      group_id: $appState.nav_context.params?.group_id || 'All'
    }
  })}
        class="chat flex items-center gap-4 p-3.5 bg-white/[0.03] border border-white/5
         rounded-[24px] hover:bg-white/[0.06] cursor-pointer transition-all active:scale-[0.99] relative"
>

    <!-- Иконка чата (Аватарка) -->
    <div class="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 {aiProfile?.color || 'bg-slate-600'}">
        {#if aiProfile}
            <Icons {...{ [aiProfile.provider]: true }} size={20} />
        {:else}
            <!-- Если данные еще не пришли из сокета, покажется красивый лоадер -->
            <div class="w-6 h-6 rounded-full bg-slate-500 animate-pulse"></div>
        {/if}
    </div>

    <!-- Текстовый блок (Название и последнее сообщение) -->
    <div class="flex-1 min-w-0">
        <div class="flex justify-between items-baseline mb-1">
            <p class="text-sm font-extralight text-white truncate pr-2">
                {chat.title}
            </p>
            <span class="text-[10px] text-gray-500 font-medium whitespace-nowrap">
        {chat.id}
      </span>
        </div>
        <p class="text-xs text-gray-400 truncate pr-4">
            {chat.body}
        </p>
    </div>

    <!-- Правый блок: Статус закреплен или нет -->
    {#if chat.is_pinned}
        <div class="absolute top-0 right-2 text-[#2481cc] text-sm">
            📌
        </div>
    {/if}

    <!-- Правый блок: Статус и счетчик непрочитанных -->
    <div class="absolute bottom-2 right-2 min-w-[20px]">
        {#if chat.status === 'unread' && chat.unread_count > 0}
      <span class="bg-[#2481cc] text-white text-[10px] font-bold rounded-full h-4.5 min-w-[18px] flex items-center
      justify-center px-1 animate-pulse"
      >
        {chat.unread_count}
      </span>
        {:else}
            <!-- Иконка двойной галочки, если прочитано -->
            <span class="text-[#2481cc] opacity-80">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7M5 13l4 4L19 7" />
        </svg>
      </span>
        {/if}
    </div>
</div>
<style>
    .chat {
        user-select: none;
        -webkit-user-select: none;
        touch-action: pan-y;
        -webkit-touch-callout: none;
    }
</style>

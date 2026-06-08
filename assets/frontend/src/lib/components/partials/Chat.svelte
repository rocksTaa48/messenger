<script lang="ts">
    import { Bot, ImageIcon, MessageSquare, Sparkles } from 'lucide-svelte';
    import { createEventDispatcher } from 'svelte';
    import { appState } from '../../../stores/socketStore';

    // 1. Принимаем объект чата сверху от родителя
    export let chat: any;

    const dispatch = createEventDispatcher();

    // 2. Мапим строку с бэкенда на живые иконки Lucide
    const iconMap: Record<string, any> = {
        'bot': Bot,
        'image': ImageIcon,
        'sparkles': Sparkles,
        'default': MessageSquare
    };

    // Выбираем иконку (если сервер прислал то, чего нет — берем дефолтную)
    $: currentIcon = iconMap[chat.icon_type] || iconMap['default'];
</script>

<!-- При клике шлем экшен прямо на сервер Elixir -->
<div
        on:click={() => appState.send("chat:click_open", { chat_id: chat.id })}
        class="flex items-center gap-4 p-3.5 bg-white/[0.03] border border-white/5
         rounded-[24px] hover:bg-white/[0.06] cursor-pointer transition-all active:scale-[0.99]"
>

    <!-- Иконка чата (Аватарка) -->
    <!-- Классы цвета (например, "text-purple-400 bg-purple-500/10") сервер тоже может спокойно отдавать строкой -->
    <div class="w-12 h-12 rounded-2xl flex items-center justify-center flex-shrink-0 {chat.icon_color || 'text-[#2481cc] bg-[#2481cc]/10'}">
        <svelte:component this={currentIcon} size={24} />
    </div>

    <!-- Текстовый блок (Название и последнее сообщение) -->
    <div class="flex-1 min-w-0">
        <div class="flex justify-between items-baseline mb-1">
            <h3 class="text-sm font-bold text-white truncate pr-2">
                {chat.theme}
            </h3>
            <span class="text-[10px] text-gray-500 font-medium whitespace-nowrap">
        {chat.id}
      </span>
        </div>
        <p class="text-xs text-gray-400 truncate pr-4">
            {chat.body}
        </p>
    </div>

    <!-- Правый блок: Статус и счетчик непрочитанных -->
    <div class="flex flex-col items-end justify-center flex-shrink-0 min-w-[20px]">
        {#if chat.status === 'unread' && chat.unread_count > 0}
      <span class="bg-[#2481cc] text-white text-[10px] font-bold rounded-full h-4.5 min-w-[18px] flex items-center justify-center px-1 animate-pulse">
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

// frontend/src/lib/stores/chatStore.ts
import { writable, get } from 'svelte/store';
import { activeChannel, socketStatus } from './socketStore';

interface Chat {
    id: number;
    title: string;
    model_name: string;
    inserted_at: string;
}

interface ChatState {
    items: Chat[];
    isLoading: boolean;
    hasMore: boolean;
    cursor: string | null;
}

// Состояние списка чатов
export const chats = writable<ChatState>({
    items: [],
    isLoading: false,
    hasMore: true,
    cursor: null
});

// Функция подгрузки следующих 15 чатов
export function loadMoreChats() {
    const channel = get(activeChannel);
    const state = get(chats);

    if (!channel || state.isLoading || !state.hasMore) return;

    chats.update(state => ({ ...state, isLoading: true }));

    channel.push('load_more_chats', { before_cursor: state.cursor })
        .receive('ok', (payload: { chats: Chat[] }) => {
            chats.update(state => {
                const newItems = [...state.items, ...payload.chats];
                const hasMore = payload.chats.length === 15;
                const cursor = payload.chats[payload.chats.length - 1]?.inserted_at || null;

                return {
                    items: newItems,
                    isLoading: false,
                    hasMore,
                    cursor
                };
            });
        })
        .receive('error', (err) => {
            console.error('Ошибка подгрузки чатов:', err);
            chats.update(state => ({ ...state, isLoading: false }));
        });
}

// Сброс состояния (при выходе из лобби)
export function resetChats() {
    chats.set({
        items: [],
        isLoading: false,
        hasMore: true,
        cursor: null
    });
}

// Обработчики real-time обновлений (когда создается/удаляется чат)
export function handleNewChat(chat: Chat) {
    chats.update(state => ({
        ...state,
        items: [chat, ...state.items], // Новый чат в начало
        hasMore: state.hasMore, // Флаг не меняем
        cursor: state.cursor // Курсор не меняем
    }));
}

export function handleDeleteChat(chatId: number) {
    chats.update(state => ({
        ...state,
        items: state.items.filter(chat => chat.id !== chatId)
    }));
}
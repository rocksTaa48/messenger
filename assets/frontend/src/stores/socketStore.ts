import { writable } from 'svelte/store';
import { Socket, Channel } from 'phoenix';

// 1) Узел навигации: четко описывает, где мы и с каким контекстом
export interface NavigationNode {
    screen: 'chats' | 'settings' | 'inside_chat';
    params?: {
        chat_id?: string;
        group_id?: string;
        [key: string]: any;
    };
}

// 2) Структура стейта приложения
export interface AppState {
    status: 'connecting' | 'connected' | 'error';

    // Навигация живет на клиенте
    nav_context: NavigationNode;                          // Где юзер прямо сейчас
    nav_history: NavigationNode[];                        // Стек пройденных экранов

    // Данные от бэкенда
    user: { id: number; username: string; balance: number } | null;
    chats_list: Array<{ id: string; title: string; unread: number; ai_profile_id: string, is_pinned: boolean; }>;
    ai_profiles: Array<{id: string; name: string; provider: string, model: string}>;
    groups: Array<{ id: string; title: string }>;
    active_chat: { id: string; messages: Array<{ id: number; text: string; group_id: number; sender: string }> } | null;
    settings: { theme: string; lang: string };
}

// 3) Начальное состояние
const initialValue: AppState = {
    status: 'connecting',
    nav_context: { screen: 'chats' }, // Стартуем всегда с лобби чатов
    nav_history: [],
    user: null,
    chats_list: [],
    groups: [],
    active_chat: null,
    settings: { theme: 'dark', lang: 'ru' }
};

const { subscribe, update } = writable<AppState>(initialValue);

let socket: Socket | null = null;
let channel: Channel | null = null;

export const appState = {
    subscribe,

    initSession(initData: string) {
        if (socket) return;

        socket = new Socket('/socket', {
            params: { initData },
            reconnectAfterMs: (tries) => [1000, 2000, 5000, 10000, 30000][tries - 1] || 30000,
            timeout: 10000
        });

        socket.onClose((e) => {
            console.log('Сокет закрылся:', e);
            update(state => ({ ...state, status: 'connecting' }));
        });

        socket.onError(() => {
            update(state => ({ ...state, status: 'error' }));
        });

        socket.connect();
        channel = socket.channel('session:lobby', {});

        // Когда Elixir присылает sync, мы обновляем ТОЛЬКО данные. Навигацию он не трогает.
        channel.on('sync', (serverState: Partial<Omit<AppState, 'nav_context' | 'nav_history' | 'status'>>) => {
            update(state => ({
                ...state,
                ...serverState,
                status: 'connected'
            }));
        });

        channel.join()
            .receive('ok', (initialServerState: Partial<Omit<AppState, 'nav_context' | 'nav_history' | 'status'>>) => {
                console.log('Авторизация в Elixir успешна!');
                update(state => ({
                    ...state,
                    ...initialServerState,
                    status: 'connected'
                }));
            })
            .receive('error', () => {
                update(state => ({ ...state, status: 'error' }));
            });
    },

    send(event: string, payload: object = {}) {
        if (channel) {
            channel.push(event, payload);
        } else {
            console.warn(`Не могу отправить ${event}, канал еще не готов.`);
        }
    },

    /**
     * Переход на новый экран (Движение ВПЕРЕД).
     * Вызываем: appState.goTo({ screen: 'inside_chat', params: { chat_id: '4', group_id: '1' } })
     */
    goTo(target: NavigationNode) {
        let isDuplicate = false;

        update(state => {
            // Сравниваем и экраны, чаты и группы
            const isSameScreen = state.nav_context.screen === target.screen;
            const isSameChat = state.nav_context.params?.chat_id === target.params?.chat_id;
            const isSameGroup = state.nav_context.params?.group_id === target.params?.group_id;

            if (isSameScreen && isSameChat && isSameGroup) {
                isDuplicate = true; // Помечаем, что это дубликат
                return state;       // Ничего не меняем в памяти
            }

            // Записываем шаг в историю если юзер меняет экран (уходит из списков в чат или настройки)
            let updatedHistory = [...state.nav_history];
            if (state.nav_context.screen !== target.screen) {
                updatedHistory.push(state.nav_context);
            }
            if (updatedHistory.length > 10) updatedHistory.shift();

            return {
                ...state,
                nav_context: target,
                nav_history: updatedHistory
            };
        });

        // Если это дубликат или пустой клик по той же вкладке — гасим функцию.
        if (isDuplicate) return;

        // Шлем запрос на бэк
        this._requestDataForScreen(target);
    },

    /**
     * Возврат назад (Движение НАЗАД).
     * Берет верхний экран из стека истории и переключается на него.
     */
    goBack() {
        let destination: NavigationNode = { screen: 'chats' };

        update(state => {
            if (state.nav_history.length === 0) return state; // Идти некуда

            const updatedHistory = [...state.nav_history];
            destination = updatedHistory.pop()!; // Достаем предыдущий экран

            return {
                ...state,
                nav_context: destination,
                nav_history: updatedHistory
            };
        });

        // Дёргаем бэк для получения данных старого экрана
        this._requestDataForScreen(destination);
    },

    /**
     * Внутренний хелпер: запросы на бэк и вызов соответствующих функций
     */
    _requestDataForScreen(node: NavigationNode) {
        switch (node.screen) {
            case 'chats':
                this.send('base:click_nav_chats', { group_id: node.params?.group_id }); // <-- Отправляемся в лобби чатов
                break;
            case 'inside_chat':
                this.send('chat:click_open', { chat_id: node.params?.chat_id }); // <-- Открываем чат
                break;
            case 'settings':
                this.send('user:get_settings');
                break;
        }
    }

};
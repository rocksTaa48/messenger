import { writable } from 'svelte/store';
import { Socket, Channel } from 'phoenix';

// 1. Описываем строгую структуру нашего ЕДИНОГО стейта приложения
export interface AppState {
    // Системный статус (чтобы показывать плашки загрузки/ошибки сети)
    status: 'connecting' | 'connected' | 'error';

    // Все данные, которые рулит Elixir (приходят из сокета)
    current_screen: 'chats' | 'settings' | 'inside_chat';
    user: { id: number; username: string; balance: number } | null;
    chats_list: Array<{ id: string; title: string; unread: number }>;
    groups: Array<{ id: string; title: string }>;
    active_chat: { id: string; messages: Array<{ id: number; text: string; sender: string }> } | null;
    settings: { theme: string; lang: string };
}

// 2. Начальное состояние (приложение только запускается)
const initialValue: AppState = {
    status: 'connecting',
    current_screen: 'chats',
    user: null,
    chats_list: [],
    groups: [],
    active_chat: null,
    settings: { theme: 'dark', lang: 'ru' }
};

// Создаем один базовый стор
const { subscribe, update, set } = writable<AppState>(initialValue);

let socket: Socket | null = null;
let channel: Channel | null = null;

// 3. Экспортируем наружу чистый объект управления
export const appState = {
    subscribe,

    initSession(initData: string) {
        if (socket) return; // Твоя защита от повторной инициализации

        // Создаем сокет с твоими таймингами реконнекта
        socket = new Socket('/socket', {
            params: { initData },
            reconnectAfterMs: (tries) => [1000, 2000, 5000, 10000, 30000][tries - 1] || 30000,
            timeout: 10000
        });

        // Хуки сокета: управляют только полем status внутри общего стейта!
        socket.onOpen(() => {
            console.log('Труба сокета открыта или восстановилась!');
        });

        socket.onClose((e) => {
            console.log('Сокет закрылся (сеть упала):', e);
            // Не ломаем данные, просто переводим статус в режим ожидания
            update(state => ({ ...state, status: 'connecting' }));
        });

        socket.onError(() => {
            update(state => ({ ...state, status: 'error' }));
        });

        socket.connect();

        // Подключаемся к ОДНОМУ персональному каналу-мозгу
        channel = socket.channel('session:lobby', {});

        // Вешаем главный обработчик синхронизации.
        // Когда Elixir говорит "sync", мы берем ВСЕ новые данные экрана и мержим их со статусом сокета
        channel.on('sync', (serverState: Partial<AppState>) => {
            update(state => ({
                ...state,
                ...serverState,
                status: 'connected' // Раз прилетел sync, значит мы точно подключены и авторизованы
            }));
        });

        // Запускаем твою функцию входа
        channel.join()
            .receive('ok', (initialServerState: Partial<AppState>) => {
                console.log('Авторизация в Elixir успешна!');
                update(state => ({
                    ...state,
                    ...initialServerState,
                    status: 'connected'
                }));
            })
            .receive('error', () => {
                update(state => ({ ...state, status: 'error' }));
            })
            .receive('timeout', () => {
                console.log('Таймаут входа в канал, ожидаем авто-реконнект...');
            });
    },

    /**
     * Единственный метод для отправки любого действия на бэкенд.
     * Вызывается в Svelte как: appState.send("click_open_chat", { chat_id: "12" })
     */
    send(event: string, payload: object = {}) {
        if (channel) {
            channel.push(event, payload);
        } else {
            console.warn(`Не могу отправить ${event}, канал еще не готов.`);
        }
    }
};

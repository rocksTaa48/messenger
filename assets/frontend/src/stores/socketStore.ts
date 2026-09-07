import { writable, get } from 'svelte/store';
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

// 2) Базовая структура стейта приложения
export interface AppState {
    status: 'connecting' | 'connected' | 'error';

    // Навигация живет на клиенте
    nav_context: NavigationNode;                          // Где юзер прямо сейчас
    nav_history: NavigationNode[];                        // Стек пройденных экранов

    // Данные от бэкенда
    user: { id: number; username: string; role: string; status: string; } | null;
    chats_list: Array<{
        id: string;
        title: string;
        unread: number;
        ai_profile_id: string;
        is_pinned: boolean;
        last_message: string;
    }>;
    ai_profiles: Array<{
        id: string;
        name: string;
        provider: string;
        model: string;
        openrouter_model_id: string;
        display_name: string;
        display_description: string;
    }>;
    groups: Array<{ id: string; title: string }>;
    active_chat: { id: string; title: string;
        messages: Array<{
            id: number;
            content: string;
            role: string;
            created_at: string;
            is_streaming?: boolean; // Ответ все еще стримится или уже нет.
        }>;
        has_more_messages?: boolean;
    } | null;
    has_more_chats: boolean;
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
    has_more_chats: false,
    has_more_messages: false,
    settings: { theme: 'dark', lang: 'ru' }
};

const store = writable<AppState>(initialValue);
const { subscribe, update } = store;

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

        /**
         * Передаем функцию.
         * Phoenix выполняет эту функцию при каждом автоматическом переподключении.
         * За счет get(store) мы всегда берем актуальный nav_context прямо из памяти фронтенда на момент реконнекта.
         */
        channel = socket.channel('session:lobby', () => {
            const currentAppState = get(store);
            return {
                nav_context: currentAppState.nav_context
            };
        });

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
                console.log('Авторизация и восстановление сессии в Elixir успешны!');

                update(state => {
                    return {
                        ...state,
                        ...initialServerState, // Принимаем стейт, собранный под наш экран
                        status: 'connected'
                    };
                });
            })
            .receive('error', () => {
                update(state => ({ ...state, status: 'error' }));
            });

        // УЧАСТОК: Обработка токенов в чат ------------------------------>
        // 1. Обработка потока токенов
        channel.on('ai:token', (payload: { chat_id: string; token: string }) => {
            update(state => {
                if (!state.active_chat) return state;

                const currentId = state.active_chat.id;
                // Приводим к строке
                if (currentId && String(currentId) !== String(payload.chat_id)) {
                    return state;
                }

                const messages = [...state.active_chat.messages];
                const lastMsg = messages[messages.length - 1];

                if (lastMsg && lastMsg.role === 'assistant' && lastMsg.is_streaming) {
                    lastMsg.content += payload.token;
                } else {
                    messages.push({
                        id: -Date.now(),
                        role: 'assistant',
                        content: payload.token,
                        created_at: new Date().toISOString(),
                        is_streaming: true
                    });
                }

                return {
                    ...state,
                    active_chat: { ...state.active_chat, id: payload.chat_id, messages }
                };
            });
        });

        // 2. Завершение генерации
        channel.on('ai:stream_done', (payload: { chat_id: string; message_id?: number; content?: string }) => {
            update(state => {
                if (!state.active_chat) return state;

                const currentId = state.active_chat.id;
                // Приводим ID к строке
                if (currentId && String(currentId) !== String(payload.chat_id)) {
                    return state;
                }

                const messages = state.active_chat.messages.map(msg => {
                    if (msg.role === 'assistant' && msg.is_streaming) {
                        return {
                            ...msg,
                            id: payload.message_id || msg.id,
                            content: payload.content || msg.content,
                            is_streaming: false
                        };
                    }
                    return msg;
                });

                return {
                    ...state,
                    active_chat: { ...state.active_chat, id: payload.chat_id, messages }
                };
            });
        });

        // 3. Ошибка генерации
        channel.on('ai:stream_error', (payload: { chat_id: string; reason: string }) => {
            console.error('AI stream error:', payload);
            update(state => {
                if (!state.active_chat) return state;

                const currentId = state.active_chat.id;
                if (currentId && String(currentId) !== String(payload.chat_id)) {
                    return state;
                }

                // На всякий случай снимаем флаг стрима, если он вдруг остался
                const messages = state.active_chat.messages.map(msg => {
                    if (msg.role === 'assistant' && msg.is_streaming) {
                        return { ...msg, is_streaming: false };
                    }
                    return msg;
                });

                return { ...state, active_chat: { ...state.active_chat, messages } };
            });
        });

        // Обработка успешного обновления названия чата от модели (она генерит название)
        channel.on('chat_title_update', (payload: { chat_id: string; title: string }) => {
            update(state => {
                const targetId = String(payload.chat_id);

                // Обновляем в общем списке (с защитой от undefined/null)
                const updatedChatsList = state.chats_list.map(chat =>
                    (chat.id && String(chat.id) === targetId)
                        ? { ...chat, title: payload.title }
                        : chat
                );

                // Обновляем и active_chat, если это он!
                let updatedActiveChat = state.active_chat;
                if (state.active_chat && String(state.active_chat.id) === targetId) {
                    updatedActiveChat = {
                        ...state.active_chat,
                        title: payload.title // Сохраняем название прямо в активный чат
                    };
                }

                return {
                    ...state,
                    chats_list: updatedChatsList,
                    active_chat: updatedActiveChat
                };
            });
        });

        // Обработка ошибки обновления названия чата
        channel.on('chat_title_error', (payload: { chat_id: string; reason: string }) => {
            // Просто логируем в консоль, чтобы не ломать стейт и не спамить юзера,
            // так как чат продолжит работать со старым/дефолтным названием
            console.warn(`[ChatNameCreator] Ошибка генерации названия для чата ${payload.chat_id}: ${payload.reason}`);

            // Возвращаем стейт без изменений
            return state;
        });
    },

    // УЧАСТОК: Добавление сообщения в чат ------------------------------------> Оптимистичная отправка сообщения
    sendMessage(text: string) {
        if (!text.trim()) return;

        const tempId = `temp-${Date.now()}`;
        let currentChatId: string | null = null;

        // 1. Оптимистично добавляем на фронт и ЗАПОМИНАЕМ chat_id из стейта
        update(state => {
            currentChatId = state.active_chat?.id || null; // <-- ИСПРАВЛЕНО: берем из стейта, а не через $appState

            const activeChat = state.active_chat || {
                id: '',
                messages: [],
                group_id: state.nav_context.params?.group_id
            };

            const newMessage = {
                id: tempId,
                role: 'user',
                content: text,
                created_at: new Date().toISOString(),
                is_pending: true
            };

            return {
                ...state,
                active_chat: {
                    ...activeChat,
                    messages: [...activeChat.messages, newMessage]
                }
            };
        });

        // 2. Шлем на бэк и ЛОВИМ результат в переменную pushRequest
        const pushRequest = this.send("chat:click_submit_message", {
            chat_id: currentChatId,
            text: text,
            temp_id: tempId
        });

        if (!pushRequest) return; // Защита, если канал умер

        // 3. Получаем ответ и подменяем временный ID на реальный
        pushRequest.receive('ok', (payload: { chat_id: string; message_id: number }) => {
            update(state => {
                if (!state.active_chat) return state;

                const messages = state.active_chat.messages.map(msg =>
                    // ИСПРАВЛЕНО: tempMsgId -> tempId
                    msg.id === tempId ? { ...msg, id: payload.message_id, is_pending: false } : msg
                );

                return {
                    ...state,
                    active_chat: {
                        ...state.active_chat,
                        id: payload.chat_id,
                        messages
                    }
                };
            });
        });

        // 4. На случай ошибки удаляем временное сообщение
        pushRequest.receive('error', () => {
            update(state => {
                if (!state.active_chat) return state;
                return {
                    ...state,
                    active_chat: {
                        ...state.active_chat,
                        // ИСПРАВЛЕНО: tempMsgId -> tempId
                        messages: state.active_chat.messages.filter(m => m.id !== tempId)
                    }
                };
            });
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
    goBack() {
        let destination: NavigationNode = { screen: 'chats' };

        update(state => {
            if (state.nav_history.length === 0) return state; // Идти некуда

            const updatedHistory = [...state.nav_history];
            destination = updatedHistory.pop()!; // Достаем предыдущий экран

            return {
                ...state,
                nav_context: destination,
                nav_history: updatedHistory,
                // Мгновенно чистим активный чат, если уходим на экран списка
                active_chat: destination.screen === 'chats' ? null : state.active_chat
            };
        });

        this._requestDataForScreen(destination);
    },

    goTo(target: NavigationNode) {
        let isDuplicate = false;

        update(state => {
            const isSameScreen = state.nav_context.screen === target.screen;
            const isSameChat = state.nav_context.params?.chat_id === target.params?.chat_id;
            const isSameGroup = state.nav_context.params?.group_id === target.params?.group_id;

            if (isSameScreen && isSameChat && isSameGroup) {
                isDuplicate = true;
                return state;
            }

            let updatedHistory = [...state.nav_history];
            if (state.nav_context.screen !== target.screen) {
                updatedHistory.push(state.nav_context);
            }
            if (updatedHistory.length > 10) updatedHistory.shift();

            return {
                ...state,
                nav_context: target,
                nav_history: updatedHistory,
                // Мгновенно чистим активный чат при любом переходе в список чатов
                active_chat: target.screen === 'chats' ? null : state.active_chat
            };
        });

        if (isDuplicate) return;
        this._requestDataForScreen(target);
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
                if (node.params?.chat_id) {
                    this.send('chat:click_open', { chat_id: node.params.chat_id }); // <-- Открываем чат
                } else {
                    this.send('chat:click_new', {}); // // <-- Подготавливаем создание чата если не пришел chat_id
                }
                break;
            case 'settings':
                this.send('user:get_settings');
                break;
        }
    }
};

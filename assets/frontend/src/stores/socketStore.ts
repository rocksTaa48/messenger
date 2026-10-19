import { writable, get } from 'svelte/store';
import { Socket, Channel } from 'phoenix';

// 1) Узел навигации: четко описывает, где мы и с каким контекстом
export interface NavigationNode {
    screen: 'chats' | 'settings' | 'inside_chat' | 'new_chat';
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
    nav_context: NavigationNode;
    nav_history: NavigationNode[];

    // Данные от бэкенда
    user: {
        id: number;
        username: string;
        role: string;
        status: string;
        ai_model_id: string;
        photo_url: any;
        first_name: string;
        last_name: string;
        profile_overrides?: {
            temperature?: number | string;
            top_p?: number | string;
            presence_penalty?: number | string;
            frequency_penalty?: number | string;
        };
    } | null;

    ai_model: {
        id: string;
        provider: string;
        model_name: string;
        display_name: string;
        display_description: string;
        display_icon: string;
        display_color: string;
        tier: string;
    } | null;

    profile_overrides?: {
        temperature?: number | string;
        top_p?: number | string;
        presence_penalty?: number | string;
        frequency_penalty?: number | string;
    } | null;

    ai_models: AppState['ai_model'][];

    ai_profile: {
        id: string;
        name: string;
        tier: string;
        display_name: string;
        display_description: string;
        temperature: string;
        top_p: string;
        frequency_penalty: string;
        presence_penalty: string;
    } | null;

    chats_list: Array<{
        id: string;
        title: string;
        unread?: number;
        group_id: number | null;
        ai_model_id: string;
        is_pinned: boolean;
        last_message: string;
        cursor_timestamp: string;
        profile_overrides?: {
            temperature?: number | string;
            top_p?: number | string;
            presence_penalty?: number | string;
            frequency_penalty?: number | string;
        };
    }>;

    groups: Array<{ id: string; title: string }>;

    active_chat:
        { id: string; title: string; ai_model_id: string; awaiting_response?: boolean;
            last_error_reason?: string | null;
            profile_overrides?: {
                temperature?: number | string;
                top_p?: number | string;
                presence_penalty?: number | string;
                frequency_penalty?: number | string;
            };
            messages: Array<{
                id: number | string;
                content: string;
                role: string;
                created_at: string;
                ai_model_id: string;
                is_streaming?: boolean;
                error?: boolean;
                is_aborted?: boolean;
                is_audio?: boolean;
                is_transcripted?: boolean;
                is_pending?: boolean;
                temp_id?: string;
            }>;
            has_more_messages?: boolean;
        } | null;

    has_more_chats: boolean;

    settings: { theme: string; lang: string };
}

// 3) Начальное состояние
const initialValue: AppState = {
    status: 'connecting',
    nav_context: { screen: 'chats' },
    nav_history: [],
    user: null,
    ai_model: null,
    ai_models: [],
    ai_profile: null,
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

        channel = socket.channel('session:lobby', () => {
            const currentAppState = get(store);
            return {
                nav_context: currentAppState.nav_context
            };
        });

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
                        ...initialServerState,
                        status: 'connected'
                    };
                });
            })
            .receive('error', () => {
                update(state => ({ ...state, status: 'error' }));
            });

        // -----------------------------------> Токены стриминга <------------------------------------
        channel.on('ai:token', (payload: { chat_id: string; token: string; ai_model_id: string; client_msg_id?: string }) => {
            update(state => {
                if (!state.active_chat) return state;

                const currentId = state.active_chat.id;
                if (currentId && String(currentId) !== String(payload.chat_id)) {
                    return state;
                }

                const messages = [...state.active_chat.messages];
                const lastMsg = messages[messages.length - 1];

                if (lastMsg && lastMsg.role === 'assistant' && lastMsg.is_aborted) {
                    return state;
                }

                if (lastMsg && lastMsg.role === 'assistant') {
                    lastMsg.content = (lastMsg.content || '') + (payload.token || '');
                    lastMsg.is_streaming = true;
                } else {
                    messages.push({
                        id: -Date.now(),
                        role: 'assistant',
                        ai_model_id: payload.ai_model_id || '',
                        content: payload.token || '',
                        created_at: new Date().toISOString(),
                        is_streaming: true
                    });
                }

                return {
                    ...state,
                    active_chat: { ...state.active_chat, id: payload.chat_id, awaiting_response: false, messages }
                };
            });
        });

        // -----------------------------------> Завершение стриминга <------------------------------------
        // Вызывается когда: (а) модель успешно завершила ответ, (б) юзер нажал Stop и был частичный контент.
        // Ошибки идут через ai:stream_error.
        channel.on('ai:stream_done', (payload: {
            chat_id: string;
            client_msg_id?: string;
            message_id?: number;
            content?: string;
            ai_model_id?: string;
            last_message?: string;
            status?: string;
            is_aborted?: boolean;
        }) => {
            update(state => {
                const targetId = String(payload.chat_id);

                const chats_list = state.chats_list.map(chat =>
                    chat && String(chat.id) === targetId
                        ? { ...chat, last_message: payload.last_message ?? chat.last_message }
                        : chat
                );

                let active_chat = state.active_chat;
                if (active_chat) {
                    const activeId = String(active_chat.id || '');
                    if (activeId === targetId || activeId === '') {
                        const messages = [...active_chat.messages];

                        let targetIdx = messages.findIndex(m => m.role === 'assistant' && m.is_streaming);

                        if (targetIdx === -1) {
                            for (let i = messages.length - 1; i >= 0; i--) {
                                if (messages[i].role === 'assistant') {
                                    targetIdx = i;
                                    break;
                                }
                            }
                        }

                        const aborted = payload.status === 'aborted'
                            || payload.status === 'aborted_empty'
                            || payload.is_aborted === true;

                        if (targetIdx >= 0) {
                            messages[targetIdx] = {
                                ...messages[targetIdx],
                                id: payload.message_id || messages[targetIdx].id,
                                content: payload.content ?? messages[targetIdx].content,
                                ai_model_id: payload.ai_model_id || messages[targetIdx].ai_model_id,
                                is_streaming: false,
                                is_aborted: aborted,
                            };
                        } else if (payload.content || payload.message_id) {
                            messages.push({
                                id: payload.message_id || -Date.now(),
                                role: 'assistant',
                                ai_model_id: payload.ai_model_id || '',
                                content: payload.content || '',
                                created_at: new Date().toISOString(),
                                is_streaming: false,
                                is_aborted: aborted,
                            });
                        }

                        active_chat = {
                            ...active_chat,
                            id: payload.chat_id,
                            awaiting_response: false,
                            last_error_reason: null,
                            messages,
                        };
                    }
                }

                return { ...state, chats_list, active_chat };
            });
        });

        // -----------------------------------> Ошибка стриминга <------------------------------------
        // Вызывается когда: провайдер упал, сеть, пустой ответ модели, или Stop до первого токена.
        // Сносим всё, что появилось ПОСЛЕ последнего user-сообщения — это «призрак» упавшей генерации.
        // В БД этих сообщений нет, поэтому слайс синхронизирует фронт с БД 1:1.
        channel.on('ai:stream_error', (payload: {
            chat_id: string;
            ai_model_id?: string | number;
            client_msg_id?: string;
            reason: string
        }) => {
            console.error('[AI stream error]', payload);
            update(state => {
                if (!state.active_chat) return state;

                const currentId = state.active_chat.id;
                if (currentId && String(currentId) !== String(payload.chat_id)) {
                    return state;
                }

                const msgs = [...state.active_chat.messages];
                let lastUserIdx = -1;
                for (let i = msgs.length - 1; i >= 0; i--) {
                    if (msgs[i].role === 'user') {
                        lastUserIdx = i;
                        break;
                    }
                }
                const cleaned = lastUserIdx >= 0 ? msgs.slice(0, lastUserIdx + 1) : msgs;

                return {
                    ...state,
                    active_chat: {
                        ...state.active_chat,
                        id: state.active_chat.id || payload.chat_id,
                        awaiting_response: false,
                        last_error_reason: payload.reason || 'error',
                        messages: cleaned,
                    }
                };
            });
        });

        // -----------------------------------> Обновление названия чата <------------------------------------
        channel.on('chat_title_update', (payload: { chat_id: string; title: string }) => {
            update(state => {
                const targetId = String(payload.chat_id);

                const chats_list = state.chats_list.map(chat =>
                    (chat.id && String(chat.id) === targetId)
                        ? { ...chat, title: payload.title }
                        : chat
                );

                let active_chat = state.active_chat;
                if (active_chat) {
                    const activeId = String(active_chat.id || '');
                    if (activeId === targetId || activeId === '') {
                        active_chat = {
                            ...active_chat,
                            id: active_chat.id || payload.chat_id,
                            title: payload.title
                        };
                    }
                }

                return { ...state, chats_list, active_chat };
            });
        });

        channel.on('chat_title_error', (payload: { chat_id: string; reason: string }) => {
            console.warn(`[ChatNameCreator] Ошибка генерации названия для чата ${payload.chat_id}: ${payload.reason}`);
            return;
        });

        // -----------------------------------> Транскрибация <------------------------------------
        channel.on('ai:transcript_done', (payload: {
            temp_id: string;
            chat_id: string;
            message_id: number;
            text: string;
            ai_model_id?: string;
            profile_overrides?: any;
        }) => {
            update(state => {
                if (!state.active_chat) return state;

                const messages = state.active_chat.messages.map(msg =>
                    msg.temp_id === payload.temp_id
                        ? {
                            ...msg,
                            id: payload.message_id,
                            content: payload.text,
                            ai_model_id: payload.ai_model_id || msg.ai_model_id,
                            is_transcripted: true,
                            is_pending: false
                        }
                        : msg
                );

                return {
                    ...state,
                    active_chat: {
                        ...state.active_chat,
                        id: state.active_chat.id || payload.chat_id,
                        ai_model_id: payload.ai_model_id || state.active_chat.ai_model_id,
                        profile_overrides: payload.profile_overrides ?? state.active_chat.profile_overrides,
                        messages
                    }
                };
            });
        });

        channel.on('ai:transcript_error', (payload: {
            temp_id: string;
            chat_id?: string | null;
            reason: string;
        }) => {
            console.error('[Transcript] error:', payload.reason);

            update(state => {
                if (!state.active_chat) return state;

                const messages = state.active_chat.messages.map(msg =>
                    msg.temp_id === payload.temp_id
                        ? {
                            ...msg,
                            is_transcripted: true,
                            is_pending: false,
                            error: true,
                            content: ''
                        }
                        : msg
                );

                return {
                    ...state,
                    active_chat: {
                        ...state.active_chat,
                        awaiting_response: false,
                        messages
                    }
                };
            });
        });
    },

    // ======================= Отправка текстового сообщения =================
    sendMessage(
        text: string,
        aiModelId: string | null = null,
        profileOverrides?: { temperature: number, topP: number, frequencyPenalty: number, presencePenalty: number }
    ) {
        if (!text.trim()) return;

        const tempId = `temp-${Date.now()}`;
        let currentChatId: string | null = null;

        // 1. Оптимистично добавляем user-бабл. Он остаётся до конца — это якорь для retry-бабла.
        update(state => {
            currentChatId = state.active_chat?.id || null;

            const activeChat = state.active_chat || {
                id: '',
                messages: [],
                group_id: state.nav_context.params?.group_id
            };

            const newMessage = {
                id: tempId,
                role: 'user',
                temp_id: tempId,
                content: text,
                created_at: new Date().toISOString(),
                is_pending: true
            };

            return {
                ...state,
                active_chat: {
                    ...activeChat,
                    awaiting_response: true,
                    last_error_reason: null,
                    messages: [...activeChat.messages, newMessage]
                }
            };
        });

        const overrides = profileOverrides
            ? {
                temperature: profileOverrides.temperature,
                top_p: profileOverrides.topP,
                frequency_penalty: profileOverrides.frequencyPenalty,
                presence_penalty: profileOverrides.presencePenalty,
            }
            : undefined;

        // 2. Шлём на бэк
        const pushRequest = this.send("chat:click_submit_message", {
            chat_id: currentChatId,
            text: text,
            temp_id: tempId,
            ...(currentChatId ? {} : {
                ai_model_id: aiModelId ? Number(aiModelId) : undefined,
                profile_overrides: overrides,
            })
        });

        if (!pushRequest) {
            // Канал ещё не готов — снимаем awaiting, чтобы не залочить UI.
            update(state => state.active_chat ? {
                ...state,
                active_chat: { ...state.active_chat, awaiting_response: false }
            } : state);
            return;
        }

        pushRequest.receive('ok', (payload: {
            chat_id: string;
            message_id: number;
            ai_model_id: string;
            profile_overrides?: {
                temperature?: number | string;
                top_p?: number | string;
                presence_penalty?: number | string;
                frequency_penalty?: number | string;
            } | null;
        }) => {
            update(state => {
                if (!state.active_chat) return state;

                const messages = state.active_chat.messages.map(msg =>
                    msg.id === tempId ? { ...msg, id: payload.message_id, is_pending: false } : msg
                );

                return {
                    ...state,
                    active_chat: {
                        ...state.active_chat,
                        id: payload.chat_id,
                        ai_model_id: payload.ai_model_id,
                        messages,
                        profile_overrides: payload.profile_overrides ?? state.active_chat.profile_overrides,
                    },
                };
            });
        });

        // Снимаем залипание awaiting на сетевой ошибке push.
        pushRequest.receive('error', () => {
            update(state => state.active_chat ? {
                ...state,
                active_chat: { ...state.active_chat, awaiting_response: false }
            } : state);
        });
    },

    // ======================= Остановка текущей генерации =================
    stopGeneration(chat_id: string) {
        update(state => {
            if (!state.active_chat || String(state.active_chat.id) !== String(chat_id)) {
                return state;
            }

            // Был ли реальный контент от assistant? Если да — backend сохранит aborted-message
            // и пришлёт ai:stream_done. Если нет — backend пришлёт ai:stream_error(:aborted_empty).
            // Оптимистично ставим корректный last_error_reason, чтобы не мигать UI.
            const hasContent = state.active_chat.messages.some(
                m => m.role === 'assistant' && m.is_streaming && (m.content || '').length > 0
            );

            const messages = state.active_chat.messages.map(msg => {
                if (msg.role === 'assistant' && msg.is_streaming) {
                    return { ...msg, is_streaming: false, is_aborted: true };
                }
                return msg;
            });

            return {
                ...state,
                active_chat: {
                    ...state.active_chat,
                    awaiting_response: false,
                    last_error_reason: hasContent ? null : 'aborted_empty',
                    messages
                }
            };
        });

        this.send("chat:click_stop_streaming", {
            chat_id: chat_id
        });
    },

    // ======================= Повтор последнего неудавшегося сообщения =================
    retryLastMessage() {
        const state = get(store);
        const chat = state.active_chat;
        if (!chat) return;
        if (chat.awaiting_response) return;

        let lastUserMsg: any = null;
        for (let i = chat.messages.length - 1; i >= 0; i--) {
            if (chat.messages[i].role === 'user') {
                lastUserMsg = chat.messages[i];
                break;
            }
        }
        if (!lastUserMsg) return;
        if (lastUserMsg.is_pending) return;
        if (!lastUserMsg.id || String(lastUserMsg.id).startsWith('temp-')) return;

        const userMsgId = lastUserMsg.id;
        const tempId = `temp-${Date.now()}`;

        update(state => {
            if (!state.active_chat) return state;
            return {
                ...state,
                active_chat: {
                    ...state.active_chat,
                    awaiting_response: true,
                    last_error_reason: null
                }
            };
        });

        const push = this.send('chat:click_retry_message', {
            chat_id: chat.id,
            message_id: userMsgId,
            temp_id: tempId
        });

        if (!push) {
            update(state => state.active_chat ? {
                ...state,
                active_chat: { ...state.active_chat, awaiting_response: false, last_error_reason: 'push_error' }
            } : state);
            return;
        }

        push.receive('error', () => {
            update(state => state.active_chat ? {
                ...state,
                active_chat: { ...state.active_chat, awaiting_response: false, last_error_reason: 'push_error' }
            } : state);
        });
    },

    // ======================= Отправка голосового сообщения =================
    sendVoiceMessage(
        blob: Blob,
        aiModelId: string | null = null,
        profileOverrides?: {
            temperature: number;
            topP: number;
            frequencyPenalty: number;
            presencePenalty: number;
        }
    ) {
        const tempId = `temp-${Date.now()}`;
        let currentChatId: string | null = null;

        update(state => {
            currentChatId = state.active_chat?.id || null;

            const activeChat = state.active_chat || {
                id: '',
                messages: [],
                group_id: state.nav_context.params?.group_id
            };

            const newMessage = {
                id: tempId,
                temp_id: tempId,
                role: 'user',
                content: '',
                created_at: new Date().toISOString(),
                is_pending: true,
                is_audio: true,
                is_transcripted: false
            };

            return {
                ...state,
                active_chat: {
                    ...activeChat,
                    awaiting_response: true,
                    last_error_reason: null,
                    messages: [...activeChat.messages, newMessage]
                }
            };
        });

        const initData = window.Telegram?.WebApp?.initData || "";

        const formData = new FormData();
        formData.append('audio', blob, 'voice.webm');
        if (currentChatId) formData.append('chat_id', currentChatId);
        formData.append('temp_id', tempId);
        if (!currentChatId && aiModelId) formData.append('ai_model_id', aiModelId);
        if (!currentChatId && profileOverrides) {
            formData.append('profile_overrides', JSON.stringify({
                temperature: profileOverrides.temperature,
                top_p: profileOverrides.topP,
                frequency_penalty: profileOverrides.frequencyPenalty,
                presence_penalty: profileOverrides.presencePenalty
            }));
        }

        fetch('/api/upload-audio', {
            method: 'POST',
            body: formData,
            headers: {
                'Authorization': `Bearer ${initData}`
            }
        })
            .then(res => {
                if (!res.ok) throw new Error(`HTTP ${res.status}`);
                return res.json();
            })
            .catch(err => {
                console.error('[sendVoiceMessage] fetch failed:', err);
                update(state => {
                    if (!state.active_chat) return state;

                    const messages = state.active_chat.messages.map(msg =>
                        msg.temp_id === tempId
                            ? { ...msg, is_transcripted: true, is_pending: false, error: true }
                            : msg
                    );

                    return {
                        ...state,
                        active_chat: {
                            ...state.active_chat,
                            awaiting_response: false,
                            messages
                        }
                    };
                });
            });
    },

    send(event: string, payload: object = {}) {
        if (channel) {
            return channel.push(event, payload);
        } else {
            console.warn(`Не могу отправить ${event}, канал еще не готов.`);
            return null;
        }
    },

    goBack() {
        let destination: NavigationNode = { screen: 'chats' };

        update(state => {
            if (state.nav_history.length === 0) return state;

            const updatedHistory = [...state.nav_history];
            destination = updatedHistory.pop()!;

            return {
                ...state,
                nav_context: destination,
                nav_history: updatedHistory,
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
                active_chat: target.screen === 'chats' ? null : state.active_chat
            };
        });

        if (isDuplicate) return;
        this._requestDataForScreen(target);
    },

    _requestDataForScreen(node: NavigationNode) {
        switch (node.screen) {
            case 'chats':
                this.send('base:click_nav_chats', { group_id: node.params?.group_id });
                break;
            case 'new_chat':
                this.send('chat:click_new', {});
                break;
            case 'inside_chat':
                this.send('chat:click_open', { chat_id: node.params.chat_id });
                break;
            case 'settings':
                this.send('user:click_show_user_usage');
                break;
        }
    }
};
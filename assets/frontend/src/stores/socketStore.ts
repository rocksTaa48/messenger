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
        user: {
            id: number;
            username: string;
            role: string;
            status: string;
            ai_model_id: string;
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
                profile_overrides?: {
                    temperature?: number | string;
                    top_p?: number | string;
                    presence_penalty?: number | string;
                    frequency_penalty?: number | string;
                };
                messages: Array<{
                    id: number;
                    content: string;
                    role: string;
                    created_at: string;
                    ai_model_id: string;
                    is_streaming?: boolean; // Ответ все еще стримится или уже нет.
                    error?: boolean;
                    is_aborted?: boolean;
                    is_audio?: boolean;         // это голосовое сообщение.
                    is_transcripted?: boolean;  // еще переводится.
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
    
            // Когда Elixir присылает sync, обновляем ТОЛЬКО данные. Навигацию не трогает.
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
            channel.on('ai:token', (payload: { chat_id: string; token: string; ai_model_id: string; client_msg_id?: string }) => {
                update(state => {
                    if (!state.active_chat) return state;

                    const currentId = state.active_chat.id;
                    if (currentId && String(currentId) !== String(payload.chat_id)) {
                        return state;
                    }

                    const messages = [...state.active_chat.messages];
                    const lastMsg = messages[messages.length - 1];

                    // Не требуем строго is_streaming === true.
                    // Если последнее сообщение уже от ассистента, просто дописываем в него.
                    // Это предотвращает создание дубликата из-за опоздавших токенов после нажатия "Стоп".
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

            // 2. Завершение генерации (исправленное)
            channel.on('ai:stream_done', (payload: {
                chat_id: string;
                client_msg_id?: string;
                message_id?: number;
                content?: string;
                ai_model_id?: string;
                last_message?: string;
                status?: string;
                error?: boolean;
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

                            if (targetIdx >= 0) {
                                messages[targetIdx] = {
                                    ...messages[targetIdx],
                                    id: payload.message_id || messages[targetIdx].id,
                                    content: payload.content ?? messages[targetIdx].content,
                                    ai_model_id: payload.ai_model_id || messages[targetIdx].ai_model_id,
                                    is_streaming: false,
                                    is_aborted: payload.status === 'aborted' || payload.status === 'aborted_empty',
                                    error: payload.error || payload.status === 'aborted_empty'  // <-- Добавили
                                };
                            } else {
                                if (payload.content || payload.message_id || payload.error) {
                                    messages.push({
                                        id: payload.message_id || -Date.now(),
                                        role: 'assistant',
                                        ai_model_id: payload.ai_model_id || '',
                                        content: payload.content || '',
                                        created_at: new Date().toISOString(),
                                        is_streaming: false,
                                        is_aborted: payload.status === 'aborted' || payload.status === 'aborted_empty',
                                        error: payload.error || payload.status === 'aborted_empty'
                                    });
                                }
                            }

                            active_chat = { ...active_chat, id: payload.chat_id, awaiting_response: false, messages };
                        }
                    }

                    return { ...state, chats_list, active_chat };
                });
            });
    
            // 3. Ошибка генерации
            channel.on('ai:stream_error', (payload: {
                chat_id: string;
                ai_model_id?: string | number;
                client_msg_id?: string;
                reason: string
            }) => {
                console.error('AI stream error:', payload);
                update(state => {
                    if (!state.active_chat) return state;
    
                    const currentId = state.active_chat.id;
                    if (currentId && String(currentId) !== String(payload.chat_id)) {
                        return state;
                    }
    
                    const messages = [...state.active_chat.messages];
                    const streamingIdx = messages.findIndex(
                        m => m.role === 'assistant' && m.is_streaming
                    );
    
                    if (streamingIdx >= 0) {
                        messages[streamingIdx] = {
                            ...messages[streamingIdx],
                            is_streaming: false,
                            ai_model_id: payload.ai_model_id,
                            error: true
                        };
                    } else {
                        messages.push({
                            id: -Date.now(),
                            role: 'assistant',
                            ai_model_id: payload.ai_model_id | '',
                            content: '',
                            error: true,
                            is_streaming: false,
                            created_at: new Date().toISOString()
                        });
                    }

                    return {
                        ...state,
                        active_chat: {
                            ...state.active_chat,
                            id: state.active_chat.id,
                            title: state.active_chat.title,
                            ai_model_id: state.active_chat.ai_model_id,
                            profile_overrides: state.active_chat.profile_overrides,
                            awaiting_response: false,
                            messages,
                            has_more_messages: state.active_chat.has_more_messages
                        }
                    };
                });
            });
    
            // Обработка успешного обновления названия чата от модели (она генерит название)
            channel.on('chat_title_update', (payload: { chat_id: string; title: string }) => {
                update(state => {
                    const targetId = String(payload.chat_id);
    
                    // chats_list — обновляем, если нашли чат
                    const chats_list = state.chats_list.map(chat =>
                        (chat.id && String(chat.id) === targetId)
                            ? { ...chat, title: payload.title }
                            : chat
                    );
    
                    // active_chat — обновляем, если он наш или у него ещё нет id. Например когда новый чат
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
    
            // Обработка ошибки обновления названия чата
            channel.on('chat_title_error', (payload: { chat_id: string; reason: string }) => {
                // Просто логируем в консоль, чтобы не ломать стейт и не спамить юзера,
                // так как чат продолжит работать со старым/дефолтным названием
                console.warn(`[ChatNameCreator] Ошибка генерации названия для чата ${payload.chat_id}: ${payload.reason}`);
    
                // Возвращаем стейт без изменений
                return state;
            });

            // 4. Успешная транскрибация голосового сообщения
            channel.on('ai:transcript_done', (payload: {
                temp_id: string;
                chat_id: string;
                message_id: number;
                text: string;
                ai_model_id?: string;
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
                            // Если это был новый чат — фиксируем реальный chat_id,
                            // чтобы последующие ai:token / ai:stream_done не отфильтровались
                            id: state.active_chat.id || payload.chat_id,
                            messages
                        }
                    };
                });
            });

            // 5. Ошибка транскрибации
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
                            // Снимаем awaiting, потому что ответа модели не будет
                            awaiting_response: false,
                            messages
                        }
                    };
                });
            });
        },
    
        // УЧАСТОК: Добавление сообщения в чат ------------------------------------> Оптимистичная отправка сообщения
        sendMessage(
            text: string,
            aiModelId: string | null = null,
            profileOverrides?: { temperature: number, topP: number, frequencyPenalty: number, presencePenalty: number }
        ) {
            if (!text.trim()) return;
    
            const tempId = `temp-${Date.now()}`;
            let currentChatId: string | null = null;
    
            // 1. Оптимистично добавляем на фронт
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
                    temp_id: tempId,  // Это айдишник для отслеживания куда стримить ответ модели, чтоб она знала, потому что сам ID затрется реальным :)
                    content: text,
                    created_at: new Date().toISOString(),
                    is_pending: true
                };
    
                return {
                    ...state,
                    active_chat: {
                        ...activeChat,
                        awaiting_response: true,
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
    
            if (!pushRequest) return;
    
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
        },

        // ======================= Останавливает текущую генерацию для указанного чата =================================
        stopGeneration(chat_id: string) {
            // 1. Оптимистично обновляем UI
            update(state => {
                if (!state.active_chat || String(state.active_chat.id) !== String(chat_id)) {
                    return state;
                }

                const messages = state.active_chat.messages.map(msg => {
                    if (msg.role === 'assistant' && msg.is_streaming) {
                        return {
                            ...msg,
                            is_streaming: false,
                            is_aborted: true // Помечаем для UI, что генерация прервана
                        };
                    }
                    return msg;
                });

                return {
                    ...state,
                    active_chat: { ...state.active_chat, awaiting_response: false, messages }
                };
            });

            // 2. Шлем на бэк
            this.send("chat:click_stop_streaming", {
                chat_id: chat_id
            });
        },

        // ========================= Отправка голосового сообщения =========================
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

            // 1. Оптимистичный бабл — пустой, с флагом isAudio
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
                        messages: [...activeChat.messages, newMessage]
                    }
                };
            });

            // 2. FormData — как в рабочем handleSendAudio
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

            // 3. Отправка — URL и заголовки как в рабочем методе
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

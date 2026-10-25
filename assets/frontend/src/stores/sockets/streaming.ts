import type { Channel } from 'phoenix';
import { getState, send, update } from './core';

export function registerStreamingListeners(channel: Channel) {
    // ==========================================
    // [AI] Токены стриминга
    // ==========================================
    channel.on('ai:token', (payload: { chat_id: string; token: string; ai_model_id: string; client_msg_id?: string }) => {
        update(state => {
            if (!state.active_chat) return state;
            const currentId = state.active_chat.id;
            if (currentId && String(currentId) !== String(payload.chat_id)) return state;

            const messages = [...state.active_chat.messages];
            const lastMsg = messages[messages.length - 1];

            if (lastMsg && lastMsg.role === 'assistant' && lastMsg.is_aborted) return state;

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
                    is_streaming: true,
                });
            }

            return { ...state, active_chat: { ...state.active_chat, id: payload.chat_id, awaiting_response: false, messages } };
        });
    });

    // ==========================================
    // [AI] Завершение стриминга
    // ==========================================
    channel.on('ai:stream_done', (payload: {
        chat_id: string; client_msg_id?: string; message_id?: number; content?: string;
        ai_model_id?: string; last_message?: string; status?: string; is_aborted?: boolean;
    }) => {
        update(state => {
            const targetId = String(payload.chat_id);
            const chats_list = state.chats_list.map(chat =>
                chat && String(chat.id) === targetId ? { ...chat, last_message: payload.last_message ?? chat.last_message } : chat
            );

            let active_chat = state.active_chat;
            if (active_chat) {
                const activeId = String(active_chat.id || '');
                if (activeId === targetId || activeId === '') {
                    const messages = [...active_chat.messages];
                    let targetIdx = messages.findIndex(m => m.role === 'assistant' && m.is_streaming);

                    if (targetIdx === -1) {
                        for (let i = messages.length - 1; i >= 0; i--) {
                            if (messages[i].role === 'assistant') { targetIdx = i; break; }
                        }
                    }

                    const aborted = payload.status === 'aborted' || payload.status === 'aborted_empty' || payload.is_aborted === true;

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

                    active_chat = { ...active_chat, id: payload.chat_id, awaiting_response: false, last_error_reason: null, messages };
                }
            }
            return { ...state, chats_list, active_chat };
        });
    });

    // ==========================================
    // [AI] Ошибка стриминга
    // ==========================================
    channel.on('ai:stream_error', (payload: { chat_id: string; ai_model_id?: string | number; client_msg_id?: string; reason: string }) => {
        console.error('[AI stream error]', payload);
        update(state => {
            if (!state.active_chat) return state;
            const currentId = state.active_chat.id;
            if (currentId && String(currentId) !== String(payload.chat_id)) return state;

            const msgs = [...state.active_chat.messages];
            let lastUserIdx = -1;
            for (let i = msgs.length - 1; i >= 0; i--) {
                if (msgs[i].role === 'user') { lastUserIdx = i; break; }
            }
            const cleaned = lastUserIdx >= 0 ? msgs.slice(0, lastUserIdx + 1) : msgs;

            return {
                ...state,
                active_chat: { ...state.active_chat, id: state.active_chat.id || payload.chat_id, awaiting_response: false, last_error_reason: payload.reason || 'error', messages: cleaned },
            };
        });
    });
}

// ============================================================================
// ДЕЙСТВИЯ СТРИМИНГА
// ============================================================================

export function stopGeneration(chat_id: string) {
    update(state => {
        if (!state.active_chat || String(state.active_chat.id) !== String(chat_id)) return state;

        const hasContent = state.active_chat.messages.some(m => m.role === 'assistant' && m.is_streaming && (m.content || '').length > 0);
        const messages = state.active_chat.messages.map(msg =>
            msg.role === 'assistant' && msg.is_streaming ? { ...msg, is_streaming: false, is_aborted: true } : msg
        );

        return {
            ...state,
            active_chat: { ...state.active_chat, awaiting_response: false, last_error_reason: hasContent ? null : 'aborted_empty', messages },
        };
    });
    send('chat:click_stop_streaming', { chat_id });
}

export function retryLastMessage() {
    const state = getState();
    const chat = state.active_chat;
    if (!chat || chat.awaiting_response) return;

    let lastUserMsg: any = null;
    for (let i = chat.messages.length - 1; i >= 0; i--) {
        if (chat.messages[i].role === 'user') { lastUserMsg = chat.messages[i]; break; }
    }
    if (!lastUserMsg || lastUserMsg.is_pending || !lastUserMsg.id || String(lastUserMsg.id).startsWith('temp-')) return;

    const userMsgId = lastUserMsg.id;
    const tempId = `temp-${Date.now()}`;

    update(s => ({ ...s, active_chat: { ...s.active_chat!, awaiting_response: true, last_error_reason: null } }));

    const push = send('chat:click_retry_message', { chat_id: chat.id, message_id: userMsgId, temp_id: tempId });
    if (!push) {
        update(s => s.active_chat ? { ...s, active_chat: { ...s.active_chat, awaiting_response: false, last_error_reason: 'push_error' } } : s);
        return;
    }
    push.receive('error', () => {
        update(s => s.active_chat ? { ...s, active_chat: { ...s.active_chat, awaiting_response: false, last_error_reason: 'push_error' } } : s);
    });
}
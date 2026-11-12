import type { Channel } from 'phoenix';
import { send, update } from './core';

export function registerChatListeners(channel: Channel) {
    // ==========================================
    // [CHAT] Обновление названия чата
    // ==========================================
    channel.on('chat_title_update', (payload: { chat_id: string; title: string }) => {
        update(state => {
            const targetId = String(payload.chat_id);
            const chats_list = state.chats_list.map(chat =>
                (chat.id && String(chat.id) === targetId) ? { ...chat, title: payload.title } : chat
            );
            let active_chat = state.active_chat;
            if (active_chat) {
                const activeId = String(active_chat.id || '');
                if (activeId === targetId || activeId === '') {
                    active_chat = { ...active_chat, id: active_chat.id || payload.chat_id, title: payload.title };
                }
            }
            return { ...state, chats_list, active_chat };
        });
    });

    channel.on('chat_title_error', (payload: { chat_id: string; reason: string }) => {
        console.warn(`[ChatNameCreator] Ошибка генерации названия для чата ${payload.chat_id}: ${payload.reason}`);
    });

    // ==========================================
    // [AI] Транскрибация аудио
    // ==========================================
    channel.on('ai:transcript_done', (payload: { temp_id: string; chat_id: string; message_id: number; text: string; ai_model_id?: string; profile_overrides?: any }) => {
        update(state => {
            if (!state.active_chat) return state;
            const messages = state.active_chat.messages.map(msg =>
                msg.temp_id === payload.temp_id ? {
                    ...msg, id: payload.message_id, content: payload.text,
                    ai_model_id: payload.ai_model_id || msg.ai_model_id, is_transcripted: true, is_pending: false,
                } : msg
            );
            return {
                ...state,
                active_chat: {
                    ...state.active_chat, id: state.active_chat.id || payload.chat_id,
                    ai_model_id: payload.ai_model_id || state.active_chat.ai_model_id,
                    profile_overrides: payload.profile_overrides ?? state.active_chat.profile_overrides, messages,
                },
            };
        });
    });

    channel.on('ai:transcript_error', (payload: { temp_id: string; chat_id?: string | null; reason: string }) => {
        console.error('[Transcript] error:', payload.reason);
        update(state => {
            if (!state.active_chat) return state;
            const messages = state.active_chat.messages.map(msg =>
                msg.temp_id === payload.temp_id ? { ...msg, is_transcripted: true, is_pending: false, error: true, content: '' } : msg
            );
            return { ...state, active_chat: { ...state.active_chat, awaiting_response: false, messages } };
        });
    });
}

// ============================================================================
// ДЕЙСТВИЯ ЧАТОВ
// ============================================================================

export function sendMessage(
    text: string,
    aiModelId: string | null = null,
    imageAiModelId: string | null = null,
    profileOverrides?: { temperature: number, topP: number, frequencyPenalty: number, presencePenalty: number }
) {
    if (!text.trim()) return;
    const tempId = `temp-${Date.now()}`;
    let currentChatId: string | null = null;
    let isImageSession = false;

    update(state => {
        currentChatId = state.active_chat?.id || null;
        isImageSession = !currentChatId && (state.nav_context?.params?.is_image_session || false);
        const activeChat = state.active_chat || { id: '', messages: [], group_id: state.nav_context.params?.group_id };
        const newMessage = { id: tempId, role: 'user', temp_id: tempId, content: text, created_at: new Date().toISOString(), is_pending: true };

        return {
            ...state,
            active_chat: { ...activeChat, awaiting_response: true, last_error_reason: null, messages: [...activeChat.messages, newMessage] },
        };
    });

    const overrides = profileOverrides ? {
        temperature: profileOverrides.temperature, top_p: profileOverrides.topP,
        frequency_penalty: profileOverrides.frequencyPenalty, presence_penalty: profileOverrides.presencePenalty,
    } : undefined;

    const pushRequest = send('chat:click_submit_message', {
        chat_id: currentChatId, text, temp_id: tempId,
        ...(currentChatId ? {} : {
            ai_model_id: aiModelId ? Number(aiModelId) : undefined,
            image_ai_model_id: imageAiModelId ? Number(imageAiModelId) : undefined,
            profile_overrides: overrides,
            is_image_session: isImageSession
        }),
    });

    if (!pushRequest) {
        update(state => state.active_chat ? { ...state, active_chat: { ...state.active_chat, awaiting_response: false } } : state);
        return;
    }

    pushRequest.receive('ok', (payload: { chat_id: string; message_id: number; ai_model_id: string; profile_overrides?: any }) => {
        update(state => {
            if (!state.active_chat) return state;
            const messages = state.active_chat.messages.map(msg => msg.id === tempId ? { ...msg, id: payload.message_id, is_pending: false } : msg);
            return {
                ...state, active_chat: { ...state.active_chat, id: payload.chat_id, ai_model_id: payload.ai_model_id, messages, profile_overrides: payload.profile_overrides ?? state.active_chat.profile_overrides },
            };
        });
    });

    pushRequest.receive('error', () => {
        update(state => state.active_chat ? { ...state, active_chat: { ...state.active_chat, awaiting_response: false } } : state);
    });
}

export function sendVoiceMessage(
    blob: Blob,
    aiModelId: string | null = null,
    imageAiModelId: string | null = null,
    profileOverrides?: any,
) {
    const tempId = `temp-${Date.now()}`;
    let currentChatId: string | null = null;
    let isImageSession = false;

    update(state => {
        currentChatId = state.active_chat?.id || null;
        isImageSession = !currentChatId && (state.nav_context?.params?.is_image_session || false);
        const activeChat = state.active_chat || { id: '', messages: [], group_id: state.nav_context.params?.group_id };
        const newMessage = { id: tempId, temp_id: tempId, role: 'user', content: '', created_at: new Date().toISOString(), is_pending: true, is_audio: true, is_transcripted: false };

        return { ...state, active_chat: { ...activeChat, awaiting_response: true, last_error_reason: null, messages: [...activeChat.messages, newMessage] } };
    });

    const initData = (window as any).Telegram?.WebApp?.initData || '';
    const formData = new FormData();
    formData.append('audio', blob, 'voice.webm');
    if (currentChatId) formData.append('chat_id', currentChatId);
    formData.append('temp_id', tempId);
    if (!currentChatId && aiModelId) formData.append('ai_model_id', aiModelId);
    if (!currentChatId && imageAiModelId) formData.append('image_ai_model_id', imageAiModelId);
    if (!currentChatId && profileOverrides) formData.append('profile_overrides', JSON.stringify(profileOverrides));
    formData.append('is_image_session', String(isImageSession));

    fetch('/api/upload-audio', { method: 'POST', body: formData, headers: { 'Authorization': `Bearer ${initData}` } })
        .then(res => { if (!res.ok) throw new Error(`HTTP ${res.status}`); return res.json(); })
        .catch(err => {
            console.error('[sendVoiceMessage] fetch failed:', err);
            update(state => {
                if (!state.active_chat) return state;
                const messages = state.active_chat.messages.map(msg => msg.temp_id === tempId ? { ...msg, is_transcripted: true, is_pending: false, error: true } : msg);
                return { ...state, active_chat: { ...state.active_chat, awaiting_response: false, messages } };
            });
        });
}

export function downloadOriginalImage(url: string, filename: string = 'generated-image.webp') {
    const initData = (window as any).Telegram?.WebApp?.initData || '';

    fetch(url, {
        headers: {
            'Authorization': `Bearer ${initData}`
        }
    })
        .then(async response => {
            if (!response.ok) throw new Error(`HTTP ${response.status}`);

            const blob = await response.blob();
            const blobUrl = window.URL.createObjectURL(blob);

            const a = document.createElement('a');
            a.href = blobUrl;
            a.download = filename;
            a.style.display = 'none';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            window.URL.revokeObjectURL(blobUrl);
        })
        .catch(error => {
            console.error('[downloadOriginalImage] failed:', error);
        });
}

export function sendImageToTelegram(imageUrl: string) {
    const initData = (window as any).Telegram?.WebApp?.initData || '';

    // Показываем нативный лоадер Telegram
    (window as any).Telegram?.WebApp?.HapticFeedback?.impactOccurred('medium');

    fetch('/api/images/send-to-telegram', {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${initData}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ image_url: imageUrl })
    })
        .then(async response => {
            if (!response.ok) throw new Error(`HTTP ${response.status}`);

            const data = await response.json();
            console.log('[sendImageToTelegram] Success:', data);

            // Показываем нативное уведомление Telegram об успехе
            (window as any).Telegram?.WebApp?.showPopup({
                title: 'Готово!',
                message: 'Изображение отправлено вам в личные сообщения бота.',
                buttons: [{ type: 'ok' }]
            });
        })
        .catch(error => {
            console.error('[sendImageToTelegram] failed:', error);
            (window as any).Telegram?.WebApp?.showPopup({
                title: 'Ошибка',
                message: 'Не удалось отправить изображение. Попробуйте позже.',
                buttons: [{ type: 'ok' }]
            });
        });
}
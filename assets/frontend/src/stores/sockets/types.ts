// ============================================================================
// ТИПЫ И ИНТЕРФЕЙСЫ
// ============================================================================

export interface NavigationNode {
    screen: 'chats' | 'settings' | 'inside_chat' | 'new_chat';
    params?: {
        chat_id?: string;
        group_id?: string;
        [key: string]: any;
    };
}

export interface AppState {
    status: 'connecting' | 'connected' | 'error';

    // --- Навигация ---
    nav_context: NavigationNode;
    nav_history: NavigationNode[];

    // --- Пользователь ---
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

    // --- AI Модели и Профили ---
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

    // --- Чаты и Сообщения ---
    chats_list: Array<{
        id: string;
        title: string;
        unread?: number;
        group_id: number | null;
        ai_model_id: string;
        is_image_session: boolean;
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

    active_chat: {
        id: string;
        title: string;
        ai_model_id: string;
        is_image_session: boolean;
        awaiting_response?: boolean;
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
            image_url?: string;
            image_media_type?: string;
            image_error?: string;
        }>;
        has_more_messages?: boolean;
    } | null;

    has_more_chats: boolean;
    has_more_messages: boolean;

    // --- Настройки ---
    settings: { theme: string; lang: string };

    // --- Платежи ---
    payment: {
        status: 'idle' | 'creating' | 'waiting' | 'completed' | 'failed';
        data: {
            payment_id?: number;
            payment_url?: string;
            exact_amount?: string;
            address?: string;
            network?: string;
            tx_hash?: string;
        } | null;
        error: string | null;
    };
}

export const initialValue: AppState = {
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
    settings: { theme: 'dark', lang: 'ru' },

    payment: {
        status: 'idle',
        data: null,
        error: null,
    },
};
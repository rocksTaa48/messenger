import type { NavigationNode } from './types';
import { send, update } from './core';

export function requestDataForScreen(node: NavigationNode) {
    switch (node.screen) {
        case 'chats':
            send('base:click_nav_chats', { group_id: node.params?.group_id });
            break;
        case 'new_chat':
            send('chat:click_new', {is_image_session: node.params?.is_image_session});
            break;
        case 'inside_chat':
            send('chat:click_open', { chat_id: node.params?.chat_id });
            break;
        case 'settings':
            send('user:click_show_user_usage');
            break;
    }
}

export function goBack() {
    let destination: NavigationNode = { screen: 'chats' };
    update(state => {
        if (state.nav_history.length === 0) return state;
        const updatedHistory = [...state.nav_history];
        destination = updatedHistory.pop()!;
        return {
            ...state,
            nav_context: destination,
            nav_history: updatedHistory,
            active_chat: destination.screen === 'chats' ? null : state.active_chat,
        };
    });
    requestDataForScreen(destination);
}

export function goTo(target: NavigationNode) {
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
            active_chat: target.screen === 'chats' ? null : state.active_chat,
        };
    });

    if (isDuplicate) return;
    requestDataForScreen(target);
}
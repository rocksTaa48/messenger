// ============================================================================
// Единая точка входа. Публичный API не меняется — компоненты можно не трогать.
// ============================================================================

import { subscribe, send, initSession as initSessionCore } from './sockets/core';
import { registerStreamingListeners, stopGeneration, retryLastMessage } from './sockets/streaming';
import { registerChatListeners, sendMessage, sendVoiceMessage, downloadOriginalImage, sendImageToTelegram } from './sockets/chat';
import { registerPaymentListeners, createPaymentInvoice, resetPaymentState } from './sockets/payment';
import { goBack, goTo, requestDataForScreen } from './sockets/nav';

export type { AppState, NavigationNode } from './sockets/types';

export const appState = {
    subscribe,

    // --- Сессия ---
    initSession(initData: string) {
        initSessionCore(initData, (channel) => {
            registerStreamingListeners(channel);
            registerChatListeners(channel);
            registerPaymentListeners(channel);
        });
    },

    // --- Транспорт ---
    send,

    // --- Чаты ---
    sendMessage,
    sendVoiceMessage,
    downloadOriginalImage,
    sendImageToTelegram,

    // --- Стриминг ---
    stopGeneration,
    retryLastMessage,

    // --- Платежи ---
    createPaymentInvoice,
    resetPaymentState,

    // --- Навигация ---
    goBack,
    goTo,
    // внутренняя, но оставляем для обратной совместимости
    _requestDataForScreen: requestDataForScreen,
};
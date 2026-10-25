import type { Channel } from 'phoenix';
import { getState, send, update } from './core';

export function registerPaymentListeners(channel: Channel) {
    channel.on('payment:invoice_created', (payload) => {
        console.log('🎯 payment:invoice_created получен:', payload);
        update(state => ({
            ...state,
            payment: { ...state.payment, status: 'waiting', data: payload, error: null },
        }));
    });

    // 2. Оплата прошла
    channel.on('payment:completed', (payload: { payment_id: number; user_id: number; tx_hash: string }) => {
        const currentState = getState();
        if (currentState.user?.id !== payload.user_id) return;

        update(state => ({
            ...state,
            payment: {
                ...state.payment,
                status: 'completed',
                data: state.payment.data ? { ...state.payment.data, tx_hash: payload.tx_hash } : null,
            },
        }));
    });

    // 3. Ошибка создания / обработки
    channel.on('payment:error', (payload: { message: string }) => {
        update(state => ({
            ...state,
            payment: { ...state.payment, status: 'failed', error: payload.message },
        }));
    });
}

// ============================================================================
// ДЕЙСТВИЯ ПЛАТЕЖЕЙ
// ============================================================================

export function createPaymentInvoice(amount: number, network: string) {
    update(state => ({
        ...state,
        payment: { ...state.payment, status: 'creating', error: null, data: null },
    }));

    const pushRequest = send('user:click_create_invoice', { amount, network });

    if (!pushRequest) {
        update(state => ({
            ...state,
            payment: { ...state.payment, status: 'failed', error: 'Соединение с сервером потеряно' },
        }));
        return;
    }

    pushRequest.receive('error', (resp: any) => {
        update(state => ({
            ...state,
            payment: {
                ...state.payment,
                status: 'failed',
                error: resp.message || 'Не удалось создать инвойс',
            },
        }));
    });
}

export function resetPaymentState() {
    update(state => ({
        ...state,
        payment: { status: 'idle', data: null, error: null },
    }));
}
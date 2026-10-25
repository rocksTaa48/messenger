import { writable, get } from 'svelte/store';
import { Socket, Channel } from 'phoenix';
import type { AppState } from './types';
import { initialValue } from './types';
export const store = writable<AppState>(initialValue);
export const { subscribe, update } = store;

export function getState(): AppState {
    return get(store);
}

let socket: Socket | null = null;
let channel: Channel | null = null;

export function send(event: string, payload: object = {}) {
    if (channel) {
        return channel.push(event, payload);
    }
    console.warn(`Не могу отправить ${event}, канал еще не готов.`);
    return null;
}

export type ChannelListenerRegistrar = (channel: Channel) => void;

export function initSession(initData: string, registerListeners: ChannelListenerRegistrar) {
    if (socket) return;

    socket = new Socket('/socket', {
        params: { initData },
        reconnectAfterMs: (tries) => [1000, 2000, 5000, 10000, 30000][tries - 1] || 30000,
        timeout: 10000,
    });

    socket.onClose(() => update(state => ({ ...state, status: 'connecting' })));
    socket.onError(() => update(state => ({ ...state, status: 'error' })));
    socket.connect();

    channel = socket.channel('session:lobby', () => {
        return { nav_context: get(store).nav_context };
    });

    // Базовая синхронизация при подключении
    channel.on('sync', (serverState: Partial<Omit<AppState, 'nav_context' | 'nav_history' | 'status'>>) => {
        update(state => ({ ...state, ...serverState, status: 'connected' }));
    });

    channel.join()
        .receive('ok', (initialServerState: Partial<Omit<AppState, 'nav_context' | 'nav_history' | 'status'>>) => {
            console.log('Авторизация и восстановление сессии в Elixir успешны!');
            update(state => ({ ...state, ...initialServerState, status: 'connected' }));
        })
        .receive('error', () => update(state => ({ ...state, status: 'error' })));

    // Регистрируем слушателей всех доменов
    registerListeners(channel);
}
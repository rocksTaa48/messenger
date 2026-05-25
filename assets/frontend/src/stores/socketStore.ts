import { writable } from 'svelte/store';
import { Socket, Channel } from 'phoenix';

export const socketStatus = writable<'connecting' | 'connected' | 'error'>('connecting');
export const currentUser = writable<any>(null);
export const activeChannel = writable<Channel | null>(null);

let socket: Socket | null = null;

// Главная функция открытия сокета вызываем ее единожды на всю сессию
export function initSession(initData: string) {
    if (socket) return; // Защита от повторной инициализации

    // 1) Создаем сокет. Phoenix под капотом будет сам управлять переподключениями
    socket = new Socket('/socket', {
        params: { initData },
        // По дефолту Phoenix пытается переподключиться через 1, 2, 5, 10 с
        reconnectAfterMs: (tries) => [1000, 2000, 5000, 10000, 30000][tries - 1] || 30000,
        // Настройки таймаута самого коннекта
        timeout: 10000
    });

    // 2) Системные хуки сокета для отслеживания моргания сети
    socket.onOpen(() => {
        console.log('Труба сокета открыта или восстановилась!');
        // Если сокет переподключился сам, статус обновится на connected
        // Но реальные данные пользователя мы подтвердим только при входе в канал нижнего порядка
    });

    socket.onClose((e) => {
        console.log('Сокет закрылся (сеть упала или сервер лег):', e);
        socketStatus.set('connecting'); // Показываем юзеру плашку реконнекта
    });

    socket.onError(() => {
        socketStatus.set('error');
    });

    // Физический коннект
    socket.connect();

    // 3) Подключаемся к SessionChannel
    const channel = socket.channel('session:lobby', {}); // Заходим в лобби чатов так как это первая страница
    activeChannel.set(channel);

    // Функция входа запускается и при первом старте, и автоматически при переподключениях сокета
    joinChannel(channel);
}

function joinChannel(channel: Channel) {
    channel.join()
        .receive('ok', (response: { user: any }) => {
            socketStatus.set('connected');
            currentUser.set(response.user); // Записываем юзера глобально
            console.log('Авторизация успешна. Данные в сторе обновлены.');
        })
        .receive('error', () => {
            socketStatus.set('error');
        })
        .receive('timeout', () => {
            // При таймауте канала Phoenix сам сделает попытку подключения чуть позже
            console.log('Таймаут входа в канал, ожидаем авто-реконнект...');
        });
}

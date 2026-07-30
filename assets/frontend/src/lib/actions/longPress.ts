interface LongPressConfig {
    duration?: number;
    callback: (event: CustomEvent) => void;
}

export function longPress(node: HTMLElement, config: LongPressConfig) {
    const { duration = 500, callback } = config;
    let pressTimer: number;
    let isLongPress = false;
    let startX = 0;
    let startY = 0;

    function startPress(event: PointerEvent) {
        // Игнорируем среднюю и правую кнопки мыши, реагируем только на левую или тач
        if (event.button !== 0 && event.pointerType !== 'touch') return;

        isLongPress = false;
        startX = event.clientX;
        startY = event.clientY;

        pressTimer = window.setTimeout(() => {
            isLongPress = true;

            if (window.Telegram?.WebApp?.HapticFeedback) {
                window.Telegram.WebApp.HapticFeedback.impactOccurred('medium');
            }

            node.dispatchEvent(
                new CustomEvent('longpress', {
                    detail: { originalEvent: event },
                    bubbles: true
                })
            );

            callback(new CustomEvent('longpress', { detail: { originalEvent: event } }));
        }, duration);
    }

    function cancelPress(event?: PointerEvent) {
        if (pressTimer) {
            clearTimeout(pressTimer);
        }
        // Если это действительно удержание тычка пальца предотвращаем последующий клик
        if (isLongPress && event) {
            event.preventDefault();
            event.stopPropagation();
        }
    }

    function movePress(event: PointerEvent) {
        const moveX = Math.abs(event.clientX - startX);
        const moveY = Math.abs(event.clientY - startY);

        if (moveX > 10 || moveY > 10) {
            cancelPress(event);
        }
    }

    node.addEventListener('pointerdown', startPress);
    node.addEventListener('pointerup', cancelPress);
    node.addEventListener('pointerleave', cancelPress);
    node.addEventListener('pointercancel', cancelPress);
    node.addEventListener('pointermove', movePress);

    node.addEventListener('contextmenu', (e) => {
        if (isLongPress) e.preventDefault();
    });

    return {
        destroy() {
            node.removeEventListener('pointerdown', startPress);
            node.removeEventListener('pointerup', cancelPress);
            node.removeEventListener('pointerleave', cancelPress);
            node.removeEventListener('pointercancel', cancelPress);
            node.removeEventListener('pointermove', movePress);
        }
    };
}
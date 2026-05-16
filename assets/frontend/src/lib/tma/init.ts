import WebApp from "@twa-dev/sdk";
import { writable } from 'svelte/store';

export const tmaTheme = writable({
    isDark: false,
    ready: false,
});

export function initTMA() {
    if (typeof window === 'undefined') return;

    const tg = WebApp;

    const updateUI = () => {
        const isDark = tg.colorScheme === 'dark';

        // Добавляем класс для стандартных dark: классов Tailwind
        document.documentElement.classList.toggle('dark', isDark);

        // Красим системную шапку и фон контейнера в цвета темы
        tg.setHeaderColor('bg_color');
        tg.setBackgroundColor('bg_color');

        // Обновляем стор
        tmaTheme.set({ isDark, ready: true });
    };

    // Если мы в Telegram
    if (tg.initData) {
        tg.ready();
        tg.expand(); // Разворачиваем на всю высоту

        updateUI();

        // Следим за изменениями настроек пользователя
        tg.onEvent('themeChanged', updateUI);
    } else {
        // Если открыли просто в браузере
        const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
        const checkSystem = () => {
            document.documentElement.classList.toggle('dark', mediaQuery.matches);
            tmaTheme.set({ isDark: mediaQuery.matches, ready: true });
        };
        checkSystem();
        mediaQuery.addEventListener('change', checkSystem);
    }
}


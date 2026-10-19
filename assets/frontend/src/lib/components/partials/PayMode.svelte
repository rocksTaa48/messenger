<script lang="ts">
    import { createEventDispatcher } from 'svelte';
    import { X, CreditCard, Star, Wallet } from 'lucide-svelte';
    import { fade, slide } from 'svelte/transition';

    export let isOpen = false;

    const dispatch = createEventDispatcher();

    function close() {
        isOpen = false;
    }

    function selectMethod(method: 'card' | 'stars' | 'tonpay') {
        close();
        dispatch('pay', { method });
    }

    const paymentMethods = [
        {
            id: 'stars',
            title: 'Telegram Stars',
            subtitle: 'Оплата внутри Telegram (Карта/Apple Pay)',
            icon: Star,
            color: 'text-yellow-400',
            bg: 'bg-yellow-400/10',
            border: 'border-yellow-400/20'
        },
        {
            id: 'tonpay',
            title: 'TonPay',
            subtitle: 'Криптовалюта (USDT, TON)',
            icon: Wallet,
            color: 'text-[#2481cc]',
            bg: 'bg-[#2481cc]/10',
            border: 'border-[#2481cc]/20'
        },
        {
            id: 'card',
            title: 'Банковская карта',
            subtitle: 'Visa, Mastercard, МИР',
            icon: CreditCard,
            color: 'text-purple-400',
            bg: 'bg-purple-400/10',
            border: 'border-purple-400/20'
        }
    ];
</script>

{#if isOpen}
    <div class="fixed inset-0 z-[110] flex items-center justify-center p-5 pointer-events-auto">
        <!-- ЗАДНИЙ ФОН -->
        <div
                on:click={close}
                class="absolute inset-0 bg-black/60 backdrop-blur-sm"
                transition:fade={{ duration: 150 }}
        ></div>

        <!-- ОКНО -->
        <div
                class="relative z-10 w-full bg-[#1c1c1e] border border-white/10 rounded-[28px] shadow-2xl flex flex-col overflow-hidden overscroll-none"
                style="max-width: 400px;"
                transition:slide={{ y: 200, duration: 250 }}
        >
            <!-- ШАПКА -->
            <div class="flex justify-between items-center px-5 pt-5 pb-3 flex-shrink-0">
                <div class="min-w-0">
                    <h3 class="text-lg font-bold text-white">
                        Выберите способ оплаты
                    </h3>
                    <p class="text-xs text-gray-500 mt-0.5">Безопасная транзакция</p>
                </div>
                <button
                        on:click={close}
                        class="p-2 bg-white/5 rounded-full text-gray-400 hover:text-white transition-colors active:scale-95 flex-shrink-0 ml-3"
                >
                    <X size={18} />
                </button>
            </div>

            <!-- Разделитель -->
            <div class="h-px bg-white/5 mx-5"></div>

            <!-- СПИСОК МЕТОДОВ -->
            <div class="flex-1 min-h-0 overflow-y-auto scrollbar-none px-5 py-3 space-y-2">
                {#each paymentMethods as method}
                    <button
                            on:click={() => selectMethod(method.id)}
                            class="w-full flex items-center gap-4 p-3 rounded-2xl bg-white/5 border border-white/5 hover:bg-white/10 hover:border-white/10 transition-all active:scale-[0.98] text-left"
                    >
                        <!-- Иконка -->
                        <div class="w-11 h-11 rounded-xl flex items-center justify-center shrink-0 {method.bg} border {method.border}">
                            <svelte:component this={method.icon} size={20} class="{method.color}" />
                        </div>

                        <!-- Текст -->
                        <div class="flex-1 min-w-0">
                            <div class="text-[15px] font-semibold text-white truncate">
                                {method.title}
                            </div>
                            <div class="text-[12px] text-gray-500 truncate mt-0.5">
                                {method.subtitle}
                            </div>
                        </div>

                        <!-- Шеврон -->
                        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-gray-600 shrink-0">
                            <polyline points="9 18 15 12 9 6"></polyline>
                        </svg>
                    </button>
                {/each}
            </div>

            <!-- Разделитель -->
            <div class="h-px bg-white/5 mx-5"></div>

            <!-- ЗАМЕТКА -->
            <div class="px-5 pb-5 pt-3 flex-shrink-0">
                <p class="text-center text-[11px] text-gray-600">
                    Нажимая на способ оплаты, вы перейдете к защищенному чекауту
                </p>
            </div>
        </div>
    </div>
{/if}

<style>
    .scrollbar-none::-webkit-scrollbar { display: none; }
    .scrollbar-none { -ms-overflow-style: none; scrollbar-width: none; }
</style>
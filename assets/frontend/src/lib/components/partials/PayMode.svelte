<script lang="ts">
    import { createEventDispatcher } from 'svelte';
    import { X, CreditCard, Star, Wallet, ArrowLeft, Loader2, Copy, Check, CheckCircle, QrCode } from 'lucide-svelte';
    import { fade, slide } from 'svelte/transition';
    import QRCode from 'qrcode';

    import { appState } from '../../../stores/socketStore';

    export let isOpen = false;
    const dispatch = createEventDispatcher();

    type Step = 'methods' | 'amount' | 'network' | 'wallet' | 'success';
    let step: Step = 'methods';

    let amount: number = 10;
    let amountInput: string = '10';
    let selectedNetwork: string = '';
    let selectedWallet: WalletId | null = null;
    let qrDataUrl: string = '';
    let copied: boolean = false;
    let copiedAmount: boolean = false;
    let deepLinkUrl: string = '';
    let showQr: boolean = false;

    // ==========================================
    // РЕАКТИВНЫЕ ПЕРЕМЕННЫЕ ИЗ СТОРА
    // ==========================================
    $: paymentStatus = $appState.payment.status;
    $: paymentData = $appState.payment.data;
    $: paymentError = $appState.payment.error;

    $: if (paymentStatus === 'waiting' && paymentData && step === 'network') {
        step = 'wallet';
        const qrSource = paymentData.payment_url || paymentData.address;
        if (qrSource) generateQR(qrSource);
    }

    $: if (paymentStatus === 'completed' && step !== 'success') {
        step = 'success';
    }

    // ==========================================
    // КОНФИГ СЕТЕЙ
    // ==========================================
    type WalletId = 'metamask' | 'trust' | 'bitget';

    type NetworkConfig = {
        id: string;
        name: string;
        emoji: string;
        fee: string;
        gasToken: string;
        chainId: number | null;
        contract: string;
        decimals: number;
        scheme: 'evm' | 'tron';
        bitgetChain: string;
        trustCoinId: number;
        wallets: WalletId[];
    };

    const NETWORK_CONFIGS: Record<string, NetworkConfig> = {
        poly: {
            id: 'poly', name: 'Polygon', emoji: '🟣', fee: '~$0.01', gasToken: 'POL',
            chainId: 137,
            contract: '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
            decimals: 6, scheme: 'evm',
            bitgetChain: 'matic',
            trustCoinId: 60,
            wallets: ['metamask', 'trust', 'bitget'],
        },
        bep20: {
            id: 'bep20', name: 'BNB Smart Chain', emoji: '🟢', fee: '~$0.001', gasToken: 'BNB',
            chainId: 56,
            contract: '0x55d398326f99059fF775485246999027B3197955',
            decimals: 18, scheme: 'evm',
            bitgetChain: 'bnb',
            trustCoinId: 60,
            wallets: ['metamask', 'trust', 'bitget'],
        },
        arb: {
            id: 'arb', name: 'Arbitrum', emoji: '🔷', fee: '~$0.1', gasToken: 'ETH',
            chainId: 42161,
            contract: '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9',
            decimals: 6, scheme: 'evm',
            bitgetChain: 'arbitrum',
            trustCoinId: 60,
            wallets: ['metamask', 'trust', 'bitget'],
        },
        trc20: {
            id: 'trc20', name: 'Tron', emoji: '🔵', fee: '~$0.02', gasToken: 'TRX',
            chainId: null,
            contract: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
            decimals: 6, scheme: 'tron',
            bitgetChain: 'trx',
            trustCoinId: 195,
            wallets: ['trust', 'bitget'],
        },
    };

    const networks = Object.values(NETWORK_CONFIGS);

    const WALLET_LABELS: Record<WalletId, { name: string; emoji: string }> = {
        metamask: { name: 'MetaMask', emoji: '🦊' },
        trust:    { name: 'Trust',    emoji: '🛡️' },
        bitget:   { name: 'Bitget',   emoji: '🔵' },
    };

    // ==========================================
    // DEEPLINKS
    // ==========================================
    function toAtomicUnits(amt: number | string, decimals: number): string {
        const str = typeof amt === 'number' ? amt.toString() : String(amt);
        const parts = str.split('.');
        const whole = (parts[0] || '0').replace(/^0+(?=\d)/, '') || '0';
        const frac = (parts[1] || '').slice(0, decimals).padEnd(decimals, '0');
        return (whole + frac).replace(/^0+(?=\d)/, '') || '0';
    }

    function buildDeepLink(
        networkId: string,
        walletId: WalletId,
        recipient: string,
        amt: number | string
    ): string {
        const cfg = NETWORK_CONFIGS[networkId];
        if (!cfg || !recipient) return '';

        const atomic = toAtomicUnits(amt, cfg.decimals);
        const human  = typeof amt === 'number' ? amt.toString() : String(amt);

        switch (walletId) {
            case 'metamask':
                if (cfg.scheme !== 'evm') return '';
                return `https://link.metamask.io/send/${cfg.contract}@${cfg.chainId}/transfer?address=${recipient}&uint256=${atomic}`;

            case 'trust':
                return `https://link.trustwallet.com/send?asset=c${cfg.trustCoinId}_t${cfg.contract}&address=${recipient}&amount=${human}`;

            case 'bitget':
                return `https://bkcode.vip?action=send&chain=${cfg.bitgetChain}&contract=${cfg.contract}&to=${recipient}&amount=${human}`;

            default:
                return '';
        }
    }

    function openInWallet() {
        if (!deepLinkUrl) return;
        const tg = (window as any)?.Telegram?.WebApp;
        if (tg?.openLink) tg.openLink(deepLinkUrl);
        else window.open(deepLinkUrl, '_blank');
    }

    // ==========================================
    // ЛОКАЛЬНОЕ СОСТОЯНИЕ
    // ==========================================
    function close() {
        isOpen = false;
        appState.resetPaymentState();
        resetLocalState();
    }

    function resetLocalState() {
        step = 'methods';
        amount = 10;
        amountInput = '10';
        selectedNetwork = '';
        selectedWallet = null;
        qrDataUrl = '';
        deepLinkUrl = '';
        copied = false;
        copiedAmount = false;
        showQr = false;
    }

    function goBack() {
        if (step === 'amount') {
            step = 'methods';
        } else if (step === 'network') {
            step = 'amount';
            appState.resetPaymentState();
        } else if (step === 'wallet') {
            step = 'network';
            appState.resetPaymentState();
            selectedWallet = null;
            deepLinkUrl = '';
            qrDataUrl = '';
            showQr = false;
            copiedAmount = false;
        }
    }

    function selectMethod(method: 'stars' | 'tonpay' | 'clusterpay') {
        if (method === 'stars' || method === 'tonpay') {
            close();
            dispatch('pay', { method });
            return;
        }
        if (method === 'clusterpay') step = 'amount';
    }

    function handleAmountInput(e: Event) {
        const target = e.target as HTMLInputElement;
        const value = target.value.replace(/[^0-9]/g, '');
        amountInput = value;
        amount = value === '' ? 0 : Math.min(Math.max(parseInt(value), 5), 1000);
    }

    function setQuickAmount(value: number) {
        amount = value;
        amountInput = value.toString();
    }

    function proceedToNetwork() {
        if (amount < 5 || amount > 1000) return;
        step = 'network';
    }

    async function generateQR(content: string) {
        qrDataUrl = await QRCode.toDataURL(content, {
            width: 280,
            margin: 2,
            color: { dark: '#a855f7', light: '#ffffff' }
        });
    }

    function selectNetwork(network: string) {
        selectedNetwork = network;
        selectedWallet = null;
        appState.createPaymentInvoice(amount, network);
    }

    async function handleWalletTap(walletId: WalletId) {
        if (!paymentData?.address || !selectedNetwork) return;

        selectedWallet = walletId;
        const amt = paymentData.exact_amount ?? amount;
        deepLinkUrl = buildDeepLink(selectedNetwork, walletId, paymentData.address, amt);

        if (deepLinkUrl) {
            await generateQR(deepLinkUrl);
            openInWallet();
        }
    }

    function toggleQr() {
        showQr = !showQr;
    }

    async function copyAddress() {
        if (paymentData?.address) {
            await navigator.clipboard.writeText(paymentData.address);
            copied = true;
            setTimeout(() => copied = false, 2000);
        }
    }

    async function copyAmount() {
        const amt = paymentData?.exact_amount ?? amount;
        if (amt != null) {
            await navigator.clipboard.writeText(String(amt));
            copiedAmount = true;
            setTimeout(() => copiedAmount = false, 2000);
        }
    }

    // ==========================================
    // МЕТОДЫ ОПЛАТЫ
    // ==========================================
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
            id: 'clusterpay',
            title: 'Криптовалюта (USDT)',
            subtitle: 'Polygon, BSC, Arbitrum, Tron',
            icon: CreditCard,
            color: 'text-purple-400',
            bg: 'bg-purple-400/10',
            border: 'border-purple-400/20'
        }
    ];
</script>

{#if isOpen}
    <div class="fixed inset-0 z-[110] flex items-center justify-center p-5 pointer-events-auto">
        <div
                class="absolute inset-0 bg-black/60 backdrop-blur-sm"
                transition:fade={{ duration: 150 }}
        ></div>

        <div
                class="relative z-10 w-full bg-[#1c1c1e] border border-white/10 rounded-[28px] shadow-2xl flex flex-col overflow-hidden overscroll-none"
                style="max-width: 400px; max-height: 85vh;"
                transition:slide={{ y: 200, duration: 250 }}
        >
            <!-- Header -->
            <div class="flex items-center px-5 pt-5 pb-3 flex-shrink-0">
                {#if step !== 'methods' && step !== 'success'}
                    <button
                            on:click={goBack}
                            class="p-2 -ml-2 bg-white/5 rounded-full text-gray-400 hover:text-white transition-colors active:scale-95"
                    >
                        <ArrowLeft size={18} />
                    </button>
                {/if}

                <div class="flex-1 min-w-0 ml-2">
                    <h3 class="text-lg font-bold text-white">
                        {#if step === 'methods'}Выберите способ оплаты
                        {:else if step === 'amount'}Сумма пополнения
                        {:else if step === 'network'}Выберите сеть
                        {:else if step === 'wallet'}Оплата USDT
                        {:else if step === 'success'}Успешно!
                        {/if}
                    </h3>
                    {#if step === 'methods'}
                        <p class="text-xs text-gray-500 mt-0.5">Безопасная транзакция</p>
                    {:else if step === 'wallet'}
                        <p class="text-xs text-gray-500 mt-0.5">
                            {NETWORK_CONFIGS[selectedNetwork]?.name ?? ''} · {paymentData?.exact_amount ?? amount} USDT
                        </p>
                    {/if}
                </div>

                <button
                        on:click={close}
                        aria-label="Закрыть"
                        class="p-2 bg-white/5 rounded-full text-gray-400 hover:text-white transition-colors active:scale-95 flex-shrink-0 ml-3"
                >
                    <X size={18} />
                </button>
            </div>

            <div class="h-px bg-white/5 mx-5"></div>

            <!-- Content -->
            <div class="flex-1 min-h-0 overflow-y-auto scrollbar-none px-5 py-3">

                <!-- STEP 1: Methods -->
                {#if step === 'methods'}
                    <div class="space-y-2">
                        {#each paymentMethods as method}
                            <button
                                    on:click={() => selectMethod(method.id)}
                                    class="w-full flex items-center gap-4 p-3 rounded-2xl bg-white/5 border border-white/5 hover:bg-white/10 hover:border-white/10 transition-all active:scale-[0.98] text-left"
                            >
                                <div class="w-11 h-11 rounded-xl flex items-center justify-center shrink-0 {method.bg} border {method.border}">
                                    <svelte:component this={method.icon} size={20} class="{method.color}" />
                                </div>
                                <div class="flex-1 min-w-0">
                                    <div class="text-[15px] font-semibold text-white truncate">{method.title}</div>
                                    <div class="text-[12px] text-gray-500 truncate mt-0.5">{method.subtitle}</div>
                                </div>
                                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="text-gray-600 shrink-0">
                                    <polyline points="9 18 15 12 9 6"></polyline>
                                </svg>
                            </button>
                        {/each}
                    </div>

                    <!-- STEP 2: Amount -->
                {:else if step === 'amount'}
                    <div class="space-y-4">
                        <div>
                            <label class="text-sm text-gray-400 mb-2 block">Сумма (USDT)</label>
                            <div class="relative">
                                <input
                                        type="text"
                                        inputmode="numeric"
                                        value={amountInput}
                                        on:input={handleAmountInput}
                                        class="w-full bg-white/5 border border-white/10 rounded-2xl px-4 py-3 text-2xl font-bold text-white focus:outline-none focus:border-purple-400/50 transition"
                                        placeholder="10"
                                />
                                <span class="absolute right-4 top-1/2 -translate-y-1/2 text-gray-500 text-sm">USDT</span>
                            </div>
                            <p class="text-xs text-gray-500 mt-2">От 5 до 1000 USDT</p>
                        </div>

                        <div class="grid grid-cols-3 gap-2">
                            {#each [25, 50, 100] as value}
                                <button
                                        on:click={() => setQuickAmount(value)}
                                        class="py-2 bg-white/5 border border-white/10 rounded-xl text-sm font-semibold text-white hover:bg-white/10 transition active:scale-95"
                                >
                                    {value} USDT
                                </button>
                            {/each}
                        </div>

                        <button
                                on:click={proceedToNetwork}
                                disabled={amount < 5 || amount > 1000}
                                class="w-full py-3 bg-purple-500 hover:bg-purple-600 disabled:bg-gray-600 disabled:opacity-50 rounded-2xl text-white font-semibold transition active:scale-[0.98]"
                        >
                            Пополнить
                        </button>
                    </div>

                    <!-- STEP 3: Network -->
                {:else if step === 'network'}
                    <div class="space-y-2">
                        {#if paymentStatus === 'creating'}
                            <div class="flex flex-col items-center justify-center py-10">
                                <Loader2 class="animate-spin text-purple-400 mb-3" size={32} />
                                <p class="text-sm text-gray-400">Создаем инвойс...</p>
                            </div>
                        {:else if paymentStatus === 'failed'}
                            <div class="p-4 bg-red-500/10 border border-red-500/20 rounded-2xl text-center">
                                <p class="text-sm text-red-400 mb-3">{paymentError || 'Ошибка создания инвойса'}</p>
                                <button
                                        on:click={() => appState.resetPaymentState()}
                                        class="px-4 py-2 bg-red-500/20 hover:bg-red-500/30 rounded-xl text-sm text-white transition"
                                >
                                    Попробовать снова
                                </button>
                            </div>
                        {:else}
                            {#each networks as network}
                                <button
                                        on:click={() => selectNetwork(network.id)}
                                        class="w-full flex items-center gap-4 p-3 rounded-2xl bg-white/5 border border-white/5 hover:bg-white/10 hover:border-white/10 transition-all active:scale-[0.98] text-left"
                                >
                                    <div class="w-11 h-11 rounded-xl flex items-center justify-center shrink-0 bg-white/5 border border-white/10 text-2xl">
                                        {network.emoji}
                                    </div>
                                    <div class="flex-1 min-w-0">
                                        <div class="text-[15px] font-semibold text-white truncate">{network.name}</div>
                                        <div class="text-[12px] text-gray-500 truncate mt-0.5">Комиссия {network.fee}</div>
                                    </div>
                                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="text-gray-600 shrink-0">
                                        <polyline points="9 18 15 12 9 6"></polyline>
                                    </svg>
                                </button>
                            {/each}
                        {/if}
                    </div>

                    <!-- STEP 4: Payment -->
                {:else if step === 'wallet'}
                    {@const cfg = NETWORK_CONFIGS[selectedNetwork]}
                    <div class="space-y-3">
                        {#if cfg}
                            <div>
                                <p class="text-xs text-gray-400 mb-2">Открыть в кошельке</p>
                                <div class="grid grid-cols-3 gap-2">
                                    {#each cfg.wallets as walletId}
                                        {@const w = WALLET_LABELS[walletId]}
                                        <button
                                                on:click={() => handleWalletTap(walletId)}
                                                class="flex flex-col items-center justify-center gap-1.5 py-3 rounded-2xl border transition-all active:scale-95
                                                    {selectedWallet === walletId
                                                        ? 'bg-purple-500/15 border-purple-400/40'
                                                        : 'bg-white/5 border-white/5 hover:bg-white/10 hover:border-white/10'}"
                                        >
                                            <span class="text-2xl leading-none">{w.emoji}</span>
                                            <span class="text-[11px] text-white font-medium truncate w-full text-center px-1">{w.name}</span>
                                        </button>
                                    {/each}
                                </div>
                            </div>

                            <button
                                    on:click={copyAmount}
                                    class="w-full bg-white/5 border border-white/10 rounded-2xl p-3 text-left hover:bg-white/10 transition active:scale-[0.98]"
                            >
                                <p class="text-xs text-gray-400 mb-1">Сумма к отправке · нажмите, чтобы скопировать</p>
                                <div class="flex items-center justify-between">
                                    <p class="text-xl font-bold text-white">{paymentData?.exact_amount ?? amount} USDT</p>
                                    {#if copiedAmount}
                                        <Check size={18} class="text-green-400" />
                                    {:else}
                                        <Copy size={18} class="text-gray-500" />
                                    {/if}
                                </div>
                            </button>

                            <div class="bg-white/5 border border-white/10 rounded-2xl p-3">
                                <p class="text-xs text-gray-400 mb-1">Адрес кошелька</p>
                                <div class="flex items-center gap-2">
                                    <p class="text-sm text-white font-mono truncate flex-1">{paymentData?.address || '...'}</p>
                                    <button
                                            on:click={copyAddress}
                                            class="p-2 bg-white/10 rounded-lg hover:bg-white/20 transition active:scale-95 shrink-0"
                                    >
                                        {#if copied}
                                            <Check size={16} class="text-green-400" />
                                        {:else}
                                            <Copy size={16} class="text-gray-400" />
                                        {/if}
                                    </button>
                                </div>
                            </div>

                            <button
                                    on:click={toggleQr}
                                    class="w-full py-2.5 bg-white/5 border border-white/10 rounded-2xl text-sm text-white font-medium hover:bg-white/10 transition active:scale-[0.98] flex items-center justify-center gap-2"
                            >
                                <QrCode size={16} />
                                {showQr ? 'Скрыть QR-код' : 'Показать QR'}
                            </button>

                            {#if showQr}
                                <div class="bg-[#2a2a2c] rounded-2xl p-4 border border-white/10 flex justify-center">
                                    {#if qrDataUrl}
                                        <img src={qrDataUrl} alt="QR Code" class="w-[240px] h-[240px] rounded-lg" />
                                    {:else}
                                        <Loader2 class="animate-spin text-purple-400" size={40} />
                                    {/if}
                                </div>
                                <p class="text-[11px] text-gray-500 -mt-1 text-center">
                                    {selectedWallet
                                        ? 'QR содержит deeplink выбранного кошелька'
                                        : 'Отсканируйте камерой кошелька'}
                                </p>
                            {/if}

                            <div class="bg-yellow-500/10 border border-yellow-500/20 rounded-xl p-3">
                                <p class="text-xs text-yellow-400">
                                    ⚠️ Для газа в сети {cfg.name} нужен {cfg.gasToken}. Без него транзакция не пройдёт.
                                </p>
                            </div>
                        {/if}

                        {#if paymentStatus === 'completed'}
                            <div class="flex items-center justify-center gap-1.5 text-green-400 text-sm pt-1">
                                <CheckCircle size={16} />
                                Оплата получена
                            </div>
                        {:else if paymentStatus === 'waiting'}
                            <div class="flex items-center justify-center gap-2 text-gray-500 text-xs pt-1">
                                <Loader2 size={12} class="animate-spin" />
                                Ожидаем поступление средств...
                            </div>
                        {/if}
                    </div>

                    <!-- STEP 5: Success -->
                {:else if step === 'success'}
                    <div class="flex flex-col items-center justify-center py-10 text-center">
                        <div class="w-16 h-16 bg-green-500/20 rounded-full flex items-center justify-center mb-4">
                            <CheckCircle size={32} class="text-green-400" />
                        </div>
                        <h3 class="text-xl font-bold text-white mb-2">Оплата прошла!</h3>
                        <p class="text-sm text-gray-400 mb-6">Средства успешно зачислены на ваш баланс.</p>
                        <button
                                on:click={close}
                                class="w-full py-3 bg-white/10 hover:bg-white/20 rounded-2xl text-white font-semibold transition active:scale-[0.98]"
                        >
                            Закрыть
                        </button>
                    </div>
                {/if}
            </div>

            {#if step === 'methods'}
                <div class="h-px bg-white/5 mx-5"></div>
                <div class="px-5 pb-5 pt-3 flex-shrink-0">
                    <p class="text-center text-[11px] text-gray-600">
                        Нажимая на способ оплаты, вы перейдете к защищенному чекауту
                    </p>
                </div>
            {/if}
        </div>
    </div>
{/if}

<style>
    .scrollbar-none::-webkit-scrollbar { display: none; }
    .scrollbar-none { -ms-overflow-style: none; scrollbar-width: none; }
</style>
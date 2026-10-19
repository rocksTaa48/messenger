import { createTonPay } from "@ton-pay/ui/vanilla";
import { createTonPayTransfer, TON } from "@ton-pay/api";

const MANIFEST_URL = "https://locorum.serveousercontent.com/tonconnect-manifest.json";
const RECIPIENT_ADDR = "0Q...твой-тестовый-адрес..."; // ← ОБЯЗАТЕЛЬНО поменяй

console.log('[tonpay] module loaded');

export const tonPayUI = createTonPay({
    manifestUrl: MANIFEST_URL,
});

console.log('[tonpay] createTonPay result:', tonPayUI);

export async function initiateTonPay(amount: number, asset: string = "TON") {
    console.log('[tonpay] initiateTonPay called:', { amount, asset });
    console.log('[tonpay] tonPayUI:', tonPayUI);
    console.log('[tonpay] tonPayUI.pay type:', typeof tonPayUI?.pay);

    try {
        const result = await tonPayUI.pay(async (senderAddr: string) => {
            console.log('[tonpay] factory called, senderAddr:', senderAddr);

            const transfer = await createTonPayTransfer(
                {
                    amount,
                    asset,
                    recipientAddr: RECIPIENT_ADDR,
                    senderAddr,
                },
                { chain: "testnet" }
            );

            console.log('[tonpay] transfer built:', transfer);
            return transfer;
        });

        console.log('[tonpay] ✅ result:', result);
        return result;
    } catch (error) {
        console.error('[tonpay] ❌ caught:', error);
        console.error('[tonpay] error type:', typeof error);
        if (error instanceof Error) {
            console.error('[tonpay] message:', error.message);
            console.error('[tonpay] stack:', error.stack);
        } else {
            console.error('[tonpay] raw:', JSON.stringify(error, null, 2));
        }
        throw error;
    }
}
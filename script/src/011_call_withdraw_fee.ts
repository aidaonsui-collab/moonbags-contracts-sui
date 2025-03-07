import { TransactionBlock } from "@mysten/sui.js/transactions";
import readline from "readline";
import { packageAddress, processResult, stakeConfigAddress, cetusGlobalConfigId, configAddress } from "./utils";

const withdrawFee = async (tokenAddress: string, platformTokenAddress: string) => {
    try {
        console.log(
            `Withdrawing fee for ${tokenAddress.split("::").at(-1)}`
        );

        const tx = new TransactionBlock();
        tx.setGasBudget(30000000);

        const bondingCurveConfig = tx.object(configAddress);
        const stakeConfig = tx.object(stakeConfigAddress);
        const cetusConfig = tx.object(cetusGlobalConfigId);
        const cetusPool = tx.pure([]);
        const clock = tx.object("0x6");

        tx.moveCall({
            target: `${packageAddress}::moonbags::withdraw_fee`,
            typeArguments: [tokenAddress, platformTokenAddress],
            arguments: [bondingCurveConfig, stakeConfig, cetusConfig, cetusPool, clock],
        });

        await processResult(tx);
    } catch (e) {
        console.error("Error withdrawing fee:", e);
    }
};

const run = async () => {
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
    });

    rl.question("Enter the token address (e.g., 0x123::token::TOKEN): ", (tokenAddress) => {
        rl.question("Enter the platform token address (e.g., 0x123::platform_token::TOKEN): ", (platformTokenAddress) => {
            withdrawFee(tokenAddress, platformTokenAddress);
            rl.close();
        });
    });
};

run();

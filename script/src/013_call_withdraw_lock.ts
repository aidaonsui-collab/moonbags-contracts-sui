import { TransactionBlock } from "@mysten/sui.js/transactions";
import readline from "readline";
import { packageAddress, processResult, lockConfigAddress } from "./utils";

const withdrawFromLock = async (tokenAddress: string, lockContractId: string) => {
    try {
        console.log(
            `Withdrawing locked ${tokenAddress.split("::").at(-1)} from lock contract ${lockContractId}`
        );

        const tx = new TransactionBlock();
        tx.setGasBudget(30000000);

        // Get the lock contract reference
        const lockContract = tx.object(lockContractId);
        const lockConfig = tx.object(lockConfigAddress);
        const clock = tx.object("0x6"); // System Clock object

        tx.moveCall({
            target: `${packageAddress}::moonbags_token_lock::withdraw`,
            typeArguments: [tokenAddress],
            arguments: [
                lockConfig,
                lockContract,
                clock
            ],
        });

        await processResult(tx);
    } catch (e) {
        console.error("Error withdrawing from token lock:", e);
    }
};

const run = async () => {
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
    });

    rl.question("Enter the token address (e.g., 0x123::token::TOKEN): ", (tokenAddress) => {
        rl.question("Enter the lock contract ID: ", (lockContractId) => {
            withdrawFromLock(tokenAddress, lockContractId);
            rl.close();
        });
    });
};

run();
import { TransactionBlock } from "@mysten/sui.js/transactions";
import readline from "readline";
import { packageAddress, processResult, stakeConfigAddress, configAddress } from "./utils";

const withdrawFeeTurbos = async (tokenAddress: string) => {
    try {
        console.log(
            `Withdrawing Turbos fee for ${tokenAddress.split("::").at(-1)}`
        );

        const tx = new TransactionBlock();
        tx.setGasBudget(30000000);

        // Hardcoded configuration - update these with your actual values
        const platformTokenAddress = "0x2::sui::SUI"; // Platform token (usually SUI)
        const feeTypeAddress = "0x91bfbc386a41afcfd9b2533058d7e915a1d3829089cc268ff4333d54d6339ca1::fee_stable::Fee"; // Turbos fee type
        const turbosPoolId = "0x123"; // TODO: Replace with actual Turbos pool ID
        const turbosPositionsId = "0x456"; // TODO: Replace with actual Turbos positions ID  
        const turbosVersionedId = "0x789"; // TODO: Replace with actual Turbos versioned ID
        const maxAmountTokenA = 1000000000; // 1 billion units (adjust as needed)
        const maxAmountTokenB = 1000000000; // 1 billion units (adjust as needed)
        const deadline = Date.now() + 3600000; // 1 hour from now

        // Required objects for the function call
        const bondingCurveConfig = tx.object(configAddress);
        const stakeConfig = tx.object(stakeConfigAddress);
        const turbosPool = tx.object(turbosPoolId);
        const turbosPositions = tx.object(turbosPositionsId);
        const clock = tx.object("0x6"); // Standard clock object
        const versioned = tx.object(turbosVersionedId);

        tx.moveCall({
            target: `${packageAddress}::moonbags::withdraw_fee_turbos`,
            typeArguments: [tokenAddress, platformTokenAddress, feeTypeAddress],
            arguments: [
                bondingCurveConfig,
                stakeConfig,
                turbosPool,
                turbosPositions,
                tx.pure(maxAmountTokenA),
                tx.pure(maxAmountTokenB),
                tx.pure(deadline),
                clock,
                versioned,
            ],
        });

        await processResult(tx);
    } catch (e) {
        console.error("Error withdrawing Turbos fee:", e);
    }
};

const run = async () => {
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
    });

    rl.question("Enter the token address (e.g., 0x123::token::TOKEN): ", (tokenAddress) => {
        withdrawFeeTurbos(tokenAddress);
        rl.close();
    });
};

run();
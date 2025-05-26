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

        const platformTokenAddress = "0x6d4f59540a0525077ce3794e9982a36bf8d894fd457c55e48be0538ebff975c8::shro::SHRO";
        const feeTypeAddress = "0x3526c88f5304c78fb93ed1cc1961d56b8517108550c9938b8a5a0e6c90fbe2a5::fee10000bps::FEE10000BPS";
        const turbosPoolId = "0xd7230deb4eb4a4c868f54057576e69435ec65722b04139c50b072ef08dae9e34";
        const turbosPositionsId = "0x8d916e3eaa3a5ce2949a4d845ec8082f7d46768ffd4c15984c32b3c5f4cabf22";
        const turbosVersionedId = "0x0ec5aedfc4a3a99aebd8a54b6b39df34b7696ada57008c35f69d6b4bb346b5c4";
        const maxAmountTokenA = BigInt("18446744073709551615");  // Max u64 value (2^64 - 1)
        const maxAmountTokenB = BigInt("18446744073709551615");  // Max u64 value (2^64 - 1)
        const deadline = Date.now() + 3600000;

        const bondingCurveConfig = tx.object(configAddress);
        const stakeConfig = tx.object(stakeConfigAddress);
        const turbosPool = tx.object(turbosPoolId);
        const turbosPositions = tx.object(turbosPositionsId);
        const clock = tx.object("0x6");
        const versioned = tx.object(turbosVersionedId);

        tx.moveCall({
            target: `${packageAddress}::moonbags::withdraw_fee_turbos_sui_after`,
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
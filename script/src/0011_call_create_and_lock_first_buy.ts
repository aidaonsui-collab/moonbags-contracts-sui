import { TransactionBlock } from "@mysten/sui.js/transactions";
import { 
    configAddress, 
    packageAddress, 
    processResult, 
    stakeConfigAddress, 
    lockConfigAddress, 
    client,
    cetusBurnManagerId,
    cetusPoolsId,
    cetusGlobalConfigId
} from "./utils";
import readline from "readline";

const createPool = async (tokenAddress: string, treasuryCapObjId: string, suiAmountStr: string, tokenAmount: number) => {
    try {
        console.log("Creating Pool...");
        const suiAmount = parseFloat(suiAmountStr) * 1e9; // Convert to nano SUI

        const tx = new TransactionBlock();
        tx.setGasBudget(1000000000);

        // Fetch required objects
        const configuration = tx.object(configAddress);
        const stakeConfig = tx.object(stakeConfigAddress);
        const lockConfig = tx.object(lockConfigAddress);
        const treasuryCap = tx.object(treasuryCapObjId);
        const clock = tx.object("0x6"); // Clock object

        // Split coins for buying
        const [coinSui] = tx.splitCoins(tx.gas, [tx.pure(suiAmount)]);

        const tokenMetadataObj = await client.getCoinMetadata({ coinType: tokenAddress });
        const suiMetadataObj = await client.getCoinMetadata({ coinType: "0x2::sui::SUI" });

        // Move call to create the pool and do first buy
        tx.moveCall({
            target: `${packageAddress}::moonbags::create_and_lock_first_buy`,
            typeArguments: [tokenAddress],
            arguments: [
                configuration,
                stakeConfig,
                lockConfig,
                treasuryCap,
                tx.pure(1), // bonding_dex
                coinSui,    // coin_sui
                tx.pure(tokenAmount), // Amount of tokens to receive
                tx.pure([2_000_000_000]), // amount_out (max_supply)
                tx.pure(3_600_000),    // locking_time_ms
                clock,
                tx.pure("name"),     // name
                tx.pure("symbol"),   // symbol
                tx.pure("uri"),      // uri
                tx.pure("description"), // description
                tx.pure("twitter"),  // twitter
                tx.pure("telegram"), // telegram
                tx.pure("website"),  // website
                tx.object(cetusBurnManagerId), // cetus_burn_manager
                tx.object(cetusPoolsId),       // cetus_pools
                tx.object(cetusGlobalConfigId), // cetus_global_config
                tx.object(suiMetadataObj?.id!), // metadata_sui
                tx.object(tokenMetadataObj?.id!), // metadata_token
            ],
        });

        await processResult(tx);
    } catch (e) {
        console.error("Error creating pool:", e);
    }
};

const run = async () => {
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
    });

    rl.question("Enter token address: ", async (token) => {
        rl.question("Enter treasury cap: ", async (treasuryCap) => {
            rl.question("Enter SUI amount to spend for first buy: ", async (suiAmount) => {
                rl.question("Enter amount of tokens to receive: ", async (tokenAmountStr) => {
                    await createPool(token, treasuryCap, suiAmount, parseInt(tokenAmountStr));
                    rl.close();
                });
            });
        });
    });
};

run();

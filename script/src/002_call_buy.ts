import { TransactionBlock } from "@mysten/sui.js/transactions";
import readline from "readline";
import {
  cetusGlobalConfigId,
  cetusPoolsId,
  client,
  configAddress,
  packageAddress,
  processResult,
} from "./utils";

const buy = async (tokenAddress: string, amount: number) => {
  try {
    const tx = new TransactionBlock();
    tx.setGasBudget(100000000);

    // Get the configuration object
    const configuration = tx.object(configAddress);

    // Split coins from gas for the purchase
    const [coinSui] = tx.splitCoins(tx.gas, [tx.pure(amount * 1e9)]);

    const [tokenMetadataObj, suiMetadataObj] = await Promise.all([
      client.getCoinMetadata({ coinType: tokenAddress }),
      client.getCoinMetadata({ coinType: "0x2::sui::SUI" }),
    ]);

    tx.moveCall({
      target: `${packageAddress}::moonbags::buy_exact_in`,
      typeArguments: [tokenAddress],
      arguments: [
        configuration,
        coinSui,
        tx.object(cetusPoolsId),
        tx.object(cetusGlobalConfigId),
        tx.object(suiMetadataObj?.id!),
        tx.object(tokenMetadataObj?.id!),
        tx.object("0x6"), // Clock object
      ],
    });

    await processResult(tx);
  } catch (e) {
    console.error("Error buying tokens:", e);
  }
};

const run = async () => {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  rl.question(
    "Enter token address (e.g., 0x123::coin::COIN): ",
    (tokenAddress) => {
      rl.question("Enter amount of SUI to spend: ", (amountStr) => {
        buy(tokenAddress, parseInt(amountStr));
        rl.close();
      });
    }
  );
};

run();

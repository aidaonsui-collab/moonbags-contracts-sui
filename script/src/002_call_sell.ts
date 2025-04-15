import { TransactionBlock } from "@mysten/sui.js/transactions";
import readline from "readline";
import {
  client,
  configAddress,
  packageAddress,
  processResult,
} from "./utils";

const sell = async (tokenAddress: string, coinObjectId: string, minSuiAmount: number) => {
  try {
    console.log(`Selling token object ${coinObjectId} of type ${tokenAddress.split("::").at(-1)}...`);
    
    const tx = new TransactionBlock();
    tx.setGasBudget(100000000);

    // Get the configuration object
    const configuration = tx.object(configAddress);

    // Use the coin object directly
    const coinToSell = tx.object(coinObjectId);

    // Call the sell function
    tx.moveCall({
      target: `${packageAddress}::moonbags::sell`,
      typeArguments: [tokenAddress],
      arguments: [
        configuration,
        coinToSell,
        tx.pure(minSuiAmount), // Minimum amount of SUI to receive
        tx.object("0x6"), // Clock object
      ],
    });

    await processResult(tx);
  } catch (e) {
    console.error("Error selling tokens:", e);
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
      rl.question("Enter coin object ID to sell: ", (coinObjectId) => {
        rl.question("Enter minimum SUI amount to receive (slippage protection): ", (minSuiAmountStr) => {
          sell(tokenAddress, coinObjectId, parseInt(minSuiAmountStr));
          rl.close();
        });
      });
    }
  );
};

run();
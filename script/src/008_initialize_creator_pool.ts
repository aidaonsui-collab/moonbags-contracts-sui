import { TransactionBlock } from "@mysten/sui.js/transactions";
import readline from "readline";
import { stakeConfigAddress, packageAddress, processResult } from "./utils";

const initializeCreatorPool = async (
  tokenAddress: string,
  creatorAddress: string
) => {
  try {
    console.log(
      `Initializing ${tokenAddress
        .split("::")
        .at(-1)} creator pool for address: ${creatorAddress}`
    );

    const tx = new TransactionBlock();
    tx.setGasBudget(30000000);

    const configuration = tx.object(stakeConfigAddress);
    const clock = tx.object("0x6");

    tx.moveCall({
      target: `${packageAddress}::moonbags_stake::initialize_creator_pool`,
      typeArguments: [tokenAddress],
      arguments: [configuration, tx.pure(creatorAddress), clock],
    });

    await processResult(tx);
  } catch (e) {
    console.error("Error initializing creator pool:", e);
  }
};

const run = async () => {
  try {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });

    rl.question(
      "Enter the creator address (e.g., 0x123...): ",
      (creatorAddress) => {
        rl.question(
          "Enter the token address (e.g., 0x123::token::TOKEN): ",
          (tokenAddress) => {
            initializeCreatorPool(tokenAddress, creatorAddress);
            rl.close();
          }
        );
      }
    );
  } catch (e) {
    console.error("Error initializing script:", e);
  }
};

run();

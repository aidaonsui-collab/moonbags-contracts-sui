import { TransactionBlock } from "@mysten/sui.js/transactions";
import readline from "readline";
import { config_address, package_address, processResult } from "./utils";

const initializeCreatorPool = async (creatorAddress: string) => {
  try {
    console.log(`Initializing creator pool for address: ${creatorAddress}`);

    const tx = new TransactionBlock();
    tx.setGasBudget(30000000);

    const configuration = tx.object(config_address);
    const clock = tx.object("0x6");

    tx.moveCall({
      target: `${package_address}::moonbags_stake::initialize_creator_pool`,
      typeArguments: [],
      arguments: [configuration, tx.pure(creatorAddress), clock],
    });

    console.log("Processing initialize creator pool transaction...");
    await processResult(tx);
    console.log("Successfully initialized creator pool!");
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
        initializeCreatorPool(creatorAddress);
        rl.close();
      }
    );
  } catch (e) {
    console.error("Error initializing script:", e);
  }
};

run();

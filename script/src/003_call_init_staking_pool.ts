import { TransactionBlock } from "@mysten/sui.js/transactions";
import { config_address, package_address, processResult } from "./utils";
import readline from "readline";

const createStakingPool = async (token: string) => {
  try {
    console.log("Creating Staking Pool...");

    const tx = new TransactionBlock();
    tx.setGasBudget(100000000);

    // Fetch required objects
    const configuration = tx.object(config_address);
    const clock = tx.object("0x6"); // Clock object

    // Move call to create the pool
    tx.moveCall({
      target: `${package_address}::moonbags_stake::initialize_staking_pool`,
      typeArguments: [token],
      arguments: [configuration, clock],
    });

    await processResult(tx);
  } catch (e) {
    console.log(e);
  }
};

const run = async () => {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  rl.question("Enter the token address: ", async (token) => {
    await createStakingPool(token);
    rl.close();
  });
};

run();

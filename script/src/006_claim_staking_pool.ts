import { TransactionBlock } from "@mysten/sui.js/transactions";
import readline from "readline";
import { config_address, package_address, processResult } from "./utils";

const claimStakingPool = async (stakingToken: string) => {
  try {
    console.log(
      `Claiming rewards from ${stakingToken.split("::").at(-1)} staking pool...`
    );

    const tx = new TransactionBlock();
    tx.setGasBudget(30000000);

    const configuration = tx.object(config_address);
    const clock = tx.object("0x6");

    const [claimedAmount] = tx.moveCall({
      target: `${package_address}::moonbags_stake::claim_staking_pool`,
      typeArguments: [stakingToken],
      arguments: [configuration, clock],
    });

    await processResult(tx);
    console.log("Successfully claimed rewards from staking pool!");
  } catch (e) {
    console.error("Error claiming from staking pool:", e);
  }
};

const run = async () => {
  try {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });

    rl.question(
      "Enter the staking token type (e.g., 0x123::token::TOKEN): ",
      (token) => {
        claimStakingPool(token);
        rl.close();
      }
    );
  } catch (e) {
    console.error("Error initializing script:", e);
  }
};

run();

import { TransactionBlock } from "@mysten/sui.js/transactions";
import readline from "readline";
import { packageAddress, processResult, stakeConfigAddress } from "./utils";

const claimCreatorPool = async (tokenAddress: string) => {
  try {
    console.log(
      `Claiming rewards from ${tokenAddress.split("::").at(-1)} creator pool`
    );

    const tx = new TransactionBlock();
    tx.setGasBudget(30000000);

    const configuration = tx.object(stakeConfigAddress);
    const clock = tx.object("0x6");

    tx.moveCall({
      target: `${packageAddress}::moonbags_stake::claim_creator_pool`,
      typeArguments: [tokenAddress],
      arguments: [configuration, clock],
    });

    await processResult(tx);
  } catch (e) {
    console.error("Error claiming from creator pool:", e);
  }
};

const run = async () => {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  rl.question(
    "Enter the token address (e.g., 0x123::token::TOKEN): ",
    (tokenAddress) => {
      claimCreatorPool(tokenAddress);
      rl.close();
    }
  );
};

run();

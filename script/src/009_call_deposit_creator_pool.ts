import { TransactionBlock } from "@mysten/sui.js/transactions";
import readline from "readline";
import { stakeConfigAddress, packageAddress, processResult } from "./utils";

const depositCreatorPool = async (
  creatorAddress: string,
  rewardAmount: number
) => {
  try {
    console.log(
      `Depositing ${rewardAmount} SUI to creator pool for: ${creatorAddress}`
    );

    const tx = new TransactionBlock();
    tx.setGasBudget(30000000);

    const configuration = tx.object(stakeConfigAddress);
    const clock = tx.object("0x6");

    const [rewardSuiCoin] = tx.splitCoins(tx.gas, [
      tx.pure(rewardAmount * 1e9),
    ]);

    tx.moveCall({
      target: `${packageAddress}::moonbags_stake::deposit_creator_pool`,
      typeArguments: [],
      arguments: [configuration, rewardSuiCoin, tx.pure(creatorAddress), clock],
    });

    console.log("Processing deposit to creator pool transaction...");
    await processResult(tx);
    console.log("Successfully deposited SUI to creator pool!");
  } catch (e) {
    console.error("Error depositing to creator pool:", e);
  }
};

const run = async () => {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  rl.question(
    "Enter the creator address (e.g., 0x123...): ",
    (creatorAddress) => {
      rl.question(`Enter the amount of SUI to deposit: `, (amount) => {
        depositCreatorPool(creatorAddress, parseFloat(amount));
        rl.close();
      });
    }
  );
};

run();

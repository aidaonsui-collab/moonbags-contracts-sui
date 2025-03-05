import { TransactionBlock } from "@mysten/sui.js/transactions";
import readline from "readline";
import { stakeConfigAddress, packageAddress, processResult } from "./utils";

const depositCreatorPool = async (
  tokenAddress: string,
  rewardAmount: number
) => {
  try {
    console.log(
      `Depositing ${rewardAmount} SUI to ${tokenAddress
        .split("::")
        .at(-1)} creator pool`
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
      typeArguments: [tokenAddress],
      arguments: [configuration, rewardSuiCoin, clock],
    });

    await processResult(tx);
  } catch (e) {
    console.error("Error depositing to creator pool:", e);
  }
};

const run = async () => {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  rl.question(`Enter the amount of SUI to deposit: `, (amount) => {
    rl.question(
      "Enter the token address (e.g., 0x123::token::TOKEN): ",
      (tokenAddress) => {
        depositCreatorPool(tokenAddress, parseFloat(amount));
        rl.close();
      }
    );
  });
};

run();

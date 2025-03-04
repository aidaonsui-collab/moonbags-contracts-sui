import { TransactionBlock } from "@mysten/sui.js/transactions";
import readline from "readline";
import { config_address, package_address, processResult } from "./utils";

const updateRewardIndex = async (
  stakingToken: string,
  rewardAmount: number
) => {
  try {
    console.log(
      `Updating reward index for ${stakingToken
        .split("::")
        .at(-1)} staking pool with ${rewardAmount} SUI...`
    );

    const tx = new TransactionBlock();
    tx.setGasBudget(100000000);

    // Fetch required objects
    const configuration = tx.object(config_address);
    const clock = tx.object("0x6"); // Clock object

    const [rewardSuiCoin] = tx.splitCoins(tx.gas, [
      tx.pure(rewardAmount * 1e9),
    ]);

    tx.moveCall({
      target: `${package_address}::moonbags_stake::update_reward_index`,
      typeArguments: [stakingToken],
      arguments: [configuration, rewardSuiCoin, clock],
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

  rl.question(
    "Enter the staking token type (e.g., 0x123::token::TOKEN): ",
    (token) => {
      rl.question("Enter the amount of SUI for rewards: ", (amount) => {
        updateRewardIndex(token, parseFloat(amount));
        rl.close();
      });
    }
  );
};

run();

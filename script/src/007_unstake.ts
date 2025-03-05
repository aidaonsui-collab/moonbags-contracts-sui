import { TransactionBlock } from "@mysten/sui.js/transactions";
import readline from "readline";
import { stakeConfigAddress, packageAddress, processResult } from "./utils";

const unstake = async (stakingToken: string, unstakeAmount: number) => {
  try {
    console.log(
      `Unstaking ${unstakeAmount} ${stakingToken.split("::").at(-1)} tokens...`
    );

    const tx = new TransactionBlock();
    tx.setGasBudget(30000000);

    // Fetch required objects
    const configuration = tx.object(stakeConfigAddress);
    const clock = tx.object("0x6"); // Clock object

    // Call the unstake function
    // Note: We're passing the amount directly as a u64
    tx.moveCall({
      target: `${packageAddress}::moonbags_stake::unstake`,
      typeArguments: [stakingToken],
      arguments: [
        configuration,
        tx.pure(unstakeAmount * 1e6), // Assuming 6 decimal places for most tokens
        clock,
      ],
    });

    console.log("Processing unstake transaction...");
    await processResult(tx);
    console.log("Successfully unstaked tokens!");
  } catch (e) {
    console.error("Error unstaking:", e);
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
        rl.question("Enter the amount to unstake: ", (amount) => {
          unstake(token, parseFloat(amount));
          rl.close();
        });
      }
    );
  } catch (e) {
    console.error("Error initializing script:", e);
  }
};

run();

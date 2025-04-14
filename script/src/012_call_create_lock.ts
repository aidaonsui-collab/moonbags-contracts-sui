import { TransactionBlock } from "@mysten/sui.js/transactions";
import readline from "readline";
import { packageAddress, processResult, lockConfigAddress } from "./utils";

const createTokenLock = async (
  tokenAddress: string,
  recipient: string,
  amount: number,
  endTimeMs: number,
  tokenObjectId: string
) => {
  try {
    console.log(
      `Creating token lock for ${amount} ${tokenAddress.split("::").at(-1)} to ${recipient} until timestamp ${endTimeMs}`
    );

    const tx = new TransactionBlock();
    tx.setGasBudget(30000000);
    
    const tokenCoin = tx.object(tokenObjectId);
    
    const lockConfig = tx.object(lockConfigAddress);
    const clock = tx.object("0x6");

    tx.moveCall({
      target: `${packageAddress}::moonbags_token_lock::create_lock`,
      typeArguments: [tokenAddress],
      arguments: [
        lockConfig,
        tokenCoin,
        tx.pure(recipient),
        tx.pure(amount),
        tx.pure(endTimeMs),
        clock,
      ],
    });

    await processResult(tx);
  } catch (e) {
    console.error("Error creating token lock:", e);
  }
};

const run = async () => {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  rl.question("Enter the token address (e.g., 0x123::token::TOKEN): ", (tokenAddress) => {
    rl.question("Enter the token coin object ID: ", (tokenObjectId) => {
      rl.question("Enter recipient address: ", (recipient) => {
        rl.question("Enter amount to lock: ", (amount) => {
          rl.question("Do you want to set (1) duration or (2) exact end time? (1/2): ", (option) => {
            if (option === "1") {
              rl.question("Enter duration in milliseconds (min 60000): ", (duration) => {
                const currentTimeMs = Date.now();
                const endTimeMs = currentTimeMs + parseInt(duration);
                
                createTokenLock(
                  tokenAddress,
                  recipient,
                  parseInt(amount),
                  endTimeMs,
                  tokenObjectId
                );
                rl.close();
              });
            } else {
              rl.question("Enter end time in milliseconds (timestamp): ", (endTime) => {
                createTokenLock(
                  tokenAddress,
                  recipient,
                  parseInt(amount),
                  parseInt(endTime),
                  tokenObjectId
                );
                rl.close();
              });
            }
          });
        });
      });
    });
  });
};

run();
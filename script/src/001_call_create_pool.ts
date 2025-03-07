import { TransactionBlock } from "@mysten/sui.js/transactions";
import { configAddress, packageAddress, processResult, stakeConfigAddress } from "./utils";
import readline from "readline";

const createPool = async (tokenAddress: string, treasuryCapObjId: string) => {
  try {
    console.log("Creating Pool...");

    const tx = new TransactionBlock();
    tx.setGasBudget(100000000);

    // Fetch required objects
    const configuration = tx.object(configAddress);
    const stakeConfig = tx.object(stakeConfigAddress);
    const treasuryCap = tx.object(treasuryCapObjId);
    const clock = tx.object("0x6"); // Clock object

    // Move call to create the pool
    tx.moveCall({
      target: `${packageAddress}::moonbags::create`,
      typeArguments: [tokenAddress],
      arguments: [
        configuration,
        stakeConfig,
        treasuryCap,
        tx.pure([10_000_000_000]), // max_supply
        clock,
        tx.pure("name"), // name
        tx.pure("symbol"), // symbol
        tx.pure("uri"), // uri
        tx.pure("description"), // description
        tx.pure("twitter"), // twitter
        tx.pure("telegram"), // telegram
        tx.pure("website"), // website
      ],
    });

    await processResult(tx);
  } catch (e) {
    console.error("Error creating pool:", e);
  }
};

const run = async () => {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  rl.question("Enter token address: ", async (token) => {
    rl.question("Enter treasury cap: ", async (treasuryCap) => {
      await createPool(token, treasuryCap);
      rl.close();
    });
  });
};

run();

import { TransactionBlock } from "@mysten/sui.js/transactions";
import readline from "readline";
import {
  config_address,
  keypair,
  package_address,
  processResult,
} from "./utils";

const claimCreatorPool = async (creatorAddress: string) => {
  try {
    console.log(
      `Claiming rewards from creator pool for address: ${creatorAddress}`
    );

    const tx = new TransactionBlock();
    tx.setGasBudget(30000000);

    // Fetch required objects
    const configuration = tx.object(config_address);
    const clock = tx.object("0x6");

    const [claimedAmount] = tx.moveCall({
      target: `${package_address}::moonbags_stake::claim_creator_pool`,
      typeArguments: [],
      arguments: [configuration, tx.pure(creatorAddress), clock],
    });

    console.log("Processing claim from creator pool transaction...");
    await processResult(tx);
    console.log("Successfully claimed rewards from creator pool!");
  } catch (e) {
    console.error("Error claiming from creator pool:", e);
  }
};

const run = async () => {
  try {
    // Display wallet address for reference
    const walletAddress = keypair.getPublicKey().toSuiAddress();
    console.log(`Current wallet address: ${walletAddress}`);
    console.log(
      "Note: You can only claim from creator pools where you are the creator"
    );

    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });

    rl.question(
      "Enter the creator address to claim rewards for (default: your address): ",
      (creatorAddress) => {
        // Use the provided address or default to the user's wallet address
        const addressToClaim = creatorAddress.trim() || walletAddress;
        claimCreatorPool(addressToClaim);
        rl.close();
      }
    );
  } catch (e) {
    console.error("Error initializing script:", e);
  }
};

run();

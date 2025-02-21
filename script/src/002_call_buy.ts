import { TransactionBlock } from "@mysten/sui.js/transactions";
import { getId, getNotUndefined, keypair, processResult } from "./utils";
import readline from "readline";

const TEST_TYPE = "0xd4120fbf1fd6605dceec684c1be80649208da27ae508ee34b6e59d808aa20510::my_coin::MY_COIN"; // Replace with actual TEST type path

const buy = async () => {
  try {
    console.log("calling buy...");

    const tx = new TransactionBlock();
    tx.setGasBudget(100000000);

    // Mint coins for testing (in production, you'd use actual coins)
    const [coin] = tx.splitCoins(tx.gas, [tx.pure(10000000)]);

    tx.moveCall({
      target: `0xc62aa415a504161f214706050c1d0d5aa5e1c1e041a2ee77dc4c32103c7f83e4::kairo::buy_exact_in`,
      typeArguments: [TEST_TYPE],
      arguments: [
        tx.object("0xbe75e9a158e0c4a02c4ba99aaa8cdc7672ac6c8f81fa1689d23f3bdd19990cf0"), // configuration
        coin, // sui coin
        tx.object("0xf699e7f2276f5c9a75944b37a0c5b5d9ddfd2471bf6242483b03ab2887d198d0"), // pools cetus
        tx.object("0xdaa46292632c3c4d8f31f23ea0f9b36a28ff3677e9684980e4438403a67a3d8f"), // global config cetus
        tx.object("0x9258181f5ceac8dbffb7030890243caed69a9599d2886d957a9cb7656af3bdb3"), // sui metadata
        tx.object("0xa093749b885a1fb4b922f59dbffed3eb9a29cfb77bfd863ed9f4682d61f2d8a2"), // token metadata
        tx.object("0x6"), // Clock object
      ],
    });

    // tx.moveCall({
    //   target: `0xc62aa415a504161f214706050c1d0d5aa5e1c1e041a2ee77dc4c32103c7f83e4::kairo::init_cetus_pool`,
    //   typeArguments: [TEST_TYPE],
    //   arguments: [
    //     coin, // sui_coin
    //     tx.object("0xdc4943ce5782dc37a53fc48f16e73459c01f3a02019d5e84512ad0f26ca9734e"), // token
    //     tx.object("0xf699e7f2276f5c9a75944b37a0c5b5d9ddfd2471bf6242483b03ab2887d198d0"), // pools cetus
    //     tx.object("0xdaa46292632c3c4d8f31f23ea0f9b36a28ff3677e9684980e4438403a67a3d8f"), // global config cetus
    //     tx.object("0x9258181f5ceac8dbffb7030890243caed69a9599d2886d957a9cb7656af3bdb3"), // sui metadata
    //     tx.object("0x5cea1fa8aaac1dec5e4b911104eca680518a9fc6f717612935a08fc66164dd5b"), // token metadata
    //     tx.object("0x6"), // Clock object
    //   ],
    // });

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
  console.log(
    "Choose the function to call: \n 1. buy"
  );
  rl.question("Enter your choice: ", async (choice) => {
    switch (choice) {
      case "1":
        await buy();
        break;
      default:
        console.log("Invalid choice");
        break;
    }
    rl.close();
  });
};

run();
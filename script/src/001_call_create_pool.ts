import { TransactionBlock } from "@mysten/sui.js/transactions";
import { processResult } from "./utils";
import readline from "readline";

const TEST_TYPE = "0xd4120fbf1fd6605dceec684c1be80649208da27ae508ee34b6e59d808aa20510::my_coin::MY_COIN"; // Replace with actual TEST type path

const createPool = async () => {
  try {
    console.log("Creating Pool...");

    const tx = new TransactionBlock();
    tx.setGasBudget(100000000);

    // Fetch required objects
    const configuration = tx.object("0xbe75e9a158e0c4a02c4ba99aaa8cdc7672ac6c8f81fa1689d23f3bdd19990cf0");
    const treasuryCap = tx.object("0x7ddb30212289fda16909a57fc66421ee0f07bd8fcd6789f1d99ce09881b6d3eb");
    const clock = tx.object("0x6"); // Clock object

    // Move call to create the pool
    tx.moveCall({
      target: `0xc62aa415a504161f214706050c1d0d5aa5e1c1e041a2ee77dc4c32103c7f83e4::kairo::create`,
      typeArguments: [TEST_TYPE],
      arguments: [
        configuration,
        treasuryCap,
        clock,
        tx.pure.string("name"), // name
        tx.pure.string("symbol"), // symbol
        tx.pure.string("uri"), // uri
        tx.pure.string("description"), // description
        tx.pure.string("twitter"), // twitter
        tx.pure.string("telegram"), // telegram
        tx.pure.string("website"), // website
      ],
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

  console.log("Choose the function to call: \n 1. Create Pool");
  rl.question("Enter your choice: ", async (choice) => {
    switch (choice) {
      case "1":
        await createPool();
        break;
      default:
        console.log("Invalid choice");
        break;
    }
    rl.close();
  });
};

run();

import { TransactionBlock } from "@mysten/sui.js/transactions";
import {
  client,
  config_address,
  keypair,
  package_address,
  processResult,
} from "./utils";
import readline from "readline";

const stake = async (token: string, amount: number) => {
  try {
    console.log(`Staking ${amount} ${token.split("::").at(-1)} tokens...`);

    const tx = new TransactionBlock();
    tx.setGasBudget(100000000);

    const configuration = tx.object(config_address);
    const clock = tx.object("0x6");

    const coinInputObjects = await client.getCoins({
      owner: keypair.getPublicKey().toSuiAddress(),
      coinType: token,
    });

    if (coinInputObjects.data.length === 0) {
      throw new Error(`No coins of type ${token} found`);
    }

    const coinObjects = coinInputObjects.data.map((coin) => coin.coinObjectId);
    const primaryCoin = tx.object(coinObjects[0]);

    if (coinObjects.length > 1) {
      const mergeCoins = coinObjects.slice(1).map((id) => tx.object(id));
      tx.mergeCoins(primaryCoin, mergeCoins);
    }

    const [stakingCoin] = tx.splitCoins(primaryCoin, [tx.pure(amount * 1e6)]);

    // Move call to create the pool
    tx.moveCall({
      target: `${package_address}::moonbags_stake::stake`,
      typeArguments: [token],
      arguments: [configuration, stakingCoin, clock],
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

  rl.question("Enter the token you want to stake: ", (token) => {
    rl.question("Enter the amount you want to stake: ", (amount) => {
      stake(token, parseInt(amount));
      rl.close();
    });
  });
};

run();

import { getFullnodeUrl, SuiClient } from "@mysten/sui.js/client";
import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import dotenv from "dotenv";
import * as fs from "fs";
dotenv.config();
export interface IObjectInfo {
  type: string | undefined;
  id: string | undefined;
}

export const packageAddress = process.env.PACKAGE_ADDRESS!;
export const configAddress = process.env.CONFIG_ADDRESS!;
export const stakeConfigAddress = process.env.STAKE_CONFIG_ADDRESS!;
export const cetusPoolsId =
  "0x50eb61dd5928cec5ea04711a2e9b72e5237e79e9fbcd2ce3d5469dc8708e0ee2";
export const cetusGlobalConfigId =
  "0x9774e359588ead122af1c7e7f64e14ade261cfeecdb5d0eb4a5b3b4c8ab8bd3e";

export const keypair = Ed25519Keypair.fromSecretKey(
  Uint8Array.from(Buffer.from(process.env.KEY!, "base64")).slice(1)
);

export const client = new SuiClient({ url: getFullnodeUrl("testnet") });

export const getId = (file: string, type: string): string | undefined => {
  try {
    const rawData = fs.readFileSync(`./result/${file}.json`, "utf8");
    const parsedData: IObjectInfo[] = JSON.parse(rawData);
    const typeToId = new Map(parsedData.map((item) => [item.type, item.id]));
    for (let [key, value] of typeToId) {
      if (key && key.startsWith(type)) {
        return value;
      }
    }
  } catch (error) {
    console.error("Error reading the created file:", error);
  }
};

export const getNotUndefined = (value: string | undefined): string => {
  if (value === undefined) {
    return "";
  } else {
    return value;
  }
};

export function generateRandomString(length: number) {
  let result = "";
  const characters =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  const charactersLength = characters.length;
  for (let i = 0; i < length; i++) {
    result += characters.charAt(Math.floor(Math.random() * charactersLength));
  }
  return result;
}

export async function processResult(tx: TransactionBlock) {
  const result = await client.signAndExecuteTransactionBlock({
    signer: keypair,
    transactionBlock: tx,
    options: {
      showObjectChanges: true,
      showEffects: true,
    },
    requestType: "WaitForLocalExecution",
  });

  console.log("status: ", JSON.stringify(result.effects?.status, null, 2));

  if (result.effects?.status?.status !== "success") {
    console.log("\n\nPublishing failed");
    return;
  }
}

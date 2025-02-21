import {
  getFullnodeUrl,
  OwnedObjectRef,
  SuiClient,
} from "@mysten/sui.js/client";
import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import dotenv from "dotenv";
import * as fs from "fs";
dotenv.config();
export interface IObjectInfo {
  type: string | undefined;
  id: string | undefined;
}

export const keypair = Ed25519Keypair.fromSecretKey(
  Uint8Array.from(Buffer.from(process.env.KEY!, "base64")).slice(1)
);

export const client = new SuiClient({ url: getFullnodeUrl("mainnet") });

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

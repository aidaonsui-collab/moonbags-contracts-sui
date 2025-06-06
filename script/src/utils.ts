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
export const lockConfigAddress = process.env.LOCK_CONFIG_ADDRESS!;
// testnet
export const cetusPoolsId =
  "0x50eb61dd5928cec5ea04711a2e9b72e5237e79e9fbcd2ce3d5469dc8708e0ee2";
export const cetusGlobalConfigId =
  "0x9774e359588ead122af1c7e7f64e14ade261cfeecdb5d0eb4a5b3b4c8ab8bd3e";
export const cetusBurnManagerId =
  "0xd04529ef15b7dad6699ee905daca0698858cab49724b2b2a1fc6b1ebc5e474ef";

// mainnet
// export const cetusPoolsId =
//   "0xf699e7f2276f5c9a75944b37a0c5b5d9ddfd2471bf6242483b03ab2887d198d0";
// export const cetusGlobalConfigId =
//   "0xdaa46292632c3c4d8f31f23ea0f9b36a28ff3677e9684980e4438403a67a3d8f";
// export const cetusBurnManagerId =
//   "0x1d94aa32518d0cb00f9de6ed60d450c9a2090761f326752ffad06b2e9404f845";

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

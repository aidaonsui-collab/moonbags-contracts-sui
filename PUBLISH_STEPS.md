# Publish runbook — moonbags-contracts-sui v13 (Cetus/Turbos migration)

**Goal:** republish the bonding-curve contracts so new tokens can migrate
to **Cetus** (fully automated, LP burned) or **Turbos** (admin-assisted
fallback) instead of the current admin → Momentum flow.

This is a **fresh publish**, not a Move upgrade — the struct layout adds
`bonding_dex: u8` to `CreatedEvent` / `Pool` etc., which Move upgrade
rules forbid. Old tokens on v12-CURRENT / AIDA-CURRENT keep their
existing migration path; only NEW tokens minted under v13 use Cetus/
Turbos.

---

## Prereqs on your local machine

```bash
# 1. Sui CLI on mainnet
sui client switch --env mainnet
sui client active-address          # confirm this is the admin wallet
sui client gas                     # need ~10 SUI free for publish gas
sui --version                      # ≥ 1.33 recommended
```

## Steps

```bash
# 1. Pull latest source
cd ~/dev/moonbags-contracts-sui    # or wherever you cloned it
git fetch origin
git checkout main
git pull

# 2. Sanity-build first (dry-run, cheap)
sui move build

# 3. Dry-run the publish to verify gas + catch errors cheaply
sui client publish --gas-budget 500000000 --dry-run

# 4. Real publish
sui client publish --gas-budget 500000000
```

## What to capture from the publish output

Scan the "Object Changes" / "Created Objects" section for these. Save
them into a text file:

| Variable | How to find it |
|---|---|
| `packageId` | First line of output — "Published to: 0x…" |
| `Configuration` | Object with type `<pkg>::moonbags::Configuration` |
| `stakeConfig` | Object with type `<pkg>::moonbags_stake::Configuration` |
| `lockConfig` | Object with type `<pkg>::moonbags_token_lock::TokenLockConfig` |
| `thresholdConfig` | Object with type `<pkg>::moonbags::ThresholdConfig` |
| `AdminCap` | Object with type `<pkg>::moonbags::AdminCap` (goes to sender) |
| `BurnManager` | From `lp_burn` dep, type `<pkg>::lp_burn::BurnManager` (may need a separate init call — see step 5) |

## Step 5 — Cetus shared objects (already on mainnet, just grab IDs)

These are Cetus-owned, not created by your publish:

```
GlobalConfig  = 0xdaa46292632c3c4d8f31f23ea0f9b36a28ff3677e9684980e4438403a67a3d8f
Pools         = 0xf699e7f2276f5c9a75944b37a0c5b5d9ddfd2471bf6242483b03ab2887d198d0
```

**metadata_sui** on mainnet:
```
0x587c29de216efd4219573e08a1f6964d4fa7cb714518c2c8a0f29abfa264327d
```

Verify:
```bash
sui client object 0xdaa46292632c3c4d8f31f23ea0f9b36a28ff3677e9684980e4438403a67a3d8f
sui client object 0xf699e7f2276f5c9a75944b37a0c5b5d9ddfd2471bf6242483b03ab2887d198d0
sui client object 0x587c29de216efd4219573e08a1f6964d4fa7cb714518c2c8a0f29abfa264327d
```

## Step 6 — Initialize ThresholdConfig if needed

```bash
sui client call \
  --package <NEW_PKG_ID> \
  --module moonbags \
  --function create_threshold_config \
  --args <AdminCap_objectId> 2000000000000 \
  --gas-budget 10000000
```
(2000000000000 = 2000 SUI in MIST. Captures the default graduation threshold.)

## Step 7 — Wire into the frontend

In **robots/frontend/lib/contracts.ts**, add a new entry:

```ts
export const MOONBAGS_CONTRACT_V13: MoonbagsContract = {
  packageId:     '<NEW_PKG_ID>',
  module:        'moonbags',
  configuration: '<NEW_Configuration>',
  stakeConfig:   '<NEW_stakeConfig>',
  lockConfig:    '<NEW_lockConfig>',
  // Cetus shared objects (mainnet — constants above)
  cetusBurnManager:   '<lp_burn::BurnManager>',
  cetusPools:         '0xf699e7f2276f5c9a75944b37a0c5b5d9ddfd2471bf6242483b03ab2887d198d0',
  cetusGlobalConfig:  '0xdaa46292632c3c4d8f31f23ea0f9b36a28ff3677e9684980e4438403a67a3d8f',
  suiMetadata:        '0x587c29de216efd4219573e08a1f6964d4fa7cb714518c2c8a0f29abfa264327d',
}

// Flip the current default to the new one
export const MOONBAGS_CONTRACT: MoonbagsContract = MOONBAGS_CONTRACT_V13
```

Update the `MoonbagsContract` type to include the new Cetus fields.

## Step 8 — Uncomment the DEX-aware tx block

In **robots/frontend/app/bondingcurve/coins/create/page.tsx**, search for:

```
=== DEX-AWARE ARGUMENTS — uncomment after moonbags republish ===
```

Delete the old `tx2.moveCall(...)` block above it and uncomment the
block below. Verify the arg order against the function signature in
`sources/moonbags.move:747` — it's the source of truth. In particular:
- If `threshold: Option<u64>` is still `Option`-wrapped in the new
  publish, use `tx2.pure.option('u64', targetRaiseMist)` instead of
  `tx2.pure.u64(targetRaiseMist)`.

## Step 9 — Smoke test on mainnet

1. Launch a tiny test token with threshold = 1 SUI, first-buy = 1 SUI
2. Immediately buy to fill the curve
3. Observe the PoolCompletedEventV2 + PoolMigratingEvent on the tx
4. Verify the Cetus pool object exists and is tradable on cetus.io

If Cetus graduation fails:
- Check the tx error — most likely a wrong shared-object ID
- Fallback to `bonding_dex = 1` (Turbos) which currently dumps to admin
  and is safe

## Rollback plan

If the new publish has a bug you can:
- Revert the `contracts.ts` change (`MOONBAGS_CONTRACT = MOONBAGS_CONTRACT_V12`)
- Revert the `page.tsx` commit that uncommented the DEX-aware args
- Existing tokens on v12 are unaffected (they live under their own package)

The new v13 package stays on-chain but just has zero pools minted under
it until you fix and re-point.

---

## What NOT to do

- ❌ Do not `sui client upgrade` — this is a fresh publish, not upgrade
- ❌ Do not reuse v12's `AdminCap` or shared objects — you'll get type mismatches
- ❌ Do not change the `externals/` deps without consulting contracts — the Cetus tick math depends on those exact versions

## Presale (phase 2, not in this publish)

The `theodyssey2/contracts/presale/sources/presale.move` still dumps to
admin. To add Cetus to presale, port the `init_cetus_pool` pattern from
`moonbags.move:1246` into `withdraw_for_migration` (`presale.move:680`).
Separate publish, separate frontend update. Do this after verifying the
bonding-curve publish works end-to-end.

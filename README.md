# Moonbags SC

## 1. Sui Version

sui 1.46.2

## 2. Build

```bash
sui move build
```

## 3. Deployment

### Setting up keys and network

```bash
# Import private key
sui keytool import $PRIVATE_KEY

# Set up networks
sui client new-env --alias=testnet --rpc https://fullnode.testnet.sui.io:443
sui client new-env --alias=mainnet --rpc https://fullnode.mainnet.sui.io:443

# List available keys and networks
sui client addresses
sui client envs

# Switch keys and networks
sui client switch --address $ALIAS
```

### Testnet Deployment

```bash
# Switch to testnet environment
sui client switch --env testnet

# Publish package to testnet
sui client publish

# If upgrading an existing package
sui client upgrade --upgrade-capability <TESTNET_UPGRADE_CAPABILITY>

# Run script to create SHRO staking pool after deployment
cd script
npx ts-node src/003_call_init_staking_pool.ts
```

> **Important**: Before deployment, refer to the [Configuration Values](#5-configuration-values) section to ensure you're using the correct parameters for testnet.

### Production (Mainnet) Deployment

```bash
# Switch to mainnet environment
sui client switch --env mainnet

# Publish package to mainnet
sui client publish

# If upgrading an existing package
sui client upgrade --upgrade-capability <MAINNET_UPGRADE_CAPABILITY>

# Run script to create SHRO staking pool after deployment
cd script
npx ts-node src/003_call_init_staking_pool.ts
```

> **Important**: Before deployment, refer to the [Configuration Values](#5-configuration-values) section to ensure you're using the correct parameters for mainnet.

## 4. Test

```bash
just test
```

## 5. Configuration Values

The following table shows configuration values in sc for testnet and mainnet environments:

| Parameter | Testnet Value | Mainnet Value | Description |
| --- | --- | --- | --- |
| DEFAULT_THRESHOLD | 3_000_000_000 (3 SUI) | 3_000_000_000_000 (3000 SUI) | Default SUI threshold for pool |
| MINIMUM_THRESHOLD | 2_000_000_000 (2 SUI) | 2_000_000_000_000 (2000 SUI) | Minimum allowable threshold |
| PLATFORM_FEE | 100 (1%) | 100 (1%) | Platform transaction fee |
| GRADUATED_FEE | 10 (0.1%) | 10 (0.1%) | Fee for graduated transactions |
| INITIAL_VIRTUAL_TOKEN_RESERVES | 10_000_000_000_000 (10M) | 1_000_000_000_000_000 (1B) | Initial supply for bonding pool |
| REMAIN_TOKEN_RESERVES | 2_000_000_000_000 (2M) | 200_000_000_000_000 (200M) | Remaining token supply |
| INIT_PLATFORM_FEE_WITHDRAW | 1_500 (15%) | 1_500 (15%) | Platform fee withdrawal percentage |
| INIT_CREATOR_FEE_WITHDRAW | 3_000 (30%) | 3_000 (30%) | Creator fee withdrawal percentage |
| INIT_STAKE_FEE_WITHDRAW | 3_500 (35%) | 3_500 (35%) | Staking fee withdrawal percentage |
| INIT_PLATFORM_STAKE_FEE_WITHDRAW | 2_000 (20%) | 2_000 (20%) | Platform staking fee percentage |
| TOKEN_PLATFORM_TYPE_NAME | 0x58ebd732c49a6441edb64ce519741a74461dc11d7383b078cac1292ba0d2fee7::shro::SHRO | 0x16ab6a14d76a90328a6b04f06b0a0ce952847017023624e0c37bf8aa314c39ba::shr::SHR | Token type name |
| VERSION (BONDING) | 1 | 1 | Contract version |
| VERSION (STAKING) | 1 | 1 | Contract version |
| TREASURY | 0x0db7989b98d681455f424035e3f01c02e27f738fdd6634ef34dedf576a9d8cea | 0x0db7989b98d681455f424035e3f01c02e27f738fdd6634ef34dedf576a9d8cea | Treasury cap |

### External Package Dependencies

| Package | Testnet Address | Mainnet Address |
| --- | --- | --- |
| CETUS_CLMM (published) | 0xb2a1d27337788bda89d350703b8326952413bd94b35b9b573ac8401b9803d018 | 0xc6faf3703b0e8ba9ed06b7851134bbbe7565eb35ff823fd78432baa4cbeaa12e |
| CETUS_CLMM (address) | 0x0c7ae833c220aa73a3643a0d508afa4ac5d50d97312ea4584e35f9eb21b9df12 | 0x1eabed72c53feb3805120a081dc15963c204dc8d091542592abaf7a35689b2fb |
| INTEGER_MATE (published) | 0xf0784730d8c5397fde92149fde6d3c273c3375e614b57470ad43f286742593c2 | 0xe2b515f0052c0b3f83c23db045d49dbe1732818ccfc5d4596c9482f7f2e76a85 |
| INTEGER_MATE (address) | 0xdcf9989b726020a24d635a4f83b267b19791c4d60663d8a1ebdcfcc5a034247d | 0x714a63a0dba6da4f017b42d5d0fb78867f18bcde904868e51d951a5a6f5b7f57 |
| LP_BURN (published) | 0x9c751fccc633f3ebad2becbe7884e5f38b4e497127689be0d404b24f79d95d71 | 0xb6ec861eec8c550269dc29a1662008a816ac4756df723af5103075b665e32e65 |
| LP_BURN (address) | 0x3b494006831b046481c8046910106e2dfbe0d1fa9bc01e41783fb3ff6534ed3a | 0x12d73de9a6bc3cb658ec9dc0fe7de2662be1cea5c76c092fcc3606048cdbac27 |
| MOVE_STL (published) | 0xa883e07d89008ce6b35c793903f7cdb3e2f4af404d204d42242cc5c4e48e7e3b | 0xe93247b408fe44ed0ee5b6ac508b36325b239d6333e44ffa240dcc0c1a69cdd8 |
| MOVE_STL (address) | 0xfc127e3f9318fc874f94e464b1ee06ec01da31ca85479b8ebd3fa068f11a5b7d | 0xbe21a06129308e0495431d12286127897aff07a8ade3970495a4404d97f9eaaa |

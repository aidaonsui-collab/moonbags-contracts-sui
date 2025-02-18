# sui trading router

## 1.Sui Version

sui 1.35.1

## 2.Build

```
sui move build
```

## 3.Deploy

### key and network

```bash
# import keys and networks
sui keytool import $PRIVATE_KEY
sui client new-env --alias=mainnet --rpc https://fullnode.mainnet.sui.io:443

# list
sui client addresses
sui client envs

# switch keys and envs
sui client switch --address $ALIAS
sui client switch --env mainnet
```

### go live

```bash
sui client publish
```

### Upgrade package

```bash
sui client upgrade --upgrade-capability <UPGRADE_CAPABILITY> --skip-dependency-verification
```

## 4.Test

```
just test
```

## Deployment

- Development Package: `0x2f5c6c8c8d7b4302f3d8acb75f69b0ded47a109f26b92ad09bd02b78c6569474`
- Fee Object: `0x04bb2e8a0e4710b8bf8124b1057653036dcac7060094e19a046ec9232f70b319`

## Testing

- Difficult to test because of the dependency on the mainnet. Therefore, we record the mainnet transactions

| action                          | tx                                                                         |
| ------------------------------- | -------------------------------------------------------------------------- |
| move_pump_router::buy_exact_out | https://suivision.xyz/txblock/HkXZ9mRY6UBjSET92e6mF1okiCk6uacCDfWKGndvPhgE |
| move_pump_router::sell_exact_in | https://suivision.xyz/txblock/3ve254utcN5BX82JBNkR5te9zdyg5sgtr4bCC5shxohm |

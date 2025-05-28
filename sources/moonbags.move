#[allow(lint(self_transfer), implicit_const_copy)]
module moonbags::moonbags {
    use std::ascii::{Self, String};
    use std::string;
    use std::type_name;
    use std::u64::min;

    use sui::sui::SUI;
    use sui::coin::{Self, Coin, CoinMetadata};
    use sui::dynamic_object_field;
    use sui::dynamic_field;
    use sui::event::emit;
    use sui::clock::{Clock, Self};

    use moonbags::curves;
    use moonbags::utils;
    use moonbags::moonbags_stake::{Self, Configuration as StakeConfig};

    use cetus_clmm::factory::Pools;
    use cetus_clmm::pool_creator::Self;
    use cetus_clmm::config::GlobalConfig;
    use cetus_clmm::pool::{Pool as CetusPool};

    use turbos_clmm::position_manager::{Positions as TurbosPositions};
	use turbos_clmm::pool::{Pool as TurbosPool, Versioned as TurbosVersioned};
    use turbos_clmm::position_nft::TurbosPositionNFT;
    
    use lp_burn::lp_burn::{Self, BurnManager};

    const DEFAULT_THRESHOLD: u64 = 3000000000; // 3 SUI
    const MINIMUM_THRESHOLD: u64 = 2000000000; // 2 SUI
    const VERSION: u64 = 3;
    const FEE_DENOMINATOR: u64 = 10000;
    const BURN_PROOF_FIELD: vector<u8> = b"burn_proof";
    const COIN_METADATA_FIELD: vector<u8> = b"metadata_token";
    const VIRTUAL_TOKEN_RESERVES_FIELD: vector<u8> = b"virtual_token_reserves";
    const BURN_PROOF_TURBOS_FIELD: vector<u8> = b"turbos_burn_proof";
    const BONDING_DEX_FIELD : vector<u8> = b"migrate_dex";

    const CETUS_DEX: u8 = 0;
    const TURBOS_DEX: u8 = 1;
    const BONDING_SUPPORT_DEXES: vector<u8> = vector[CETUS_DEX, TURBOS_DEX];

    const EInvalidInput: u64 = 1;
    const ENotEnoughThreshold: u64 = 2;
    const EWrongVersion: u64 = 3;
    const ECompletedPool: u64 = 4;
    const EInsufficientInput: u64 = 5;
    const EExistTokenSupply: u64 = 6;
    const EPoolNotComplete: u64 = 7;
    const ENotUpgrade: u64 = 8;
    const EInvalidWithdrawPool: u64 = 9;
    const EInvalidWithdrawAmount: u64 = 10;

    public struct AdminCap has key {
        id: UID,
    }

    public struct Configuration has store, key {
        id: UID,
        version: u64,
        admin: address,
        treasury: address,
        fee_platform_recipient: address,
        platform_fee: u64,
        initial_virtual_token_reserves: u64,
        remain_token_reserves: u64,
        token_decimals: u8,
        init_platform_fee_withdraw: u16,
        init_creator_fee_withdraw: u16,
        init_stake_fee_withdraw: u16,
        init_platform_stake_fee_withdraw: u16,
        token_platform_type_name: String,
    }

    public struct ThresholdConfig has store, key {
        id: UID,
        threshold: u64,
    }

    #[allow(lint(coin_field))]
    public struct Pool<phantom Token> has store, key {
        id: UID,
        real_sui_reserves: Coin<SUI>,
        real_token_reserves: Coin<Token>,
        virtual_token_reserves: u64,
        virtual_sui_reserves: u64,
        remain_token_reserves: Coin<Token>,
        fee_recipient: Coin<SUI>,
        is_completed: bool,
        platform_fee_withdraw: u16,
        creator_fee_withdraw: u16,
        stake_fee_withdraw: u16,
        platform_stake_fee_withdraw: u16,
        threshold: u64,
    }

    public struct ConfigChangedEvent has copy, drop, store {
        old_platform_fee: u64,
        new_platform_fee: u64,
        old_initial_virtual_token_reserves: u64,
        new_initial_virtual_token_reserves: u64,
        old_remain_token_reserves: u64,
        new_remain_token_reserves: u64,
        old_token_decimals: u8,
        new_token_decimals: u8,
        old_init_platform_fee_withdraw: u16,
        new_init_platform_fee_withdraw: u16,
        old_init_creator_fee_withdraw: u16,
        new_init_creator_fee_withdraw: u16,
        old_init_stake_fee_withdraw: u16,
        new_init_stake_fee_withdraw: u16,
        old_init_platform_stake_fee_withdraw: u16,
        new_init_platform_stake_fee_withdraw: u16,
        old_token_platform_type_name: String,
        new_token_platform_type_name: String,
        ts: u64,
    }

    public struct CreatedEvent has copy, drop, store {
        name: String,
        symbol: String,
        uri: String,
        description: String,
        twitter: String,
        telegram: String,
        website: String,
        token_address: String,
        bonding_curve: String,
        pool_id: ID,
        created_by: address,
        virtual_sui_reserves: u64,
        virtual_token_reserves: u64,
        real_sui_reserves: u64,
        real_token_reserves: u64,
        platform_fee_withdraw: u16,
        creator_fee_withdraw: u16,
        stake_fee_withdraw: u16,
        platform_stake_fee_withdraw: u16,
        threshold: u64,
        ts: u64,
    }

    public struct OwnershipTransferredEvent has copy, drop, store {
        old_admin: address,
        new_admin: address,
        ts: u64,
    }

    public struct PoolCompletedEvent has copy, drop, store {
        token_address: String,
        lp: String,
        ts: u64,
    }

    public struct TradedEvent has copy, drop, store {
        is_buy: bool,
        user: address,
        token_address: String,
        sui_amount: u64,
        token_amount: u64,
        virtual_sui_reserves: u64,
        virtual_token_reserves: u64,
        real_sui_reserves: u64,
        real_token_reserves: u64,
        pool_id: ID,
        fee: u64,
        ts: u64,
    }

    public struct ConfigChangedEventV2 has copy, drop, store {
        old_platform_fee: u64,
        new_platform_fee: u64,
        old_initial_virtual_token_reserves: u64,
        new_initial_virtual_token_reserves: u64,
        old_remain_token_reserves: u64,
        new_remain_token_reserves: u64,
        old_token_decimals: u8,
        new_token_decimals: u8,
        old_init_platform_fee_withdraw: u16,
        new_init_platform_fee_withdraw: u16,
        old_init_creator_fee_withdraw: u16,
        new_init_creator_fee_withdraw: u16,
        old_init_stake_fee_withdraw: u16,
        new_init_stake_fee_withdraw: u16,
        old_init_platform_stake_fee_withdraw: u16,
        new_init_platform_stake_fee_withdraw: u16,
        old_token_platform_type_name: String,
        new_token_platform_type_name: String,
        ts: u64,
    }

    public struct CreatedEventV2 has copy, drop, store {
        name: String,
        symbol: String,
        uri: String,
        description: String,
        twitter: String,
        telegram: String,
        website: String,
        token_address: String,
        bonding_curve: String,
        pool_id: ID,
        created_by: address,
        virtual_sui_reserves: u64,
        virtual_token_reserves: u64,
        real_sui_reserves: u64,
        real_token_reserves: u64,
        platform_fee_withdraw: u16,
        creator_fee_withdraw: u16,
        stake_fee_withdraw: u16,
        platform_stake_fee_withdraw: u16,
        threshold: u64,
        bonding_dex: u8,
        ts: u64,
    }

    public struct OwnershipTransferredEventV2 has copy, drop, store {
        old_admin: address,
        new_admin: address,
        ts: u64,
    }

    public struct PoolCompletedEventV2 has copy, drop, store {
        token_address: String,
        lp: String,
        ts: u64,
    }

    public struct PoolMigratingEvent has copy, drop, store {
        token_address: String,
        sui_amount: u64,
        token_amount: u64,
        bonding_dex: u8,
        ts: u64,
    }

    public struct TradedEventV2 has copy, drop, store {
        is_buy: bool,
        user: address,
        token_address: String,
        sui_amount: u64,
        token_amount: u64,
        virtual_sui_reserves: u64,
        virtual_token_reserves: u64,
        real_sui_reserves: u64,
        real_token_reserves: u64,
        pool_id: ID,
        fee: u64,
        ts: u64,
    }

    fun init(ctx: &mut TxContext) {
        let admin = AdminCap {
            id: object::new(ctx),
        };

        let configuration = Configuration {
            id: object::new(ctx),
            version: VERSION,
            admin: ctx.sender(),
            treasury: ctx.sender(),
            fee_platform_recipient: ctx.sender(),
            platform_fee: 100, // 1%
            initial_virtual_token_reserves: 8000000000000, // 8 million
            remain_token_reserves: 2000000000000, // 2 million
            token_decimals: 6,
            init_platform_fee_withdraw: 1500,        // 15% to platform
            init_creator_fee_withdraw: 3000,         // 30% to creator
            init_stake_fee_withdraw: 3500,           // 35% to stakers
            init_platform_stake_fee_withdraw: 2000,  // 20% to platform stakers
            token_platform_type_name: b"6d4f59540a0525077ce3794e9982a36bf8d894fd457c55e48be0538ebff975c8::shro::SHRO".to_ascii_string(),
        };
        transfer::public_share_object<Configuration>(configuration);

        transfer::transfer(admin, ctx.sender());
    }

    public entry fun create<Token>(
        _configuration: &mut Configuration,
        _stake_config: &mut StakeConfig,
        mut _treasury_cap: coin::TreasuryCap<Token>,
        _metadata_token: CoinMetadata<Token>,
        _threshold: Option<u64>,
        _clock: &Clock,
        _name: String,
        _symbol: String,
        _uri: String,
        _description: String,
        _twitter: String,
        _telegram: String,
        _website: String,
        _ctx: &mut TxContext
    ) {
        abort 0
    }

    public entry fun create_v2<Token>(
        configuration: &mut Configuration,
        stake_config: &mut StakeConfig,
        mut treasury_cap: coin::TreasuryCap<Token>,
        metadata_token: CoinMetadata<Token>,
        bonding_dex: u8,
        threshold: Option<u64>,
        clock: &Clock,
        name: String,
        symbol: String,
        uri: String,
        description: String,
        twitter: String,
        telegram: String,
        website: String,
        ctx: &mut TxContext
    ) {
        assert!(ascii::length(&uri) <= 300, EInvalidInput);
        assert!(ascii::length(&description) <= 1000, EInvalidInput);
        assert!(ascii::length(&twitter) <= 500, EInvalidInput);
        assert!(ascii::length(&telegram) <= 500, EInvalidInput);
        assert!(ascii::length(&website) <= 500, EInvalidInput);

        assert_version(configuration.version);
        assert!(coin::total_supply<Token>(&treasury_cap) == 0, EExistTokenSupply);

        let threshold = option::get_with_default(&threshold, DEFAULT_THRESHOLD);
        assert!(threshold >= MINIMUM_THRESHOLD, EInvalidInput);

        let initial_virtual_sui_reserves = calculate_init_sui_reserves(configuration, threshold);

        let actual_virtual_token_reserves = utils::as_u64(
            utils::div(
                utils::mul(
                    utils::from_u64(configuration.initial_virtual_token_reserves),
                    utils::from_u64(configuration.initial_virtual_token_reserves)
                ),
                utils::from_u64(configuration.initial_virtual_token_reserves - configuration.remain_token_reserves)
            )
        );

        let mut pool = Pool<Token>{
            id                          : object::new(ctx),
            real_sui_reserves           : coin::zero<SUI>(ctx),
            real_token_reserves         : coin::mint<Token>(&mut treasury_cap, configuration.initial_virtual_token_reserves, ctx),
            virtual_token_reserves      : actual_virtual_token_reserves,
            virtual_sui_reserves        : initial_virtual_sui_reserves,
            remain_token_reserves       : coin::mint<Token>(&mut treasury_cap, configuration.remain_token_reserves, ctx),
            fee_recipient               : coin::zero<SUI>(ctx),
            is_completed                : false,
            platform_fee_withdraw       : configuration.init_platform_fee_withdraw,
            creator_fee_withdraw        : configuration.init_creator_fee_withdraw,
            stake_fee_withdraw          : configuration.init_stake_fee_withdraw,
            platform_stake_fee_withdraw : configuration.init_platform_stake_fee_withdraw,
            threshold                   : threshold,
        };

        // save to dynamic field due to can't change the field of obj while upgrade
        let virtual_remain_token_reserves = utils::as_u64(
            utils::div(
                utils::mul(
                    utils::from_u64(configuration.remain_token_reserves),
                    utils::from_u64(configuration.initial_virtual_token_reserves)
                ),
                utils::from_u64(configuration.initial_virtual_token_reserves - configuration.remain_token_reserves)
            )
        );
        dynamic_field::add(&mut pool.id,  VIRTUAL_TOKEN_RESERVES_FIELD, virtual_remain_token_reserves);
        dynamic_object_field::add(&mut pool.id, COIN_METADATA_FIELD, metadata_token);

        assert!(vector::contains(&BONDING_SUPPORT_DEXES, &bonding_dex), EInvalidInput);
        dynamic_field::add(&mut pool.id,  BONDING_DEX_FIELD, bonding_dex);

        transfer::public_transfer<coin::TreasuryCap<Token>>(treasury_cap, @0x0);

        let token_address = type_name::get<Token>();
        let pool_address = type_name::get<Pool<Token>>();

        let created_event = CreatedEventV2 {
            name                        : name,
            symbol                      : symbol,
            uri                         : uri,
            description                 : description,
            twitter                     : twitter,
            telegram                    : telegram,
            website                     : website,
            token_address               : type_name::into_string(token_address),
            bonding_curve               : type_name::get_module(&pool_address),
            pool_id                     : object::id<Pool<Token>>(&pool),
            created_by                  : ctx.sender(),
            virtual_sui_reserves        : pool.virtual_sui_reserves,
            virtual_token_reserves      : pool.virtual_token_reserves,
            real_sui_reserves           : coin::value<SUI>(&pool.real_sui_reserves),
            real_token_reserves         : coin::value<Token>(&pool.real_token_reserves),
            platform_fee_withdraw       : pool.platform_fee_withdraw,
            creator_fee_withdraw        : pool.creator_fee_withdraw,
            stake_fee_withdraw          : pool.stake_fee_withdraw,
            platform_stake_fee_withdraw : pool.platform_stake_fee_withdraw,
            bonding_dex                 : bonding_dex,
            threshold                   : threshold,
            ts                          : clock::timestamp_ms(clock),
        };
        dynamic_object_field::add<String, Pool<Token>>(&mut configuration.id, type_name::get_address(&token_address), pool);
        emit<CreatedEventV2>(created_event);

        moonbags_stake::initialize_staking_pool<Token>(stake_config, clock, ctx);
        moonbags_stake::initialize_creator_pool<Token>(stake_config, ctx.sender(), clock, ctx);
    }

    fun swap<Token>(pool: &mut Pool<Token>, coin_token: Coin<Token>, coin_sui: Coin<SUI>, amount_token_out: u64, amount_sui_out: u64, ctx: &mut TxContext) : (Coin<Token>, Coin<SUI>) {
        let before_virtual_token_reserves = pool.virtual_token_reserves;
        let before_virtual_sui_reserves = pool.virtual_sui_reserves;

        assert!(coin::value<Token>(&coin_token) > 0 || coin::value<SUI>(&coin_sui) > 0, EInvalidInput);

        pool.virtual_token_reserves = pool.virtual_token_reserves + coin::value<Token>(&coin_token);
        pool.virtual_sui_reserves = pool.virtual_sui_reserves + coin::value<SUI>(&coin_sui);

        if (coin::value<Token>(&coin_token) > 0) {
            pool.virtual_token_reserves = pool.virtual_token_reserves - amount_token_out;
        };
        if (coin::value<SUI>(&coin_sui) > 0) {
            pool.virtual_sui_reserves = pool.virtual_sui_reserves - amount_sui_out;
        };

        assert_lp_value_is_increased_or_not_changed(before_virtual_token_reserves, before_virtual_sui_reserves, pool.virtual_token_reserves, pool.virtual_sui_reserves);

        coin::join<Token>(&mut pool.real_token_reserves, coin_token);
        coin::join<SUI>(&mut pool.real_sui_reserves, coin_sui);

        (coin::split<Token>(&mut pool.real_token_reserves, amount_token_out, ctx), coin::split<SUI>(&mut pool.real_sui_reserves, amount_sui_out, ctx))
    }

    public fun assert_pool_not_completed<Token>(configuration: &Configuration) {
        let token_address = type_name::get<Token>();
        assert!(dynamic_object_field::borrow<String, Pool<Token>>(&configuration.id, type_name::get_address(&token_address)).is_completed, EPoolNotComplete);
    }

    fun assert_lp_value_is_increased_or_not_changed(before_token_reserves: u64, before_sui_reserves: u64, after_token_reserves: u64, after_sui_reserves: u64) {
        assert!((before_token_reserves as u128) * (before_sui_reserves as u128) <= (after_token_reserves as u128) * (after_sui_reserves as u128), EInvalidInput);
    }

    fun assert_version(version: u64) {
        assert!(version <= VERSION, EWrongVersion);
    }

    public entry fun buy_exact_out<Token>(configuration: &mut Configuration, mut coin_sui: Coin<SUI>, amount_out: u64, cetus_burn_manager: &mut BurnManager, cetus_pools: &mut Pools, cetus_global_config: &mut GlobalConfig, metadata_sui: &CoinMetadata<SUI>, clock: &Clock, ctx: &mut TxContext) {
        assert_version(configuration.version);

        let token_address = type_name::get<Token>();
        let pool = dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut configuration.id, type_name::get_address(&token_address));

        assert!(!pool.is_completed, ECompletedPool);
        assert!(amount_out > 0, EInvalidInput);

        let amount_sui_in = coin::value<SUI>(&coin_sui);
        let virtual_remain_token_reserves = get_virtual_remain_token_reserves(pool);
        let token_reserves_in_pool = pool.virtual_token_reserves - virtual_remain_token_reserves;
        let actual_amount_out = min(amount_out, token_reserves_in_pool);

        let amount_in_swap = curves::calculate_add_liquidity_cost(pool.virtual_sui_reserves, pool.virtual_token_reserves, actual_amount_out) + 1;
        let fee = utils::as_u64(utils::div(utils::mul(utils::from_u64(amount_in_swap), utils::from_u64(configuration.platform_fee)), utils::from_u64(FEE_DENOMINATOR)));

        coin::join(&mut pool.fee_recipient, coin::split<SUI>(&mut coin_sui, fee, ctx));

        assert!(amount_sui_in >= amount_in_swap + fee, EInsufficientInput);

        let (coin_token_out, coin_sui_out) = swap<Token>(pool, coin::zero<Token>(ctx), coin_sui, actual_amount_out, amount_sui_in - amount_in_swap - fee, ctx);

        pool.virtual_token_reserves = pool.virtual_token_reserves - coin::value<Token>(&coin_token_out);

        transfer::public_transfer<Coin<SUI>>(coin_sui_out, ctx.sender());
        transfer::public_transfer<Coin<Token>>(coin_token_out, ctx.sender());

        let traded_event = TradedEventV2{
            is_buy                 : true,
            user                   : ctx.sender(),
            token_address          : type_name::into_string(token_address),
            sui_amount             : amount_in_swap,
            token_amount           : actual_amount_out,
            virtual_sui_reserves   : pool.virtual_sui_reserves,
            virtual_token_reserves : pool.virtual_token_reserves,
            real_sui_reserves      : coin::value<SUI>(&pool.real_sui_reserves),
            real_token_reserves    : coin::value<Token>(&pool.real_token_reserves),
            pool_id                : object::id(pool),
            fee                    : fee,
            ts                     : clock::timestamp_ms(clock),
        };
        emit<TradedEventV2>(traded_event);

        if (actual_amount_out == token_reserves_in_pool) {
            transfer_pool<Token>(configuration.admin, pool, cetus_burn_manager, cetus_pools, cetus_global_config, metadata_sui, clock, ctx);
        };
    }

    public entry fun buy_exact_in<Token>(configuration: &mut Configuration, coin_sui: Coin<SUI>, amount_in: u64, amount_out_min: u64, cetus_burn_manager: &mut BurnManager, cetus_pools: &mut Pools, cetus_global_config: &mut GlobalConfig, metadata_sui: &CoinMetadata<SUI>, clock: &Clock, ctx: &mut TxContext) {
        let (coin_sui_out, coin_token_out) = buy_exact_in_returns<Token>(configuration, coin_sui, amount_in, amount_out_min, cetus_burn_manager, cetus_pools, cetus_global_config, metadata_sui, clock, ctx);
        transfer::public_transfer<Coin<SUI>>(coin_sui_out, ctx.sender());
        transfer::public_transfer<Coin<Token>>(coin_token_out, ctx.sender());
    }

    fun buy_direct<Token>(admin: address, mut coin_sui: Coin<SUI>, pool: &mut Pool<Token>, amount_out: u64, platform_fee: u64, cetus_burn_manager: &mut BurnManager, cetus_pools: &mut Pools, cetus_global_config: &mut GlobalConfig, metadata_sui: &CoinMetadata<SUI>, clock: &Clock, ctx: &mut TxContext) {
        assert!(!pool.is_completed, ECompletedPool);
        assert!(amount_out > 0, EInvalidInput);

        let amount_sui_in = coin::value<SUI>(&coin_sui);
        let virtual_remain_token_reserves = get_virtual_remain_token_reserves(pool);
        let token_reserves_in_pool = pool.virtual_token_reserves - virtual_remain_token_reserves;
        let actual_amount_out = min(amount_out, token_reserves_in_pool);

        let amount_in_swap = curves::calculate_add_liquidity_cost(pool.virtual_sui_reserves, pool.virtual_token_reserves, actual_amount_out) + 1;
        let fee = utils::as_u64(utils::div(utils::mul(utils::from_u64(amount_in_swap), utils::from_u64(platform_fee)), utils::from_u64(FEE_DENOMINATOR)));
        assert!(amount_sui_in >= amount_in_swap + fee, EInsufficientInput);

        coin::join(&mut pool.fee_recipient, coin::split<SUI>(&mut coin_sui, fee, ctx));

        let (coin_token_out, coin_sui_out) = swap<Token>(pool, coin::zero<Token>(ctx), coin_sui, actual_amount_out, amount_sui_in - amount_in_swap - fee, ctx);

        pool.virtual_token_reserves = pool.virtual_token_reserves - coin::value<Token>(&coin_token_out);

        transfer::public_transfer<Coin<SUI>>(coin_sui_out, ctx.sender());
        transfer::public_transfer<Coin<Token>>(coin_token_out, ctx.sender());

        let traded_event = TradedEventV2{
            is_buy                 : true,
            user                   : ctx.sender(),
            token_address          : type_name::into_string(type_name::get<Token>()),
            sui_amount             : amount_in_swap,
            token_amount           : actual_amount_out,
            virtual_sui_reserves   : pool.virtual_sui_reserves,
            virtual_token_reserves : pool.virtual_token_reserves,
            real_sui_reserves      : coin::value<SUI>(&pool.real_sui_reserves),
            real_token_reserves    : coin::value<Token>(&pool.real_token_reserves),
            pool_id                : object::id(pool),
            fee                    : fee,
            ts                     : clock::timestamp_ms(clock),
        };
        emit<TradedEventV2>(traded_event);

        if (token_reserves_in_pool == actual_amount_out) {
            transfer_pool<Token>(admin, pool, cetus_burn_manager, cetus_pools, cetus_global_config, metadata_sui, clock, ctx);
        };
    }

    public fun buy_exact_out_returns<Token>(configuration: &mut Configuration, mut coin_sui: Coin<SUI>, amount_out: u64, cetus_burn_manager: &mut BurnManager, cetus_pools: &mut Pools, cetus_global_config: &mut GlobalConfig,  metadata_sui: &CoinMetadata<SUI>, clock: &Clock, ctx: &mut TxContext) : (Coin<SUI>, Coin<Token>) {
        assert_version(configuration.version);
        let token_address = type_name::get<Token>();
        let pool = dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut configuration.id, type_name::get_address(&token_address));
        assert!(!pool.is_completed, ECompletedPool);
        assert!(amount_out > 0, EInvalidInput);

        let virtual_remain_token_reserves = get_virtual_remain_token_reserves(pool);
        let token_reserves_in_pool = pool.virtual_token_reserves - virtual_remain_token_reserves;
        let actual_amount_out = min(amount_out, token_reserves_in_pool);

        let amount_sui_in = coin::value<SUI>(&coin_sui);
        let amount_in_swap = curves::calculate_add_liquidity_cost(pool.virtual_sui_reserves, pool.virtual_token_reserves, actual_amount_out) + 1;
        let fee = utils::as_u64(utils::div(utils::mul(utils::from_u64(amount_in_swap), utils::from_u64(configuration.platform_fee)), utils::from_u64(FEE_DENOMINATOR)));
        assert!(amount_sui_in >= amount_in_swap + fee, EInsufficientInput);

        coin::join(&mut pool.fee_recipient, coin::split<SUI>(&mut coin_sui, fee, ctx));

        let (coin_token_out, coin_sui_out) = swap<Token>(pool, coin::zero<Token>(ctx), coin_sui, actual_amount_out, amount_sui_in - amount_in_swap - fee, ctx);

        pool.virtual_token_reserves = pool.virtual_token_reserves - coin::value<Token>(&coin_token_out);

        let traded_event = TradedEventV2{
            is_buy                 : true,
            user                   : ctx.sender(),
            token_address          : type_name::into_string(token_address),
            sui_amount             : amount_in_swap,
            token_amount           : actual_amount_out,
            virtual_sui_reserves   : pool.virtual_sui_reserves,
            virtual_token_reserves : pool.virtual_token_reserves,
            real_sui_reserves      : coin::value<SUI>(&pool.real_sui_reserves),
            real_token_reserves    : coin::value<Token>(&pool.real_token_reserves),
            pool_id                : object::id<Pool<Token>>(pool),
            fee                    : fee,
            ts                     : clock::timestamp_ms(clock),
        };
        emit<TradedEventV2>(traded_event);

        if (token_reserves_in_pool == actual_amount_out) {
            transfer_pool<Token>(configuration.admin, pool, cetus_burn_manager, cetus_pools, cetus_global_config , metadata_sui, clock, ctx);
        };
        (coin_sui_out, coin_token_out)
    }

    public fun buy_exact_in_returns<Token>(configuration: &mut Configuration, mut coin_sui: Coin<SUI>, amount_in: u64, amount_out_min: u64, cetus_burn_manager: &mut BurnManager, cetus_pools: &mut Pools, cetus_global_config: &mut GlobalConfig, metadata_sui: &CoinMetadata<SUI>, clock: &Clock, ctx: &mut TxContext): (Coin<SUI>, Coin<Token>) {
        assert_version(configuration.version);
        let total_sui_in = coin::value<SUI>(&coin_sui);
        assert!(total_sui_in >= amount_in, EInsufficientInput);
        assert!(amount_in > 0, EInvalidInput);

        let token_address = type_name::get<Token>();
        let pool = dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut configuration.id, type_name::get_address(&token_address));

        assert!(!pool.is_completed, ECompletedPool);

        let amount_out_swap = curves::calculate_remove_liquidity_return(pool.virtual_sui_reserves, pool.virtual_token_reserves, amount_in);
        let token_reserves_in_pool = pool.virtual_token_reserves - get_virtual_remain_token_reserves(pool);
        
        let (actual_amount_out, amount_in_swap) = if (amount_out_swap > token_reserves_in_pool) {
            // When buying all remaining tokens, we need to recalculate the required SUI amount
            let actual_out = token_reserves_in_pool;
            let required_sui = curves::calculate_add_liquidity_cost(pool.virtual_sui_reserves, pool.virtual_token_reserves, actual_out) + 1;
            (actual_out, required_sui)
        } else {
            // Normal case, use the original amount_in
            (amount_out_swap, amount_in)
        };

        assert!(actual_amount_out >= amount_out_min, EInvalidInput);

        let fee = utils::as_u64(utils::div(utils::mul(utils::from_u64(amount_in_swap), utils::from_u64(configuration.platform_fee)), utils::from_u64(FEE_DENOMINATOR)));
        coin::join(&mut pool.fee_recipient, coin::split<SUI>(&mut coin_sui, fee, ctx));

        assert!(total_sui_in >= amount_in_swap + fee, EInsufficientInput);

        let (coin_token_out, coin_sui_out) = swap<Token>(pool, coin::zero<Token>(ctx), coin_sui, actual_amount_out, total_sui_in - amount_in_swap - fee, ctx);

        pool.virtual_token_reserves = pool.virtual_token_reserves - coin::value<Token>(&coin_token_out);

        let traded_event = TradedEventV2{
            is_buy                 : true,
            user                   : ctx.sender(),
            token_address          : type_name::into_string(token_address),
            sui_amount             : amount_in_swap,
            token_amount           : actual_amount_out,
            virtual_sui_reserves   : pool.virtual_sui_reserves,
            virtual_token_reserves : pool.virtual_token_reserves,
            real_sui_reserves      : coin::value<SUI>(&pool.real_sui_reserves),
            real_token_reserves    : coin::value<Token>(&pool.real_token_reserves),
            pool_id                : object::id(pool),
            fee                    : fee,
            ts                     : clock::timestamp_ms(clock),
        };
        emit<TradedEventV2>(traded_event);

        if (actual_amount_out == token_reserves_in_pool) {
            transfer_pool<Token>(configuration.admin, pool, cetus_burn_manager, cetus_pools, cetus_global_config, metadata_sui, clock, ctx);
        };
        (coin_sui_out, coin_token_out)
    }

    public fun check_pool_exist<Token>(configuration: &Configuration) : bool {
        let token_address = type_name::get<Token>();
        dynamic_object_field::exists_<String>(&configuration.id, type_name::get_address(&token_address))
    }

    public entry fun create_and_first_buy<Token>(
        _configuration: &mut Configuration,
        _stake_config: &mut StakeConfig,
        mut _treasury_cap: coin::TreasuryCap<Token>,
        _coin_sui: Coin<SUI>,
        _amount_out: u64,
        _threshold: Option<u64>,
        _clock: &Clock,
        _name: String,
        _symbol: String,
        _uri: String,
        _description: String,
        _twitter: String,
        _telegram: String,
        _website: String,
        _cetus_burn_manager: &mut BurnManager,
        _cetus_pools: &mut Pools,
        _cetus_global_config: &mut GlobalConfig,
        _metadata_sui: &CoinMetadata<SUI>,
        _metadata_token: CoinMetadata<Token>,
        _ctx: &mut TxContext
    ) {
        abort 0
    }

    public entry fun create_and_first_buy_v2<Token>(
        configuration: &mut Configuration,
        stake_config: &mut StakeConfig,
        mut treasury_cap: coin::TreasuryCap<Token>,
        bonding_dex: u8,
        coin_sui: Coin<SUI>,
        amount_out: u64,
        threshold: Option<u64>,
        clock: &Clock,
        name: String,
        symbol: String,
        uri: String,
        description: String,
        twitter: String,
        telegram: String,
        website: String,
        cetus_burn_manager: &mut BurnManager,
        cetus_pools: &mut Pools,
        cetus_global_config: &mut GlobalConfig,
        metadata_sui: &CoinMetadata<SUI>,
        metadata_token: CoinMetadata<Token>,
        ctx: &mut TxContext
    ) {
        assert!(ascii::length(&uri) <= 300, EInvalidInput);
        assert!(ascii::length(&description) <= 1000, EInvalidInput);
        assert!(ascii::length(&twitter) <= 500, EInvalidInput);
        assert!(ascii::length(&telegram) <= 500, EInvalidInput);
        assert!(ascii::length(&website) <= 500, EInvalidInput);

        assert_version(configuration.version);
        assert!(coin::total_supply<Token>(&treasury_cap) == 0, EExistTokenSupply);

        let threshold = option::get_with_default(&threshold, DEFAULT_THRESHOLD);
        assert!(threshold >= MINIMUM_THRESHOLD, EInvalidInput);

        let initial_virtual_sui_reserves = calculate_init_sui_reserves(configuration, threshold);

        let actual_virtual_token_reserves = utils::as_u64(
            utils::div(
                utils::mul(
                    utils::from_u64(configuration.initial_virtual_token_reserves),
                    utils::from_u64(configuration.initial_virtual_token_reserves)
                ),
                utils::from_u64(configuration.initial_virtual_token_reserves - configuration.remain_token_reserves)
            )
        );

        let mut pool = Pool<Token>{
            id                          : object::new(ctx),
            real_sui_reserves           : coin::zero<SUI>(ctx),
            real_token_reserves         : coin::mint<Token>(&mut treasury_cap, configuration.initial_virtual_token_reserves, ctx),
            virtual_token_reserves      : actual_virtual_token_reserves,
            virtual_sui_reserves        : initial_virtual_sui_reserves,
            remain_token_reserves       : coin::mint<Token>(&mut treasury_cap, configuration.remain_token_reserves, ctx),
            fee_recipient               : coin::zero<SUI>(ctx),
            is_completed                : false,
            platform_fee_withdraw       : configuration.init_platform_fee_withdraw,
            creator_fee_withdraw        : configuration.init_creator_fee_withdraw,
            stake_fee_withdraw          : configuration.init_stake_fee_withdraw,
            platform_stake_fee_withdraw : configuration.init_platform_stake_fee_withdraw,
            threshold                   : threshold,
        };

        // save to dynamic field due to can't change the field of obj while upgrade
        let virtual_remain_token_reserves = utils::as_u64(
            utils::div(
                utils::mul(
                    utils::from_u64(configuration.remain_token_reserves),
                    utils::from_u64(configuration.initial_virtual_token_reserves)
                ),
                utils::from_u64(configuration.initial_virtual_token_reserves - configuration.remain_token_reserves)
            )
        );
        dynamic_field::add(&mut pool.id,  VIRTUAL_TOKEN_RESERVES_FIELD, virtual_remain_token_reserves);
        dynamic_object_field::add(&mut pool.id, COIN_METADATA_FIELD, metadata_token);

        assert!(vector::contains(&BONDING_SUPPORT_DEXES, &bonding_dex), EInvalidInput);
        dynamic_field::add(&mut pool.id,  BONDING_DEX_FIELD, bonding_dex);

        let token_address = type_name::get<Token>();
        let pool_address = type_name::get<Pool<Token>>();
        let created_event = CreatedEventV2 {
            name                        : name,
            symbol                      : symbol,
            uri                         : uri,
            description                 : description,
            twitter                     : twitter,
            telegram                    : telegram,
            website                     : website,
            token_address               : type_name::into_string(token_address),
            bonding_curve               : type_name::get_module(&pool_address),
            pool_id                     : object::id<Pool<Token>>(&pool),
            created_by                  : ctx.sender(),
            virtual_sui_reserves        : pool.virtual_sui_reserves,
            virtual_token_reserves      : pool.virtual_token_reserves,
            real_sui_reserves           : coin::value<SUI>(&pool.real_sui_reserves),
            real_token_reserves         : coin::value<Token>(&pool.real_token_reserves),
            platform_fee_withdraw       : pool.platform_fee_withdraw,
            creator_fee_withdraw        : pool.creator_fee_withdraw,
            stake_fee_withdraw          : pool.stake_fee_withdraw,
            platform_stake_fee_withdraw : pool.platform_stake_fee_withdraw,
            bonding_dex                 : bonding_dex,
            threshold                   : threshold,
            ts                          : clock::timestamp_ms(clock),
        };

        transfer::public_transfer<coin::TreasuryCap<Token>>(treasury_cap, @0x0);

        if (coin::value<SUI>(&coin_sui) > 0) {
            buy_direct<Token>(configuration.admin, coin_sui, &mut pool, amount_out, configuration.platform_fee, cetus_burn_manager, cetus_pools, cetus_global_config, metadata_sui, clock, ctx);
        } else {
            coin::destroy_zero<SUI>(coin_sui);
        };

        dynamic_object_field::add<String, Pool<Token>>(&mut configuration.id, type_name::get_address(&token_address), pool);
        emit<CreatedEventV2>(created_event);

        moonbags_stake::initialize_staking_pool<Token>(stake_config, clock, ctx);
        moonbags_stake::initialize_creator_pool<Token>(stake_config, ctx.sender(), clock, ctx);
    }

    public entry fun create_threshold_config(_: &AdminCap, threshold: u64, ctx: &mut TxContext) {
        let threshold_config = ThresholdConfig{
            id        : object::new(ctx),
            threshold : threshold,
        };
        transfer::public_share_object<ThresholdConfig>(threshold_config);
    }

    public fun early_complete_pool<Token>(_: &AdminCap, configuration: &mut Configuration, threshold_config: &mut ThresholdConfig, clock: &Clock, ctx: &mut TxContext) {
        let token_address = type_name::get<Token>();
        let pool = dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut configuration.id, type_name::get_address(&token_address));
        pool.is_completed = true;

        let real_sui_reserves_amount = coin::value<SUI>(&pool.real_sui_reserves);
        let mut real_sui_coin = coin::split<SUI>(&mut pool.real_sui_reserves, real_sui_reserves_amount, ctx);

        let real_token_reserves = &pool.real_token_reserves;
        let remain_token_reserves = &pool.remain_token_reserves;

        let mut real_token_coin = coin::split<Token>(&mut pool.real_token_reserves, coin::value<Token>(real_token_reserves), ctx);
        assert!(real_sui_reserves_amount >= threshold_config.threshold, ENotEnoughThreshold);
        coin::join<Token>(&mut real_token_coin, coin::split<Token>(&mut pool.remain_token_reserves, coin::value<Token>(remain_token_reserves), ctx));
        if (real_sui_reserves_amount >= threshold_config.threshold) {
            transfer::public_transfer<Coin<SUI>>(coin::split<SUI>(&mut real_sui_coin, threshold_config.threshold, ctx), configuration.admin);
            transfer::public_transfer<Coin<Token>>(coin::split<Token>(&mut real_token_coin, configuration.remain_token_reserves, ctx), configuration.admin);
        };
        transfer::public_transfer<Coin<SUI>>(real_sui_coin, ctx.sender());
        transfer::public_transfer<Coin<Token>>(real_token_coin, ctx.sender());
        let pool_completed_event = PoolCompletedEventV2{
            token_address : type_name::into_string(type_name::get<Token>()),
            lp            : ascii::string(b"0x0"),
            ts            : clock::timestamp_ms(clock),
        };
        emit<PoolCompletedEventV2>(pool_completed_event);
    }

    public fun estimate_amount_out<Token>(configuration: &mut Configuration, amount_sui_in: u64, amount_token_in: u64) : (u64, u64) {
        let token_address = type_name::get<Token>();
        let pool = dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut configuration.id, type_name::get_address(&token_address));
        if (amount_sui_in > 0 && amount_token_in == 0) {
            (0, curves::calculate_token_amount_received(pool.virtual_sui_reserves, pool.virtual_token_reserves, amount_sui_in - utils::as_u64(utils::div(utils::mul(utils::from_u64(amount_sui_in), utils::from_u64(configuration.platform_fee)), utils::from_u64(FEE_DENOMINATOR)))))
        } else {
            let (amount_sui_out, amount_token_out) = if (amount_sui_in == 0 && amount_token_in > 0) {
                let amount_sui_out_with_fee = curves::calculate_remove_liquidity_return(pool.virtual_token_reserves, pool.virtual_sui_reserves, amount_token_in);
                (amount_sui_out_with_fee - utils::as_u64(utils::div(utils::mul(utils::from_u64(amount_sui_out_with_fee), utils::from_u64(configuration.platform_fee)), utils::from_u64(FEE_DENOMINATOR))), 0)
            } else {
                (0, 0)
            };
            (amount_sui_out, amount_token_out)
        }
    }

    public entry fun migrate_version(_: &AdminCap, configuration: &mut Configuration) {
        assert!(configuration.version < VERSION, ENotUpgrade);
        configuration.version = VERSION;
    }

    public entry fun sell<Token>(configuration: &mut Configuration, coin_token: Coin<Token>, amount_out_min: u64, clock: &Clock, ctx: &mut TxContext) {
        assert_version(configuration.version);
        let token_address = type_name::get<Token>();
        let pool = dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut configuration.id, type_name::get_address(&token_address));

        assert!(!pool.is_completed, ECompletedPool);
        let amount_in = coin::value<Token>(&coin_token);
        assert!(amount_in > 0, EInvalidInput);

        let mut amount_sui_out = curves::calculate_remove_liquidity_return(pool.virtual_token_reserves, pool.virtual_sui_reserves, amount_in);
        // cover last sell
        amount_sui_out = min(amount_sui_out, coin::value(&pool.real_sui_reserves));

        let fee = utils::as_u64(utils::div(utils::mul(utils::from_u64(amount_sui_out), utils::from_u64(configuration.platform_fee)), utils::from_u64(FEE_DENOMINATOR)));
        assert!(amount_sui_out - fee >= amount_out_min, EInvalidInput);
        let (coin_token_out, mut coin_sui_out) = swap<Token>(pool, coin_token, coin::zero<SUI>(ctx), 0, amount_sui_out, ctx);
        pool.virtual_sui_reserves = pool.virtual_sui_reserves - coin::value<SUI>(&coin_sui_out);

        coin::join(&mut pool.fee_recipient, coin::split<SUI>(&mut coin_sui_out, fee, ctx));

        transfer::public_transfer<Coin<SUI>>(coin_sui_out, ctx.sender());
        transfer::public_transfer<Coin<Token>>(coin_token_out, ctx.sender());

        let traded_event = TradedEventV2{
            is_buy                 : false,
            user                   : ctx.sender(),
            token_address          : type_name::into_string(token_address),
            sui_amount             : amount_sui_out,
            token_amount           : amount_in,
            virtual_sui_reserves   : pool.virtual_sui_reserves,
            virtual_token_reserves : pool.virtual_token_reserves,
            real_sui_reserves      : coin::value<SUI>(&pool.real_sui_reserves),
            real_token_reserves    : coin::value<Token>(&pool.real_token_reserves),
            pool_id                : object::id<Pool<Token>>(pool),
            fee                    : fee,
            ts                     : clock::timestamp_ms(clock),
        };
        emit<TradedEventV2>(traded_event);
    }

    public fun sell_returns<Token>(configuration: &mut Configuration, coin_token: Coin<Token>, amount_out_min: u64, clock: &Clock, ctx: &mut TxContext) : (Coin<SUI>, Coin<Token>) {
        assert_version(configuration.version);
        let token_address = type_name::get<Token>();
        let pool = dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut configuration.id, type_name::get_address(&token_address));

        assert!(!pool.is_completed, ECompletedPool);
        let amount_in = coin::value<Token>(&coin_token);
        assert!(amount_in > 0, EInvalidInput);

        let mut amount_sui_out = curves::calculate_remove_liquidity_return(pool.virtual_token_reserves, pool.virtual_sui_reserves, amount_in);
        // cover last sell
        amount_sui_out = min(amount_sui_out, coin::value(&pool.real_sui_reserves));

        let fee = utils::as_u64(utils::div(utils::mul(utils::from_u64(amount_sui_out), utils::from_u64(configuration.platform_fee)), utils::from_u64(FEE_DENOMINATOR)));
        assert!(amount_sui_out - fee >= amount_out_min, EInvalidInput);
        let (coin_token_out, mut coin_sui_out) = swap<Token>(pool, coin_token, coin::zero<SUI>(ctx), 0, amount_sui_out, ctx);
        pool.virtual_sui_reserves = pool.virtual_sui_reserves - coin::value<SUI>(&coin_sui_out);

        coin::join(&mut pool.fee_recipient, coin::split<SUI>(&mut coin_sui_out, fee, ctx));

        let traded_event = TradedEventV2{
            is_buy                 : false,
            user                   : ctx.sender(),
            token_address          : type_name::into_string(token_address),
            sui_amount             : amount_sui_out,
            token_amount           : amount_in,
            virtual_sui_reserves   : pool.virtual_sui_reserves,
            virtual_token_reserves : pool.virtual_token_reserves,
            real_sui_reserves      : coin::value<SUI>(&pool.real_sui_reserves),
            real_token_reserves    : coin::value<Token>(&pool.real_token_reserves),
            pool_id                : object::id<Pool<Token>>(pool),
            fee                    : fee,
            ts                     : clock::timestamp_ms(clock),
        };
        emit<TradedEventV2>(traded_event);
        (coin_sui_out, coin_token_out)
    }

    public fun skim<Token>(_: &AdminCap, configuration: &mut Configuration, ctx: &mut TxContext) {
        let token_address = type_name::get<Token>();
        let pool = dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut configuration.id, type_name::get_address(&token_address));
        assert!(pool.is_completed, ECompletedPool);

        let real_token_reserves = &pool.real_token_reserves;
        let real_sui_reserves = &pool.real_sui_reserves;

        transfer::public_transfer<Coin<SUI>>(coin::split<SUI>(&mut pool.real_sui_reserves, coin::value<SUI>(real_sui_reserves), ctx), ctx.sender());
        transfer::public_transfer<Coin<Token>>(coin::split<Token>(&mut pool.real_token_reserves, coin::value<Token>(real_token_reserves), ctx), ctx.sender());
    }

    public entry fun transfer_admin(admin_cap: AdminCap, configuration: &mut Configuration, new_admin: address, clock: &Clock, ctx: &mut TxContext) {
        configuration.admin = new_admin;
        transfer::transfer(admin_cap, new_admin);

        let ownership_transferred_event = OwnershipTransferredEventV2 {
            old_admin : ctx.sender(),
            new_admin : new_admin,
            ts        : clock::timestamp_ms(clock),
        };
        emit<OwnershipTransferredEventV2>(ownership_transferred_event);
    }

    public entry fun update_fee_recipients(
        _: &AdminCap,
        configuration: &mut Configuration,
        new_treasury: address,
        new_fee_platform_recipient: address,
    ) {
        configuration.treasury = new_treasury;
        configuration.fee_platform_recipient = new_fee_platform_recipient;
    }

    public entry fun update_initial_virtual_token_reserves(
        _: &AdminCap,
        configuration: &mut Configuration,
        new_initial_virtual_token_reserves: u64,
    ) {
        configuration.initial_virtual_token_reserves = new_initial_virtual_token_reserves;
    }

    fun get_virtual_remain_token_reserves<Token>(pool: &Pool<Token>): u64 {
        if (dynamic_field::exists_(&pool.id, VIRTUAL_TOKEN_RESERVES_FIELD)) {
            *dynamic_field::borrow<vector<u8>, u64>(&pool.id, VIRTUAL_TOKEN_RESERVES_FIELD)
        } else {
            coin::value(&pool.remain_token_reserves) // hardcode use for v1
        }
    }

    fun transfer_pool<Token>(admin: address, pool: &mut Pool<Token>, cetus_burn_manager: &mut BurnManager, cetus_pools: &mut Pools, cetus_global_config: &mut GlobalConfig, metadata_sui: &CoinMetadata<SUI>, clock: &Clock, ctx: &mut TxContext) {
        pool.is_completed = true;

        let real_token_reserves = &pool.real_token_reserves;
        let remain_token_reserves = &pool.remain_token_reserves;
        let real_sui_reserves = &pool.real_sui_reserves;

        let mut coin_token = coin::split<Token>(&mut pool.real_token_reserves, coin::value<Token>(real_token_reserves), ctx);
        coin::join<Token>(&mut coin_token, coin::split<Token>(&mut pool.remain_token_reserves, coin::value<Token>(remain_token_reserves), ctx));

        let coin_sui = coin::split<SUI>(&mut pool.real_sui_reserves, coin::value<SUI>(real_sui_reserves), ctx);

        let pool_completed_event = PoolCompletedEventV2 {
            token_address : type_name::into_string(type_name::get<Token>()),
            lp            : ascii::string(b"0x0"),
            ts            : clock::timestamp_ms(clock),
        };
        emit<PoolCompletedEventV2>(pool_completed_event);

        let bonding_dex_exists = dynamic_field::exists_<vector<u8>>(&pool.id, BONDING_DEX_FIELD);
        let bonding_dex = if (bonding_dex_exists) {
            dynamic_field::borrow<vector<u8>, u8>(&pool.id, BONDING_DEX_FIELD)
        } else {
            &TURBOS_DEX
        };

        emit<PoolMigratingEvent>(PoolMigratingEvent {
            token_address   : type_name::into_string(type_name::get<Token>()),
            sui_amount      : coin::value<SUI>(&coin_sui),
            token_amount    : coin::value<Token>(&coin_token),
            bonding_dex     : *bonding_dex,
            ts              : clock::timestamp_ms(clock),
        });

        if (bonding_dex == CETUS_DEX) {
            init_cetus_pool<Token>(
                admin, coin_sui, coin_token,
                pool, cetus_burn_manager, cetus_pools,
                cetus_global_config, metadata_sui, clock, ctx
            );
        } else {
            // for turbos finance
            transfer::public_transfer<Coin<Token>>(coin_token, admin);
            transfer::public_transfer<Coin<SUI>>(coin_sui, admin);
        };

        // Make coin metadata token publicly accessible to anyone
        let metadata_token = dynamic_object_field::remove<vector<u8>, CoinMetadata<Token>>(&mut pool.id, COIN_METADATA_FIELD);
        transfer::public_freeze_object(metadata_token);
    }

    fun calculate_init_sui_reserves(configuration: &Configuration, threshold: u64) : u64 {
        let remain_token_reserves = configuration.remain_token_reserves;
        let initial_virtual_token_reserves = configuration.initial_virtual_token_reserves;

        assert!(initial_virtual_token_reserves > remain_token_reserves, EInvalidInput);

        utils::as_u64(
            utils::div(
                utils::mul(
                    utils::from_u64(threshold),
                    utils::from_u64(remain_token_reserves)
                ),
                utils::from_u64(initial_virtual_token_reserves - remain_token_reserves)
            )
        )
    }

    public entry fun update_config(
        _: &AdminCap,
        configuration: &mut Configuration,
        new_platform_fee: u64,
        new_initial_virtual_token_reserves: u64,
        new_remain_token_reserves: u64,
        new_token_decimals: u8,
        new_init_platform_fee_withdraw: u16,
        new_init_creator_fee_withdraw: u16,
        new_init_stake_fee_withdraw: u16,
        new_init_platform_stake_fee_withdraw: u16,
        new_token_platform_type_name: String,
        clock: &Clock
    ) {
        assert!((new_init_platform_fee_withdraw + new_init_creator_fee_withdraw + new_init_stake_fee_withdraw + new_init_platform_stake_fee_withdraw) as u64 <= FEE_DENOMINATOR, EInvalidInput);

        let config_changed_event = ConfigChangedEventV2 {
            old_platform_fee                        : configuration.platform_fee,
            new_platform_fee                        : new_platform_fee,
            old_initial_virtual_token_reserves      : configuration.initial_virtual_token_reserves,
            new_initial_virtual_token_reserves      : new_initial_virtual_token_reserves,
            old_remain_token_reserves               : configuration.remain_token_reserves,
            new_remain_token_reserves               : new_remain_token_reserves,
            old_token_decimals                      : configuration.token_decimals,
            new_token_decimals                      : new_token_decimals,
            old_init_platform_fee_withdraw          : configuration.init_platform_fee_withdraw,
            new_init_platform_fee_withdraw          : new_init_platform_fee_withdraw,
            old_init_creator_fee_withdraw           : configuration.init_creator_fee_withdraw,
            new_init_creator_fee_withdraw           : new_init_creator_fee_withdraw,
            old_init_stake_fee_withdraw             : configuration.init_stake_fee_withdraw,
            new_init_stake_fee_withdraw             : new_init_stake_fee_withdraw,
            old_init_platform_stake_fee_withdraw    : configuration.init_platform_stake_fee_withdraw,
            new_init_platform_stake_fee_withdraw    : new_init_platform_stake_fee_withdraw,
            old_token_platform_type_name            : configuration.token_platform_type_name,
            new_token_platform_type_name            : new_token_platform_type_name,
            ts                                      : clock::timestamp_ms(clock),
        };

        configuration.platform_fee = new_platform_fee;
        configuration.initial_virtual_token_reserves = new_initial_virtual_token_reserves;
        configuration.remain_token_reserves = new_remain_token_reserves;
        configuration.token_decimals = new_token_decimals;
        configuration.init_platform_fee_withdraw = new_init_platform_fee_withdraw;
        configuration.init_creator_fee_withdraw = new_init_creator_fee_withdraw;
        configuration.init_stake_fee_withdraw = new_init_stake_fee_withdraw;
        configuration.init_platform_stake_fee_withdraw = new_init_platform_stake_fee_withdraw;
        configuration.token_platform_type_name = new_token_platform_type_name;

        emit<ConfigChangedEventV2>(config_changed_event);
    }

    public entry fun update_threshold_config(_: &AdminCap, threshold_config: &mut ThresholdConfig, new_threshold: u64) {
        threshold_config.threshold = new_threshold;
    }

    /*
     * explanation of some magic numbers:
     * cetus tick bound is (-443636, 443636)
     * tick spacing is 200 (1%)
     * tick_upper_idx = 443636 - 443636 % 200 = 443600 (full range)
     * sqrt(340282366920938463463374607431768211456) = sqrt(2**128) = 2**64 (Q64)
     */
    public entry fun init_cetus_pool<Token>(admin: address, coin_sui: Coin<SUI>, coin_token: Coin<Token>, pool: &mut Pool<Token>, cetus_burn_manager: &mut BurnManager, cetus_pools: &mut Pools, cetus_config: &mut GlobalConfig, metadata_sui: &CoinMetadata<SUI>, clock: &Clock, ctx: &mut TxContext) {
        let token_amount = coin::value<Token>(&coin_token) as u256;
        let sui_amount = coin::value<SUI>(&coin_sui) as u256;
        let metadata_token = dynamic_object_field::borrow(&pool.id, COIN_METADATA_FIELD);

        let icon_url = if (coin::get_icon_url<Token>(metadata_token).is_some()) {
            coin::get_icon_url<Token>(metadata_token).extract().inner_url().to_string()
        } else {
            string::utf8(b"")
        };

        let (position, coin_token, coin_sui) = pool_creator::create_pool_v2<Token, SUI>(
            cetus_config, cetus_pools, 200, sqrt(340282366920938463463374607431768211456 * sui_amount / token_amount),
            icon_url, 4294523696, 443600,
            coin_token, coin_sui, metadata_token, metadata_sui,
            true, clock, ctx
        );
        let burn_proof = lp_burn::burn_lp_v2(cetus_burn_manager, position, ctx);
        dynamic_object_field::add(&mut pool.id, BURN_PROOF_FIELD, burn_proof);
        transfer::public_transfer<Coin<Token>>(coin_token, admin);
        transfer::public_transfer<Coin<SUI>>(coin_sui, admin);
    }

    public fun burn_turbos_position_nft<Token, CoinTypeA, CoinTypeB, FeeType>(
        turbos_pool: &mut TurbosPool<CoinTypeA, CoinTypeB, FeeType>,
        bonding_curve_config: &mut Configuration,
        positions: &mut TurbosPositions,
        position_nft: TurbosPositionNFT,
        versioned: &TurbosVersioned,
        ctx: &mut TxContext
    ) {
        assert_version(bonding_curve_config.version);
        
        // Validate that one coin type is Token and the other is SUI
        let token_type = type_name::into_string(type_name::get<Token>());
        let coinA_type = type_name::into_string(type_name::get<CoinTypeA>());
        let coinB_type = type_name::into_string(type_name::get<CoinTypeB>());
        let sui_type = type_name::into_string(type_name::get<SUI>());
        
        assert!(
            (coinA_type == token_type && coinB_type == sui_type) || 
            (coinA_type == sui_type && coinB_type == token_type),
            EInvalidInput
        );
        
        let token_address = type_name::get_address(&type_name::get<Token>());
        let pool = dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut bonding_curve_config.id, token_address);
        
        assert!(pool.is_completed, EInvalidWithdrawPool);
        assert!(!dynamic_field::exists_(&pool.id, BURN_PROOF_TURBOS_FIELD), EInvalidInput);

        let burn_proof = turbos_clmm::position_manager::burn_position_nft_with_return_<CoinTypeA, CoinTypeB, FeeType>(
            turbos_pool,
            positions,
            position_nft,
            versioned,
            ctx
        );
        
        dynamic_object_field::add(&mut pool.id, BURN_PROOF_TURBOS_FIELD, burn_proof);
    }

    public fun withdraw_fee_bonding_curve<Token, PlatformToken>(bonding_curve_config: &mut Configuration, stake_config: &mut StakeConfig, clock: &Clock, ctx: &mut TxContext) {
        assert_version(bonding_curve_config.version);
        let platform_token_type_name = type_name::into_string(type_name::get<PlatformToken>());
        assert!(platform_token_type_name == bonding_curve_config.token_platform_type_name, EInsufficientInput);

        let token_address = type_name::get_address(&type_name::get<Token>());
        let pool = dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut bonding_curve_config.id, token_address);
        
        distribute_fees<Token, PlatformToken>(pool, bonding_curve_config.fee_platform_recipient, stake_config, clock, ctx);
    }

    public fun withdraw_fee_cetus<Token, PlatformToken>(
        bonding_curve_config: &mut Configuration, 
        stake_config: &mut StakeConfig, 
        cetus_burn_manager: &mut BurnManager,
        cetus_config: &GlobalConfig, 
        cetus_pool: &mut CetusPool<Token, SUI>, 
        clock: &Clock, 
        ctx: &mut TxContext
    ) {
        assert_version(bonding_curve_config.version);
        let platform_token_type_name = type_name::into_string(type_name::get<PlatformToken>());
        assert!(platform_token_type_name == bonding_curve_config.token_platform_type_name, EInsufficientInput);

        let token_address = type_name::get_address(&type_name::get<Token>());
        let pool = dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut bonding_curve_config.id, token_address);

        assert!(pool.is_completed, EInvalidWithdrawPool);
        assert!(dynamic_object_field::exists_(&pool.id, BURN_PROOF_FIELD), EInvalidWithdrawPool);

        let burn_proof = dynamic_object_field::borrow_mut(&mut pool.id, BURN_PROOF_FIELD);
        let (token_coin, sui_coin) = lp_burn::collect_fee<Token, SUI>(
            cetus_burn_manager,
            cetus_config, 
            cetus_pool, 
            burn_proof,
            ctx
        );

        transfer::public_transfer<Coin<Token>>(token_coin, bonding_curve_config.treasury); // token fee to address for now
        coin::join(&mut pool.fee_recipient, sui_coin);
        
        distribute_fees<Token, PlatformToken>(pool, bonding_curve_config.fee_platform_recipient, stake_config, clock, ctx);
    }

    public fun withdraw_fee_turbos_sui_after<Token, PlatformToken, FeeType>(
        bonding_curve_config: &mut Configuration,
        stake_config: &mut StakeConfig,
        turbos_pool: &mut TurbosPool<Token, SUI, FeeType>,
        turbos_positions: &mut TurbosPositions,  
        max_amount_token_a: u64,                        
        max_amount_token_b: u64,
        deadline: u64,
        clock: &Clock,
        versioned: &TurbosVersioned,
        ctx: &mut TxContext
    ) {
        assert_version(bonding_curve_config.version);
        let platform_token_type_name = type_name::into_string(type_name::get<PlatformToken>());
        assert!(platform_token_type_name == bonding_curve_config.token_platform_type_name, EInsufficientInput);

        let token_address = type_name::get_address(&type_name::get<Token>());
        let pool = dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut bonding_curve_config.id, token_address);

        assert!(pool.is_completed, EInvalidWithdrawPool);
        assert!(dynamic_object_field::exists_(&pool.id, BURN_PROOF_TURBOS_FIELD), EInvalidWithdrawPool);

        let burn_nft = dynamic_object_field::borrow_mut(&mut pool.id, BURN_PROOF_TURBOS_FIELD);
        let (token_coin, sui_coin) = turbos_clmm::position_manager::burn_nft_collect_fee_with_return_(turbos_pool, turbos_positions, burn_nft, max_amount_token_a, max_amount_token_b, deadline, clock, versioned, ctx);

        transfer::public_transfer<Coin<Token>>(token_coin, bonding_curve_config.treasury); // token fee to address for now
        coin::join(&mut pool.fee_recipient, sui_coin);
        
        distribute_fees<Token, PlatformToken>(pool, bonding_curve_config.fee_platform_recipient, stake_config, clock, ctx);
    }

    public fun withdraw_fee_turbos_sui_first<Token, PlatformToken, FeeType>(
        bonding_curve_config: &mut Configuration,
        stake_config: &mut StakeConfig,
        turbos_pool: &mut TurbosPool<SUI, Token, FeeType>,
        turbos_positions: &mut TurbosPositions,  
        max_amount_token_a: u64,                        
        max_amount_token_b: u64,
        deadline: u64,
        clock: &Clock,
        versioned: &TurbosVersioned,
        ctx: &mut TxContext
    ) {
        assert_version(bonding_curve_config.version);
        let platform_token_type_name = type_name::into_string(type_name::get<PlatformToken>());
        assert!(platform_token_type_name == bonding_curve_config.token_platform_type_name, EInsufficientInput);

        let token_address = type_name::get_address(&type_name::get<Token>());
        let pool = dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut bonding_curve_config.id, token_address);

        assert!(pool.is_completed, EInvalidWithdrawPool);
        assert!(dynamic_object_field::exists_(&pool.id, BURN_PROOF_TURBOS_FIELD), EInvalidWithdrawPool);

        let burn_nft = dynamic_object_field::borrow_mut(&mut pool.id, BURN_PROOF_TURBOS_FIELD);
        let (sui_coin, token_coin) = turbos_clmm::position_manager::burn_nft_collect_fee_with_return_(turbos_pool, turbos_positions, burn_nft, max_amount_token_a, max_amount_token_b, deadline, clock, versioned, ctx);

        transfer::public_transfer<Coin<Token>>(token_coin, bonding_curve_config.treasury); // token fee to address for now
        coin::join(&mut pool.fee_recipient, sui_coin);
        
        distribute_fees<Token, PlatformToken>(pool, bonding_curve_config.fee_platform_recipient, stake_config, clock, ctx);
    }

    // Helper function to distribute fees to different stakeholders
    fun distribute_fees<Token, PlatformToken>(
        pool: &mut Pool<Token>,
        admin_platform_fee: address,
        stake_config: &mut StakeConfig,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let fee_amount = coin::value(&pool.fee_recipient);
        // Return early to prevent excessive function calls, threshold FEE_DENOMINATOR prevent division to zero
        if (fee_amount <= FEE_DENOMINATOR) {
            return
        };

        let platform_share = utils::as_u64(utils::div(utils::mul(utils::from_u64(fee_amount), utils::from_u64(pool.platform_fee_withdraw as u64)), utils::from_u64(FEE_DENOMINATOR)));
        let creator_share = utils::as_u64(utils::div(utils::mul(utils::from_u64(fee_amount), utils::from_u64(pool.creator_fee_withdraw as u64)), utils::from_u64(FEE_DENOMINATOR)));
        let stake_share = utils::as_u64(utils::div(utils::mul(utils::from_u64(fee_amount), utils::from_u64(pool.stake_fee_withdraw as u64)), utils::from_u64(FEE_DENOMINATOR)));
        let platform_stake_share = utils::as_u64(utils::div(utils::mul(utils::from_u64(fee_amount), utils::from_u64(pool.platform_stake_fee_withdraw as u64)), utils::from_u64(FEE_DENOMINATOR)));

        assert!(platform_share + creator_share + stake_share + platform_stake_share <= fee_amount, EInvalidWithdrawAmount);

        let platform_coin = coin::split(&mut pool.fee_recipient, platform_share, ctx);
        transfer::public_transfer(platform_coin, admin_platform_fee);

        let creator_coin = coin::split(&mut pool.fee_recipient, creator_share, ctx);
        moonbags_stake::deposit_creator_pool<Token>(stake_config, creator_coin, clock, ctx);

        let stake_coin = coin::split(&mut pool.fee_recipient, stake_share, ctx);
        moonbags_stake::update_reward_index<Token>(stake_config, stake_coin, clock, ctx);

        let platform_stake_coin = coin::split(&mut pool.fee_recipient, platform_stake_share, ctx);
        moonbags_stake::update_reward_index<PlatformToken>(stake_config, platform_stake_coin, clock, ctx);
    }

    fun sqrt(number: u256) : u128 {
        assert!(number > 0, EInvalidInput);
        let mut result = number;
        let mut next_estimate = (number + 1) / 2;
        while (next_estimate < result) {
            result = next_estimate;
            let sum = next_estimate + number / next_estimate;
            next_estimate = sum / 2;
        };
        result as u128
    }

    #[test_only]
    public(package) fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test_only]
    public(package) fun create_pool_for_withdraw_fee_testing<Token>(configuration: &mut Configuration, mut treasury_cap: coin::TreasuryCap<Token>, fee_recipient: Coin<SUI>,ctx: &mut TxContext) {
        let pool = Pool<Token> {
            id                          : object::new(ctx),
            real_sui_reserves           : coin::zero<SUI>(ctx),
            real_token_reserves         : coin::mint<Token>(&mut treasury_cap, configuration.initial_virtual_token_reserves - configuration.remain_token_reserves, ctx),
            virtual_token_reserves      : configuration.initial_virtual_token_reserves,
            virtual_sui_reserves        : calculate_init_sui_reserves(configuration, DEFAULT_THRESHOLD),
            remain_token_reserves       : coin::mint<Token>(&mut treasury_cap, configuration.remain_token_reserves, ctx),
            fee_recipient               : fee_recipient,
            is_completed                : false,
            platform_fee_withdraw       : configuration.init_platform_fee_withdraw,
            creator_fee_withdraw        : configuration.init_creator_fee_withdraw,
            stake_fee_withdraw          : configuration.init_stake_fee_withdraw,
            platform_stake_fee_withdraw : configuration.init_platform_stake_fee_withdraw,
            threshold                   : DEFAULT_THRESHOLD,
        };

        dynamic_object_field::add<String, Pool<Token>>(
            &mut configuration.id,
            type_name::get_address(&type_name::get<Token>()),
            pool
        );

        transfer::public_transfer(treasury_cap, ctx.sender());
    }

    #[test_only]
    public(package) fun update_config_for_testing(configuration: &mut Configuration, token_platform_type_name: String) {
        configuration.token_platform_type_name = token_platform_type_name;
    }

    #[test_only]
    public(package) fun get_config_value_for_testing(configuration: &Configuration) : (u16, u16, u16, u16) {
        (
            configuration.init_platform_fee_withdraw,
            configuration.init_creator_fee_withdraw,
            configuration.init_stake_fee_withdraw,
            configuration.init_platform_stake_fee_withdraw
        )
    }

    #[test_only]
    public(package) fun join_sui_for_testing<Token>(pool: &mut Pool<Token>, coin_sui: Coin<SUI>) {
        pool.virtual_sui_reserves = pool.virtual_sui_reserves + coin::value(&coin_sui);
        coin::join(&mut pool.real_sui_reserves, coin_sui);
    }

    #[test_only]
    public(package) fun borrow_mut_pool<Token>(configuration: &mut Configuration): &mut Pool<Token> {
        let token_address = type_name::get<Token>();
        dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut configuration.id, type_name::get_address(&token_address))
    }

    #[test_only]
    public(package) fun get_pool_info_for_testing<Token>(configuration: &Configuration) : (u64, u64, u64, u64, bool, u64) {
        let token_address = type_name::get<Token>();
        let pool = dynamic_object_field::borrow<String, Pool<Token>>(&configuration.id, type_name::get_address(&token_address));
        
        (
            coin::value(&pool.real_sui_reserves),
            coin::value(&pool.real_token_reserves),
            pool.virtual_sui_reserves,
            pool.virtual_token_reserves,
            pool.is_completed,
            coin::value(&pool.fee_recipient)
        )
    }

    // @notion: Mimic of the function `buy_exact_out` for testing purposes
    #[test_only]
    public(package) fun buy_exact_out_without_init_cetus<Token>(configuration: &mut Configuration, mut coin_sui: Coin<SUI>, amount_out: u64, ctx: &mut TxContext) {
        assert_version(configuration.version);

        let token_address = type_name::get<Token>();
        let pool = dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut configuration.id, type_name::get_address(&token_address));

        assert!(!pool.is_completed, ECompletedPool);
        assert!(amount_out > 0, EInvalidInput);

        let amount_sui_in = coin::value<SUI>(&coin_sui);
        let virtual_remain_token_reserves = get_virtual_remain_token_reserves(pool);
        let token_reserves_in_pool = pool.virtual_token_reserves - virtual_remain_token_reserves;
        let actual_amount_out = min(amount_out, token_reserves_in_pool);

        let amount_in_swap = curves::calculate_add_liquidity_cost(pool.virtual_sui_reserves, pool.virtual_token_reserves, actual_amount_out) + 1;
        let fee = utils::as_u64(utils::div(utils::mul(utils::from_u64(amount_in_swap), utils::from_u64(configuration.platform_fee)), utils::from_u64(FEE_DENOMINATOR)));

        coin::join(&mut pool.fee_recipient, coin::split<SUI>(&mut coin_sui, fee, ctx));

        assert!(amount_sui_in >= amount_in_swap + fee, EInsufficientInput);

        let (coin_token_out, coin_sui_out) = swap<Token>(pool, coin::zero<Token>(ctx), coin_sui, actual_amount_out, amount_sui_in - amount_in_swap - fee, ctx);

        pool.virtual_token_reserves = pool.virtual_token_reserves - coin::value<Token>(&coin_token_out);

        transfer::public_transfer<Coin<SUI>>(coin_sui_out, ctx.sender());
        transfer::public_transfer<Coin<Token>>(coin_token_out, ctx.sender());

        if (actual_amount_out == token_reserves_in_pool) {
            transfer_pool_without_init_cetus<Token>(configuration.admin, pool, ctx);
        };
    }

    // @notion: Mimic of the function `transfer_pool` for testing purposes
    #[test_only]
    fun transfer_pool_without_init_cetus<Token>(admin: address, pool: &mut Pool<Token>, ctx: &mut TxContext) {
        pool.is_completed = true;

        let real_token_reserves = &pool.real_token_reserves;
        let remain_token_reserves = &pool.remain_token_reserves;
        let real_sui_reserves = &pool.real_sui_reserves;

        let mut coin_token = coin::split<Token>(&mut pool.real_token_reserves, coin::value<Token>(real_token_reserves), ctx);
        coin::join<Token>(&mut coin_token, coin::split<Token>(&mut pool.remain_token_reserves, coin::value<Token>(remain_token_reserves), ctx));

        let coin_sui = coin::split<SUI>(&mut pool.real_sui_reserves, coin::value<SUI>(real_sui_reserves), ctx);

        // Transfer the remaining coins to the admin
        transfer::public_transfer<Coin<Token>>(coin_token, admin);
        transfer::public_transfer<Coin<SUI>>(coin_sui, admin);
    }
}

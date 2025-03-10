#[allow(lint(self_transfer))]
module moonbags::moonbags {
    use std::ascii::{Self, String};
    use std::string;
    use std::type_name;
    use std::u64::min;

    use sui::sui::SUI;
    use sui::coin::{Self, Coin, CoinMetadata};
    use sui::dynamic_object_field;
    use sui::event::emit;
    use sui::clock::{Clock, Self};

    use moonbags::curves;
    use moonbags::utils;
    use moonbags::moonbags_stake::{Self, Configuration as StakeConfig};

    use cetus_clmm::factory::Pools;
    use cetus_clmm::pool_creator::Self;
    use cetus_clmm::config::GlobalConfig;
    use cetus_clmm::position::Position;
    use cetus_clmm::pool::{Self, Pool as CetusPool};

    const DEFAULT_THRESHOLD: u64 = 3000000000; // 3 SUI
    const MINIMUM_THRESHOLD: u64 = 2000000000; // 2 SUI
    const VERSION: u64 = 1;

    // const ENotHavePermission: u64 = 1;
    const EInvalidInput: u64 = 2;
    const EWrongVersion: u64 = 4;
    const ECompletedPool: u64 = 5;
    const EInsufficientInput: u64 = 6;
    const EExistTokenSupply: u64 = 7;
    const ENotUpgrade: u64 = 10;
    const EInvalidWithdrawPool: u64 = 11;
    const EInvalidWithdrawAmount: u64 = 12;

    public struct AdminCap has key {
        id: UID,
    }

    public struct Configuration has store, key {
        id: UID,
        version: u64,
        admin: address,
        platform_fee: u64,
        graduated_fee: u64,
        initial_virtual_sui_reserves: u64,
        initial_virtual_token_reserves: u64,
        remain_token_reserves: u64,
        token_decimals: u8,
        platform_fee_withdraw: u16,
        creator_fee_withdraw: u16,
        stake_fee_withdraw: u16,
        platform_stake_fee_withdraw: u16,
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
        threshold: u64,
        fee_recipient: Coin<SUI>,
        position_graduated: Option<Position>,
        is_completed: bool,
    }

    public struct ConfigChangedEvent has copy, drop, store {
        old_platform_fee: u64,
        new_platform_fee: u64,
        old_graduated_fee: u64,
        new_graduated_fee: u64,
        old_initial_virtual_sui_reserves: u64,
        new_initial_virtual_sui_reserves: u64,
        old_initial_virtual_token_reserves: u64,
        new_initial_virtual_token_reserves: u64,
        old_remain_token_reserves: u64,
        new_remain_token_reserves: u64,
        old_token_decimals: u8,
        new_token_decimals: u8,
        old_platform_fee_withdraw: u16,
        new_platform_fee_withdraw: u16,
        old_creator_fee_withdraw: u16,
        new_creator_fee_withdraw: u16,
        old_stake_fee_withdraw: u16,
        new_stake_fee_withdraw: u16,
        old_platform_stake_fee_withdraw: u16,
        new_platform_stake_fee_withdraw: u16,
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
        pool_id: ID,
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
            platform_fee: 50,
            graduated_fee: 750, // 7,5%
            initial_virtual_sui_reserves: 3000000000, // 3 sui
            initial_virtual_token_reserves: 10000000000000000,
            remain_token_reserves: 2000000000000000,
            token_decimals: 6,
            platform_fee_withdraw: 1500,        // 15% to platform
            creator_fee_withdraw: 3000,         // 30% to creator
            stake_fee_withdraw: 3500,           // 35% to stakers
            platform_stake_fee_withdraw: 2000,  // 20% to platform stakers
            token_platform_type_name: b"edd50618685ad1e4ccaf1a7d8b793a4ea1551df8a6210f27d659b85ef1c4c901::shro::SHRO".to_ascii_string(),
        };
        transfer::public_share_object<Configuration>(configuration);

        transfer::transfer(admin, ctx.sender());
    }

    public entry fun create<Token>(
        configuration: &mut Configuration,
        stake_config: &mut StakeConfig,
        mut treasury_cap: coin::TreasuryCap<Token>,
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

        let pool = Pool<Token>{
            id                     : object::new(ctx),
            real_sui_reserves      : coin::zero<SUI>(ctx),
            real_token_reserves    : coin::mint<Token>(&mut treasury_cap, configuration.initial_virtual_token_reserves - configuration.remain_token_reserves, ctx),
            virtual_token_reserves : configuration.initial_virtual_token_reserves,
            virtual_sui_reserves   : configuration.initial_virtual_sui_reserves,
            remain_token_reserves  : coin::mint<Token>(&mut treasury_cap, configuration.remain_token_reserves, ctx),
            threshold              : threshold,
            fee_recipient          : coin::zero<SUI>(ctx),
            position_graduated     : option::none(),
            is_completed           : false,
        };

        transfer::public_transfer<coin::TreasuryCap<Token>>(treasury_cap, @0x0);

        let token_address = type_name::get<Token>();
        let pool_address = type_name::get<Pool<Token>>();

        let created_event = CreatedEvent{
            name                   : name,
            symbol                 : symbol,
            uri                    : uri,
            description            : description,
            twitter                : twitter,
            telegram               : telegram,
            website                : website,
            token_address          : type_name::into_string(token_address),
            bonding_curve          : type_name::get_module(&pool_address),
            pool_id                : object::id<Pool<Token>>(&pool),
            created_by             : ctx.sender(),
            virtual_sui_reserves   : configuration.initial_virtual_sui_reserves,
            virtual_token_reserves : configuration.initial_virtual_token_reserves,
            threshold              : pool.threshold,
            ts                     : clock::timestamp_ms(clock),
        };
        dynamic_object_field::add<String, Pool<Token>>(&mut configuration.id, type_name::get_address(&token_address), pool);
        emit<CreatedEvent>(created_event);

        moonbags_stake::initialize_staking_pool<Token>(stake_config, clock, ctx);
        moonbags_stake::initialize_creator_pool<Token>(stake_config, ctx.sender(), clock, ctx);
    }

    fun swap<Token>(pool: &mut Pool<Token>, coin_token: Coin<Token>, coin_sui: Coin<SUI>, amount_token_out: u64, amount_sui_out: u64, ctx: &mut TxContext) : (Coin<Token>, Coin<SUI>) {
        let before_virtual_token_reserves = pool.virtual_token_reserves;
        let before_virtual_sui_reserves = pool.virtual_sui_reserves;

        assert!(coin::value<Token>(&coin_token) > 0 || coin::value<SUI>(&coin_sui) > 0, EInvalidInput);

        if (coin::value<Token>(&coin_token) > 0) {
            pool.virtual_token_reserves = pool.virtual_token_reserves - amount_token_out;
        };
        if (coin::value<SUI>(&coin_sui) > 0) {
            pool.virtual_sui_reserves = pool.virtual_sui_reserves - amount_sui_out;
        };

        pool.virtual_token_reserves = pool.virtual_token_reserves + coin::value<Token>(&coin_token);
        pool.virtual_sui_reserves = pool.virtual_sui_reserves + coin::value<SUI>(&coin_sui);

        assert_lp_value_is_increased_or_not_changed(before_virtual_token_reserves, before_virtual_sui_reserves, pool.virtual_token_reserves, pool.virtual_sui_reserves);

        coin::join<Token>(&mut pool.real_token_reserves, coin_token);
        coin::join<SUI>(&mut pool.real_sui_reserves, coin_sui);

        (coin::split<Token>(&mut pool.real_token_reserves, amount_token_out, ctx), coin::split<SUI>(&mut pool.real_sui_reserves, amount_sui_out, ctx))
    }

    public fun assert_pool_not_completed<Token>(configuration: &Configuration) {
        let token_address = type_name::get<Token>();
        assert!(dynamic_object_field::borrow<String, Pool<Token>>(&configuration.id, type_name::get_address(&token_address)).is_completed, 9);
    }

    fun assert_lp_value_is_increased_or_not_changed(before_token_reserves: u64, before_sui_reserves: u64, after_token_reserves: u64, after_sui_reserves: u64) {
        assert!((before_token_reserves as u128) * (before_sui_reserves as u128) <= (after_token_reserves as u128) * (after_sui_reserves as u128), 2);
    }

    fun assert_version(version: u64) {
        assert!(version == VERSION, EWrongVersion);
    }

    public entry fun buy_exact_out<Token>(configuration: &mut Configuration, mut coin_sui: Coin<SUI>, amount_out: u64, cetus_pools: &mut Pools, cetus_global_config: &mut GlobalConfig, metadata_sui: &CoinMetadata<SUI>, metadata_token: &CoinMetadata<Token>, clock: &Clock, ctx: &mut TxContext) {
        assert_version(configuration.version);

        let token_address = type_name::get<Token>();
        let pool = dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut configuration.id, type_name::get_address(&token_address));

        assert!(!pool.is_completed, ECompletedPool);
        assert!(amount_out > 0, EInvalidInput);

        let amount_sui_in = coin::value<SUI>(&coin_sui);
        let token_reserves_in_pool = pool.virtual_token_reserves - coin::value<Token>(&pool.remain_token_reserves);
        let actual_amount_out = min(amount_out, token_reserves_in_pool);

        let amount_in_swap = curves::calculate_add_liquidity_cost(pool.virtual_sui_reserves, pool.virtual_token_reserves, actual_amount_out) + 1;
        let fee = utils::as_u64(utils::div(utils::mul(utils::from_u64(amount_in_swap), utils::from_u64(configuration.platform_fee)), utils::from_u64(10000)));

        coin::join(&mut pool.fee_recipient, coin::split<SUI>(&mut coin_sui, fee, ctx));

        assert!(amount_sui_in >= amount_in_swap + fee, EInsufficientInput);

        let (coin_token_out, coin_sui_out) = swap<Token>(pool, coin::zero<Token>(ctx), coin_sui, actual_amount_out, amount_sui_in - amount_in_swap - fee, ctx);

        pool.virtual_token_reserves = pool.virtual_token_reserves - coin::value<Token>(&coin_token_out);

        transfer::public_transfer<Coin<SUI>>(coin_sui_out, ctx.sender());
        transfer::public_transfer<Coin<Token>>(coin_token_out, ctx.sender());

        if (actual_amount_out == token_reserves_in_pool || coin::value<SUI>(&pool.real_sui_reserves) >= pool.threshold) {
            transfer_pool<Token>(configuration.admin, configuration.graduated_fee,  pool, cetus_pools, cetus_global_config, metadata_sui, metadata_token, clock, ctx);
        };
        let traded_event = TradedEvent{
            is_buy                 : true,
            user                   : ctx.sender(),
            token_address          : type_name::into_string(token_address),
            sui_amount             : amount_in_swap,
            token_amount           : actual_amount_out,
            virtual_sui_reserves   : pool.virtual_sui_reserves,
            virtual_token_reserves : pool.virtual_token_reserves,
            pool_id                : object::id(pool),
            ts                     : clock::timestamp_ms(clock),
        };
        emit<TradedEvent>(traded_event);
    }

    public entry fun buy_exact_in<Token>(configuration: &mut Configuration, mut coin_sui: Coin<SUI>, cetus_pools: &mut Pools, cetus_global_config: &mut GlobalConfig, metadata_sui: &CoinMetadata<SUI>, metadata_token: &CoinMetadata<Token>, clock: &Clock, ctx: &mut TxContext) {
        assert_version(configuration.version);
        let amount_sui_in = coin::value<SUI>(&coin_sui);

        let token_address = type_name::get<Token>();
        let pool = dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut configuration.id, type_name::get_address(&token_address));

        let fee = utils::as_u64(utils::div(utils::mul(utils::from_u64(amount_sui_in), utils::from_u64(configuration.platform_fee)), utils::from_u64(10000)));

        coin::join(&mut pool.fee_recipient, coin::split<SUI>(&mut coin_sui, fee, ctx));

        let amount_in_swap = amount_sui_in - fee;

        assert!(!pool.is_completed, ECompletedPool);
        assert!(amount_sui_in > 0, EInvalidInput);
        let token_reserves_in_pool = pool.virtual_token_reserves - coin::value<Token>(&pool.remain_token_reserves);

        let amount_out_swap = curves::calculate_remove_liquidity_return(pool.virtual_sui_reserves, pool.virtual_token_reserves, amount_in_swap) - 1;
        let actual_token_amount_out = min(amount_out_swap, token_reserves_in_pool);
        let actual_sui_amount_in = curves::calculate_add_liquidity_cost(pool.virtual_sui_reserves, pool.virtual_token_reserves, actual_token_amount_out) + 1;
        assert!(amount_sui_in >= amount_in_swap + fee, EInsufficientInput);

        let sui_amount_remain = amount_in_swap - actual_sui_amount_in;

        let (coin_token_out, coin_sui_out) = swap<Token>(pool, coin::zero<Token>(ctx), coin_sui, actual_token_amount_out, sui_amount_remain, ctx);

        pool.virtual_token_reserves = pool.virtual_token_reserves - coin::value<Token>(&coin_token_out);

        transfer::public_transfer<Coin<SUI>>(coin_sui_out, ctx.sender());
        transfer::public_transfer<Coin<Token>>(coin_token_out, ctx.sender());

        if (actual_token_amount_out == token_reserves_in_pool || coin::value<SUI>(&pool.real_sui_reserves) >= pool.threshold) {
            transfer_pool<Token>(configuration.admin, configuration.graduated_fee ,pool, cetus_pools, cetus_global_config, metadata_sui, metadata_token, clock, ctx);
        };
        let traded_event = TradedEvent{
            is_buy                 : true,
            user                   : ctx.sender(),
            token_address          : type_name::into_string(token_address),
            sui_amount             : actual_sui_amount_in,
            token_amount           : actual_token_amount_out,
            virtual_sui_reserves   : pool.virtual_sui_reserves,
            virtual_token_reserves : pool.virtual_token_reserves,
            pool_id                : object::id(pool),
            ts                     : clock::timestamp_ms(clock),
        };
        emit<TradedEvent>(traded_event);
    }

    fun buy_direct<Token>(admin: address, graduated_fee: u64, mut coin_sui: Coin<SUI>, pool: &mut Pool<Token>, amount_out: u64, platform_fee: u64, cetus_pools: &mut Pools, cetus_global_config: &mut GlobalConfig, metadata_sui: &CoinMetadata<SUI>, metadata_token: &CoinMetadata<Token>, clock: &Clock, ctx: &mut TxContext) {
        assert!(!pool.is_completed, ECompletedPool);
        assert!(amount_out > 0, EInvalidInput);

        let amount_sui_in = coin::value<SUI>(&coin_sui);
        let token_reserves_in_pool = pool.virtual_token_reserves - coin::value<Token>(&pool.remain_token_reserves);
        let actual_amount_out = min(amount_out, token_reserves_in_pool);

        let amount_in_swap = curves::calculate_add_liquidity_cost(pool.virtual_sui_reserves, pool.virtual_token_reserves, actual_amount_out) + 1;
        let fee = utils::as_u64(utils::div(utils::mul(utils::from_u64(amount_in_swap), utils::from_u64(platform_fee)), utils::from_u64(10000)));
        assert!(amount_sui_in >= amount_in_swap + fee, EInsufficientInput);

        coin::join(&mut pool.fee_recipient, coin::split<SUI>(&mut coin_sui, fee, ctx));

        let (coin_token_out, coin_sui_out) = swap<Token>(pool, coin::zero<Token>(ctx), coin_sui, actual_amount_out, amount_sui_in - amount_in_swap - fee, ctx);

        pool.virtual_token_reserves = pool.virtual_token_reserves - coin::value<Token>(&coin_token_out);

        transfer::public_transfer<Coin<SUI>>(coin_sui_out, ctx.sender());
        transfer::public_transfer<Coin<Token>>(coin_token_out, ctx.sender());

        if (token_reserves_in_pool == actual_amount_out || coin::value<SUI>(&pool.real_sui_reserves) >= pool.threshold) {
            transfer_pool<Token>(admin, graduated_fee, pool, cetus_pools, cetus_global_config, metadata_sui, metadata_token, clock, ctx);
        };
        let traded_event = TradedEvent{
            is_buy                 : true,
            user                   : ctx.sender(),
            token_address          : type_name::into_string(type_name::get<Token>()),
            sui_amount             : amount_in_swap,
            token_amount           : actual_amount_out,
            virtual_sui_reserves   : pool.virtual_sui_reserves,
            virtual_token_reserves : pool.virtual_token_reserves,
            pool_id                : object::id(pool),
            ts                     : clock::timestamp_ms(clock),
        };
        emit<TradedEvent>(traded_event);
    }

    public fun buy_exact_out_returns<Token>(configuration: &mut Configuration, mut coin_sui: Coin<SUI>, amount_out: u64, cetus_pools: &mut Pools, cetus_global_config: &mut GlobalConfig,  metadata_sui: &CoinMetadata<SUI>, metadata_token: &CoinMetadata<Token>, clock: &Clock, ctx: &mut TxContext) : (Coin<SUI>, Coin<Token>) {
        assert_version(configuration.version);
        let token_address = type_name::get<Token>();
        let pool = dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut configuration.id, type_name::get_address(&token_address));
        assert!(!pool.is_completed, ECompletedPool);
        assert!(amount_out > 0, EInvalidInput);

        let token_reserves_in_pool = pool.virtual_token_reserves - coin::value<Token>(&pool.remain_token_reserves);
        let actual_amount_out = min(amount_out, token_reserves_in_pool);

        let amount_sui_in = coin::value<SUI>(&coin_sui);
        let amount_in_swap = curves::calculate_add_liquidity_cost(pool.virtual_sui_reserves, pool.virtual_token_reserves, actual_amount_out) + 1;
        let fee = utils::as_u64(utils::div(utils::mul(utils::from_u64(amount_in_swap), utils::from_u64(configuration.platform_fee)), utils::from_u64(10000)));
        assert!(amount_sui_in >= amount_in_swap + fee, EInsufficientInput);

        coin::join(&mut pool.fee_recipient, coin::split<SUI>(&mut coin_sui, fee, ctx));

        let (coin_token_out, coin_sui_out) = swap<Token>(pool, coin::zero<Token>(ctx), coin_sui, actual_amount_out, amount_sui_in - amount_in_swap - fee, ctx);

        pool.virtual_token_reserves = pool.virtual_token_reserves - coin::value<Token>(&coin_token_out);

        if (token_reserves_in_pool == actual_amount_out || coin::value<SUI>(&pool.real_sui_reserves) >= pool.threshold) {
            transfer_pool<Token>(configuration.admin, configuration.graduated_fee, pool, cetus_pools, cetus_global_config , metadata_sui, metadata_token, clock, ctx);
        };
        let traded_event = TradedEvent{
            is_buy                 : true,
            user                   : ctx.sender(),
            token_address          : type_name::into_string(token_address),
            sui_amount             : amount_in_swap,
            token_amount           : actual_amount_out,
            virtual_sui_reserves   : pool.virtual_sui_reserves,
            virtual_token_reserves : pool.virtual_token_reserves,
            pool_id                : object::id<Pool<Token>>(pool),
            ts                     : clock::timestamp_ms(clock),
        };
        emit<TradedEvent>(traded_event);
        (coin_sui_out, coin_token_out)
    }

    public fun buy_exact_in_returns<Token>(configuration: &mut Configuration, mut coin_sui: Coin<SUI>, cetus_pools: &mut Pools, cetus_global_config: &mut GlobalConfig, metadata_sui: &CoinMetadata<SUI>, metadata_token: &CoinMetadata<Token>, clock: &Clock, ctx: &mut TxContext) : (Coin<SUI>, Coin<Token>) {
        assert_version(configuration.version);
        let amount_sui_in = coin::value<SUI>(&coin_sui);

        let token_address = type_name::get<Token>();
        let pool = dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut configuration.id, type_name::get_address(&token_address));

        let fee = utils::as_u64(utils::div(utils::mul(utils::from_u64(amount_sui_in), utils::from_u64(configuration.platform_fee)), utils::from_u64(10000)));

        coin::join(&mut pool.fee_recipient, coin::split<SUI>(&mut coin_sui, fee, ctx));

        let amount_in_swap = amount_sui_in - fee;

        assert!(!pool.is_completed, ECompletedPool);
        assert!(amount_sui_in > 0, EInvalidInput);
        let token_reserves_in_pool = pool.virtual_token_reserves - coin::value<Token>(&pool.remain_token_reserves);

        let amount_out_swap = curves::calculate_remove_liquidity_return(pool.virtual_sui_reserves, pool.virtual_token_reserves, amount_in_swap);
        let actual_amount_out = min(amount_out_swap, token_reserves_in_pool);
        let actual_amount_in = curves::calculate_add_liquidity_cost(pool.virtual_sui_reserves, pool.virtual_token_reserves, actual_amount_out) + 1;
        assert!(amount_sui_in >= amount_in_swap + fee, EInsufficientInput);

        let (coin_token_out, coin_sui_out) = swap<Token>(pool, coin::zero<Token>(ctx), coin_sui, actual_amount_out, amount_sui_in - actual_amount_in - fee, ctx);

        if (actual_amount_out == token_reserves_in_pool || coin::value<SUI>(&pool.real_sui_reserves) >= pool.threshold) {
            transfer_pool<Token>(configuration.admin, configuration.graduated_fee, pool, cetus_pools, cetus_global_config, metadata_sui, metadata_token, clock, ctx);
        };
        let traded_event = TradedEvent{
            is_buy                 : true,
            user                   : ctx.sender(),                                                 
            token_address          : type_name::into_string(token_address),
            sui_amount             : actual_amount_in,
            token_amount           : actual_amount_out,
            virtual_sui_reserves   : pool.virtual_sui_reserves,
            virtual_token_reserves : pool.virtual_token_reserves,
            pool_id                : object::id(pool),
            ts                     : clock::timestamp_ms(clock),
        };
        emit<TradedEvent>(traded_event);
        (coin_sui_out, coin_token_out)
    }

    public fun check_pool_exist<Token>(configuration: &Configuration) : bool {
        let token_address = type_name::get<Token>();
        dynamic_object_field::exists_<String>(&configuration.id, type_name::get_address(&token_address))
    }

    public entry fun create_and_first_buy<Token>(
        configuration: &mut Configuration,
        stake_config: &mut StakeConfig,
        mut treasury_cap: coin::TreasuryCap<Token>,
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
        cetus_pools: &mut Pools, 
        cetus_global_config: &mut GlobalConfig,
        metadata_sui: &CoinMetadata<SUI>,
        metadata_token: &CoinMetadata<Token>,
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

        let mut pool = Pool<Token>{
            id                     : object::new(ctx),
            real_sui_reserves      : coin::zero<SUI>(ctx),
            real_token_reserves    : coin::mint<Token>(&mut treasury_cap, configuration.initial_virtual_token_reserves - configuration.remain_token_reserves, ctx),
            virtual_token_reserves : configuration.initial_virtual_token_reserves,
            virtual_sui_reserves   : configuration.initial_virtual_sui_reserves,
            remain_token_reserves  : coin::mint<Token>(&mut treasury_cap, configuration.remain_token_reserves, ctx),
            threshold              : threshold,
            fee_recipient          : coin::zero<SUI>(ctx),
            position_graduated     : option::none(),
            is_completed           : false,
        };

        transfer::public_transfer<coin::TreasuryCap<Token>>(treasury_cap, @0x0);

        let token_address = type_name::get<Token>();
        if (coin::value<SUI>(&coin_sui) > 0) {
            buy_direct<Token>(configuration.admin, configuration.graduated_fee, coin_sui, &mut pool, amount_out, configuration.platform_fee, cetus_pools, cetus_global_config, metadata_sui, metadata_token, clock, ctx);
        } else {
            coin::destroy_zero<SUI>(coin_sui);
        };
        let pool_address = type_name::get<Pool<Token>>();

        let created_event = CreatedEvent{
            name                   : name,
            symbol                 : symbol,
            uri                    : uri,
            description            : description,
            twitter                : twitter,
            telegram               : telegram,
            website                : website,
            token_address          : type_name::into_string(token_address),
            bonding_curve          : type_name::get_module(&pool_address),
            pool_id                : object::id<Pool<Token>>(&pool),
            created_by             : ctx.sender(),
            virtual_sui_reserves   : configuration.initial_virtual_sui_reserves,
            virtual_token_reserves : configuration.initial_virtual_token_reserves,
            threshold              : pool.threshold,
            ts                     : clock::timestamp_ms(clock),
        };
        dynamic_object_field::add<String, Pool<Token>>(&mut configuration.id, type_name::get_address(&token_address), pool);
        emit<CreatedEvent>(created_event);

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
        assert!(real_sui_reserves_amount >= threshold_config.threshold, 3);
        coin::join<Token>(&mut real_token_coin, coin::split<Token>(&mut pool.remain_token_reserves, coin::value<Token>(remain_token_reserves), ctx));
        if (real_sui_reserves_amount >= threshold_config.threshold) {
            transfer::public_transfer<Coin<SUI>>(coin::split<SUI>(&mut real_sui_coin, threshold_config.threshold, ctx), configuration.admin);
            transfer::public_transfer<Coin<Token>>(coin::split<Token>(&mut real_token_coin, configuration.remain_token_reserves, ctx), configuration.admin);
        };
        transfer::public_transfer<Coin<SUI>>(real_sui_coin, ctx.sender());
        transfer::public_transfer<Coin<Token>>(real_token_coin, ctx.sender());
        let pool_completed_event = PoolCompletedEvent{
            token_address : type_name::into_string(type_name::get<Token>()),
            lp            : ascii::string(b"0x0"),
            ts            : clock::timestamp_ms(clock),
        };
        emit<PoolCompletedEvent>(pool_completed_event);
    }

    public fun estimate_amount_out<Token>(configuration: &mut Configuration, amount_sui_in: u64, amount_token_in: u64) : (u64, u64) {
        let token_address = type_name::get<Token>();
        let pool = dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut configuration.id, type_name::get_address(&token_address));
        if (amount_sui_in > 0 && amount_token_in == 0) {
            (0, curves::calculate_token_amount_received(pool.virtual_sui_reserves, pool.virtual_token_reserves, amount_sui_in - utils::as_u64(utils::div(utils::mul(utils::from_u64(amount_sui_in), utils::from_u64(configuration.platform_fee)), utils::from_u64(10000)))))
        } else {
            let (amount_sui_out, amount_token_out) = if (amount_sui_in == 0 && amount_token_in > 0) {
                let amount_sui_out_with_fee = curves::calculate_remove_liquidity_return(pool.virtual_token_reserves, pool.virtual_sui_reserves, amount_token_in);
                (amount_sui_out_with_fee - utils::as_u64(utils::div(utils::mul(utils::from_u64(amount_sui_out_with_fee), utils::from_u64(configuration.platform_fee)), utils::from_u64(10000))), 0)
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

        let amount_sui_out = curves::calculate_remove_liquidity_return(pool.virtual_token_reserves, pool.virtual_sui_reserves, amount_in);
        let fee = utils::as_u64(utils::div(utils::mul(utils::from_u64(amount_sui_out), utils::from_u64(configuration.platform_fee)), utils::from_u64(10000)));
        assert!(amount_sui_out - fee >= amount_out_min, 2);
        let (coin_token_out, mut coin_sui_out) = swap<Token>(pool, coin_token, coin::zero<SUI>(ctx), 0, amount_sui_out, ctx);
        pool.virtual_sui_reserves = pool.virtual_sui_reserves - coin::value<SUI>(&coin_sui_out);

        coin::join(&mut pool.fee_recipient, coin::split<SUI>(&mut coin_sui_out, fee, ctx));

        transfer::public_transfer<Coin<SUI>>(coin_sui_out, ctx.sender());
        transfer::public_transfer<Coin<Token>>(coin_token_out, ctx.sender());

        let traded_event = TradedEvent{
            is_buy                 : false,
            user                   : ctx.sender(),
            token_address          : type_name::into_string(token_address),
            sui_amount             : amount_sui_out,
            token_amount           : amount_in,
            virtual_sui_reserves   : pool.virtual_sui_reserves,
            virtual_token_reserves : pool.virtual_token_reserves,
            pool_id                : object::id<Pool<Token>>(pool),
            ts                     : clock::timestamp_ms(clock),
        };
        emit<TradedEvent>(traded_event);
    }

    public fun sell_returns<Token>(configuration: &mut Configuration, coin_token: Coin<Token>, amount_out_min: u64, clock: &Clock, ctx: &mut TxContext) : (Coin<SUI>, Coin<Token>) {
        assert_version(configuration.version);
        let token_address = type_name::get<Token>();
        let pool = dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut configuration.id, type_name::get_address(&token_address));

        assert!(!pool.is_completed, ECompletedPool);
        let amount_in = coin::value<Token>(&coin_token);
        assert!(amount_in > 0, EInvalidInput);

        let amount_sui_out = curves::calculate_remove_liquidity_return(pool.virtual_token_reserves, pool.virtual_sui_reserves, amount_in);
        let fee = utils::as_u64(utils::div(utils::mul(utils::from_u64(amount_sui_out), utils::from_u64(configuration.platform_fee)), utils::from_u64(10000)));
        assert!(amount_sui_out - fee >= amount_out_min, 2);
        let (coin_token_out, mut coin_sui_out) = swap<Token>(pool, coin_token, coin::zero<SUI>(ctx), 0, amount_sui_out, ctx);
        pool.virtual_sui_reserves = pool.virtual_sui_reserves - coin::value<SUI>(&coin_sui_out);

        coin::join(&mut pool.fee_recipient, coin::split<SUI>(&mut coin_sui_out, fee, ctx));

        let traded_event = TradedEvent{
            is_buy                 : false,
            user                   : ctx.sender(),
            token_address          : type_name::into_string(token_address),
            sui_amount             : amount_sui_out,
            token_amount           : amount_in,
            virtual_sui_reserves   : pool.virtual_sui_reserves,
            virtual_token_reserves : pool.virtual_token_reserves,
            pool_id                : object::id<Pool<Token>>(pool),
            ts                     : clock::timestamp_ms(clock),
        };
        emit<TradedEvent>(traded_event);
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

        let ownership_transferred_event = OwnershipTransferredEvent{
            old_admin : ctx.sender(),
            new_admin : new_admin,
            ts        : clock::timestamp_ms(clock),
        };
        emit<OwnershipTransferredEvent>(ownership_transferred_event);
    }

    fun transfer_pool<Token>(admin: address, graduated_fee: u64, pool: &mut Pool<Token>, cetus_pools: &mut Pools, cetus_global_config: &mut GlobalConfig, metadata_sui: &CoinMetadata<SUI>, metadata_token: &CoinMetadata<Token>, clock: &Clock, ctx: &mut TxContext) {
        pool.is_completed = true;

        let real_token_reserves = &pool.real_token_reserves;
        let remain_token_reserves = &pool.remain_token_reserves;
        let real_sui_reserves = &pool.real_sui_reserves;

        let mut coin_token = coin::split<Token>(&mut pool.real_token_reserves, coin::value<Token>(real_token_reserves), ctx);
        coin::join<Token>(&mut coin_token, coin::split<Token>(&mut pool.remain_token_reserves, coin::value<Token>(remain_token_reserves), ctx));

        let mut coin_sui = coin::split<SUI>(&mut pool.real_sui_reserves, coin::value<SUI>(real_sui_reserves), ctx);

        let sui_graduated_fee = utils::as_u64(utils::div(utils::mul(utils::from_u64(coin::value<SUI>(&coin_sui)), utils::from_u64(graduated_fee)), utils::from_u64(10000)));
        transfer::public_transfer<Coin<SUI>>(coin::split<SUI>(&mut coin_sui, sui_graduated_fee, ctx), admin);

        let pool_completed_event = PoolCompletedEvent{
            token_address : type_name::into_string(type_name::get<Token>()),
            lp            : ascii::string(b"0x0"),
            ts            : clock::timestamp_ms(clock),
        };
        emit<PoolCompletedEvent>(pool_completed_event);

        init_cetus_pool<Token>(admin, coin_sui, coin_token, pool, cetus_pools, cetus_global_config, metadata_sui, metadata_token, clock, ctx);
    }

    public entry fun update_config(
        _: &AdminCap, 
        configuration: &mut Configuration, 
        new_platform_fee: u64, 
        new_graduated_fee: u64, 
        new_initial_virtual_sui_reserves: u64, 
        new_initial_virtual_token_reserves: u64, 
        new_remain_token_reserves: u64, 
        new_token_decimals: u8, 
        new_platform_fee_withdraw: u16,
        new_creator_fee_withdraw: u16,
        new_stake_fee_withdraw: u16,
        new_platform_stake_fee_withdraw: u16,
        new_token_platform_type_name: String,
        clock: &Clock
    ) {
        let config_changed_event = ConfigChangedEvent {
            old_platform_fee                   : configuration.platform_fee,
            new_platform_fee                   : new_platform_fee,
            old_graduated_fee                  : configuration.graduated_fee,
            new_graduated_fee                  : new_graduated_fee,
            old_initial_virtual_sui_reserves   : configuration.initial_virtual_sui_reserves,
            new_initial_virtual_sui_reserves   : new_initial_virtual_sui_reserves,
            old_initial_virtual_token_reserves : configuration.initial_virtual_token_reserves,
            new_initial_virtual_token_reserves : new_initial_virtual_token_reserves,
            old_remain_token_reserves          : configuration.remain_token_reserves,
            new_remain_token_reserves          : new_remain_token_reserves,
            old_token_decimals                 : configuration.token_decimals,
            new_token_decimals                 : new_token_decimals,
            old_platform_fee_withdraw          : configuration.platform_fee_withdraw,
            new_platform_fee_withdraw          : new_platform_fee_withdraw,
            old_creator_fee_withdraw           : configuration.creator_fee_withdraw,
            new_creator_fee_withdraw           : new_creator_fee_withdraw,
            old_stake_fee_withdraw             : configuration.stake_fee_withdraw,
            new_stake_fee_withdraw             : new_stake_fee_withdraw,
            old_platform_stake_fee_withdraw    : configuration.platform_stake_fee_withdraw,
            new_platform_stake_fee_withdraw    : new_platform_stake_fee_withdraw,
            old_token_platform_type_name       : configuration.token_platform_type_name,
            new_token_platform_type_name       : new_token_platform_type_name,
            ts                                 : clock::timestamp_ms(clock),
        };

        configuration.platform_fee = new_platform_fee;
        configuration.graduated_fee = new_graduated_fee;
        configuration.initial_virtual_sui_reserves = new_initial_virtual_sui_reserves;
        configuration.initial_virtual_token_reserves = new_initial_virtual_token_reserves;
        configuration.remain_token_reserves = new_remain_token_reserves;
        configuration.token_decimals = new_token_decimals;
        configuration.platform_fee_withdraw = new_platform_fee_withdraw;
        configuration.creator_fee_withdraw = new_creator_fee_withdraw;
        configuration.stake_fee_withdraw = new_stake_fee_withdraw;       
        configuration.platform_stake_fee_withdraw = new_platform_stake_fee_withdraw; 
        configuration.token_platform_type_name = new_token_platform_type_name;

        emit<ConfigChangedEvent>(config_changed_event);
    }

    public entry fun update_threshold_config(_: &AdminCap, threshold_config: &mut ThresholdConfig, new_threshold: u64) {
        threshold_config.threshold = new_threshold;
    }

    /*
     * explanation of some magic numbers:
     * cetus tick bound is (-443636, 443636)
     * standard tick spacing is 60
     * tick_upper_idx = 443636 - 443636 % 60 = 443580
     * sqrt(340282366920938463463374607431768211456) = sqrt(2**128) = 2**64 (Q64)
     */
    public entry fun init_cetus_pool<Token>(admin: address, coin_sui: Coin<SUI>, coin_token: Coin<Token>, pool: &mut Pool<Token>, cetus_pools: &mut Pools, cetus_config: &mut GlobalConfig, metadata_sui: &CoinMetadata<SUI>, metadata_token: &CoinMetadata<Token>, clock: &Clock, ctx: &mut TxContext) {
        let token_amount = coin::value<Token>(&coin_token) as u256;
        let sui_amount = coin::value<SUI>(&coin_sui) as u256;
        let token_name = type_name::into_string(type_name::get<Token>());
        let token_name_bytes = *ascii::as_bytes(&token_name);
        let sui_name = type_name::into_string(type_name::get<SUI>());
        let sui_name_bytes = *ascii::as_bytes(&sui_name);
        let mut i = 0;
        let mut is_token_first = false;
        while (i < vector::length<u8>(&token_name_bytes)) {
            let sui_name_byte = *vector::borrow<u8>(&sui_name_bytes, i);
            let token_name_byte = *vector::borrow<u8>(&token_name_bytes, i);
            if (token_name_byte < sui_name_byte) {
                is_token_first = false;
                break
            };
            if (token_name_byte > sui_name_byte) {
                is_token_first = true;
                break
            };
            i = i + 1;
        };
        if (is_token_first) {
            let (position, coin_token, coin_sui) = pool_creator::create_pool_v2<Token, SUI>(
                cetus_config, cetus_pools, 60, sqrt(340282366920938463463374607431768211456 * sui_amount / token_amount),
                string::utf8(b""), 4294523716, 443580,
                coin_token, coin_sui, metadata_token, metadata_sui,
                true, clock, ctx
            );
            option::fill(&mut pool.position_graduated, position);
            transfer::public_transfer<Coin<Token>>(coin_token, admin);
            transfer::public_transfer<Coin<SUI>>(coin_sui, admin);
        } else {
            let (position, coin_sui, coin_token) = pool_creator::create_pool_v2<SUI, Token>(
                cetus_config, cetus_pools, 60, sqrt(340282366920938463463374607431768211456 * token_amount / sui_amount),
                string::utf8(b""), 4294523716, 443580, 
                coin_sui, coin_token, metadata_sui, metadata_token, 
                false, clock, ctx
            );
            option::fill(&mut pool.position_graduated, position);
            transfer::public_transfer<Coin<SUI>>(coin_sui, admin);
            transfer::public_transfer<Coin<Token>>(coin_token, admin);
        };
    }

    // support TOKEN and SUI
    public fun withdraw_fee<Token, PlatformToken>(bonding_curve_config: &mut Configuration, stake_config: &mut StakeConfig, cetus_config: &GlobalConfig, cetus_pool: &mut Option<CetusPool<Token, SUI>>, clock: &Clock, ctx: &mut TxContext) {
        let token_address = type_name::get_address(&type_name::get<Token>());
        let pool = dynamic_object_field::borrow_mut<String, Pool<Token>>(&mut bonding_curve_config.id, token_address);

        // claim fee after graduating
        if (cetus_pool.is_some()) {
            assert!(pool.is_completed, EInvalidWithdrawPool);
            assert!(pool.position_graduated.is_some(), EInvalidWithdrawPool);

            let (token_fee_balance, sui_fee_balance) = pool::collect_fee<Token, SUI>(
                cetus_config, option::borrow_mut(cetus_pool), option::borrow(&pool.position_graduated), true
            );

            let token_coin = coin::from_balance(token_fee_balance, ctx);
            transfer::public_transfer<Coin<Token>>(token_coin, bonding_curve_config.admin); // token fee to admin for now

            coin::join(&mut pool.fee_recipient, coin::from_balance(sui_fee_balance, ctx));
        };

        let fee_amount = coin::value(&pool.fee_recipient);
        assert!(fee_amount > 0, EInsufficientInput);

        let platform_token_type_name = type_name::into_string(type_name::get<PlatformToken>());
        assert!(platform_token_type_name == bonding_curve_config.token_platform_type_name, EInsufficientInput);

        let platform_share = utils::as_u64(utils::div(utils::mul(utils::from_u64(fee_amount), utils::from_u64(bonding_curve_config.platform_fee_withdraw as u64)), utils::from_u64(10000)));    
        let creator_share = utils::as_u64(utils::div(utils::mul(utils::from_u64(fee_amount), utils::from_u64(bonding_curve_config.creator_fee_withdraw as u64)), utils::from_u64(10000)));  
        let stake_share = utils::as_u64(utils::div(utils::mul(utils::from_u64(fee_amount), utils::from_u64(bonding_curve_config.stake_fee_withdraw as u64)), utils::from_u64(10000)));         
        let platform_stake_share = utils::as_u64(utils::div(utils::mul(utils::from_u64(fee_amount), utils::from_u64(bonding_curve_config.platform_stake_fee_withdraw as u64)), utils::from_u64(10000)));

        assert!(platform_share + creator_share + stake_share + platform_stake_share <= fee_amount, EInvalidWithdrawAmount);

        let platform_coin = coin::split(&mut pool.fee_recipient, platform_share, ctx);
        transfer::public_transfer(platform_coin, bonding_curve_config.admin);

        let creator_coin = coin::split(&mut pool.fee_recipient, creator_share, ctx);
        moonbags_stake::deposit_creator_pool<Token>(stake_config, creator_coin, clock, ctx);

        let stake_coin = coin::split(&mut pool.fee_recipient, stake_share, ctx);
        moonbags_stake::update_reward_index<Token>(stake_config, stake_coin, clock, ctx);

        let platform_stake_coin = coin::split(&mut pool.fee_recipient, platform_stake_share, ctx);
        moonbags_stake::update_reward_index<PlatformToken>(stake_config, platform_stake_coin, clock, ctx);
    }

    fun sqrt(number: u256) : u128 {
        assert!(number > 0, 1);
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
            id: object::new(ctx),
            real_sui_reserves: coin::zero<SUI>(ctx),
            real_token_reserves: coin::mint<Token>(&mut treasury_cap, configuration.initial_virtual_token_reserves - configuration.remain_token_reserves, ctx),
            virtual_token_reserves: configuration.initial_virtual_token_reserves,
            virtual_sui_reserves: configuration.initial_virtual_sui_reserves,
            remain_token_reserves: coin::mint<Token>(&mut treasury_cap, configuration.remain_token_reserves, ctx),
            threshold: DEFAULT_THRESHOLD,
            fee_recipient: fee_recipient,
            position_graduated: option::none(),
            is_completed: false,
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
            configuration.platform_fee_withdraw,
            configuration.creator_fee_withdraw,
            configuration.stake_fee_withdraw,
            configuration.platform_stake_fee_withdraw
        )
    }
}


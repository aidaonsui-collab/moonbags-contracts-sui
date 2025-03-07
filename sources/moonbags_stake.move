#[allow(lint(self_transfer))]
module moonbags::moonbags_stake {
    // === Imports ===
    use std::type_name;
    use std::ascii::String;

    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::dynamic_object_field;
    use sui::event::emit;
    use sui::clock::{Clock, Self};

    // === Errors ===
    const EStakingPoolNotExist: u64 = 1;
    const EStakingCreatorNotExist: u64 = 2;
    const EStakingAccountNotExist: u64 = 3;
    const EAccountBalanceNotEnough: u64 = 4;
    const ENoStakers: u64 = 5;
    const EInvalidCreator: u64 = 6;
    const EInvalidAmount: u64 = 7;
    const EPoolAlreadyExist: u64 = 8;
    const ERewardToClaimNotValid: u64 = 9;

    // === Constants ===
    const MULTIPLIER: u128 = 1_000_000_000_000_000_000; // 1e9

    // === Structs ===
    public struct Configuration has key, store {
        id: UID,
        version: u64,
        admin: address,
    }

    #[allow(lint(coin_field))]
    public struct StakingPool<phantom StakingToken> has key, store {
        id: UID,
        staking_token: Coin<StakingToken>,
        sui_token: Coin<SUI>,
        total_supply: u64,
        reward_index: u128,
    }

    #[allow(lint(coin_field))]
    public struct CreatorPool<phantom StakingToken> has key, store {
        id: UID,
        sui_token: Coin<SUI>,
        creator: address,
    }

    public struct StakingAccount has key, store {
        id: UID,
        balance: u64,
        reward_index: u128,
        earned: u64,
    }

    // === Events ===
    public struct InitializeStakingPoolEvent has copy, drop, store {
        token_address: String,
        staking_pool: ID,
        initializer: String,
        timestamp: u64,
    }

    public struct InitializeCreatorPoolEvent has copy, drop, store {
        token_address: String,
        creator_pool: ID,
        initializer: String,
        creator: String,
        timestamp: u64,
    }

    public struct StakeEvent has copy, drop, store {
        token_address: String,
        staking_pool: ID,
        staker: String,
        amount: u64,
        timestamp: u64,
    }

    public struct UnstakeEvent has copy, drop, store {
        token_address: String,
        staking_pool: ID,
        unstaker: String,
        amount: u64,
        timestamp: u64,
    }

    public struct UpdateRewardIndexEvent has copy, drop, store {
        token_address: String,
        staking_pool: ID,
        reward_updater: String,
        reward: u64,
        timestamp: u64,
    }

    public struct DepositPoolCreatorEvent has copy, drop, store {
        token_address: String,
        creator_pool: ID,
        depositor: String,
        amount: u64,
        timestamp: u64,
    }

    public struct ClaimStakingPoolEvent has copy, drop, store {
        token_address: String,
        staking_pool: ID,
        claimer: String,
        reward: u64,
        timestamp: u64,
    }
    
    public struct ClaimCreatorPoolEvent has copy, drop, store {
        token_address: String,
        creator_pool: ID,
        claimer: String,
        reward: u64,
        timestamp: u64,
    }

    fun init(ctx: &mut TxContext) {
        let configuration = Configuration {
            id: object::new(ctx),
            version: 1,
            admin: ctx.sender(),
        };
        transfer::public_share_object<Configuration>(configuration);
    }

    // === Public Functions ===
    
    /**
     * Initializes a new staking pool for a specific token type.
     * 
     * @typeArgument StakingToken - The token type that will be staked in this pool.
     * @param configuration - Global configuration object.
     * @param clock - clock for timestamp recording.
     * @param ctx - Mutable transaction context.
     */
    public fun initialize_staking_pool<StakingToken>(configuration: &mut Configuration, clock: &Clock, ctx: &mut TxContext) {
        let staking_pool_type_name = type_name::into_string(type_name::get<StakingPool<StakingToken>>());

        assert!(!dynamic_object_field::exists_(&configuration.id, staking_pool_type_name), EPoolAlreadyExist);

        let staking_pool = StakingPool<StakingToken> {
            id                  : object::new(ctx),
            staking_token       : coin::zero<StakingToken>(ctx),
            sui_token           : coin::zero<SUI>(ctx),
            total_supply        : 0,
            reward_index        : 0,
        };

        let initialize_staking_pool_event = InitializeStakingPoolEvent {
            token_address       : type_name::into_string(type_name::get<StakingToken>()),
            staking_pool        : object::id(&staking_pool),
            initializer         : ctx.sender().to_ascii_string(),
            timestamp           : clock::timestamp_ms(clock),
        };
        emit<InitializeStakingPoolEvent>(initialize_staking_pool_event);

        dynamic_object_field::add(&mut configuration.id, staking_pool_type_name, staking_pool);
    }

    /**
     * Initializes a creator pool for a specific token type.
     * 
     * @typeArgument StakingToken - The token type associated with this creator pool.
     * @param configuration - Global configuration object.
     * @param creator - Address of the creator for this pool.
     * @param clock - Clock for timestamp recording.
     * @param ctx - Mutable transaction context.
     */
    public fun initialize_creator_pool<StakingToken>(configuration: &mut Configuration, creator: address, clock: &Clock, ctx: &mut TxContext) {
        let creator_pool_type_name = type_name::into_string(type_name::get<CreatorPool<StakingToken>>());

        assert!(!dynamic_object_field::exists_(&configuration.id, creator_pool_type_name), EPoolAlreadyExist);

        let creator_pool = CreatorPool<StakingToken> {
            id                  : object::new(ctx),
            sui_token           : coin::zero<SUI>(ctx),
            creator             : creator,
        };

        let initialize_staking_pool_event = InitializeCreatorPoolEvent {
            token_address       : type_name::into_string(type_name::get<StakingToken>()),
            creator_pool        : object::id(&creator_pool),
            initializer         : ctx.sender().to_ascii_string(),
            creator             : creator.to_ascii_string(),
            timestamp           : clock::timestamp_ms(clock),
        };
        emit<InitializeCreatorPoolEvent>(initialize_staking_pool_event);

        dynamic_object_field::add(&mut configuration.id, creator_pool_type_name, creator_pool);
    }

    /**
     * Updates the reward index of a staking pool by adding new rewards.
     * 
     * @typeArgument StakingToken - The token type associated with the staking pool.
     * @param configuration - Global configuration object.
     * @param reward_sui_coin - SUI coin to be added as rewards to the staking pool.
     * @param clock - Clock for timestamp recording.
     * @param ctx - Mutable transaction context for sender information.
     */
    public fun update_reward_index<StakingToken>(configuration: &mut Configuration, reward_sui_coin: Coin<SUI>, clock: &Clock, ctx: &mut TxContext) {
        let staking_pool_type_name = type_name::into_string(type_name::get<StakingPool<StakingToken>>());

        assert!(dynamic_object_field::exists_(&configuration.id, staking_pool_type_name), EStakingPoolNotExist);

        let staking_pool = dynamic_object_field::borrow_mut<String, StakingPool<StakingToken>>(
            &mut configuration.id,
            staking_pool_type_name
        );

        assert!(staking_pool.total_supply > 0, ENoStakers);

        let reward_amount = coin::value<SUI>(&reward_sui_coin);
        assert!(reward_amount > 0, EInvalidAmount);

        staking_pool.reward_index = staking_pool.reward_index + (reward_amount as u128) * MULTIPLIER / (staking_pool.total_supply as u128);

        coin::join(&mut staking_pool.sui_token, reward_sui_coin);

        let update_reward_index_event = UpdateRewardIndexEvent {
            token_address       : type_name::into_string(type_name::get<StakingToken>()),
            staking_pool        : object::id(staking_pool),
            reward_updater      : ctx.sender().to_ascii_string(),
            reward              : reward_amount,
            timestamp           : clock::timestamp_ms(clock)
        };
        emit<UpdateRewardIndexEvent>(update_reward_index_event);
    }

    /**
     * Deposits SUI coin into a creator pool.
     * 
     * @typeArgument StakingToken - The token type associated with the creator pool.
     * @param configuration - Global configuration object.
     * @param reward_sui_coin - SUI coin to be deposited into the creator pool.
     * @param clock - Clock for timestamp recording.
     * @param ctx - Mutable transaction context for sender information.
     */
    public fun deposit_creator_pool<StakingToken>(configuration: &mut Configuration, reward_sui_coin: Coin<SUI>, clock: &Clock, ctx: &mut TxContext) {
        let creator_pool_type_name = type_name::into_string(type_name::get<CreatorPool<StakingToken>>());

        assert!(dynamic_object_field::exists_(&configuration.id, creator_pool_type_name), EStakingCreatorNotExist);

        let creator_pool = dynamic_object_field::borrow_mut<String, CreatorPool<StakingToken>>(
            &mut configuration.id,
            creator_pool_type_name
        );

        let reward_amount = coin::value<SUI>(&reward_sui_coin);
        assert!(reward_amount > 0, EInvalidAmount);

        coin::join(&mut creator_pool.sui_token, reward_sui_coin);

        let update_reward_index_event = DepositPoolCreatorEvent {
            token_address       : type_name::into_string(type_name::get<StakingToken>()),
            creator_pool        : object::id(creator_pool),
            depositor           : ctx.sender().to_ascii_string(),
            amount              : reward_amount,
            timestamp           : clock::timestamp_ms(clock)
        };
        emit<DepositPoolCreatorEvent>(update_reward_index_event);
    }

    /**
     * Stakes tokens in a staking pool.
     * 
     * @typeArgument StakingToken - The token type to stake.
     * @param configuration - Global configuration object.
     * @param staking_coin - Tokens to stake.
     * @param clock - Clock for timestamp recording.
     * @param ctx - Mutable transaction context.
     */
    public fun stake<StakingToken>(configuration: &mut Configuration, staking_coin: Coin<StakingToken>, clock: &Clock, ctx: &mut TxContext) {
        let staking_pool_type_name = type_name::into_string(type_name::get<StakingPool<StakingToken>>());
        
        assert!(dynamic_object_field::exists_(&configuration.id, staking_pool_type_name), EStakingPoolNotExist);

        let staking_pool = dynamic_object_field::borrow_mut<String, StakingPool<StakingToken>>(
            &mut configuration.id,
            staking_pool_type_name
        );

        let staker_address = ctx.sender();
        if (!dynamic_object_field::exists_(&staking_pool.id, staker_address)) {
            // first time staking
            let new_staking_account = StakingAccount {
                id              : object::new(ctx),
                balance         : 0,
                reward_index    : 0,
                earned          : 0,
            };
            dynamic_object_field::add(&mut staking_pool.id, staker_address, new_staking_account);
        };

        let staking_account: &mut StakingAccount = dynamic_object_field::borrow_mut(&mut staking_pool.id, staker_address);

        // Update rewards before stake
        update_rewards(staking_pool.reward_index, staking_account);

        let amount_token_staking_in = coin::value<StakingToken>(&staking_coin);
        assert!(amount_token_staking_in > 0, EInvalidAmount);

        staking_account.balance = staking_account.balance + amount_token_staking_in;
        staking_pool.total_supply = staking_pool.total_supply + amount_token_staking_in;

        coin::join(&mut staking_pool.staking_token, staking_coin);

        let stake_event = StakeEvent {
            token_address       : type_name::into_string(type_name::get<StakingToken>()),
            staking_pool        : object::id(staking_pool),
            staker              : staker_address.to_ascii_string(),
            amount              : amount_token_staking_in,
            timestamp           : clock::timestamp_ms(clock),
        };
        emit<StakeEvent>(stake_event);
    }

    /**
     * Unstakes tokens from a staking pool.
     * 
     * @typeArgument StakingToken - The token type to unstake.
     * @param configuration - Global configuration object.
     * @param unstake_amount - Amount of tokens to unstake.
     * @param clock - Clock for timestamp recording.
     * @param ctx - Mutable transaction context for sender information.
     */
    public fun unstake<StakingToken>(configuration: &mut Configuration, unstake_amount: u64, clock: &Clock, ctx: &mut TxContext) {
        assert!(unstake_amount > 0, EInvalidAmount);

        let staking_pool_type_name = type_name::into_string(type_name::get<StakingPool<StakingToken>>());

        assert!(dynamic_object_field::exists_(&configuration.id, staking_pool_type_name), EStakingPoolNotExist);

        let staking_pool = dynamic_object_field::borrow_mut<String, StakingPool<StakingToken>>(
            &mut configuration.id,
            staking_pool_type_name
        );

        let staker_address = ctx.sender();
        assert!(dynamic_object_field::exists_(&staking_pool.id, staker_address), EStakingAccountNotExist);

        let staking_account: &mut StakingAccount = dynamic_object_field::borrow_mut(&mut staking_pool.id, staker_address);

        // Update rewards before unstake
        update_rewards(staking_pool.reward_index, staking_account);

        assert!(staking_account.balance >= unstake_amount, EAccountBalanceNotEnough);

        staking_account.balance = staking_account.balance - unstake_amount;
        staking_pool.total_supply = staking_pool.total_supply - unstake_amount;

        let unstake_coin = coin::split(&mut staking_pool.staking_token, unstake_amount, ctx);
        transfer::public_transfer<Coin<StakingToken>>(unstake_coin, staker_address);

        let unstake_event = UnstakeEvent {
            token_address       : type_name::into_string(type_name::get<StakingToken>()),
            staking_pool        : object::id(staking_pool),
            unstaker            : staker_address.to_ascii_string(),
            amount              : unstake_amount,
            timestamp           : clock::timestamp_ms(clock),
        };
        emit<UnstakeEvent>(unstake_event);
    }

    /**
     * Claims rewards from a staking pool.
     * 
     * @typeArgument StakingToken - The token type associated with the staking pool.
     * @param configuration - Global configuration object.
     * @param clock - Clock for timestamp recording.
     * @param ctx - Mutable transaction context for sender information.
     * @return The amount of SUI claimed as rewards.
     */
    public fun claim_staking_pool<StakingToken>(configuration: &mut Configuration, clock: &Clock, ctx: &mut TxContext) : u64 {
        let staking_pool_type_name = type_name::into_string(type_name::get<StakingPool<StakingToken>>());

        assert!(dynamic_object_field::exists_(&configuration.id, staking_pool_type_name), EStakingPoolNotExist);

        let staking_pool = dynamic_object_field::borrow_mut<String, StakingPool<StakingToken>>(
            &mut configuration.id,
            staking_pool_type_name
        );

        let staker_address = ctx.sender();
        assert!(dynamic_object_field::exists_(&staking_pool.id, staker_address), EStakingAccountNotExist);

        let staking_account: &mut StakingAccount = dynamic_object_field::borrow_mut(&mut staking_pool.id, staker_address);

        // Update rewards before claiming
        update_rewards(staking_pool.reward_index, staking_account);

        let reward_amount = staking_account.earned;

        assert!(reward_amount > 0, ERewardToClaimNotValid);

        staking_account.earned = 0;
        let sui_coin = coin::split(&mut staking_pool.sui_token, reward_amount, ctx);
        transfer::public_transfer<Coin<SUI>>(sui_coin, staker_address);

        let claim_staking_pool_event = ClaimStakingPoolEvent {
            token_address       : type_name::into_string(type_name::get<StakingToken>()),
            staking_pool        : object::id(staking_pool),
            claimer             : staker_address.to_ascii_string(),
            reward              : reward_amount,
            timestamp           : clock::timestamp_ms(clock),
        };
        emit<ClaimStakingPoolEvent>(claim_staking_pool_event);

        reward_amount
    }

    /**
     * Claims rewards from a creator pool.
     * 
     * @typeArgument StakingToken - The token type associated with the creator pool.
     * @param configuration - Global configuration object.
     * @param clock - Clock for timestamp recording.
     * @param ctx - Mutable transaction context for sender information.
     * @return The amount of SUI claimed from the creator pool.
     */
    public fun claim_creator_pool<StakingToken>(configuration: &mut Configuration, clock: &Clock, ctx: &mut TxContext) : u64 {
        let creator_pool_type_name = type_name::into_string(type_name::get<CreatorPool<StakingToken>>());

        assert!(dynamic_object_field::exists_(&configuration.id, creator_pool_type_name), EStakingCreatorNotExist);

        let creator_pool = dynamic_object_field::borrow_mut<String, CreatorPool<StakingToken>>(
            &mut configuration.id,
            creator_pool_type_name,
        );

        assert!(creator_pool.creator == ctx.sender(), EInvalidCreator);

        let reward_amount = coin::value<SUI>(&creator_pool.sui_token);
        assert!(reward_amount > 0, ERewardToClaimNotValid);

        let sui_coin = coin::split(&mut creator_pool.sui_token, reward_amount, ctx);
        transfer::public_transfer<Coin<SUI>>(sui_coin, creator_pool.creator);

        let claim_creator_pool_event = ClaimCreatorPoolEvent {
            token_address       : type_name::into_string(type_name::get<StakingToken>()),
            creator_pool        : object::id(creator_pool),
            claimer             : ctx.sender().to_ascii_string(),
            reward              : reward_amount,
            timestamp           : clock::timestamp_ms(clock),
        };
        emit<ClaimCreatorPoolEvent>(claim_creator_pool_event);

        reward_amount
    }

    // === View Functions ===

    /**
     * Calculates the rewards earned by the sender for staking tokens.
     * 
     * @typeArgument StakingToken - The token type associated with the staking pool.
     * @param configuration - Global configuration object.
     * @param ctx - Mutable transaction context for sender information.
     * @return The total amount of rewards earned.
     */
    public fun calculate_rewards_earned<StakingToken>(configuration: &Configuration, ctx: &mut TxContext): u64 {
        let staking_pool_type_name = type_name::into_string(type_name::get<StakingPool<StakingToken>>());

        assert!(dynamic_object_field::exists_(&configuration.id, staking_pool_type_name), EStakingPoolNotExist);

        let staking_pool = dynamic_object_field::borrow<String, StakingPool<StakingToken>>(
            &configuration.id,
            staking_pool_type_name
        );

        let staker_address = ctx.sender();
        assert!(dynamic_object_field::exists_(&staking_pool.id, staker_address), EStakingAccountNotExist);

        let staking_account: &StakingAccount = dynamic_object_field::borrow(&staking_pool.id, staker_address);

        staking_account.earned + calculate_rewards(staking_pool.reward_index, staking_account)
    }

    // === Private Functions ===

    /**
     * Calculates the pending rewards for a staking account.
     * 
     * @param staking_pool_reward_index - Current reward index of the staking pool.
     * @param staking_account - The staking account to calculate rewards for.
     * @return The amount of pending rewards.
     */
    fun calculate_rewards(staking_pool_reward_index: u128, staking_account: &StakingAccount): u64 {
        let shares = staking_account.balance as u128;
        ((shares * (staking_pool_reward_index - staking_account.reward_index)) / MULTIPLIER) as u64
    }


    /**
     * Updates the rewards earned by a staking account based on the current reward index.
     * 
     * @param staking_pool_reward_index - Current reward index of the staking pool.
     * @param staking_account - The staking account to update rewards for.
     */
    fun update_rewards(staking_pool_reward_index: u128, staking_account: &mut StakingAccount) {
        staking_account.earned = staking_account.earned + calculate_rewards(staking_pool_reward_index, staking_account);
        staking_account.reward_index = staking_pool_reward_index;
    }

    // === Test Functions ===
    #[test_only]
    public(package) fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test_only]
    public(package) fun get_configuration_id_for_testing(config: &Configuration): &UID {
        &config.id
    }

    #[test_only]
    public(package) fun get_staking_pool_values_for_testing<StakingToken>(pool: &StakingPool<StakingToken>): (&UID ,u64, u64, u64, u128) {
        (
            &pool.id,
            coin::value(&pool.staking_token),
            coin::value(&pool.sui_token),
            pool.total_supply,
            pool.reward_index,
        )
    }

    #[test_only]
    public(package) fun get_staking_account_values_for_testing(account: &StakingAccount): (u64, u128, u64) {
        (
            account.balance,
            account.reward_index,
            account.earned,
        )
    }

   #[test_only]
    public(package) fun get_creator_pool_reward_value_for_testing<StakingToken>(pool: &CreatorPool<StakingToken>): u64 {
        coin::value(&pool.sui_token)
    }
}
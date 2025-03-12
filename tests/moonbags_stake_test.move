#[test_only]
module moonbags::staking_test {
    use std::type_name;
    use std::ascii::String;
    // use std::debug::print;

    use sui::test_scenario::Self;
    use sui::clock;
    use sui::coin::Self;
    use sui::sui::SUI;
    use sui::dynamic_object_field;
    
    use moonbags::moonbags_stake::{Self, Configuration, StakingPool, StakingAccount, CreatorPool};
    
    const ADMIN: address = @0x00;
    const USER_1: address = @0x10;
    const USER_2: address = @0x20;
    const ONE_HOUR_IN_MS: u64 = 60 * 60 * 1000;

    const EOutputEqualToExpected: u64 = 0;

    public struct StakingToken has drop {}

    #[test_only]
    public(package) fun get_staking_pool<Token>(config: &Configuration) : &StakingPool<Token> {
        let staking_pool_type_name = type_name::into_string(type_name::get<StakingPool<Token>>());
        let config_id = moonbags_stake::get_configuration_id_for_testing(config);
        let staking_pool = dynamic_object_field::borrow<String, StakingPool<Token>>(config_id, staking_pool_type_name);
        staking_pool
    }

    #[test_only]
    public(package) fun get_creator_pool<Token>(config: &Configuration) : &CreatorPool<Token> {
        let creator_pool_type_name = type_name::into_string(type_name::get<CreatorPool<Token>>());
        let config_id = moonbags_stake::get_configuration_id_for_testing(config);
        let creator_pool = dynamic_object_field::borrow(config_id, creator_pool_type_name);
        creator_pool
    }

    #[test_only]
    public(package) fun get_staking_account(staking_pool_id: &UID, staker_address: address) : &StakingAccount {
        let staking_account: &StakingAccount = dynamic_object_field::borrow(staking_pool_id, staker_address);
        staking_account
    }

    #[test]
    fun test_initialize_staking_pool() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(ADMIN);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());

            // Initialize staking pool for the first time
            moonbags_stake::initialize_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());

            // Verify that staking pool exists
            let staking_pool_type_name = type_name::into_string(type_name::get<StakingPool<StakingToken>>());
            let config_id = moonbags_stake::get_configuration_id_for_testing(&config);
            assert!(dynamic_object_field::exists_(config_id, staking_pool_type_name), EOutputEqualToExpected);

            // Check initial staking pool values
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (_, staking_token_value, sui_token_value, total_supply, reward_index) = moonbags_stake::get_staking_pool_values_for_testing(staking_pool);
            assert!(staking_token_value == 0, EOutputEqualToExpected);
            assert!(sui_token_value == 0, EOutputEqualToExpected);
            assert!(total_supply == 0, EOutputEqualToExpected);
            assert!(reward_index == 0, EOutputEqualToExpected);

            // Initialize staking pool again - should be a no-op
            moonbags_stake::initialize_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());
            
            // Verify pool still exists with same values
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (_, staking_token_value, sui_token_value, total_supply, reward_index) = moonbags_stake::get_staking_pool_values_for_testing(staking_pool);
            assert!(staking_token_value == 0, EOutputEqualToExpected);
            assert!(sui_token_value == 0, EOutputEqualToExpected);
            assert!(total_supply == 0, EOutputEqualToExpected);
            assert!(reward_index == 0, EOutputEqualToExpected);

            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    fun test_initialize_creator_pool() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(ADMIN);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());

            // Initialize creator pool for the first time
            moonbags_stake::initialize_creator_pool<StakingToken>(&mut config, USER_1, &clock, scenario.ctx());

            // Verify that creator pool exists
            let creator_pool_type_name = type_name::into_string(type_name::get<CreatorPool<StakingToken>>());
            let config_id = moonbags_stake::get_configuration_id_for_testing(&config);
            assert!(dynamic_object_field::exists_(config_id, creator_pool_type_name), EOutputEqualToExpected);

            // Check initial creator pool values
            let creator_pool = get_creator_pool<StakingToken>(&config);
            let reward_value = moonbags_stake::get_creator_pool_reward_value_for_testing(creator_pool);
            assert!(reward_value == 0, EOutputEqualToExpected);

            // Initialize creator pool again - should be a no-op
            moonbags_stake::initialize_creator_pool<StakingToken>(&mut config, USER_1, &clock, scenario.ctx());
            
            // Verify pool still exists with same values
            let creator_pool = get_creator_pool<StakingToken>(&config);
            let reward_value = moonbags_stake::get_creator_pool_reward_value_for_testing(creator_pool);
            assert!(reward_value == 0, EOutputEqualToExpected);

            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = moonbags_stake::ENoStakers)]
    fun test_update_reward_index_no_stakers() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(ADMIN);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());

            // Create staking pool
            moonbags_stake::initialize_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());

            // Try to update reward index with no stakers
            let reward_amount = 1_000;
            let reward_coin = coin::mint_for_testing<SUI>(reward_amount, scenario.ctx());
            
            // This should fail with ENoStakers
            moonbags_stake::update_reward_index<StakingToken>(&mut config, reward_coin, &clock, scenario.ctx());

            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = moonbags_stake::EInvalidAmount)]
    fun test_update_reward_index_zero_amount() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(ADMIN);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Create staking pool
            moonbags_stake::initialize_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());

            // Stake some tokens to make the pool have stakers
            let stake_amount = 10_000;
            let stake_coin = coin::mint_for_testing<StakingToken>(stake_amount, scenario.ctx());
            moonbags_stake::stake(&mut config, stake_coin, &clock, scenario.ctx());
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(ADMIN);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Try to update with zero reward
            let reward_amount = 0;
            let reward_coin = coin::mint_for_testing<SUI>(reward_amount, scenario.ctx());
            
            // This should fail with EInvalidAmount
            moonbags_stake::update_reward_index<StakingToken>(&mut config, reward_coin, &clock, scenario.ctx());
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = moonbags_stake::EStakingPoolNotExist)]
    fun test_update_reward_index_pool_not_exist() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(ADMIN);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Try to update reward index without creating staking pool
            let reward_amount = 1_000;
            let reward_coin = coin::mint_for_testing<SUI>(reward_amount, scenario.ctx());
            
            // This should fail with EStakingPoolNotExist
            moonbags_stake::update_reward_index<StakingToken>(&mut config, reward_coin, &clock, scenario.ctx());
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    fun test_update_reward_index_success() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(ADMIN);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Create staking pool
            moonbags_stake::initialize_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());
            
            // Setup some staking to have non-zero total supply
            let stake_amount = 10_000;
            let stake_coin = coin::mint_for_testing<StakingToken>(stake_amount, scenario.ctx());
            moonbags_stake::stake(&mut config, stake_coin, &clock, scenario.ctx());
            
            // Check initial staking pool values
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (_, initial_staking_value, initial_sui_value, initial_supply, initial_reward_index) = 
                moonbags_stake::get_staking_pool_values_for_testing(staking_pool);
            
            assert!(initial_staking_value == 10_000, EOutputEqualToExpected);
            assert!(initial_sui_value == 0, EOutputEqualToExpected);
            assert!(initial_supply == 10_000, EOutputEqualToExpected);
            assert!(initial_reward_index == 0, EOutputEqualToExpected);
            
            // Add first reward
            let reward_amount_1 = 500;
            let reward_coin_1 = coin::mint_for_testing<SUI>(reward_amount_1, scenario.ctx());
            moonbags_stake::update_reward_index<StakingToken>(&mut config, reward_coin_1, &clock, scenario.ctx());
            
            // Check updated pool values after first reward
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (_, staking_value, sui_value, total_supply, reward_index) = 
                moonbags_stake::get_staking_pool_values_for_testing(staking_pool);
            
            assert!(staking_value == 10_000, EOutputEqualToExpected);
            assert!(sui_value == 500, EOutputEqualToExpected);
            assert!(total_supply == 10_000, EOutputEqualToExpected);
            // reward_index = (500 * 1_000_000_000) / 10_000 = 50_000_000
            assert!(reward_index == 50_000_000, EOutputEqualToExpected);
            
            // Add second reward
            let reward_amount_2 = 800;
            let reward_coin_2 = coin::mint_for_testing<SUI>(reward_amount_2, scenario.ctx());
            moonbags_stake::update_reward_index<StakingToken>(&mut config, reward_coin_2, &clock, scenario.ctx());
            
            // Check updated pool values after second reward
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (_, staking_value, sui_value, total_supply, reward_index) = 
                moonbags_stake::get_staking_pool_values_for_testing(staking_pool);
            
            assert!(staking_value == 10_000, EOutputEqualToExpected);
            assert!(sui_value == 1300, EOutputEqualToExpected); // 500 + 800
            assert!(total_supply == 10_000, EOutputEqualToExpected);
            // Additional reward_index = (800 * 1_000_000_000) / 10_000 = 80_000_000
            // Total reward_index = 50_000_000 + 80_000_000 = 130_000_000
            assert!(reward_index == 130_000_000, EOutputEqualToExpected);
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = moonbags_stake::EStakingCreatorNotExist)]
    fun test_deposit_creator_pool_not_exist() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(ADMIN);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Try to deposit to a non-existent creator pool
            let reward_amount = 1_000;
            let reward_coin = coin::mint_for_testing<SUI>(reward_amount, scenario.ctx());
            
            // This should fail with EStakingCreatorNotExist
            moonbags_stake::deposit_creator_pool<StakingToken>(&mut config, reward_coin, &clock, scenario.ctx());
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = moonbags_stake::EInvalidAmount)]
    fun test_deposit_creator_pool_zero_amount() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(ADMIN);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Initialize the creator pool first
            moonbags_stake::initialize_creator_pool<StakingToken>(&mut config, USER_1, &clock, scenario.ctx());
            
            // Try to deposit zero amount
            let reward_amount = 0;
            let reward_coin = coin::mint_for_testing<SUI>(reward_amount, scenario.ctx());
            
            // This should fail with EInvalidAmount
            moonbags_stake::deposit_creator_pool<StakingToken>(&mut config, reward_coin, &clock, scenario.ctx());
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    fun test_deposit_creator_pool_success() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(ADMIN);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Initialize the creator pool
            moonbags_stake::initialize_creator_pool<StakingToken>(&mut config, USER_1, &clock, scenario.ctx());
            
            // Verify initial pool value
            let creator_pool = get_creator_pool<StakingToken>(&config);
            let initial_reward = moonbags_stake::get_creator_pool_reward_value_for_testing(creator_pool);
            assert!(initial_reward == 0, EOutputEqualToExpected);
            
            // First deposit
            let reward_amount1 = 1_000;
            let reward_coin1 = coin::mint_for_testing<SUI>(reward_amount1, scenario.ctx());
            moonbags_stake::deposit_creator_pool<StakingToken>(&mut config, reward_coin1, &clock, scenario.ctx());
            
            // Verify updated pool value after first deposit
            let creator_pool = get_creator_pool<StakingToken>(&config);
            let updated_reward = moonbags_stake::get_creator_pool_reward_value_for_testing(creator_pool);
            assert!(updated_reward == 1_000, EOutputEqualToExpected);
            
            // Second deposit
            let reward_amount2 = 500;
            let reward_coin2 = coin::mint_for_testing<SUI>(reward_amount2, scenario.ctx());
            moonbags_stake::deposit_creator_pool<StakingToken>(&mut config, reward_coin2, &clock, scenario.ctx());
            
            // Verify updated pool value after second deposit
            let creator_pool = get_creator_pool<StakingToken>(&config);
            let final_reward = moonbags_stake::get_creator_pool_reward_value_for_testing(creator_pool);
            assert!(final_reward == 1_500, EOutputEqualToExpected);
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = moonbags_stake::EInvalidAmount)]
    fun test_stake_zero_amount() {
        let mut scenario = test_scenario::begin(USER_1);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Initialize staking pool
            moonbags_stake::initialize_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());
            
            // Create staking coin with zero value
            let stake_amount = 0;
            let stake_coin = coin::mint_for_testing<StakingToken>(stake_amount, scenario.ctx());
            
            // This should fail with EInvalidAmount
            moonbags_stake::stake(&mut config, stake_coin, &clock, scenario.ctx());
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = moonbags_stake::EStakingPoolNotExist)]
    fun test_stake_pool_not_exist() {
        let mut scenario = test_scenario::begin(USER_1);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Create staking coin
            let stake_amount = 1000;
            let stake_coin = coin::mint_for_testing<StakingToken>(stake_amount, scenario.ctx());
            
            // Staking without initializing the pool first should fail
            moonbags_stake::stake(&mut config, stake_coin, &clock, scenario.ctx());
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    fun test_stake_first_time() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());

            // Initialize staking pool
            moonbags_stake::initialize_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());
            
            // Create staking coin
            let stake_amount = 5000;
            let stake_coin = coin::mint_for_testing<StakingToken>(stake_amount, scenario.ctx());
            
            // First time staking
            moonbags_stake::stake(&mut config, stake_coin, &clock, scenario.ctx());
            
            // Check updated pool values
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (pool_id, staking_token_value, sui_token_value, total_supply, reward_index) = 
                moonbags_stake::get_staking_pool_values_for_testing(staking_pool);
            
            assert!(staking_token_value == 5000, EOutputEqualToExpected);
            assert!(sui_token_value == 0, EOutputEqualToExpected);
            assert!(total_supply == 5000, EOutputEqualToExpected);
            assert!(reward_index == 0, EOutputEqualToExpected);
            
            // Check staking account was created correctly
            let staking_account = get_staking_account(pool_id, USER_1);
            let (balance, acc_reward_index, earned) = moonbags_stake::get_staking_account_values_for_testing(staking_account);
            
            assert!(balance == 5000, EOutputEqualToExpected);
            assert!(acc_reward_index == 0, EOutputEqualToExpected);
            assert!(earned == 0, EOutputEqualToExpected);
            
            // Check unstake deadline was set
            let unstake_deadline = moonbags_stake::get_unstake_deadline_for_testing(staking_account);
            let current_time = clock::timestamp_ms(&clock);
            assert!(unstake_deadline > current_time, EOutputEqualToExpected);
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    fun test_stake_additional_amount() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Initialize staking pool
            moonbags_stake::initialize_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());

            // First stake
            let stake_amount1 = 3000;
            let stake_coin1 = coin::mint_for_testing<StakingToken>(stake_amount1, scenario.ctx());
            moonbags_stake::stake(&mut config, stake_coin1, &clock, scenario.ctx());
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(ADMIN);
        {
            // Add some rewards between stakes
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            let reward_amount = 600;
            let reward_coin = coin::mint_for_testing<SUI>(reward_amount, scenario.ctx());
            moonbags_stake::update_reward_index<StakingToken>(&mut config, reward_coin, &clock, scenario.ctx());
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let mut clock = clock::create_for_testing(scenario.ctx());
            
            // Get reward state before additional stake
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (pool_id, _, _, _, pool_reward_index) = moonbags_stake::get_staking_pool_values_for_testing(staking_pool);
            
            let staking_account_before = get_staking_account(pool_id, USER_1);
            let old_unstake_deadline = moonbags_stake::get_unstake_deadline_for_testing(staking_account_before);
            
            // Increment the clock time to ensure the unstake deadline changes
            clock::increment_for_testing(&mut clock, 3600 * 1000); // Add 1 hour in milliseconds
            
            // Additional stake
            let stake_amount2 = 2000;
            let stake_coin2 = coin::mint_for_testing<StakingToken>(stake_amount2, scenario.ctx());
            moonbags_stake::stake(&mut config, stake_coin2, &clock, scenario.ctx());
            
            // Check updated pool values
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (pool_id, staking_token_value, _, total_supply, _) = 
                moonbags_stake::get_staking_pool_values_for_testing(staking_pool);
            
            assert!(staking_token_value == 5000, EOutputEqualToExpected); // 3000 + 2000
            assert!(total_supply == 5000, EOutputEqualToExpected);
            
            // Check staking account was updated correctly
            let staking_account_after = get_staking_account(pool_id, USER_1);
            let (balance_after, acc_reward_index_after, earned_after) = 
                moonbags_stake::get_staking_account_values_for_testing(staking_account_after);
            
            assert!(balance_after == 5000, EOutputEqualToExpected); // 3000 + 2000
            assert!(acc_reward_index_after == pool_reward_index, EOutputEqualToExpected); // Updated during stake
            
            // Earned should be preserved from previous rewards calculation
            // With 3000 staked and 600 reward: (600 * 1_000_000_000) / 3000 * 3000 / 1_000_000_000 = 600
            assert!(earned_after == 600, EOutputEqualToExpected);
            
            // Check unstake deadline was updated
            let new_unstake_deadline = moonbags_stake::get_unstake_deadline_for_testing(staking_account_after);
            assert!(new_unstake_deadline > old_unstake_deadline, EOutputEqualToExpected);
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = moonbags_stake::EInvalidAmount)]
    fun test_unstake_zero_amount() {
        let mut scenario = test_scenario::begin(USER_1);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let mut clock = clock::create_for_testing(scenario.ctx());
            
            // Initialize staking pool
            moonbags_stake::initialize_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());
            
            // Stake some tokens first
            let stake_amount = 1000;
            let stake_coin = coin::mint_for_testing<StakingToken>(stake_amount, scenario.ctx());
            moonbags_stake::stake(&mut config, stake_coin, &clock, scenario.ctx());
            
            // Advance time to pass the unstake deadline
            clock::increment_for_testing(&mut clock, ONE_HOUR_IN_MS + 1); // 1 hour + 1ms
            
            // Try to unstake zero amount
            moonbags_stake::unstake<StakingToken>(&mut config, 0, &clock, scenario.ctx()); // Should fail
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = moonbags_stake::EStakingPoolNotExist)]
    fun test_unstake_pool_not_exist() {
        let mut scenario = test_scenario::begin(USER_1);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Try to unstake without initializing the pool
            moonbags_stake::unstake<StakingToken>(&mut config, 100, &clock, scenario.ctx()); // Should fail
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = moonbags_stake::EStakingAccountNotExist)]
    fun test_unstake_account_not_exist() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(ADMIN);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Initialize staking pool
            moonbags_stake::initialize_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        // USER_1 tries to unstake without having a staking account
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Try to unstake without having staked first
            moonbags_stake::unstake<StakingToken>(&mut config, 100, &clock, scenario.ctx()); // Should fail
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = moonbags_stake::EAccountBalanceNotEnough)]
    fun test_unstake_balance_not_enough() {
        let mut scenario = test_scenario::begin(USER_1);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let mut clock = clock::create_for_testing(scenario.ctx());
            
            // Initialize staking pool
            moonbags_stake::initialize_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());
            
            // Stake some tokens
            let stake_amount = 1000;
            let stake_coin = coin::mint_for_testing<StakingToken>(stake_amount, scenario.ctx());
            moonbags_stake::stake(&mut config, stake_coin, &clock, scenario.ctx());
            
            // Advance time to pass the unstake deadline
            clock::increment_for_testing(&mut clock, ONE_HOUR_IN_MS + 1); // 1 hour + 1ms
            
            // Try to unstake more than balance
            moonbags_stake::unstake<StakingToken>(&mut config, 1001, &clock, scenario.ctx()); // Should fail
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = moonbags_stake::EUnstakeDeadlineNotAllow)]
    fun test_unstake_deadline() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());

            // Create staking pool
            moonbags_stake::initialize_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());

            // Create staking coin
            let stake_amount = 10_000;
            let stake_coin = coin::mint_for_testing<StakingToken>(stake_amount, scenario.ctx());

            // Stake tokens
            moonbags_stake::stake(&mut config, stake_coin, &clock, scenario.ctx());

            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());

            moonbags_stake::unstake<StakingToken>(&mut config, 10_000, &clock, scenario.ctx());

            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    fun test_unstake_successful() {
        let mut scenario = test_scenario::begin(USER_1);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Initialize staking pool
            moonbags_stake::initialize_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());
            
            // Stake some tokens
            let stake_amount = 1000;
            let stake_coin = coin::mint_for_testing<StakingToken>(stake_amount, scenario.ctx());
            moonbags_stake::stake(&mut config, stake_coin, &clock, scenario.ctx());
            
            // Get staking pool and account info before unstaking
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (pool_id, initial_token_value, _, initial_supply, _) = 
                moonbags_stake::get_staking_pool_values_for_testing(staking_pool);
            
            assert!(initial_token_value == 1000, EOutputEqualToExpected);
            assert!(initial_supply == 1000, EOutputEqualToExpected);
            
            let staking_account = get_staking_account(pool_id, USER_1);
            let (initial_balance, _, _) = moonbags_stake::get_staking_account_values_for_testing(staking_account);
            
            assert!(initial_balance == 1000, EOutputEqualToExpected);
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(ADMIN);
        {
            // Add rewards
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            let reward_coin = coin::mint_for_testing<SUI>(500, scenario.ctx());
            moonbags_stake::update_reward_index<StakingToken>(&mut config, reward_coin, &clock, scenario.ctx());
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let mut clock = clock::create_for_testing(scenario.ctx());
            
            // Advance time to pass the unstake deadline
            clock::increment_for_testing(&mut clock, ONE_HOUR_IN_MS + 1); // 1 hour + 1ms
            
            // Unstake half of the tokens
            let unstake_amount = 500;
            moonbags_stake::unstake<StakingToken>(&mut config, unstake_amount, &clock, scenario.ctx());
            
            // Verify updated pool state
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (pool_id, token_value, _, supply, reward_index) = 
                moonbags_stake::get_staking_pool_values_for_testing(staking_pool);
            
            assert!(token_value == 500, EOutputEqualToExpected); // 1000 - 500
            assert!(supply == 500, EOutputEqualToExpected); // 1000 - 500
            
            // Verify updated account state
            let staking_account = get_staking_account(pool_id, USER_1);
            let (balance, acc_reward_index, earned) = 
                moonbags_stake::get_staking_account_values_for_testing(staking_account);
            
            assert!(balance == 500, EOutputEqualToExpected); // 1000 - 500
            assert!(acc_reward_index == reward_index, EOutputEqualToExpected); // Should be updated before unstake
            assert!(earned == 500, EOutputEqualToExpected); // All rewards should be calculated before unstaking
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    fun test_multiple_unstakes() {
        let mut scenario = test_scenario::begin(USER_1);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Initialize staking pool and stake tokens
            moonbags_stake::initialize_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());
            let stake_coin = coin::mint_for_testing<StakingToken>(1000, scenario.ctx());
            moonbags_stake::stake(&mut config, stake_coin, &clock, scenario.ctx());
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let mut clock = clock::create_for_testing(scenario.ctx());
            
            // Advance time to allow unstaking
            clock::increment_for_testing(&mut clock, ONE_HOUR_IN_MS + 1);
            
            // First unstake
            moonbags_stake::unstake<StakingToken>(&mut config, 300, &clock, scenario.ctx());
            
            // Verify pool and account state
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (pool_id, _, _, supply, _) = moonbags_stake::get_staking_pool_values_for_testing(staking_pool);
            assert!(supply == 700, EOutputEqualToExpected);
            
            let staking_account = get_staking_account(pool_id, USER_1);
            let (balance, _, _) = moonbags_stake::get_staking_account_values_for_testing(staking_account);
            assert!(balance == 700, EOutputEqualToExpected);
            
            // Second unstake
            moonbags_stake::unstake<StakingToken>(&mut config, 200, &clock, scenario.ctx());
            
            // Verify updated pool and account state
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (pool_id, _, _, supply, _) = moonbags_stake::get_staking_pool_values_for_testing(staking_pool);
            assert!(supply == 500, EOutputEqualToExpected);
            
            let staking_account = get_staking_account(pool_id, USER_1);
            let (balance, _, _) = moonbags_stake::get_staking_account_values_for_testing(staking_account);
            assert!(balance == 500, EOutputEqualToExpected);
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = moonbags_stake::EStakingPoolNotExist)]
    fun test_claim_staking_pool_pool_not_exist() {
        let mut scenario = test_scenario::begin(USER_1);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Try to claim rewards without initializing the staking pool
            moonbags_stake::claim_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx()); // Should fail
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = moonbags_stake::EStakingAccountNotExist)]
    fun test_claim_staking_pool_account_not_exist() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(ADMIN);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Initialize the staking pool
            moonbags_stake::initialize_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        // USER_1 tries to claim without having a staking account
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Try to claim without having staked first
            moonbags_stake::claim_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx()); // Should fail
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = moonbags_stake::ERewardToClaimNotValid)]
    fun test_claim_staking_pool_no_rewards() {
        let mut scenario = test_scenario::begin(USER_1);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Initialize the staking pool
            moonbags_stake::initialize_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());
            
            // Stake some tokens to create a staking account
            let stake_amount = 1000;
            let stake_coin = coin::mint_for_testing<StakingToken>(stake_amount, scenario.ctx());
            moonbags_stake::stake(&mut config, stake_coin, &clock, scenario.ctx());
            
            // Try to claim with no rewards accumulated
            moonbags_stake::claim_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx()); // Should fail
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    fun test_claim_staking_pool_success() {
        let mut scenario = test_scenario::begin(USER_1);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Initialize the staking pool
            moonbags_stake::initialize_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());
            
            // Stake some tokens
            let stake_amount = 1000;
            let stake_coin = coin::mint_for_testing<StakingToken>(stake_amount, scenario.ctx());
            moonbags_stake::stake(&mut config, stake_coin, &clock, scenario.ctx());
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(ADMIN);
        {
            // Add rewards
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            let reward_amount = 500;
            let reward_coin = coin::mint_for_testing<SUI>(reward_amount, scenario.ctx());
            moonbags_stake::update_reward_index<StakingToken>(&mut config, reward_coin, &clock, scenario.ctx());
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Verify expected rewards before claiming
            let expected_rewards = moonbags_stake::calculate_rewards_earned<StakingToken>(&config, scenario.ctx());
            assert!(expected_rewards == 500, EOutputEqualToExpected);
            
            // Claim rewards
            let claimed_amount = moonbags_stake::claim_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());
            assert!(claimed_amount == 500, EOutputEqualToExpected);
            
            // Verify pool state after claim
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (pool_id, _, sui_token_value, _, _) = moonbags_stake::get_staking_pool_values_for_testing(staking_pool);
            assert!(sui_token_value == 0, EOutputEqualToExpected); // All rewards claimed
            
            // Verify account state after claim
            let staking_account = get_staking_account(pool_id, USER_1);
            let (_, _, earned) = moonbags_stake::get_staking_account_values_for_testing(staking_account);
            assert!(earned == 0, EOutputEqualToExpected); // No more rewards to claim
            
            // Verify attempting to claim again would fail (we're not executing this, just checking)
            let rewards_after = moonbags_stake::calculate_rewards_earned<StakingToken>(&config, scenario.ctx());
            assert!(rewards_after == 0, EOutputEqualToExpected);
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = moonbags_stake::EStakingCreatorNotExist)]
    fun test_claim_creator_pool_not_exist() {
        let mut scenario = test_scenario::begin(USER_1);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Try to claim from a non-existent creator pool
            moonbags_stake::claim_creator_pool<StakingToken>(&mut config, &clock, scenario.ctx()); // Should fail
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = moonbags_stake::EInvalidCreator)]
    fun test_claim_creator_pool_invalid_creator() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(ADMIN);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Initialize creator pool with USER_1 as the creator
            moonbags_stake::initialize_creator_pool<StakingToken>(&mut config, USER_1, &clock, scenario.ctx());
            
            // Add some rewards to the pool
            let reward_amount = 1000;
            let reward_coin = coin::mint_for_testing<SUI>(reward_amount, scenario.ctx());
            moonbags_stake::deposit_creator_pool<StakingToken>(&mut config, reward_coin, &clock, scenario.ctx());
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        // USER_2 tries to claim from USER_1's creator pool
        scenario.next_tx(USER_2);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // USER_2 tries to claim from USER_1's creator pool - should fail
            moonbags_stake::claim_creator_pool<StakingToken>(&mut config, &clock, scenario.ctx());
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = moonbags_stake::ERewardToClaimNotValid)]
    fun test_claim_creator_pool_no_rewards() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(ADMIN);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Initialize creator pool with USER_1 as the creator but no rewards
            moonbags_stake::initialize_creator_pool<StakingToken>(&mut config, USER_1, &clock, scenario.ctx());
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // USER_1 tries to claim with no rewards in the pool - should fail
            moonbags_stake::claim_creator_pool<StakingToken>(&mut config, &clock, scenario.ctx());
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    fun test_claim_creator_pool_success() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(ADMIN);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Initialize creator pool with USER_1 as the creator
            moonbags_stake::initialize_creator_pool<StakingToken>(&mut config, USER_1, &clock, scenario.ctx());
            
            // Add rewards to the pool
            let reward_amount = 2500;
            let reward_coin = coin::mint_for_testing<SUI>(reward_amount, scenario.ctx());
            moonbags_stake::deposit_creator_pool<StakingToken>(&mut config, reward_coin, &clock, scenario.ctx());
            
            // Verify initial pool state
            let creator_pool = get_creator_pool<StakingToken>(&config);
            let initial_reward = moonbags_stake::get_creator_pool_reward_value_for_testing(creator_pool);
            assert!(initial_reward == 2500, EOutputEqualToExpected);
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            
            // USER_1 claims rewards as the creator
            let claimed_amount = moonbags_stake::claim_creator_pool<StakingToken>(&mut config, &clock, scenario.ctx());
            assert!(claimed_amount == 2500, EOutputEqualToExpected);
            
            // Verify pool state after claim
            let creator_pool = get_creator_pool<StakingToken>(&config);
            let remaining_reward = moonbags_stake::get_creator_pool_reward_value_for_testing(creator_pool);
            assert!(remaining_reward == 0, EOutputEqualToExpected);
            
            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    /*
    * Full Test with Scenarios:
    * 1. admin create staking pool
    * 2. user_1 stake 10_000 token in
    * 3. admin add reward 1_000 sui
    * 4. user_2 stake 15_000 token in
    * 5. admin add reward 1_000 sui
    * 6. user_1 claims rewards
    * 7. admin add reward 1_000 sui
    * 8. user_1 unstakes 5_000 tokens
    * 9. user_2 claims rewards
    * 10. admin create creator pool
    * 11. admin deposit 1000 sui to creator pool
    * 12. user_1 claim from creator pool
    */
    #[test]
    fun test_full_wih_scenarios() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(ADMIN); // admin create staking pool
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());

            // Create staking pool
            moonbags_stake::initialize_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());

            let staking_pool = get_staking_pool<StakingToken>(&config);

            // Check staking pool values
            let (_, staking_token_value, sui_token_value, total_supply, reward_index) = moonbags_stake::get_staking_pool_values_for_testing(staking_pool);
            assert!(staking_token_value == 0, EOutputEqualToExpected);
            assert!(sui_token_value == 0, EOutputEqualToExpected);
            assert!(total_supply == 0, EOutputEqualToExpected);
            assert!(reward_index == 0, EOutputEqualToExpected);

            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(USER_1); // user_1 stake 10000 token in
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());

            // Create staking coin
            let stake_amount = 10_000;
            let stake_coin = coin::mint_for_testing<StakingToken>(stake_amount, scenario.ctx());

            // Stake tokens
            moonbags_stake::stake(&mut config, stake_coin, &clock, scenario.ctx());

            // Check updated pool values
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (pool_id, staking_token_value, sui_token_value, total_supply, reward_index) = moonbags_stake::get_staking_pool_values_for_testing(staking_pool);

            assert!(staking_token_value == 10_000, EOutputEqualToExpected);
            assert!(sui_token_value == 0, EOutputEqualToExpected);
            assert!(total_supply == 10_000, EOutputEqualToExpected);
            assert!(reward_index == 0, EOutputEqualToExpected);

            let staking_account = get_staking_account(pool_id, USER_1);
            let (balance, reward_index, earned) = moonbags_stake::get_staking_account_values_for_testing(staking_account);

            assert!(balance == 10_000, EOutputEqualToExpected);
            assert!(reward_index == 0, EOutputEqualToExpected);
            assert!(earned == 0, EOutputEqualToExpected);

            let user1_reward_earned = moonbags_stake::calculate_rewards_earned<StakingToken>(&config, scenario.ctx());
            assert!(user1_reward_earned == 0, EOutputEqualToExpected);

            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(ADMIN); // admin add reward 1000 sui
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());

            let reward_amount = 1_000;
            let reward_coin = coin::mint_for_testing<SUI>(reward_amount, scenario.ctx());

            // Update rewards
            moonbags_stake::update_reward_index<StakingToken>(&mut config, reward_coin, &clock, scenario.ctx());

            // Check updated pool values after reward
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (_, staking_token_value, sui_token_value, total_supply, reward_index) = moonbags_stake::get_staking_pool_values_for_testing(staking_pool);

            // Reward index should be updated: (reward_amount * MULTIPLIER) / total_supply
            assert!(reward_index == 100_000_000, EOutputEqualToExpected);
            assert!(sui_token_value == 1_000, EOutputEqualToExpected); 
            assert!(staking_token_value == 10_000, EOutputEqualToExpected);
            assert!(total_supply == 10_000, EOutputEqualToExpected);

            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(USER_2); // user_2 stake 15000 token in
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());

            // Create staking coin
            let stake_amount = 15_000;
            let stake_coin = coin::mint_for_testing<StakingToken>(stake_amount, scenario.ctx());

            // Stake tokens
            moonbags_stake::stake(&mut config, stake_coin, &clock, scenario.ctx());

            // Check updated pool values
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (pool_id, staking_token_value, sui_token_value, total_supply, reward_index) = moonbags_stake::get_staking_pool_values_for_testing(staking_pool);

            assert!(staking_token_value == 25_000, EOutputEqualToExpected);
            assert!(sui_token_value == 1_000, EOutputEqualToExpected);
            assert!(total_supply == 25_000, EOutputEqualToExpected);
            assert!(reward_index == 100_000_000, EOutputEqualToExpected);

            let staking_account = get_staking_account(pool_id, USER_2);
            let (balance, reward_index, earned) = moonbags_stake::get_staking_account_values_for_testing(staking_account);

            assert!(balance == 15_000, EOutputEqualToExpected);
            assert!(reward_index == 100_000_000, EOutputEqualToExpected);
            assert!(earned == 0, EOutputEqualToExpected);

            let user2_reward_earned = moonbags_stake::calculate_rewards_earned<StakingToken>(&config, scenario.ctx());
            assert!(user2_reward_earned == 0, EOutputEqualToExpected);

            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(ADMIN); // admin add reward 1000 sui
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());

            let reward_amount = 1_000;
            let reward_coin = coin::mint_for_testing<SUI>(reward_amount, scenario.ctx());

            // Update rewards
            moonbags_stake::update_reward_index<StakingToken>(&mut config, reward_coin, &clock, scenario.ctx());

            // Check updated pool values after reward
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (_, staking_token_value, sui_token_value, total_supply, reward_index) = moonbags_stake::get_staking_pool_values_for_testing(staking_pool);

            // Reward index should be updated: (reward_amount * MULTIPLIER) / total_supply
            assert!(reward_index == 140_000_000, EOutputEqualToExpected);
            assert!(sui_token_value == 2_000, EOutputEqualToExpected); 
            assert!(staking_token_value == 25_000, EOutputEqualToExpected);
            assert!(total_supply == 25_000, EOutputEqualToExpected);

            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(USER_1); // user_1 claims rewards
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());

            // Calculate expected rewards for USER_1 before claiming
            let user1_reward_before = moonbags_stake::calculate_rewards_earned<StakingToken>(&config, scenario.ctx());
            assert!(user1_reward_before == 1400, EOutputEqualToExpected);

            // Claim rewards
            let claimed_amount = moonbags_stake::claim_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());
            assert!(claimed_amount == 1400, EOutputEqualToExpected);

            // Verify pool state after claim
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (pool_id, staking_token_value, sui_token_value, total_supply, reward_index) = moonbags_stake::get_staking_pool_values_for_testing(staking_pool);
            
            assert!(staking_token_value == 25_000, EOutputEqualToExpected);
            assert!(sui_token_value == 600, EOutputEqualToExpected);
            assert!(total_supply == 25_000, EOutputEqualToExpected);
            assert!(reward_index == 140_000_000, EOutputEqualToExpected);

            // Verify user's staking account
            let staking_account = get_staking_account(pool_id, USER_1);
            let (balance, acc_reward_index, earned) = moonbags_stake::get_staking_account_values_for_testing(staking_account);
            
            assert!(balance == 10_000, EOutputEqualToExpected);
            assert!(acc_reward_index == 140_000_000, EOutputEqualToExpected);
            assert!(earned == 0, EOutputEqualToExpected); // Earned should be 0 after claiming

            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(ADMIN); // admin add reward 1000 sui
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());

            let reward_amount = 1_000;
            let reward_coin = coin::mint_for_testing<SUI>(reward_amount, scenario.ctx());

            // Update rewards
            moonbags_stake::update_reward_index<StakingToken>(&mut config, reward_coin, &clock, scenario.ctx());

            // Check updated pool values after reward
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (_, staking_token_value, sui_token_value, total_supply, reward_index) = moonbags_stake::get_staking_pool_values_for_testing(staking_pool);

            assert!(staking_token_value == 25_000, EOutputEqualToExpected);
            assert!(sui_token_value == 1_600, EOutputEqualToExpected); 
            assert!(total_supply == 25_000, EOutputEqualToExpected);
            assert!(reward_index == 180_000_000, EOutputEqualToExpected);

            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(USER_1); // user_1 unstakes 5_000 tokens
        {
            let mut config = scenario.take_shared<Configuration>();
            let mut clock = clock::create_for_testing(scenario.ctx());
            clock::increment_for_testing(&mut clock, ONE_HOUR_IN_MS); // increase 1 hour

            // Unstake tokens
            moonbags_stake::unstake<StakingToken>(&mut config, 5_000, &clock, scenario.ctx());

            // Check updated pool values after unstake
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (pool_id, staking_token_value, sui_token_value, total_supply, reward_index) = moonbags_stake::get_staking_pool_values_for_testing(staking_pool);

            assert!(staking_token_value == 20_000, EOutputEqualToExpected);
            assert!(sui_token_value == 1_600, EOutputEqualToExpected);
            assert!(total_supply == 20_000, EOutputEqualToExpected);
            assert!(reward_index == 180_000_000, EOutputEqualToExpected);

            // Verify user's staking account after unstake
            let staking_account = get_staking_account(pool_id, USER_1);
            let (balance, acc_reward_index, earned) = moonbags_stake::get_staking_account_values_for_testing(staking_account);

            assert!(balance == 5_000, EOutputEqualToExpected);
            assert!(acc_reward_index == 180_000_000, EOutputEqualToExpected);
            assert!(earned == 400, EOutputEqualToExpected);

            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(USER_2); // user_2 claims rewards
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());

            // Calculate expected rewards for USER_2 before claiming
            let user2_reward_before = moonbags_stake::calculate_rewards_earned<StakingToken>(&config, scenario.ctx());
            assert!(user2_reward_before == 1200, EOutputEqualToExpected);

            // Claim rewards
            let claimed_amount = moonbags_stake::claim_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());
            assert!(claimed_amount == 1200, EOutputEqualToExpected);

            // Verify pool state after claim
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (pool_id, staking_token_value, sui_token_value, total_supply, reward_index) = moonbags_stake::get_staking_pool_values_for_testing(staking_pool);
            
            assert!(staking_token_value == 20_000, EOutputEqualToExpected);
            assert!(sui_token_value == 400, EOutputEqualToExpected);
            assert!(total_supply == 20_000, EOutputEqualToExpected);
            assert!(reward_index == 180_000_000, EOutputEqualToExpected);

            // Verify user's staking account
            let staking_account = get_staking_account(pool_id, USER_2);
            let (balance, acc_reward_index, earned) = moonbags_stake::get_staking_account_values_for_testing(staking_account);
            
            assert!(balance == 15_000, EOutputEqualToExpected);
            assert!(acc_reward_index == 180_000_000, EOutputEqualToExpected);
            assert!(earned == 0, EOutputEqualToExpected); // Earned should be 0 after claiming

            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(ADMIN); // admin create creator pool
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());

            // Create staking pool
            moonbags_stake::initialize_creator_pool<StakingToken>(&mut config, USER_1, &clock, scenario.ctx());

            let creator_pool = get_creator_pool<StakingToken>(&config);

            // Check staking pool values
            let reward_sui = moonbags_stake::get_creator_pool_reward_value_for_testing(creator_pool);
            assert!(reward_sui == 0, EOutputEqualToExpected);

            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(ADMIN); // admin deposit 1000 sui to creator pool
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());

            let reward_amount = 1_000;
            let reward_coin = coin::mint_for_testing<SUI>(reward_amount, scenario.ctx());

            moonbags_stake::deposit_creator_pool<StakingToken>(&mut config, reward_coin, &clock, scenario.ctx());

            let creator_pool = get_creator_pool<StakingToken>(&config);

            // Check staking pool values
            let reward_sui = moonbags_stake::get_creator_pool_reward_value_for_testing(creator_pool);

            assert!(reward_sui == 1_000, EOutputEqualToExpected);

            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(USER_1); // user_1 claim from creator pool
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());

            let reward_sui = moonbags_stake::claim_creator_pool<StakingToken>(&mut config, &clock, scenario.ctx());

            assert!(reward_sui == 1_000, EOutputEqualToExpected);

            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }
}

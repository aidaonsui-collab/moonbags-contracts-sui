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
    fun test_init() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
        };
        scenario.end();
    }

    // #[test]
    // fun test_initialize_staking_pool() {
    //     let mut scenario = test_scenario::begin(ADMIN);
    //     {
    //         moonbags_stake::init_for_testing(scenario.ctx());
    //         let mut config = scenario.take_shared<Configuration>();
    //         let clock = clock::create_for_testing(scenario.ctx());
            
    //         let staking_pool_address = type_name::get_address(&type_name::get<StakingPool<StakingToken>>());

    //         // Call initialize_staking_pool
    //         moonbags_stake::initialize_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());

    //         // Verify that the staking pool was created
    //         assert!(dynamic_object_field::exists_(&config.id, staking_pool_address), EPoolAlreadyExist);

    //         // Ensure reinitialization fails
    //         let error = move_to::catch_abort(|| {
    //             moonbags_stake::initialize_staking_pool<StakingToken>(&mut config, &clock, scenario.ctx());
    //         });
    //         assert!(error == EPoolAlreadyExist, 0);

    //         test_scenario::return_shared(config);
    //         clock::destroy_for_testing(clock);
    //     };
    //     scenario.end();
    // }

    // *
    // Test Scenarios:
    // 1. admin create staking pool
    // 2. user_1 stake 10_000 token in
    // 3. admin add reward 1_000 sui
    // 4. user_2 stake 15_000 token in
    // 5. admin add reward 1_000 sui
    // 6. user_1 claims rewards
    // 7. admin add reward 1_000 sui
    // 8. user_1 unstakes 5_000 tokens
    // 9. user_2 claims rewards
    // *
    #[test]
    fun test_taking_pool_scenarios() {
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
            assert!(reward_index == 100_000_000_000_000_000, EOutputEqualToExpected);
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
            assert!(reward_index == 100_000_000_000_000_000, EOutputEqualToExpected);

            let staking_account = get_staking_account(pool_id, USER_2);
            let (balance, reward_index, earned) = moonbags_stake::get_staking_account_values_for_testing(staking_account);

            assert!(balance == 15_000, EOutputEqualToExpected);
            assert!(reward_index == 100_000_000_000_000_000, EOutputEqualToExpected);
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
            assert!(reward_index == 140_000_000_000_000_000, EOutputEqualToExpected);
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
            assert!(reward_index == 140_000_000_000_000_000, EOutputEqualToExpected);

            // Verify user's staking account
            let staking_account = get_staking_account(pool_id, USER_1);
            let (balance, acc_reward_index, earned) = moonbags_stake::get_staking_account_values_for_testing(staking_account);
            
            assert!(balance == 10_000, EOutputEqualToExpected);
            assert!(acc_reward_index == 140_000_000_000_000_000, EOutputEqualToExpected);
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
            assert!(reward_index == 180_000_000_000_000_000, EOutputEqualToExpected);

            test_scenario::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(USER_1); // user_1 unstakes 5_000 tokens
        {
            let mut config = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());

            // Unstake tokens
            moonbags_stake::unstake<StakingToken>(&mut config, 5_000, &clock, scenario.ctx());

            // Check updated pool values after unstake
            let staking_pool = get_staking_pool<StakingToken>(&config);
            let (pool_id, staking_token_value, sui_token_value, total_supply, reward_index) = moonbags_stake::get_staking_pool_values_for_testing(staking_pool);

            assert!(staking_token_value == 20_000, EOutputEqualToExpected);
            assert!(sui_token_value == 1_600, EOutputEqualToExpected);
            assert!(total_supply == 20_000, EOutputEqualToExpected);
            assert!(reward_index == 180_000_000_000_000_000, EOutputEqualToExpected);

            // Verify user's staking account after unstake
            let staking_account = get_staking_account(pool_id, USER_1);
            let (balance, acc_reward_index, earned) = moonbags_stake::get_staking_account_values_for_testing(staking_account);

            assert!(balance == 5_000, EOutputEqualToExpected);
            assert!(acc_reward_index == 180_000_000_000_000_000, EOutputEqualToExpected);
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
            assert!(reward_index == 180_000_000_000_000_000, EOutputEqualToExpected);

            // Verify user's staking account
            let staking_account = get_staking_account(pool_id, USER_2);
            let (balance, acc_reward_index, earned) = moonbags_stake::get_staking_account_values_for_testing(staking_account);
            
            assert!(balance == 15_000, EOutputEqualToExpected);
            assert!(acc_reward_index == 180_000_000_000_000_000, EOutputEqualToExpected);
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

    // *
    // Test Scenarios:
    // 1. admin create creator pool
    // 2. admin deposit 1000 sui to creator pool
    // 3. user_1 claim from creator pool
    // *
    #[test]
    fun test_creator_pool_scenarios() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags_stake::init_for_testing(scenario.ctx());
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

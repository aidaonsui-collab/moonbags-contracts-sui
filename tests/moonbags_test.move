#[test_only]
module moonbags::moonbags_test {
    use sui::test_scenario::{Self, Scenario};
    use sui::clock;
    use sui::coin;
    use sui::sui::SUI;
    use std::string;

    use cetus_clmm::pool::{Pool as CetusPool};

    use moonbags::moonbags as mb;
    use moonbags::moonbags::{
        Self,
        Configuration as BondingConfig,
        AdminCap,
        ThresholdConfig,
    };
    use moonbags::moonbags_stake::{Self, Configuration as StakeConfig};
    use moonbags::staking_test::{get_creator_pool, get_staking_pool};

    const ADMIN: address = @0x00;
    const USER_1: address = @0x10;
    const RECIPIENT_FEE: u64 = 1_000_000_000_000;
    const ONE_TOKEN: u64 = 1_000_000;
    const ONE_SUI: u64 = 1_000_000_000;

    const TOKEN_NAME: vector<u8> = b"TOKEN_NAME";
    const TOKEN_SYMBOL: vector<u8> = b"TOKEN_SYMBOL";
    const TOKEN_URI: vector<u8> = b"TOKEN_URI";
    const TOKEN_DESCRIPTION: vector<u8> = b"TOKEN_DESCRIPTION";
    const TWITTER: vector<u8> = b"TWITTER";
    const TELEGRAM: vector<u8> = b"TELEGRAM";
    const WEBSITE: vector<u8> = b"WEBSITE";



    const EOutputNotEqualToExpected: u64 = 0;

    public struct TestToken has drop {}
    public struct SHRO has drop {}

    #[test_only]
    fun init_before_test(scenario: &mut Scenario) {
        {
            moonbags::init_for_testing(scenario.ctx());
            moonbags_stake::init_for_testing(scenario.ctx());
        };
    }

    #[test_only]
    fun create_token_for_test(scenario: &mut Scenario) {
        {
            let mut config = scenario.take_shared<BondingConfig>();
            let mut stake_config = scenario.take_shared<StakeConfig>();
            let treasury_cap = coin::create_treasury_cap_for_testing<TestToken>(scenario.ctx());
            let clock = clock::create_for_testing(scenario.ctx());
            mb::create(
                &mut config,
                &mut stake_config,
                treasury_cap,
                option::none(),
                &clock,
                TOKEN_NAME.to_ascii_string(),
                TOKEN_SYMBOL.to_ascii_string(),
                TOKEN_URI.to_ascii_string(),
                TOKEN_DESCRIPTION.to_ascii_string(),
                TWITTER.to_ascii_string(),
                TELEGRAM.to_ascii_string(),
                WEBSITE.to_ascii_string(),
                scenario.ctx()
            );
            test_scenario::return_shared(config);
            test_scenario::return_shared(stake_config);
            clock::destroy_for_testing(clock);
        };
    }

    #[test]
    fun withdraw_fee_testing() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(ADMIN);
        {
            let mut bonding_config = scenario.take_shared<BondingConfig>();
            let mut stake_config = scenario.take_shared<StakeConfig>();
            let clock = clock::create_for_testing(scenario.ctx());
            let treasury_cap = coin::create_treasury_cap_for_testing<TestToken>(scenario.ctx());

            let fee_recipient_coin = coin::mint_for_testing<SUI>(RECIPIENT_FEE, scenario.ctx()); // 1000 sui

            moonbags_stake::initialize_staking_pool<SHRO>(&mut stake_config, &clock, scenario.ctx());
            moonbags::create_pool_for_withdraw_fee_testing<TestToken>(&mut bonding_config, treasury_cap, fee_recipient_coin, scenario.ctx());
            moonbags_stake::initialize_staking_pool<TestToken>(&mut stake_config, &clock, scenario.ctx());
            moonbags_stake::initialize_creator_pool<TestToken>(&mut stake_config, USER_1, &clock, scenario.ctx());

            moonbags::update_config_for_testing(&mut bonding_config, b"0000000000000000000000000000000000000000000000000000000000000000::moonbags_test::SHRO".to_ascii_string());

            let stake_amount = 10_000;
            let platform_stake_coin = coin::mint_for_testing<SHRO>(stake_amount, scenario.ctx());
            let stake_coin = coin::mint_for_testing<TestToken>(stake_amount, scenario.ctx());

            // Stake tokens
            moonbags_stake::stake<TestToken>(&mut stake_config, stake_coin, &clock, scenario.ctx());
            moonbags_stake::stake<SHRO>(&mut stake_config, platform_stake_coin, &clock, scenario.ctx());

            test_scenario::return_shared(bonding_config);
            test_scenario::return_shared(stake_config);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(USER_1);
        {
            let mut bonding_config = scenario.take_shared<BondingConfig>();
            let mut stake_config = scenario.take_shared<StakeConfig>();
            let clock = clock::create_for_testing(scenario.ctx());

            let mut option_cetus_pool = option::none<CetusPool<TestToken, SUI>>();

            let (admin, cetus_config) = cetus_clmm::config::new_global_config_for_test(scenario.ctx(), 2000);

            moonbags::withdraw_fee<TestToken, SHRO>(&mut bonding_config, &mut stake_config, &cetus_config, &mut option_cetus_pool, &clock, scenario.ctx());

            let (_, creator_fee_withdraw, stake_fee_withdraw, platform_stake_fee_withdraw) = moonbags::get_config_value_for_testing(&bonding_config);

            let staking_pool = get_staking_pool<TestToken>(&stake_config);
            let (_, _, sui_reward_value, _, _, _) = moonbags_stake::get_staking_pool_values_for_testing(staking_pool);
            assert!(sui_reward_value == RECIPIENT_FEE * (stake_fee_withdraw as u64) / 10_000, EOutputNotEqualToExpected);

            let staking_pool = get_staking_pool<SHRO>(&stake_config);
            let (_, _, sui_reward_value, _, _, _) = moonbags_stake::get_staking_pool_values_for_testing(staking_pool);
            assert!(sui_reward_value == RECIPIENT_FEE * (platform_stake_fee_withdraw as u64) / 10_000, EOutputNotEqualToExpected);

            let staking_pool = get_creator_pool<TestToken>(&stake_config);
            let sui_reward_value = moonbags_stake::get_creator_pool_reward_value_for_testing(staking_pool);
            assert!(sui_reward_value == RECIPIENT_FEE * (creator_fee_withdraw as u64) / 10_000, EOutputNotEqualToExpected);

            option::destroy_none(option_cetus_pool);

            transfer::public_transfer(admin, ADMIN);
            transfer::public_transfer(cetus_config, ADMIN);

            test_scenario::return_shared(bonding_config);
            test_scenario::return_shared(stake_config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    fun test_create_token() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(USER_1);
        {
            create_token_for_test(&mut scenario);
        };
        scenario.end();
    }

    #[test]
    fun test_check_pool_exist() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(USER_1);
        {
            create_token_for_test(&mut scenario);
        };
        scenario.next_tx(USER_1);
        {
            let config = scenario.take_shared<BondingConfig>();
            let is_exist = mb::check_pool_exist<TestToken>(&config);
            assert!(is_exist == true, EOutputNotEqualToExpected);
            test_scenario::return_shared(config);
        };
        scenario.end();
    }

    #[test]
    fun test_check_pool_exist_without_create() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(USER_1);
        {
            let config = scenario.take_shared<BondingConfig>();
            let is_exist = mb::check_pool_exist<TestToken>(&config);
            assert!(is_exist == false, EOutputNotEqualToExpected);
            test_scenario::return_shared(config);
        };
        scenario.end();
    }

    #[test]
    fun test_create_threshold_config() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(ADMIN);
        {
            let admin_cap = scenario.take_from_sender<AdminCap>();
            mb::create_threshold_config(&admin_cap, 100, scenario.ctx());
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        scenario.end();
    }

    #[test]
    fun test_update_threshold_config() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(ADMIN);
        {
            let admin_cap = scenario.take_from_sender<AdminCap>();
            mb::create_threshold_config(&admin_cap, 100, scenario.ctx());
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        scenario.next_tx(ADMIN);
        {
            let admin_cap = scenario.take_from_sender<AdminCap>();
            let mut threshold_config = scenario.take_shared<ThresholdConfig>();
            mb::update_threshold_config(&admin_cap, &mut threshold_config, 200);
            test_scenario::return_to_sender(&scenario, admin_cap);
            test_scenario::return_shared(threshold_config);
        };
        scenario.end();
    }

    #[test]
    fun test_early_complete_pool() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(ADMIN);
        {
            let admin_cap = scenario.take_from_sender<AdminCap>();
            mb::create_threshold_config(&admin_cap, ONE_TOKEN * 2000, scenario.ctx());
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        scenario.next_tx(ADMIN);
        {
            let mut bonding_config = scenario.take_shared<BondingConfig>();
            let treasury_cap = coin::create_treasury_cap_for_testing<TestToken>(scenario.ctx());
            let fee_recipient_coin = coin::mint_for_testing<SUI>(RECIPIENT_FEE, scenario.ctx()); // 1000 sui
            moonbags::create_pool_for_withdraw_fee_testing<TestToken>(&mut bonding_config, treasury_cap, fee_recipient_coin, scenario.ctx());
            test_scenario::return_shared(bonding_config);
        };
        scenario.next_tx(ADMIN);
        {
            let mut config = scenario.take_shared<BondingConfig>();
            let mut threshold_config = scenario.take_shared<ThresholdConfig>();
            let admin_cap = scenario.take_from_sender<AdminCap>();
            let pool = mb::borrow_mut_pool<TestToken>(&mut config);
            let coin_sui = coin::mint_for_testing<SUI>(ONE_TOKEN * 2000, scenario.ctx());
            mb::join_sui_for_testing(pool, coin_sui);
            let clock = clock::create_for_testing(scenario.ctx());
            mb::early_complete_pool<TestToken>(&admin_cap, &mut config, &mut threshold_config, &clock, scenario.ctx());
            test_scenario::return_shared(config);
            test_scenario::return_shared(threshold_config);
            test_scenario::return_to_sender(&scenario, admin_cap);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = mb::ENotEnoughThreshold)]
    fun test_early_complete_pool_not_enough_threshold() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(ADMIN);
        {
            let admin_cap = scenario.take_from_sender<AdminCap>();
            mb::create_threshold_config(&admin_cap, ONE_TOKEN * 2000, scenario.ctx());
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        scenario.next_tx(ADMIN);
        {
            let mut bonding_config = scenario.take_shared<BondingConfig>();
            let treasury_cap = coin::create_treasury_cap_for_testing<TestToken>(scenario.ctx());
            let fee_recipient_coin = coin::mint_for_testing<SUI>(RECIPIENT_FEE, scenario.ctx()); // 1000 sui
            moonbags::create_pool_for_withdraw_fee_testing<TestToken>(&mut bonding_config, treasury_cap, fee_recipient_coin, scenario.ctx());
            test_scenario::return_shared(bonding_config);
        };
        scenario.next_tx(ADMIN);
        {
            let mut config = scenario.take_shared<BondingConfig>();
            let mut threshold_config = scenario.take_shared<ThresholdConfig>();
            let admin_cap = scenario.take_from_sender<AdminCap>();
            let pool = mb::borrow_mut_pool<TestToken>(&mut config);
            let coin_sui = coin::mint_for_testing<SUI>(ONE_TOKEN * 1000, scenario.ctx());
            mb::join_sui_for_testing(pool, coin_sui);
            let clock = clock::create_for_testing(scenario.ctx());
            mb::early_complete_pool<TestToken>(&admin_cap, &mut config, &mut threshold_config, &clock, scenario.ctx());
            test_scenario::return_shared(config);
            test_scenario::return_shared(threshold_config);
            test_scenario::return_to_sender(&scenario, admin_cap);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }

    #[test]
    fun test_skim() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(ADMIN);
        {
            let admin_cap = scenario.take_from_sender<AdminCap>();
            mb::create_threshold_config(&admin_cap, ONE_TOKEN * 2000, scenario.ctx());
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        scenario.next_tx(ADMIN);
        {
            let mut bonding_config = scenario.take_shared<BondingConfig>();
            let treasury_cap = coin::create_treasury_cap_for_testing<TestToken>(scenario.ctx());
            let fee_recipient_coin = coin::mint_for_testing<SUI>(RECIPIENT_FEE, scenario.ctx()); // 1000 sui
            moonbags::create_pool_for_withdraw_fee_testing<TestToken>(&mut bonding_config, treasury_cap, fee_recipient_coin, scenario.ctx());
            test_scenario::return_shared(bonding_config);
        };
        scenario.next_tx(ADMIN);
        {
            let mut config = scenario.take_shared<BondingConfig>();
            let mut threshold_config = scenario.take_shared<ThresholdConfig>();
            let admin_cap = scenario.take_from_sender<AdminCap>();
            let pool = mb::borrow_mut_pool<TestToken>(&mut config);
            let coin_sui = coin::mint_for_testing<SUI>(ONE_TOKEN * 2000, scenario.ctx());
            mb::join_sui_for_testing(pool, coin_sui);
            let clock = clock::create_for_testing(scenario.ctx());
            mb::early_complete_pool<TestToken>(&admin_cap, &mut config, &mut threshold_config, &clock, scenario.ctx());
            test_scenario::return_shared(config);
            test_scenario::return_shared(threshold_config);
            test_scenario::return_to_sender(&scenario, admin_cap);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(ADMIN);
        {
            let admin_cap = scenario.take_from_sender<AdminCap>();
            let mut config = scenario.take_shared<BondingConfig>();
            mb::skim<TestToken>(&admin_cap, &mut config, scenario.ctx());
            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = mb::ECompletedPool)]
    fun test_skim_not_completed() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(ADMIN);
        {
            let admin_cap = scenario.take_from_sender<AdminCap>();
            mb::create_threshold_config(&admin_cap, ONE_TOKEN * 2000, scenario.ctx());
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        scenario.next_tx(ADMIN);
        {
            let mut bonding_config = scenario.take_shared<BondingConfig>();
            let treasury_cap = coin::create_treasury_cap_for_testing<TestToken>(scenario.ctx());
            let fee_recipient_coin = coin::mint_for_testing<SUI>(RECIPIENT_FEE, scenario.ctx()); // 1000 sui
            moonbags::create_pool_for_withdraw_fee_testing<TestToken>(&mut bonding_config, treasury_cap, fee_recipient_coin, scenario.ctx());
            test_scenario::return_shared(bonding_config);
        };
        scenario.next_tx(ADMIN);
        {
            let admin_cap = scenario.take_from_sender<AdminCap>();
            let mut config = scenario.take_shared<BondingConfig>();
            mb::skim<TestToken>(&admin_cap, &mut config, scenario.ctx());
            test_scenario::return_shared(config);
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = mb::EInvalidInput)]
    fun test_create_pool_invalid_uri_length() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<BondingConfig>();
            let mut stake_config = scenario.take_shared<StakeConfig>();
            let treasury_cap = coin::create_treasury_cap_for_testing<TestToken>(scenario.ctx());
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Creating a URI string that exceeds the 300 character limit
            let mut long_uri = string::utf8(vector::empty<u8>());
            let mut i = 0;
            while (i < 301) {
                string::append_utf8(&mut long_uri, b"a");
                i = i + 1;
            };
            
            mb::create(
                &mut config,
                &mut stake_config,
                treasury_cap,
                option::none(),
                &clock,
                TOKEN_NAME.to_ascii_string(),
                TOKEN_SYMBOL.to_ascii_string(),
                long_uri.to_ascii(),
                TOKEN_DESCRIPTION.to_ascii_string(),
                TWITTER.to_ascii_string(),
                TELEGRAM.to_ascii_string(),
                WEBSITE.to_ascii_string(),
                scenario.ctx()
            );
            test_scenario::return_shared(config);
            test_scenario::return_shared(stake_config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }
    
    #[test]
    #[expected_failure(abort_code = mb::EInvalidInput)]
    fun test_create_pool_invalid_description_length() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<BondingConfig>();
            let mut stake_config = scenario.take_shared<StakeConfig>();
            let treasury_cap = coin::create_treasury_cap_for_testing<TestToken>(scenario.ctx());
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Creating a description string that exceeds the 1000 character limit
            let mut long_description = string::utf8(vector::empty<u8>());
            let mut i = 0;
            while (i < 1001) {
                string::append_utf8(&mut long_description, b"a");
                i = i + 1;
            };
            
            mb::create(
                &mut config,
                &mut stake_config,
                treasury_cap,
                option::none(),
                &clock,
                TOKEN_NAME.to_ascii_string(),
                TOKEN_SYMBOL.to_ascii_string(),
                TOKEN_URI.to_ascii_string(),
                long_description.to_ascii(),
                TWITTER.to_ascii_string(),
                TELEGRAM.to_ascii_string(),
                WEBSITE.to_ascii_string(),
                scenario.ctx()
            );
            test_scenario::return_shared(config);
            test_scenario::return_shared(stake_config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }
    
    #[test]
    #[expected_failure(abort_code = mb::EExistTokenSupply)]
    fun test_create_pool_non_zero_supply() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<BondingConfig>();
            let mut stake_config = scenario.take_shared<StakeConfig>();
            let mut treasury_cap = coin::create_treasury_cap_for_testing<TestToken>(scenario.ctx());
            
            // Mint some tokens before creating the pool
            let token = coin::mint<TestToken>(&mut treasury_cap, 1000, scenario.ctx());
            transfer::public_transfer(token, USER_1);
            
            let clock = clock::create_for_testing(scenario.ctx());
            mb::create(
                &mut config,
                &mut stake_config,
                treasury_cap,
                option::none(),
                &clock,
                TOKEN_NAME.to_ascii_string(),
                TOKEN_SYMBOL.to_ascii_string(),
                TOKEN_URI.to_ascii_string(),
                TOKEN_DESCRIPTION.to_ascii_string(),
                TWITTER.to_ascii_string(),
                TELEGRAM.to_ascii_string(),
                WEBSITE.to_ascii_string(),
                scenario.ctx()
            );
            test_scenario::return_shared(config);
            test_scenario::return_shared(stake_config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }
    
    #[test]
    #[expected_failure(abort_code = mb::EInvalidInput)]
    fun test_create_pool_below_min_threshold() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<BondingConfig>();
            let mut stake_config = scenario.take_shared<StakeConfig>();
            let treasury_cap = coin::create_treasury_cap_for_testing<TestToken>(scenario.ctx());
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Use a threshold below the minimum (2 SUI)
            let below_min_threshold = option::some(1000000000); // 1 SUI
            
            mb::create(
                &mut config,
                &mut stake_config,
                treasury_cap,
                below_min_threshold,
                &clock,
                TOKEN_NAME.to_ascii_string(),
                TOKEN_SYMBOL.to_ascii_string(),
                TOKEN_URI.to_ascii_string(),
                TOKEN_DESCRIPTION.to_ascii_string(),
                TWITTER.to_ascii_string(),
                TELEGRAM.to_ascii_string(),
                WEBSITE.to_ascii_string(),
                scenario.ctx()
            );
            test_scenario::return_shared(config);
            test_scenario::return_shared(stake_config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }
    
    #[test]
    fun test_create_pool_custom_threshold() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<BondingConfig>();
            let mut stake_config = scenario.take_shared<StakeConfig>();
            let treasury_cap = coin::create_treasury_cap_for_testing<TestToken>(scenario.ctx());
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Use a custom valid threshold (4 SUI)
            let custom_threshold = option::some(4000000000);
            
            mb::create(
                &mut config,
                &mut stake_config,
                treasury_cap,
                custom_threshold,
                &clock,
                TOKEN_NAME.to_ascii_string(),
                TOKEN_SYMBOL.to_ascii_string(),
                TOKEN_URI.to_ascii_string(),
                TOKEN_DESCRIPTION.to_ascii_string(),
                TWITTER.to_ascii_string(),
                TELEGRAM.to_ascii_string(),
                WEBSITE.to_ascii_string(),
                scenario.ctx()
            );
            
            // Verify that pool exists after creation
            let is_exist = mb::check_pool_exist<TestToken>(&config);
            assert!(is_exist == true, EOutputNotEqualToExpected);
            // Get the pool info and verify the values
            let (real_sui_reserves, real_token_reserves, virtual_sui_reserves, 
                virtual_token_reserves, is_completed, fee_recipient_value) = 
                mb::get_pool_info_for_testing<TestToken>(&config);

            // Check initial real reserves
            assert!(real_sui_reserves == 0, EOutputNotEqualToExpected);
            assert!(real_token_reserves == 8000000000000, EOutputNotEqualToExpected);

            // Check virtual reserves
            assert!(virtual_sui_reserves == 1000000000, EOutputNotEqualToExpected); 
            assert!(virtual_token_reserves == 10000000000000, EOutputNotEqualToExpected);

            // Check pool is not completed
            assert!(!is_completed, EOutputNotEqualToExpected);

            // Check fee recipient is empty initially
            assert!(fee_recipient_value == 0, EOutputNotEqualToExpected);
            
            test_scenario::return_shared(config);
            test_scenario::return_shared(stake_config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }
    
    #[test]
    fun test_buy_exact_out() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(USER_1);
        {
            create_token_for_test(&mut scenario);
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<BondingConfig>();
            // Mint some SUI to use for buying
            let coin_sui = coin::mint_for_testing<SUI>(ONE_SUI, scenario.ctx());
            
            // Buy tokens with exact output amount
            let amount_out = ONE_TOKEN * 100; // Want to buy 100 token
            moonbags::buy_exact_out_without_init_cetus<TestToken>(&mut config, coin_sui, amount_out, scenario.ctx());
            
            // Verify pool state after buying
            let (real_sui_reserves, real_token_reserves, virtual_sui_reserves, 
                virtual_token_reserves, _, fee_recipient) =
                moonbags::get_pool_info_for_testing<TestToken>(&config);

            assert!(real_sui_reserves == 7501, EOutputNotEqualToExpected);
            assert!(real_token_reserves == 7999900000000, EOutputNotEqualToExpected);
            assert!(virtual_sui_reserves == 750007501, EOutputNotEqualToExpected);
            assert!(virtual_token_reserves == 9999900000000, EOutputNotEqualToExpected);
            assert!(fee_recipient == 75, EOutputNotEqualToExpected);
            
            test_scenario::return_shared(config);
        };
        scenario.end();
    }
    
    #[test]
    #[expected_failure(abort_code = mb::EInsufficientInput)]
    fun test_buy_exact_out_insufficient_input() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(USER_1);
        {
            create_token_for_test(&mut scenario);
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<BondingConfig>();
            // Mint a tiny amount of SUI, not enough to buy the requested tokens
            let coin_sui = coin::mint_for_testing<SUI>(1, scenario.ctx());
            
            // Try to buy a substantial amount of tokens with insufficient SUI
            let amount_out = ONE_TOKEN; // Want to buy 1 token
            moonbags::buy_exact_out_without_init_cetus<TestToken>(&mut config, coin_sui, amount_out, scenario.ctx());
            
            test_scenario::return_shared(config);
        };
        scenario.end();
    }

    #[test]
    fun test_buy_all_tokens_completes_pool() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(USER_1);
        {
            create_token_for_test(&mut scenario);
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<BondingConfig>();        
            
            let coin_sui = coin::mint_for_testing<SUI>(ONE_SUI * 100, scenario.ctx());
            let token_amount_out = ONE_TOKEN * 100_000_000; // over amount
            
            // This should buy all tokens and trigger pool completion
            moonbags::buy_exact_out_without_init_cetus<TestToken>(&mut config, coin_sui, token_amount_out, scenario.ctx());
            
            // Check that pool is now completed
            let (real_sui, real_token, virtual_sui, virtual_token, is_completed, _) = 
                moonbags::get_pool_info_for_testing<TestToken>(&config);

            assert!(is_completed, EOutputNotEqualToExpected);
            assert!(real_token == 0, EOutputNotEqualToExpected);
            assert!(real_sui == 0, EOutputNotEqualToExpected);
            assert!(virtual_sui == 3750000001, EOutputNotEqualToExpected);
            assert!(virtual_token == 2000000000000, EOutputNotEqualToExpected);

            test_scenario::return_shared(config);
        };
        scenario.next_tx(ADMIN);
        {
            assert!(scenario.has_most_recent_for_sender<coin::Coin<SUI>>(), EOutputNotEqualToExpected);
        };
        scenario.end();
    }

    #[test]
    fun test_buy_exact_in() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(USER_1);
        {
            create_token_for_test(&mut scenario);
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<BondingConfig>();
            // Mint some SUI to use for buying 0,1 
            let coin_sui = coin::mint_for_testing<SUI>(ONE_SUI / 10, scenario.ctx());
            
            // Buy tokens with exact SUI input
            moonbags::buy_exact_in_without_init_cetus<TestToken>(&mut config, coin_sui, scenario.ctx());
            
            // Verify pool state after buying
            let (real_sui_reserves, real_token_reserves, virtual_sui_reserves, 
                virtual_token_reserves, _, fee_recipient) = moonbags::get_pool_info_for_testing<TestToken>(&config);

            assert!(real_sui_reserves == 99000000, EOutputNotEqualToExpected);
            assert!(real_token_reserves == 6833922261485, EOutputNotEqualToExpected);
            assert!(virtual_sui_reserves == 849000000, EOutputNotEqualToExpected);
            assert!(virtual_token_reserves == 8833922261485, EOutputNotEqualToExpected);
            assert!(fee_recipient == 1000000, EOutputNotEqualToExpected);
            
            test_scenario::return_shared(config);
        };
        scenario.end();
    }
    
    #[test]
    #[expected_failure(abort_code = mb::EInvalidInput)]
    fun test_buy_exact_in_zero_amount() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(USER_1);
        {
            create_token_for_test(&mut scenario);
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<BondingConfig>();
            let coin_sui = coin::mint_for_testing<SUI>(0, scenario.ctx());
            
            // Try to buy with zero SUI
            moonbags::buy_exact_in_without_init_cetus<TestToken>(&mut config, coin_sui, scenario.ctx());
            
            test_scenario::return_shared(config);
        };
        scenario.end();
    }
    
    #[test]
    fun test_buy_exact_in_completes_pool() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(USER_1);
        {
            create_token_for_test(&mut scenario);
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<BondingConfig>();
            
            // Mint large amount of SUI to buy all tokens
            let coin_sui = coin::mint_for_testing<SUI>(ONE_SUI * 100, scenario.ctx());
            
            // This should buy all tokens and trigger pool completion
            moonbags::buy_exact_in_without_init_cetus<TestToken>(&mut config, coin_sui, scenario.ctx());
            
            // Check that pool is now completed
            let (real_sui, real_token, virtual_sui, virtual_token, is_completed, _) = 
                moonbags::get_pool_info_for_testing<TestToken>(&config);

            assert!(is_completed, EOutputNotEqualToExpected);
            assert!(real_token == 0, EOutputNotEqualToExpected);
            assert!(real_sui == 0, EOutputNotEqualToExpected);
            assert!(virtual_sui == 3750000001, EOutputNotEqualToExpected);
            assert!(virtual_token == 2000000000000, EOutputNotEqualToExpected);

            test_scenario::return_shared(config);
        };
        scenario.next_tx(ADMIN);
        {
            assert!(scenario.has_most_recent_for_sender<coin::Coin<SUI>>(), EOutputNotEqualToExpected);
        };
        scenario.end();
    }

    #[test]
    fun test_sell() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(USER_1);
        {
            create_token_for_test(&mut scenario);
        };
        scenario.next_tx(USER_1); // buy 100
        {
            let mut config = scenario.take_shared<BondingConfig>();
            let coin_sui = coin::mint_for_testing<SUI>(ONE_SUI, scenario.ctx());
            
            let amount_out = ONE_TOKEN * 100;
            moonbags::buy_exact_out_without_init_cetus<TestToken>(&mut config, coin_sui, amount_out, scenario.ctx());
            
            test_scenario::return_shared(config);
        };
        scenario.next_tx(USER_1); // sell 10
        {
            let mut config = scenario.take_shared<BondingConfig>();
            
            // Mint tokens directly instead of buying first
            let token_obj = coin::mint_for_testing<TestToken>(ONE_TOKEN * 10, scenario.ctx());
            
            // Set minimum expected SUI amount
            let amount_out_min = 0; // Accept any amount for this test
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Sell tokens
            moonbags::sell<TestToken>(&mut config, token_obj, amount_out_min, &clock, scenario.ctx());
            
            // Verify pool state after selling
            let (real_sui, real_token, virtual_sui, virtual_token, _, fee_recipient) = 
                moonbags::get_pool_info_for_testing<TestToken>(&config);
            
            assert!(real_sui == 7500 - 750, EOutputNotEqualToExpected); // SUI decreased
            assert!(real_token == 7999900000000 + 10000000, EOutputNotEqualToExpected); // Token increased
            assert!(virtual_sui == 750007501 - 751, EOutputNotEqualToExpected); // Virtual SUI adjusted
            assert!(virtual_token == 9999900000000 + 10000000, EOutputNotEqualToExpected); // Virtual token adjusted
            assert!(fee_recipient == 75 + 7, EOutputNotEqualToExpected); // Fee increased
            
            // Check user received SUI
            assert!(scenario.has_most_recent_for_sender<coin::Coin<SUI>>(), EOutputNotEqualToExpected);
            
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(config);
        };
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = mb::EInvalidInput)] // Invalid slippage tolerance
    fun test_sell_slippage_too_high() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(USER_1);
        {
            create_token_for_test(&mut scenario);
        };
        scenario.next_tx(USER_1); // buy 100
        {
            let mut config = scenario.take_shared<BondingConfig>();
            let coin_sui = coin::mint_for_testing<SUI>(ONE_SUI, scenario.ctx());
            
            let amount_out = ONE_TOKEN * 100;
            moonbags::buy_exact_out_without_init_cetus<TestToken>(&mut config, coin_sui, amount_out, scenario.ctx());
            
            test_scenario::return_shared(config);
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<BondingConfig>();
            
            // Mint tokens directly
            let token_obj = coin::mint_for_testing<TestToken>(ONE_TOKEN * 100, scenario.ctx());
            
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Try to sell with an unrealistically high minimum output
            let amount_out_min = ONE_SUI * 100; // Way too high
            moonbags::sell<TestToken>(&mut config, token_obj, amount_out_min, &clock, scenario.ctx());
            
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(config);
        };
        scenario.end();
    }
    
    #[test]
    #[expected_failure(abort_code = mb::EInvalidInput)]
    fun test_sell_zero_tokens() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(USER_1);
        {
            create_token_for_test(&mut scenario);
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<BondingConfig>();
            // Create an empty token coin
            let empty_token = coin::mint_for_testing<TestToken>(0, scenario.ctx());
            
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Try to sell zero tokens
            moonbags::sell<TestToken>(&mut config, empty_token, 0, &clock, scenario.ctx());
            
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(config);
        };
        scenario.end();
    }
    
    #[test]
    #[expected_failure(abort_code = mb::ECompletedPool)]
    fun test_sell_to_completed_pool() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(ADMIN);
        {
            let admin_cap = scenario.take_from_sender<AdminCap>();
            mb::create_threshold_config(&admin_cap, ONE_TOKEN * 2000, scenario.ctx());
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        scenario.next_tx(ADMIN);
        {
            let mut bonding_config = scenario.take_shared<BondingConfig>();
            let treasury_cap = coin::create_treasury_cap_for_testing<TestToken>(scenario.ctx());
            let fee_recipient_coin = coin::mint_for_testing<SUI>(RECIPIENT_FEE, scenario.ctx());
            moonbags::create_pool_for_withdraw_fee_testing<TestToken>(&mut bonding_config, treasury_cap, fee_recipient_coin, scenario.ctx());
            test_scenario::return_shared(bonding_config);
        };
        scenario.next_tx(ADMIN);
        {
            // Mark the pool as completed
            let mut config = scenario.take_shared<BondingConfig>();
            let mut threshold_config = scenario.take_shared<ThresholdConfig>();
            let admin_cap = scenario.take_from_sender<AdminCap>();
            let pool = mb::borrow_mut_pool<TestToken>(&mut config);
            let coin_sui = coin::mint_for_testing<SUI>(ONE_TOKEN * 2000, scenario.ctx());
            mb::join_sui_for_testing(pool, coin_sui);
            let clock = clock::create_for_testing(scenario.ctx());
            mb::early_complete_pool<TestToken>(&admin_cap, &mut config, &mut threshold_config, &clock, scenario.ctx());
            test_scenario::return_shared(config);
            test_scenario::return_shared(threshold_config);
            test_scenario::return_to_sender(&scenario, admin_cap);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(USER_1);
        {
            let mut config = scenario.take_shared<BondingConfig>();
            let token_coins = coin::mint_for_testing<TestToken>(ONE_TOKEN, scenario.ctx());
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Try to sell to a completed pool
            moonbags::sell<TestToken>(&mut config, token_coins, 0, &clock, scenario.ctx());
            
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(config);
        };
        scenario.end();
    }
    
    #[test]
    fun test_sell_return() {
        let mut scenario = test_scenario::begin(ADMIN);
        init_before_test(&mut scenario);
        scenario.next_tx(USER_1);
        {
            create_token_for_test(&mut scenario);
        };
        scenario.next_tx(USER_1); // buy 100
        {
            let mut config = scenario.take_shared<BondingConfig>();
            let coin_sui = coin::mint_for_testing<SUI>(ONE_SUI, scenario.ctx());
            
            let amount_out = ONE_TOKEN * 100;
            moonbags::buy_exact_out_without_init_cetus<TestToken>(&mut config, coin_sui, amount_out, scenario.ctx());
            
            test_scenario::return_shared(config);
        };
        scenario.next_tx(USER_1); // sell 10
        {
            let mut config = scenario.take_shared<BondingConfig>();
            
            // Mint tokens directly instead of buying first
            let token_obj = coin::mint_for_testing<TestToken>(ONE_TOKEN * 10, scenario.ctx());
            
            // Set minimum expected SUI amount
            let amount_out_min = 0; // Accept any amount for this test
            let clock = clock::create_for_testing(scenario.ctx());
            
            // Sell tokens
            let (coin_sui_out, coin_token_out) = moonbags::sell_returns<TestToken>(&mut config, token_obj, amount_out_min, &clock, scenario.ctx());

            assert!(coin::value(&coin_sui_out) == 744, EOutputNotEqualToExpected); // Expected SUI received
            assert!(coin::value(&coin_token_out) == 0, EOutputNotEqualToExpected); // No token change expected
            
            // Verify pool state after selling
            let (real_sui, real_token, virtual_sui, virtual_token, _, fee_recipient) = 
                moonbags::get_pool_info_for_testing<TestToken>(&config);
            
            assert!(real_sui == 7500 - 750, EOutputNotEqualToExpected); // SUI decreased
            assert!(real_token == 7999900000000 + 10000000, EOutputNotEqualToExpected); // Token increased
            assert!(virtual_sui == 750007501 - 751, EOutputNotEqualToExpected); // Virtual SUI adjusted
            assert!(virtual_token == 9999900000000 + 10000000, EOutputNotEqualToExpected); // Virtual token adjusted
            assert!(fee_recipient == 75 + 7, EOutputNotEqualToExpected); // Fee increased
            
            // Clean up returned coins
            transfer::public_transfer(coin_sui_out, USER_1);
            transfer::public_transfer(coin_token_out, USER_1);
            
            clock::destroy_for_testing(clock);
            test_scenario::return_shared(config);
        };
        scenario.end();
    }
}

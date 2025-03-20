#[test_only]
module moonbags::moonbags_test {
    use sui::test_scenario::{Self, Scenario};
    use sui::clock;
    use sui::coin;
    use sui::sui::SUI;

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
    const ONE_TOKEN: u64 = 1_000_000_000;

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
            let (_, _, sui_reward_value, _, _) = moonbags_stake::get_staking_pool_values_for_testing(staking_pool);
            assert!(sui_reward_value == RECIPIENT_FEE * (stake_fee_withdraw as u64) / 10_000, EOutputNotEqualToExpected);

            let staking_pool = get_staking_pool<SHRO>(&stake_config);
            let (_, _, sui_reward_value, _, _) = moonbags_stake::get_staking_pool_values_for_testing(staking_pool);
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
}

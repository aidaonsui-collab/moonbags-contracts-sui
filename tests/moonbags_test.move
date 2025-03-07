#[test_only]
module moonbags::moonbags_test {
    use sui::test_scenario::Self;
    use sui::clock;
    use sui::coin;
    use sui::sui::SUI;

    use cetus_clmm::pool::{Pool as CetusPool};

    use moonbags::moonbags::{Self, Configuration as BondingConfig};
    use moonbags::moonbags_stake::{Self, Configuration as StakeConfig};
    use moonbags::staking_test::{get_creator_pool, get_staking_pool};

    const ADMIN: address = @0x00;
    const USER_1: address = @0x10;
    const RECIPIENT_FEE: u64 = 1_000_000_000_000;

    const EOutputEqualToExpected: u64 = 0;

    public struct TestToken has drop {}
    public struct SHRO has drop {}

    #[test]
    fun test_init() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags::init_for_testing(scenario.ctx());
        };
        scenario.end();
    }

    #[test]
    fun withdraw_fee_testing() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            moonbags::init_for_testing(scenario.ctx());
            moonbags_stake::init_for_testing(scenario.ctx());
        };
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
            assert!(sui_reward_value == RECIPIENT_FEE * (stake_fee_withdraw as u64) / 10_000, EOutputEqualToExpected);

            let staking_pool = get_staking_pool<SHRO>(&stake_config);
            let (_, _, sui_reward_value, _, _) = moonbags_stake::get_staking_pool_values_for_testing(staking_pool);
            assert!(sui_reward_value == RECIPIENT_FEE * (platform_stake_fee_withdraw as u64) / 10_000, EOutputEqualToExpected);

            let staking_pool = get_creator_pool<TestToken>(&stake_config);
            let sui_reward_value = moonbags_stake::get_creator_pool_reward_value_for_testing(staking_pool);
            assert!(sui_reward_value == RECIPIENT_FEE * (creator_fee_withdraw as u64) / 10_000, EOutputEqualToExpected);

            option::destroy_none(option_cetus_pool);

            transfer::public_transfer(admin, ADMIN);
            transfer::public_transfer(cetus_config, ADMIN);

            test_scenario::return_shared(bonding_config);
            test_scenario::return_shared(stake_config);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }
}
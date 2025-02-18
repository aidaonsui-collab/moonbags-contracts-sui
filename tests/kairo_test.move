#[test_only]
module kairo::kairo_test {
    use sui::test_scenario::{Self};
    use sui::{
        coin,
        clock
    };
    use sui::sui::SUI;
    use std::ascii::{
        string,
    };
    use kairo::kairo::{
        Self,
        Configuration
    };

    const ADMIN: address = @0x00;
    const USER_1: address = @0x10;

    public struct TEST has drop {}

    #[test]
    fun test_init() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            kairo::init_for_testing(scenario.ctx());
        };
        scenario.end();
    }

    #[test]
    fun create_token_for_test() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            kairo::init_for_testing(scenario.ctx());
        };
        scenario.next_tx(USER_1);
        {
            let treasury_cap = coin::create_treasury_cap_for_testing<TEST>(scenario.ctx());
            let mut configuration = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            kairo::create<TEST>(&mut configuration, treasury_cap, &clock, string(b"test"), string(b"TEST"), string(b"test"), string(b"test"), string(b"test"), string(b"test"), string(b"test"), scenario.ctx());
            test_scenario::return_shared(configuration);
            clock::destroy_for_testing(clock);
        };
        scenario.next_tx(USER_1);
        {
            let mut configuration = scenario.take_shared<Configuration>();
            let clock = clock::create_for_testing(scenario.ctx());
            let coin = coin::mint_for_testing<SUI>(100000000, scenario.ctx());
            kairo::buy_exact_in<TEST>(&mut configuration, coin, &clock, scenario.ctx());
            test_scenario::return_shared(configuration);
            clock::destroy_for_testing(clock);
        };
        scenario.end();
    }
}
#[test_only]
module moonbags::token_lock_test {
    use sui::test_scenario::{Self as ts};
    use sui::coin::{Self, Coin};
    use sui::clock;
    
    use moonbags::moonbags_token_lock::{Self, AdminCap, Configuration, LockContract};

    const ADMIN: address = @0x1;
    const USER: address = @0x2;
    const RECIPIENT: address = @0x3;
    const ONE_HOUR: u64 = 3600000; // 1 hour in milliseconds

    const EOutputNotEqualToExpected: u64 = 0;
    
    public struct TEST_TOKEN has drop {}
    
    fun setup() {
        let mut scenario = ts::begin(ADMIN);
        {
            moonbags_token_lock::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::end(scenario);
    }
    
    #[test]
    fun test_init() {
        let mut scenario = ts::begin(ADMIN);
        {
            moonbags_token_lock::init_for_testing(ts::ctx(&mut scenario));
        };
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            // Admin should have received the AdminCap
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            ts::return_to_sender(&scenario, admin_cap);
            
            // Config should be shared
            let config = ts::take_shared<Configuration>(&scenario);
            ts::return_shared(config);
        };
        ts::end(scenario);
    }
    
    #[test]
    fun test_create_lock() {
        setup();
        let mut scenario = ts::begin(ADMIN);
        
        // Create test token and mint to user
        let mut treasury_cap = coin::create_treasury_cap_for_testing(scenario.ctx());
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            let coin = coin::mint<TEST_TOKEN>(&mut treasury_cap, 20000, ts::ctx(&mut scenario));
            transfer::public_transfer(coin, USER);
        };
        
        ts::next_tx(&mut scenario, USER);
        {
            let config = ts::take_shared<Configuration>(&scenario);
            let mut user_coin = ts::take_from_sender<Coin<TEST_TOKEN>>(&scenario);
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            
            let amount = 15000;
            let duration_ms = ONE_HOUR; // 1 hour
            
            moonbags_token_lock::create_lock<TEST_TOKEN>(
                &config,
                &mut user_coin,
                RECIPIENT,
                amount,
                duration_ms,
                &clock,
                ts::ctx(&mut scenario)
            );
            
            ts::return_to_sender(&scenario, user_coin);
            ts::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            // Verify contract exists and is properly set up
            let lock_contract = ts::take_shared<LockContract<TEST_TOKEN>>(&scenario);
            
            // Use the view function instead of direct field access
            let (balance, amount, _, _, locker, recipient, closed) = 
                moonbags_token_lock::view_lock_for_testing(&lock_contract);
                
            assert!(amount == 15000, EOutputNotEqualToExpected);
            assert!(locker == USER, EOutputNotEqualToExpected);
            assert!(recipient == RECIPIENT, EOutputNotEqualToExpected);
            assert!(!closed, EOutputNotEqualToExpected);
            assert!(balance == 15000, EOutputNotEqualToExpected);
            
            ts::return_shared(lock_contract);
        };
        
        transfer::public_transfer(treasury_cap, ADMIN);
        ts::end(scenario);
    }
    
    #[test]
    fun test_withdraw_after_lock_period() {
        setup();
        let mut scenario = ts::begin(ADMIN);
        
        // Create test token and mint to user
        let mut treasury_cap = coin::create_treasury_cap_for_testing(scenario.ctx());
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            let coin = coin::mint<TEST_TOKEN>(&mut treasury_cap, 20000, ts::ctx(&mut scenario));
            transfer::public_transfer(coin, USER);
        };
        
        // Create lock
        ts::next_tx(&mut scenario, USER);
        {
            let config = ts::take_shared<Configuration>(&scenario);
            let mut user_coin = ts::take_from_sender<Coin<TEST_TOKEN>>(&scenario);
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            
            let amount = 15000;
            let duration_ms = ONE_HOUR; // 1 hour
            
            moonbags_token_lock::create_lock<TEST_TOKEN>(
                &config,
                &mut user_coin,
                RECIPIENT,
                amount,
                duration_ms,
                &clock,
                ts::ctx(&mut scenario)
            );
            
            ts::return_to_sender(&scenario, user_coin);
            ts::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        
        // Withdraw after lock period
        ts::next_tx(&mut scenario, RECIPIENT);
        {
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            let mut lock_contract = ts::take_shared<LockContract<TEST_TOKEN>>(&scenario);
            
            // Advance clock past end time
            clock::increment_for_testing(&mut clock, 3700000); // 1 hour + buffer
            
            moonbags_token_lock::withdraw<TEST_TOKEN>(
                &mut lock_contract,
                &clock,
                ts::ctx(&mut scenario)
            );
            
            // Use the view function to check if closed
            let (_, _, _, _, _, _, closed) = moonbags_token_lock::view_lock_for_testing(&lock_contract);
            assert!(closed, EOutputNotEqualToExpected);
            
            ts::return_shared(lock_contract);
            clock::destroy_for_testing(clock);
        };
        
        // Verify recipient received tokens
        ts::next_tx(&mut scenario, RECIPIENT);
        {
            let recipient_coin = ts::take_from_sender<Coin<TEST_TOKEN>>(&scenario);
            assert!(coin::value(&recipient_coin) == 15000, EOutputNotEqualToExpected);
            ts::return_to_sender(&scenario, recipient_coin);
        };
        
        transfer::public_transfer(treasury_cap, ADMIN);
        ts::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = moonbags_token_lock::EUnauthorized)]
    fun test_withdraw_before_lock_period() {
        setup();
        let mut scenario = ts::begin(ADMIN);
        
        // Create test token and mint to user
        let mut treasury_cap = coin::create_treasury_cap_for_testing(scenario.ctx());
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            let coin = coin::mint<TEST_TOKEN>(&mut treasury_cap, 20000, ts::ctx(&mut scenario));
            transfer::public_transfer(coin, USER);
        };
        
        // Create lock
        ts::next_tx(&mut scenario, USER);
        {
            let config = ts::take_shared<Configuration>(&scenario);
            let mut user_coin = ts::take_from_sender<Coin<TEST_TOKEN>>(&scenario);
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            
            moonbags_token_lock::create_lock<TEST_TOKEN>(
                &config,
                &mut user_coin,
                RECIPIENT,
                15000,
                ONE_HOUR,
                &clock,
                ts::ctx(&mut scenario)
            );
            
            ts::return_to_sender(&scenario, user_coin);
            ts::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        
        // Try to withdraw before lock period (should fail)
        ts::next_tx(&mut scenario, RECIPIENT);
        {
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            let mut lock_contract = ts::take_shared<LockContract<TEST_TOKEN>>(&scenario);
            
            // Advance clock but still within lock period (e.g., 30 minutes = 1,800,000 ms)
            clock::increment_for_testing(&mut clock, 1800000);
            
            // This should fail because we're only halfway through the lock period (3,600,000 ms)
            moonbags_token_lock::withdraw<TEST_TOKEN>(
                &mut lock_contract,
                &clock,
                ts::ctx(&mut scenario)
            );
            
            ts::return_shared(lock_contract);
            clock::destroy_for_testing(clock);
        };
        
        transfer::public_transfer(treasury_cap, ADMIN);
        ts::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = moonbags_token_lock::EContractClosed)]
    fun test_withdraw_closed_contract() {
        setup();
        let mut scenario = ts::begin(ADMIN);
        
        // Create test token and mint to user
        let mut treasury_cap = coin::create_treasury_cap_for_testing(scenario.ctx());
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            let coin = coin::mint<TEST_TOKEN>(&mut treasury_cap, 20000, ts::ctx(&mut scenario));
            transfer::public_transfer(coin, USER);
        };
        
        // Create lock
        ts::next_tx(&mut scenario, USER);
        {
            let config = ts::take_shared<Configuration>(&scenario);
            let mut user_coin = ts::take_from_sender<Coin<TEST_TOKEN>>(&scenario);
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            
            moonbags_token_lock::create_lock<TEST_TOKEN>(
                &config,
                &mut user_coin,
                RECIPIENT,
                15000,
                ONE_HOUR,
                &clock,
                ts::ctx(&mut scenario)
            );
            
            ts::return_to_sender(&scenario, user_coin);
            ts::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        
        // First withdraw (should succeed)
        ts::next_tx(&mut scenario, RECIPIENT);
        {
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            let mut lock_contract = ts::take_shared<LockContract<TEST_TOKEN>>(&scenario);
            
            clock::increment_for_testing(&mut clock, 3700000);
            
            moonbags_token_lock::withdraw<TEST_TOKEN>(
                &mut lock_contract,
                &clock,
                ts::ctx(&mut scenario)
            );
            
            ts::return_shared(lock_contract);
            clock::destroy_for_testing(clock);
        };
        
        // Second withdraw attempt (should fail)
        ts::next_tx(&mut scenario, RECIPIENT);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            let mut lock_contract = ts::take_shared<LockContract<TEST_TOKEN>>(&scenario);
            
            moonbags_token_lock::withdraw<TEST_TOKEN>(
                &mut lock_contract,
                &clock,
                ts::ctx(&mut scenario)
            );
            
            ts::return_shared(lock_contract);
            clock::destroy_for_testing(clock);
        };
        
        transfer::public_transfer(treasury_cap, ADMIN);
        ts::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = moonbags_token_lock::EInvalidConfig)]
    fun test_update_config_invalid_fee() {
        setup();
        let mut scenario = ts::begin(ADMIN);
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut config = ts::take_shared<Configuration>(&scenario);
            
            // Fee above 10000 (100%) should fail
            moonbags_token_lock::update_config(
                &admin_cap,
                &mut config,
                10001,
                ADMIN
            );
            
            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(config);
        };
        
        ts::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = moonbags_token_lock::EInvalidParams)]
    fun test_create_lock_invalid_amount() {
        setup();
        let mut scenario = ts::begin(ADMIN);
        
        let mut treasury_cap = coin::create_treasury_cap_for_testing(scenario.ctx());
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            let coin = coin::mint<TEST_TOKEN>(&mut treasury_cap, 20000, ts::ctx(&mut scenario));
            transfer::public_transfer(coin, USER);
        };
        
        // Try to create lock with amount that's too small
        ts::next_tx(&mut scenario, USER);
        {
            let config = ts::take_shared<Configuration>(&scenario);
            let mut user_coin = ts::take_from_sender<Coin<TEST_TOKEN>>(&scenario);
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            
            // Amount too small (under FEE_DENOMINATOR)
            moonbags_token_lock::create_lock<TEST_TOKEN>(
                &config,
                &mut user_coin,
                RECIPIENT,
                9000, // Under 10000
                ONE_HOUR,
                &clock,
                ts::ctx(&mut scenario)
            );
            
            ts::return_to_sender(&scenario, user_coin);
            ts::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        
        transfer::public_transfer(treasury_cap, ADMIN);
        ts::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = moonbags_token_lock::EInvalidParams)]
    fun test_create_lock_invalid_duration() {
        setup();
        let mut scenario = ts::begin(ADMIN);
        
        let mut treasury_cap = coin::create_treasury_cap_for_testing(scenario.ctx());
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            let coin = coin::mint<TEST_TOKEN>(&mut treasury_cap, 20000, ts::ctx(&mut scenario));
            transfer::public_transfer(coin, USER);
        };
        
        // Try to create lock with duration that's too short
        ts::next_tx(&mut scenario, USER);
        {
            let config = ts::take_shared<Configuration>(&scenario);
            let mut user_coin = ts::take_from_sender<Coin<TEST_TOKEN>>(&scenario);
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            
            // Duration less than minimum (1 minute)
            moonbags_token_lock::create_lock<TEST_TOKEN>(
                &config,
                &mut user_coin,
                RECIPIENT,
                15000,
                30000, // 30 seconds (under minimum)
                &clock,
                ts::ctx(&mut scenario)
            );
            
            ts::return_to_sender(&scenario, user_coin);
            ts::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        
        transfer::public_transfer(treasury_cap, ADMIN);
        ts::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = moonbags_token_lock::EInsufficientFunds)]
    fun test_create_lock_insufficient_funds() {
        setup();
        let mut scenario = ts::begin(ADMIN);
        
        let mut treasury_cap = coin::create_treasury_cap_for_testing(scenario.ctx());
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            // Mint fewer tokens than needed
            let coin = coin::mint<TEST_TOKEN>(&mut treasury_cap, 10000, ts::ctx(&mut scenario));
            transfer::public_transfer(coin, USER);
        };
        
        ts::next_tx(&mut scenario, USER);
        {
            let config = ts::take_shared<Configuration>(&scenario);
            let mut user_coin = ts::take_from_sender<Coin<TEST_TOKEN>>(&scenario);
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            
            // Try to lock more tokens than available
            moonbags_token_lock::create_lock<TEST_TOKEN>(
                &config,
                &mut user_coin,
                RECIPIENT,
                15000, // More than the 10000 available
                ONE_HOUR,
                &clock,
                ts::ctx(&mut scenario)
            );
            
            ts::return_to_sender(&scenario, user_coin);
            ts::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        
        transfer::public_transfer(treasury_cap, ADMIN);
        ts::end(scenario);
    }
    
    #[test]
    fun test_fee_calculation() {
        setup();
        let mut scenario = ts::begin(ADMIN);
        
        // Set fee to 1% for easier calculation
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut config = ts::take_shared<Configuration>(&scenario);
            
            moonbags_token_lock::update_config(
                &admin_cap,
                &mut config,
                100, // 1%
                ADMIN
            );
            
            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(config);
        };
        
        let mut treasury_cap = coin::create_treasury_cap_for_testing(scenario.ctx());
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            let coin = coin::mint<TEST_TOKEN>(&mut treasury_cap, 20000, ts::ctx(&mut scenario));
            transfer::public_transfer(coin, USER);
        };
        
        ts::next_tx(&mut scenario, USER);
        {
            let config = ts::take_shared<Configuration>(&scenario);
            let mut user_coin = ts::take_from_sender<Coin<TEST_TOKEN>>(&scenario);
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            
            let amount = 15000;
            // Expected fee: 1% of 15000 = 150
            
            let initial_balance = coin::value(&user_coin);
            
            moonbags_token_lock::create_lock<TEST_TOKEN>(
                &config,
                &mut user_coin,
                RECIPIENT,
                amount,
                ONE_HOUR,
                &clock,
                ts::ctx(&mut scenario)
            );
            
            let final_balance = coin::value(&user_coin);
            assert!(initial_balance - final_balance == amount + 150, EOutputNotEqualToExpected); // Amount + fee
            
            ts::return_to_sender(&scenario, user_coin);
            ts::return_shared(config);
            clock::destroy_for_testing(clock);
        };
        
        // Check admin received the fee
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_coin = ts::take_from_sender<Coin<TEST_TOKEN>>(&scenario);
            assert!(coin::value(&admin_coin) == 150, EOutputNotEqualToExpected); // 1% of 15000
            ts::return_to_sender(&scenario, admin_coin);
        };
        
        transfer::public_transfer(treasury_cap, ADMIN);
        ts::end(scenario);
    }
}
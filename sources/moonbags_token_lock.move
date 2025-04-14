module moonbags::moonbags_token_lock {
    // === Imports ===
    use std::ascii::String;
    use std::type_name;

    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::event;
    use sui::balance::{Self, Balance};

    // === Errors ===
    const EContractClosed: u64 = 1;
    const EInsufficientFunds: u64 = 2;
    const EUnauthorized: u64 = 3;
    const EInvalidParams: u64 = 4;
    const EInvalidConfig: u64 = 5;

    // === Constants ===
    const FEE_DENOMINATOR: u64 = 10000;

    // === Structs ===
    public struct AdminCap has key {
        id: UID,
    }

    public struct Configuration has key, store {
        id: UID,
        lock_fee: u64,
        admin: address,
    }
    
    public struct LockContract<phantom T> has key {
        id: UID,
        balance: Balance<T>,
        amount: u64,
        start_time: u64,
        end_time: u64,
        locker: address,
        recipient: address,
        closed: bool,
    }

    // === Events ===
    public struct LockCreatedEvent has copy, drop {
        contract_id: address,
        token_address: String,
        locker: address,
        recipient: address,
        amount: u64,
        fee: u64,
        start_time: u64,
        end_time: u64,
    }
    
    public struct TokensWithdrawnEvent has copy, drop {
        contract_id: address,
        sender: address,
        recipient: address,
        amount: u64,
    }

    fun init(ctx: &mut TxContext) {
        transfer::transfer(
            AdminCap { id: object::new(ctx) },
            ctx.sender()
        );

        transfer::public_share_object(
            Configuration {
                id          : object::new(ctx),
                lock_fee    : 0, // 0% fee
                admin       : ctx.sender(),
            }
        );
    }

    // === Public Functions ===

    /*
     * Creates a new time-locked token contract.
     * 
     * @param config - Reference to the configuration object containing fee settings
     * @param token_coin - Mutable reference to the coin that will be locked (must contain enough balance for amount + fee)
     * @param recipient - Address that will be able to claim the tokens after the lock period
     * @param amount - Amount of tokens to lock (must be greater than FEE_DENOMINATOR)
     * @param end_time - End time of the lock in milliseconds (must be greater than current time)
     * @param clock - Reference to the clock object for timestamp verification
     * @param ctx - Transaction context
     */
    public entry fun create_lock<Token>(
        config: &Configuration,
        mut token_coin: Coin<Token>,
        recipient: address,
        amount: u64,
        end_time: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let start_time = clock::timestamp_ms(clock);

        assert!(amount >= FEE_DENOMINATOR, EInvalidParams);
        assert!(end_time > start_time, EInvalidParams);

        let fee = (amount * config.lock_fee) / FEE_DENOMINATOR;
        let total_required = amount + fee;
        
        assert!(coin::value(&token_coin) >= total_required, EInsufficientFunds);

        let fee_coin = coin::split(&mut token_coin, fee, ctx);
        transfer::public_transfer(fee_coin, config.admin);

        let contract = LockContract<Token> {
            id          : object::new(ctx),
            balance     : coin::into_balance(coin::split(&mut token_coin, amount, ctx)),
            amount      : amount,
            start_time  : start_time,
            end_time    : end_time,
            recipient   : recipient,
            locker      : ctx.sender(),
            closed      : false
        };

        transfer::public_transfer(token_coin , ctx.sender());

        event::emit(LockCreatedEvent {
            contract_id     : object::uid_to_address(&contract.id),
            token_address   : type_name::into_string(type_name::get<Token>()),
            locker          : ctx.sender(),
            recipient       : recipient,
            amount          : amount,
            fee             : fee,
            start_time      : start_time,
            end_time        : end_time,
        });

        transfer::share_object(contract);
    }

    /*
     * Withdraws tokens from a lock contract after the lock period has ended.
     * 
     * @param contract - Mutable reference to the lock contract
     * @param clock - Reference to the clock object for timestamp verification
     * @param ctx - Transaction context
     */
    public entry fun withdraw<Token>(
        config: &Configuration,
        contract: &mut LockContract<Token>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender = ctx.sender();

        assert!(
            sender == config.admin || 
            sender == contract.recipient || 
            sender == contract.locker, 
            EUnauthorized
        );
        
        assert!(!contract.closed, EContractClosed);
        
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time >= contract.end_time, EUnauthorized);

        let amount = balance::value(&contract.balance);
        let coin = coin::from_balance(balance::withdraw_all(&mut contract.balance), ctx);
        
        transfer::public_transfer(coin, contract.recipient);
        
        contract.closed = true;
        
        event::emit(TokensWithdrawnEvent {
            contract_id : object::uid_to_address(&contract.id),
            sender      : sender,
            recipient   : contract.recipient,
            amount      : amount,
        });
    }

    // === Admin Functions ===
    public entry fun update_config(
        _: &AdminCap,
        config: &mut Configuration,
        new_lock_fee: u64,
        new_admin: address,
    ) {
        assert!(new_lock_fee <= FEE_DENOMINATOR, EInvalidConfig);
        
        config.lock_fee = new_lock_fee;
        config.admin = new_admin;
    }

    // === Test Functions ===
    #[test_only]
    public(package) fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test_only]
    public(package) fun view_lock_for_testing<T>(
        contract: &LockContract<T>
    ): (u64, u64, u64, u64, address, address, bool) {
        (
            balance::value(&contract.balance),
            contract.amount,
            contract.start_time,
            contract.end_time,
            contract.locker,
            contract.recipient,
            contract.closed
        )
    }
}
#[test_only]
module moonbags::test_token {
    use sui::coin;

    public struct TEST_TOKEN has drop {}

    fun create_test_token(otw: TEST_TOKEN, ctx: &mut TxContext): (coin::TreasuryCap<TEST_TOKEN>, coin::CoinMetadata<TEST_TOKEN>) {
        let (treasury_cap, metadata) = coin::create_currency(
            otw,
            9,
            b"TEST",
            b"TEST",
            b"TEST",
            option::none(),
            ctx,
        );

        (treasury_cap, metadata)
    }

    // --------- Test-only Functions ---------
    #[test_only]
    use sui::test_utils::create_one_time_witness;

    #[test_only]
    public fun create_test_token_for_testing(ctx: &mut TxContext): (coin::TreasuryCap<TEST_TOKEN>, coin::CoinMetadata<TEST_TOKEN>) {
        create_test_token(create_one_time_witness<TEST_TOKEN>(), ctx)
    }
}
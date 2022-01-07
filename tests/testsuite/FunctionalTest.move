//! account: dummy, 0x2
//! sender:dummy
address dummy = {{dummy}};
module dummy::Dummy {
    use 0x1::Account;
    use 0x1::Token;

    struct ETH has copy, drop, store { }
    struct USDT has copy, drop, store { }

    struct SharedMintCapability<TokenType: store> has key, store {
        cap: Token::MintCapability<TokenType>,
    }

    struct SharedBurnCapability<TokenType> has key {
        cap: Token::BurnCapability<TokenType>,
    }

    public fun initialize<TokenType: store>(account: &signer) {
        Token::register_token<TokenType>(account, 9);
        Account::do_accept_token<TokenType>(account);
        let burn_cap = Token::remove_burn_capability<TokenType>(account);
        move_to(account, SharedBurnCapability<TokenType> { cap: burn_cap });
        let mint_cap = Token::remove_mint_capability<TokenType>(account);
        move_to(account, SharedMintCapability<TokenType> { cap: mint_cap });
    }

    public fun mint_token<TokenType: store>(account: &signer, amount: u128) acquires SharedMintCapability {
        let token = mint<TokenType>(amount);
        Account::deposit_to_self(account, token);
    }

    /// Burn the given token.
    public fun burn<TokenType: store>(token: Token::Token<TokenType>) acquires SharedBurnCapability{
        let cap = borrow_global<SharedBurnCapability<TokenType>>(token_address<TokenType>());
        Token::burn_with_capability(&cap.cap, token);
    }

    public fun mint<TokenType: store>(amount: u128): Token::Token<TokenType> acquires SharedMintCapability {
        let cap = borrow_global<SharedMintCapability<TokenType>>(token_address<TokenType>());
        Token::mint_with_capability<TokenType>(&cap.cap, amount)
    }

    public fun token_address<TokenType: store>(): address {
        Token::token_address<TokenType>()
    }
}
// check: "Keep(EXECUTED)"

//! new-transaction
//! sender: dummy
script {
    use dummy::Dummy::{Self, ETH, USDT};

    const MULTIPLE: u128 = 1000000000;

    fun register_token(sender: signer) {
        Dummy::initialize<ETH>(&sender);
        Dummy::initialize<USDT>(&sender);
    }
}
// check: "Keep(EXECUTED)"

//! new-transaction
//! account: admin, 0x100
//! sender: admin
address admin = {{admin}};
script {
    use dummy::Dummy::{ETH, USDT};
    use 0x100::SwapConfig;
    use 0x100::SwapPair;
    use 0x300::SwapScripts;
    // init config and pair
    fun init(sender: signer) {
        SwapConfig::initialize(
            &sender, 20u128, 4u128,
            0u128, 0u128, 0u128, 0u128, 0u128
        );
        SwapConfig::update(
            &sender, 30u128, 5u128,
            0u128, 0u128, 0u128, 0u128, 0u128
        );
        let (fee_rate, treasury_fee_rate) = SwapConfig::get_fee_config();
        assert(fee_rate == 30u128 && treasury_fee_rate == 5u128, 3002);
        // create pair
        SwapScripts::create_pair<ETH, USDT>(sender);
        assert(SwapPair::pair_exists<ETH, USDT>(@admin), 3003);
    }
}
// check: "Keep(EXECUTED)"

//! new-transaction
//! account: lp, 10000000000 0x1::STC::STC
//! sender: lp
address lp = {{lp}};
script {
    use 0x1::Account;
    use dummy::Dummy::{Self, ETH, USDT};
    use 0x100::SwapPair::LPToken;
    use 0x300::SwapScripts;

    const MULTIPLE: u128 = 1000000000;

    // add_liquidity, STC:USDT = 5:20 = 1:4, k = 100, lptoken = 5
    fun add_liquidity(sender: signer) {
        Dummy::mint_token<ETH>(&sender, 5 * MULTIPLE);
        Dummy::mint_token<USDT>(&sender, 20 * MULTIPLE);
        SwapScripts::add_liquidity<ETH, USDT>(sender, 5*MULTIPLE , 20*MULTIPLE, 1*MULTIPLE, 1*MULTIPLE);
        // get 10 LP token
        assert(Account::balance<LPToken<ETH, USDT>>(@lp) == 10 * MULTIPLE, 4001);
    }
}
// check: EXECUTED

//! new-transaction
//! account: alice
//! sender: alice
address alice = {{alice}};
script {
    use 0x1::Account;
    use 0x1::Debug;
    use dummy::Dummy::{Self, ETH, USDT};
    use 0x100::SwapPair;
    use 0x300::SwapScripts;
    const MULTIPLE: u128 = 1000000000;

    fun swap_exact_token_for_token(sender: signer) {
        Dummy::mint_token<ETH>(&sender, 1 * MULTIPLE);
        // swap 1 ETH
        SwapScripts::swap_exact_token_for_token<ETH, USDT>(sender, 1*MULTIPLE , 3*MULTIPLE);
        // get 3.324995831 USDT
        let balance_usdt = Account::balance<USDT>(@alice);
        Debug::print<u128>(&balance_usdt);
        assert(balance_usdt == 3324995831, 5001);
        // STC = 6, USDT = 16.675004169
        let (reserve_x, reserve_y) = SwapPair::get_reserves<ETH, USDT>();
        assert(reserve_x == 6000000000 && reserve_y == 16675004169, 5001);
    }
}
// check: EXECUTED

//! new-transaction
//! account: bob
//! sender: bob
address bob = {{bob}};
script {
    use 0x1::Account;
    use dummy::Dummy::{Self, ETH, USDT};
    use 0x100::SwapPair;
    use 0x300::SwapScripts;
    const MULTIPLE: u128 = 1000000000;

    fun swap_token_for_exact_token(sender: signer) {
        // mint 10 USDT
        Dummy::mint_token<USDT>(&sender, 10 * MULTIPLE);
        // swap 3.345035942 USDT for 1 ETH
        SwapScripts::swap_token_for_exact_token<USDT, ETH>(sender, 4*MULTIPLE , 1*MULTIPLE);
        let balance_usdt = Account::balance<USDT>(@bob);
        let balance_eth = Account::balance<ETH>(@bob);
        assert(balance_usdt == 6654964058, 6001);
        assert(balance_eth == 1000000000, 6002);
        // ETH = 5, USDT = 20.020040111
        let (reserve_x, reserve_y) = SwapPair::get_reserves<ETH, USDT>();
        assert(reserve_x == 5000000000 && reserve_y == 20020040111, 6003);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: lp
address lp = {{lp}};
script {
    use 0x1::Account;
    use dummy::Dummy::{ETH, USDT};
    use 0x100::SwapPair;
    use 0x300::SwapScripts;

    const MULTIPLE: u128 = 1000000000;

    // remove 10 LP token
    fun remove_liquidity(sender: signer) {
        SwapScripts::remove_liquidity<ETH, USDT>(sender, 10*MULTIPLE, 1*MULTIPLE, 1*MULTIPLE);
        let (reserve_x, reserve_y) = SwapPair::get_reserves<ETH, USDT>();
        assert(reserve_x == 417189 && reserve_y == 1670427, 7001);
        // get 4.999582811 ETH, 20.018369684 USDT
        let balance_eth = Account::balance<ETH>(@lp);
        let balance_usdt = Account::balance<USDT>(@lp);
        assert(balance_eth == 4999582811 && balance_usdt == 20018369684, 7002);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: admin
address admin = {{admin}};
script {
    use 0x1::Account;
    use dummy::Dummy::{ETH, USDT};
    use 0x100::SwapPair::{Self, LPToken};
    use 0x300::SwapScripts;

    const MULTIPLE: u128 = 1000000000;

    // remove 10 LP token
    fun remove_liquidity(sender: signer) {
        let lp_amount = Account::balance<LPToken<ETH, USDT>>(@admin);
        SwapScripts::remove_liquidity<ETH, USDT>(sender, lp_amount, 1, 1);
        let (reserve_x, reserve_y) = SwapPair::get_reserves<ETH, USDT>();
        assert(reserve_x == 0 && reserve_y == 0, 8001);
        // get 0.000417189 ETH, 0.001670427 USDT
        let balance_eth = Account::balance<ETH>(@admin);
        let balance_usdt = Account::balance<USDT>(@admin);
        assert(balance_eth == 417189 && balance_usdt == 1670427, 8002);
    }
}
// check: EXECUTED
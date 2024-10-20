module launchpad_addr::liquidity_pool {
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::fungible_asset::{Self, Metadata};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    
    struct LiquidityPool has key {
        token_a: Object<Metadata>,
        token_b: Object<Metadata>,
        balance_a: u64,
        balance_b: u64,
        lp_supply: u64,
        add_liquidity_events: EventHandle<AddLiquidityEvent>,
    }

    struct LPToken {}

    #[event]
    struct AddLiquidityEvent has drop, store {
        user: address,
        amount_a: u64,
        amount_b: u64,
        lp_tokens_minted: u64,
    }

    public fun create_pool(
        account: &signer,
        token_a: Object<Metadata>,
        token_b: Object<Metadata>,
    ) {
        let pool = LiquidityPool {
            token_a,
            token_b,
            balance_a: 0,
            balance_b: 0,
            lp_supply: 0,
            add_liquidity_events: account::new_event_handle<AddLiquidityEvent>(account),
        };
        move_to(account, pool);
    }

    public fun add_liquidity(
        account: &signer,
        token_a: Object<Metadata>,
        token_b: Object<Metadata>,
        amount_a: u64,
        amount_b: u64,
    ) acquires LiquidityPool {
        let sender = signer::address_of(account);
        let pool = borrow_global_mut<LiquidityPool>(@launchpad_addr);

        assert!(token_a == pool.token_a && token_b == pool.token_b, 1); // Invalid tokens

        let fa_a = primary_fungible_store::withdraw(account, token_a, amount_a);
        let fa_b = primary_fungible_store::withdraw(account, token_b, amount_b);

        primary_fungible_store::deposit(@launchpad_addr, fa_a);
        primary_fungible_store::deposit(@launchpad_addr, fa_b);

        pool.balance_a = pool.balance_a + amount_a;
        pool.balance_b = pool.balance_b + amount_b;

        let lp_tokens_minted = if (pool.lp_supply == 0) {
            ((amount_a as u128) * (amount_b as u128) as u64)
        } else {
            let a_ratio = ((amount_a as u128) * (pool.lp_supply as u128)) / (pool.balance_a as u128);
            let b_ratio = ((amount_b as u128) * (pool.lp_supply as u128)) / (pool.balance_b as u128);
            if (a_ratio < b_ratio) { (a_ratio as u64) } else { (b_ratio as u64) }
        };

        pool.lp_supply = pool.lp_supply + lp_tokens_minted;

        event::emit_event(
            &mut pool.add_liquidity_events,
            AddLiquidityEvent {
                user: sender,
                amount_a,
                amount_b,
                lp_tokens_minted,
            },
        );
    }
}
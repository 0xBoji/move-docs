module launchpad_addr::liquidity_pool {
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};

    struct LiquidityPool<phantom CoinTypeA, phantom CoinTypeB> has key {
        coin_a: coin::Coin<CoinTypeA>,
        coin_b: coin::Coin<CoinTypeB>,
        lp_supply: u64,
        add_liquidity_events: EventHandle<AddLiquidityEvent>,
    }

    struct LPToken<phantom CoinTypeA, phantom CoinTypeB> {}

    #[event]
    struct AddLiquidityEvent has drop, store {
        user: address,
        amount_a: u64,
        amount_b: u64,
        lp_tokens_minted: u64,
    }

    public fun create_pool<CoinTypeA, CoinTypeB>(
        account: &signer,
    ) {
        let pool = LiquidityPool<CoinTypeA, CoinTypeB> {
            coin_a: coin::zero<CoinTypeA>(),
            coin_b: coin::zero<CoinTypeB>(),
            lp_supply: 0,
            add_liquidity_events: account::new_event_handle<AddLiquidityEvent>(account),
        };
        move_to(account, pool);
    }

    public fun add_liquidity<CoinTypeA, CoinTypeB>(
        account: &signer,
        amount_a: u64,
        amount_b: u64,
    ) acquires LiquidityPool {
        let sender = signer::address_of(account);
        let pool = borrow_global_mut<LiquidityPool<CoinTypeA, CoinTypeB>>(@launchpad_addr);

        let coin_a = coin::withdraw<CoinTypeA>(account, amount_a);
        let coin_b = coin::withdraw<CoinTypeB>(account, amount_b);

        coin::merge(&mut pool.coin_a, coin_a);
        coin::merge(&mut pool.coin_b, coin_b);

        let lp_tokens_minted = if (pool.lp_supply == 0) {
            ((amount_a as u128) * (amount_b as u128) as u64)
        } else {
            let a_ratio = ((amount_a as u128) * (pool.lp_supply as u128)) / (coin::value(&pool.coin_a) as u128);
            let b_ratio = ((amount_b as u128) * (pool.lp_supply as u128)) / (coin::value(&pool.coin_b) as u128);
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
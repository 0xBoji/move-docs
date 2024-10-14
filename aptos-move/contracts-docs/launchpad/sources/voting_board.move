module message_board_addr::Voting
{
    use std::signer;
    use std::vector;
    use std::simple_map::{Self, SimpleMap};
    use std::account;
    use std::string::String;
    use std::string;
    use std::event;

    const E_IS_NOT_INITIALIZED: u64 = 1;
    const E_DOES_NOT_CONTAIN_KEY: u64 = 2;
    const E_IS_INITIALIZED: u64 = 3;
    const E_IS_INITIALIZED_WITH_OPTION: u64 = 4;
    const E_WINNER_DECLARED: u64 = 5;
    const E_HAS_VOTED: u64 = 6;

    struct OptionList has key {
        option_list: SimpleMap<String, u64>,
        c_list: vector<String>,
        winner: String
    }

    // Add this struct definition at the top of your module
    #[event]
    struct WinnerDeclared has drop, store {
        winner: String,
        votes: u64,
    }

    struct VotingList has key {
        voters: SimpleMap<address, u64>
    }

    public fun assert_is_initialized(addr: address) {
        assert!(exists<OptionList>(addr), E_IS_NOT_INITIALIZED);
        assert!(exists<VotingList>(addr), E_IS_NOT_INITIALIZED);
    }

    public fun assert_uninitialized(addr: address) {
        assert!(!exists<OptionList>(addr), E_IS_INITIALIZED);
        assert!(!exists<VotingList>(addr), E_IS_INITIALIZED);
    }

    public fun assert_contains_key(map: &SimpleMap<String, u64>, option: &String) {
        assert!(simple_map::contains_key(map, option), E_DOES_NOT_CONTAIN_KEY);
    }

    public fun assert_not_contains_key(map: &SimpleMap<String, u64>, option: &String) {
        assert!(!simple_map::contains_key(map, option), E_IS_INITIALIZED_WITH_OPTION);
    }

    public entry fun initialize_with_option(acc: &signer, option: String) acquires OptionList {
        let addr = signer::address_of(acc);
        assert_uninitialized(addr);

        let c_store = OptionList{
            option_list: simple_map::create(),
            c_list: vector::empty<String>(),
            winner: string::utf8(b""),
        };
        move_to(acc, c_store);

        let v_store = VotingList {
            voters: simple_map::create(),
        };
        move_to(acc, v_store);

        let c_store = borrow_global_mut<OptionList>(addr);
        simple_map::add(&mut c_store.option_list, option, 0);
        vector::push_back(&mut c_store.c_list, option);
    }

    public entry fun add_option(acc: &signer, option: String, store_addr: address) acquires OptionList {
            assert_is_initialized(store_addr);

            let c_store = borrow_global_mut<OptionList>(store_addr);
            assert!(c_store.winner == string::utf8(b""), E_WINNER_DECLARED);
            assert_not_contains_key(&c_store.option_list, &option);
            simple_map::add(&mut c_store.option_list, option, 0);
            vector::push_back(&mut c_store.c_list, option);
        }

    public entry fun vote(acc: &signer, option: String, store_addr: address) acquires OptionList, VotingList {
        let addr = signer::address_of(acc);

        assert_is_initialized(store_addr);

        let c_store = borrow_global_mut<OptionList>(store_addr);
        let v_store = borrow_global_mut<VotingList>(store_addr);
        assert!(c_store.winner == string::utf8(b""), E_WINNER_DECLARED);
        assert!(!simple_map::contains_key(&v_store.voters, &addr), E_HAS_VOTED);
        assert_contains_key(&c_store.option_list, &option);
        let votes = simple_map::borrow_mut(&mut c_store.option_list, &option);
        *votes = *votes + 1;
        simple_map::add(&mut v_store.voters, addr, 1);
    }

    #[view]
    public fun view_current_scores(store_addr: address): (vector<String>, vector<u64>) acquires OptionList {
        assert_is_initialized(store_addr);

        let c_store = borrow_global<OptionList>(store_addr);
        assert!(c_store.winner == string::utf8(b""), E_WINNER_DECLARED);

        let options = vector::empty<String>();
        let scores = vector::empty<u64>();
        let i = 0;
        let option_count = vector::length(&c_store.c_list);

        while (i < option_count) {
            let option = *vector::borrow(&c_store.c_list, (i as u64));
            let votes = *simple_map::borrow(&c_store.option_list, &option);
            vector::push_back(&mut options, option);
            vector::push_back(&mut scores, votes);
            i = i + 1;
        };

        (options, scores)
    }


    public entry fun declare_winner(store_addr: address) acquires OptionList {
        assert_is_initialized(store_addr);

        let c_store = borrow_global_mut<OptionList>(store_addr);
        assert!(c_store.winner == string::utf8(b""), E_WINNER_DECLARED);

        let options = vector::length(&c_store.c_list);

        let i = 0;
        let winner = string::utf8(b"");
        let max_votes: u64 = 0;

        while (i < options) {
            let option = *vector::borrow(&c_store.c_list, (i as u64));
            let votes = simple_map::borrow(&c_store.option_list, &option);

            if(max_votes < *votes) {
                max_votes = *votes;
                winner = option;
            };
            i = i + 1;
        };

        c_store.winner = winner;
        
        // Emit an event with the winner
        event::emit(WinnerDeclared { 
            winner: winner,
            votes: max_votes,
        });
    }

    // Modify the view_winner function to always return the winner, even if not yet declared
    #[view]
    public fun view_winner(store_addr: address): String acquires OptionList {
        let c_store = borrow_global<OptionList>(store_addr);
        if (c_store.winner == string::utf8(b"")) {
            string::utf8(b"No winner declared yet")
        } else {
            c_store.winner
        }
    }

    
}
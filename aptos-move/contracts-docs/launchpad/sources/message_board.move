module message_board_addr::testing {
    use std::string::String;
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata};
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::primary_fungible_store;
    use std::signer;
    use std::string::{Self, utf8};
    use std::option;
    use std::vector;
    // use aptos_framework::account;

    const ASSET_SYMBOL: vector<u8> = b"MV";


    struct Message has key {
        string_content: String,
    }

    struct MinterRegistry has key {
        minters: vector<address>,
    }

    struct MinterInfo has key {
        amount_minted: u64,
    }

    struct MinterData has drop, store {
    addr: address,
    amount: u64,
}

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Hold refs to control the minting, transfer, and burning of fungible assets.
    struct ManagedFungibleAsset has key {
        mint_ref: MintRef,
        transfer_ref: TransferRef,
        burn_ref: BurnRef,
    }

    const BOARD_OBJECT_SEED: vector<u8> = b"message_board";

    struct BoardObjectController has key {
        extend_ref: ExtendRef,
    }

    // This function is only called once when the module is published for the first time.
    // init_module is optional, you can also have an entry function as the initializer.
    fun init_module(admin: &signer) {
        let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            utf8(b"MV Coin"), /* name */
            utf8(ASSET_SYMBOL), /* symbol */
            8, /* decimals */
            utf8(b"https://res.cloudinary.com/dgbreoalg/image/upload/v1726735567/aptocoin_tu01yz.png"), /* icon */
            utf8(b"https://github.com/nwakaku"), /* project */
        );

        // Create mint/burn/transfer refs to allow the creator to manage the fungible asset.
        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);

        // Move the refs into ManagedFungibleAsset after initialization
        let metadata_object_signer = object::generate_signer(constructor_ref);
        move_to(
            &metadata_object_signer,
            ManagedFungibleAsset { mint_ref, transfer_ref, burn_ref }
        );

        // Initialize MinterRegistry
        move_to(admin, MinterRegistry { minters: vector::empty() });
    }

    public entry fun mint_tokens(user: &signer, amount: u64) acquires ManagedFungibleAsset, MinterRegistry, MinterInfo {
        let user_address = signer::address_of(user);
        let asset = get_metadata();
        
        let managed_fungible_asset = borrow_global<ManagedFungibleAsset>(object::object_address(&asset));
        let user_wallet = primary_fungible_store::ensure_primary_store_exists(user_address, asset);
        
        // Mint the tokens in full units (amount * 10^8)
        let full_amount = amount * 100_000_000; // Adjust to mint full tokens
        let fa = fungible_asset::mint(&managed_fungible_asset.mint_ref, full_amount);
        fungible_asset::deposit_with_ref(&managed_fungible_asset.transfer_ref, user_wallet, fa);

        // Update MinterRegistry and MinterInfo
        update_minter_info(user, full_amount);
    }


    fun update_minter_info(user: &signer, amount: u64) acquires MinterRegistry, MinterInfo {
        let user_address = signer::address_of(user);
        let minter_registry = borrow_global_mut<MinterRegistry>(@message_board_addr);
        
        if (!vector::contains(&minter_registry.minters, &user_address)) {
            vector::push_back(&mut minter_registry.minters, user_address);
            move_to(user, MinterInfo { amount_minted: amount });
        } else if (!exists<MinterInfo>(user_address)) {
            move_to(user, MinterInfo { amount_minted: amount });
        } else {
            let minter_info = borrow_global_mut<MinterInfo>(user_address);
            minter_info.amount_minted = minter_info.amount_minted + amount;
        }
    }

    #[view]
    public fun get_all_minters(): vector<address> acquires MinterRegistry {
        *&borrow_global<MinterRegistry>(@message_board_addr).minters
    }

    #[view]
    public fun get_minter_info(minter: address): u64 acquires MinterInfo {
        if (exists<MinterInfo>(minter)) {
            borrow_global<MinterInfo>(minter).amount_minted
        } else {
            0
        }
    }

    #[view]
    public fun list_all_minters_and_tokens(): vector<MinterData> acquires MinterRegistry, MinterInfo {
        let minters = get_all_minters();
        let result = vector::empty<MinterData>();
        let i = 0;
        let len = vector::length(&minters);
        while (i < len) {
            let minter = *vector::borrow(&minters, i);
            let amount = get_minter_info(minter);
            vector::push_back(&mut result, MinterData { addr: minter, amount });
            i = i + 1;
        };
        result
    }

    #[view]
    /// Return the address of the managed fungible asset created when this module is deployed.
    public fun get_metadata(): Object<Metadata> {
        let asset_address = object::create_object_address(&@message_board_addr, ASSET_SYMBOL);
        object::address_to_object<Metadata>(asset_address)
    }

    #[view]
    public fun get_token_balance(account: address): u64 {
        let asset = get_metadata(); // Retrieve metadata of the fungible asset
        let store = primary_fungible_store::primary_store(account, asset); // Get the primary store for the account
        primary_fungible_store::balance(account, asset) // Corrected: Pass account and asset
    }

    
    // Updated Transfer Function: Ownership check removed
    public entry fun transfer(admin: &signer, from: address, to: address, amount: u64) acquires ManagedFungibleAsset {
        let asset = get_metadata();
        let transfer_ref = &borrow_global<ManagedFungibleAsset>(object::object_address(&asset)).transfer_ref;
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        let to_wallet = primary_fungible_store::ensure_primary_store_exists(to, asset);
        let fa = fungible_asset::withdraw_with_ref(transfer_ref, from_wallet, amount);
        fungible_asset::deposit_with_ref(transfer_ref, to_wallet, fa);
    }

    // Updated Burn Function: Ownership check removed
    public entry fun burn(admin: &signer, from: address, amount: u64) acquires ManagedFungibleAsset {
        let asset = get_metadata();
        let burn_ref = &borrow_global<ManagedFungibleAsset>(object::object_address(&asset)).burn_ref;
        let from_wallet = primary_fungible_store::primary_store(from, asset);
        fungible_asset::burn_from(burn_ref, from_wallet, amount);
    }


    /// Borrow the immutable reference of the refs of metadata.
    /// This validates that the signer is the metadata object's owner.
    inline fun authorized_borrow_refs(
        owner: &signer,
        asset: Object<Metadata>,
    ): &ManagedFungibleAsset acquires ManagedFungibleAsset {
        assert!(object::is_owner(asset, signer::address_of(owner)), 1);  // Permission denied
        borrow_global<ManagedFungibleAsset>(object::object_address(&asset))
    }

    // ======================== Write functions ========================

    public entry fun post_message(
        _sender: &signer,
        new_string_content: String,
    ) acquires Message, BoardObjectController {
        if (!exist_message()) {
            let board_obj_signer = get_board_obj_signer();
            move_to(&board_obj_signer, Message {
                string_content: new_string_content,
            });
        };
        let message = borrow_global_mut<Message>(get_board_obj_address());
        message.string_content = new_string_content;
    }

    // ======================== Read Functions ========================

    #[view]
    public fun exist_message(): bool {
        exists<Message>(get_board_obj_address())
    }

    #[view]
    public fun get_message_content(): (String) acquires Message {
        let message = borrow_global<Message>(get_board_obj_address());
        message.string_content
    }

    // ======================== Helper functions ========================

    fun get_board_obj_address(): address {
        object::create_object_address(&@message_board_addr, BOARD_OBJECT_SEED)
    }

    fun get_board_obj_signer(): signer acquires BoardObjectController {
        object::generate_signer_for_extending(&borrow_global<BoardObjectController>(get_board_obj_address()).extend_ref)
    }

    // ======================== Unit Tests ========================


    #[test_only]
    public fun init_module_for_test(sender: &signer) {
        init_module(sender);
    }

     #[test_only]
    use std::debug;

    #[test(creator = @message_board_addr, user1 = @0x456, user2 = @0x789)]
    fun test_minter_tracking(creator: &signer, user1: &signer, user2: &signer) acquires ManagedFungibleAsset, MinterRegistry, MinterInfo {
        // Initialize the module
        init_module(creator);

        // Users mint tokens
        mint_tokens(user1, 100);
        mint_tokens(user2, 200);
        mint_tokens(user1, 150);

        // Check minter list
        let minters = get_all_minters();
        assert!(vector::length(&minters) == 2, 0);
        assert!(vector::contains(&minters, &signer::address_of(user1)), 1);
        assert!(vector::contains(&minters, &signer::address_of(user2)), 2);

        // Check individual minter info
        assert!(get_minter_info(signer::address_of(user1)) == 250, 3);
        assert!(get_minter_info(signer::address_of(user2)) == 200, 4);

        // List all minters and their tokens
        let minter_list = list_all_minters_and_tokens();
        assert!(vector::length(&minter_list) == 2, 5);

        let minter_data1 = vector::borrow(&minter_list, 0);
        let minter_data2 = vector::borrow(&minter_list, 1);

        assert!((minter_data1.addr == signer::address_of(user1) && minter_data1.amount == 250) ||
                (minter_data1.addr == signer::address_of(user2) && minter_data1.amount == 200), 6);
        assert!((minter_data2.addr == signer::address_of(user1) && minter_data2.amount == 250) ||
                (minter_data2.addr == signer::address_of(user2) && minter_data2.amount == 200), 7);

        // Check token balances
        let balance_user1 = get_token_balance(signer::address_of(user1));
        let balance_user2 = get_token_balance(signer::address_of(user2));


        // Print the balances
        aptos_std::debug::print(&utf8(b"User1 balance: "));
        aptos_std::debug::print(&balance_user1);

        aptos_std::debug::print(&utf8(b"User2 balance: "));
        aptos_std::debug::print(&balance_user2);

        // Assert balances are correct
        assert!(balance_user1 == 250, 8);
        assert!(balance_user2 == 200, 9);
    }


    // Updated Transfer Test: Reflects ownership check removal
    #[test(creator = @message_board_addr, user1 = @0x456, user2 = @0x789)]
    fun test_transfer(creator: &signer, user1: &signer, user2: &signer) 
        acquires ManagedFungibleAsset, MinterInfo, MinterRegistry {
        // Initialize the module
        init_module(creator);

        // Mint tokens for user1
        mint_tokens(user1, 100);
        
        // Transfer tokens from user1 to user2 (without ownership check)
        transfer(creator, signer::address_of(user1), signer::address_of(user2), 50);

        // Check token balances
        let balance_user1 = get_token_balance(signer::address_of(user1));
        let balance_user2 = get_token_balance(signer::address_of(user2));

        // Assert balances are correct after transfer
        assert!(balance_user1 == 50, 0); // 100 - 50 transferred
        assert!(balance_user2 == 50, 1); // user2 received 50
    }


    // Updated Burn Test: Reflects ownership check removal
    #[test(creator = @message_board_addr, user1 = @0x456)]
    fun test_burn(creator: &signer, user1: &signer) 
        acquires ManagedFungibleAsset, MinterInfo, MinterRegistry {
        // Initialize the module
        init_module(creator);

        // Mint tokens for user1
        mint_tokens(user1, 100);

        // Burn 30 tokens from user1 (without ownership check)
        burn(creator, signer::address_of(user1), 30);

        // Check token balance after burn
        let balance_user1 = get_token_balance(signer::address_of(user1));

        // Assert balance is correct after burn
        assert!(balance_user1 == 70, 0); // 100 - 30 burned
    }

}
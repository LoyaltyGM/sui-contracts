/**
    User Store Module.
    This module is responsible for storing user data.
    Its functions are only accessible by the friend modules.
*/
module loyalty_gm::user_store {
    friend loyalty_gm::loyalty_system;
    friend loyalty_gm::loyalty_token;

    use sui::object::{ID};
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};
    use sui::vec_set::{Self, VecSet};

    // ======== Constants =========

    const INITIAL_XP: u64 = 0;

    // ======== Errors =========

    const ETaskAlreadyDone: u64 = 0;
    const ETaskNotStarted: u64 = 1;

    // ======== Structs =========

    /**
        User data.
    */
    struct User has store, drop {
        token_id: ID,
        /// Address of the user that data belongs to.
        owner: address,
        /// Tasks that are currently active.
        active_tasks: VecSet<ID>,
        /// Tasks that are already done.
        done_tasks: VecSet<ID>,
        /// XP that can be claimed by the user. It is reset to INITIAL_XP after claiming.
        claimable_xp: u64,
    }

    // ======== Public functions =========

    /**
        Create a new user store.
        It represents a table that maps user addresses to user data.
    */
    public(friend) fun new(ctx: &mut TxContext): Table<address, User> {  
        table::new<address, User>(ctx)
    }

    /**
        Add a new user to the store.
    */
    public(friend) fun add_user(
        store: &mut Table<address, User>, 
        token_id: ID,
        ctx: &mut TxContext
    ) {
        let owner = tx_context::sender(ctx);
        let data = User {
            token_id,
            active_tasks: vec_set::empty(),
            done_tasks: vec_set::empty(),
            owner,
            claimable_xp: INITIAL_XP,
        };

        table::add(store, owner, data)
    }

    /**
        Update the user's XP.
    */
    public(friend) fun update_user_xp(
        store: &mut Table<address, User>, 
        owner: address,
        reward_xp: u64
    ) {
        let user_data = table::borrow_mut<address, User>(store, owner);
        user_data.claimable_xp = user_data.claimable_xp + reward_xp;
    }

    /**
        Reset the user's XP to INITIAL_XP.
    */
    public(friend) fun reset_user_xp(store: &mut Table<address, User>, owner: address) {
        let user_data = table::borrow_mut<address, User>(store, owner);
        user_data.claimable_xp = INITIAL_XP;
    }

    /**
        Start a task with the given ID for the user.
    */
    public(friend) fun start_task(store: &mut Table<address, User>, task_id: ID, owner: address) {
        let user_data = table::borrow_mut<address, User>(store, owner);
        assert!(!vec_set::contains(&user_data.done_tasks, &task_id), ETaskAlreadyDone);
        vec_set::insert(&mut user_data.active_tasks, task_id)
    }

    /**
        Finish a task with the given ID for the user.
    */
    public(friend) fun finish_task(
        store: &mut Table<address, User>, 
        task_id: ID, 
        owner: address,
        reward_xp: u64
    ) {
        let user_data = table::borrow_mut<address, User>(store, owner);

        assert!(!vec_set::contains(&user_data.done_tasks, &task_id), ETaskAlreadyDone);
        assert!(vec_set::contains(&user_data.active_tasks, &task_id), ETaskNotStarted);

        vec_set::remove(&mut user_data.active_tasks, &task_id);
        vec_set::insert(&mut user_data.done_tasks, task_id);

        update_user_xp(store, owner, reward_xp)
    }

    /**
        Get the size of the user store.
    */
    public fun size(store: &Table<address, User>): u64 {
        table::length(store)
    }

    /**
        Get the user data for the given address.
    */
    public fun get_user(store: &Table<address, User>, owner: address): &User {
        table::borrow(store, owner)
    }

    /**
        Check if the user exists in the store.
    */
    public fun user_exists(table: &Table<address, User>, owner: address): bool {
        table::contains(table, owner)
    }

    /**
        Get the user's claimable XP.
    */
    public fun get_user_xp(table: &Table<address, User>, owner: address): u64 {
        let user_data = table::borrow<address, User>(table, owner);
        user_data.claimable_xp
    }
}
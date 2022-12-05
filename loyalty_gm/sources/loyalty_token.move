module loyalty_gm::loyalty_token {
    use sui::object::{Self, UID, ID};
    use std::string::{Self, String};
    use sui::transfer;
    use sui::url::{Url};
    use sui::tx_context::{Self, TxContext};
    use sui::event::{emit};
    use sui::math::{Self};
    use loyalty_gm::loyalty_system::{Self, LoyaltySystem};
    use loyalty_gm::user_store::{Self};

    // ======== Constants =========

    const INITIAL_LVL: u64 = 0;
    const INITIAL_XP: u64 = 0;
    const LVL_DIVIDER: u64 = 10;

    // ======== Error codes =========

    const ENotUniqueAddress: u64 = 0;
    const ETooManyMint: u64 = 1;
    const ENoClaimableXp: u64 = 2;
    const EAdminOnly: u64 = 3;
    const EInvalidTokenStore: u64 = 4;

    // ======== Structs =========

    /// Loyalty NFT.
    struct LoyaltyToken has key, store {
        id: UID,
        loyalty_system: ID,
        name: String,
        description: String,
        url: Url,

        // Level of nft [0-255]
        lvl: u64,
        // Expiration timestamp (UNIX time) - app specific
        xp: u64,
        // TODO:
        // array of lvl points 
        // pointsToNextLvl: u128,
    }

    // ======== Events =========

    struct MintTokenEvent has copy, drop {
        object_id: ID,
        loyalty_system:ID,
        minter: address,
        name: string::String,
    }

    struct ClaimXpEvent has copy, drop {
        token_id: ID,
        claimer: address,
        claimed_xp: u64,
    }


    // ======= Public functions =======

    public entry fun mint(
        ls: &mut LoyaltySystem,
        ctx: &mut TxContext
    ) {
        loyalty_system::increment_total_minted(ls);

        let nft = LoyaltyToken {
            id: object::new(ctx),
            loyalty_system: object::id(ls),
            name: *loyalty_system::get_name(ls),
            description: *loyalty_system::get_description(ls),
            url: *loyalty_system::get_url(ls),
            lvl: INITIAL_LVL,
            // lvl_threshold: INITIAL_LVL_THRESHOLD,
            xp: INITIAL_XP,
        };
        let sender = tx_context::sender(ctx);

        emit(MintTokenEvent {
            object_id: object::id(&nft),
            loyalty_system: object::id(ls),
            minter: sender,
            name: nft.name,
        });

        user_store::add_user(loyalty_system::get_mut_user_store(ls), object::id(&nft), ctx);
        transfer::transfer(nft, sender);
    }

    public entry fun claim_exp (
        ls: &mut LoyaltySystem,
        token: &mut LoyaltyToken, 
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let claimable_xp = user_store::get_user_xp(loyalty_system::get_user_store(ls), sender);
        assert!(claimable_xp > 0, ENoClaimableXp);

        emit(ClaimXpEvent {
            token_id: object::id(token),
            claimer: sender,
            claimed_xp: claimable_xp,
        });

        user_store::reset_user_xp(loyalty_system::get_mut_user_store(ls), sender);

        update_token_xp(claimable_xp, token);
        update_token_lvl(ls, token);
    }

    // ======== Admin Functions =========

    // ======= Private and Utility functions =======

    fun update_token_xp(xp_to_add: u64, token: &mut LoyaltyToken) {
        let new_xp = token.xp + xp_to_add;
        token.xp = new_xp;
    }

    fun update_token_lvl(ls: &mut LoyaltySystem, token: &mut LoyaltyToken) {
        let max_lvl = loyalty_system::get_max_lvl(ls);
        let lvl = math::sqrt(token.xp/LVL_DIVIDER);
        token.lvl = if (lvl <= max_lvl) lvl else max_lvl;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ResourceNFT1155} from "../src/ResourceNFT1155.sol";
import {ItemNFT721} from "../src/ItemNFT721.sol";
import {MagicToken} from "../src/MagicToken.sol";
import {CraftingSearch} from "../src/CraftingSearch.sol";
import {Marketplace} from "../src/Marketplace.sol";

contract FullTest is Test {
    ResourceNFT1155 res;
    ItemNFT721 items;
    MagicToken magic;
    CraftingSearch cs;
    Marketplace mkt;
    address admin = address(0xA11CE);
    address user = address(0xBEBA);
    address buyer = address(0xDEAD);

    function setUp() public {
        // Deploy contracts
        res = new ResourceNFT1155(admin);
        items = new ItemNFT721(admin);
        magic = new MagicToken(admin);
        cs = new CraftingSearch(admin, res, items);
        mkt = new Marketplace(admin, items, magic);

        // Grant roles from admin account
        vm.startPrank(admin);
        // CraftingSearch needs to mint/burn resources
        res.grantRole(res.MINTER_ROLE(), address(cs));
        res.grantRole(res.BURNER_ROLE(), address(cs));

        // CraftingSearch needs to mint items
        items.grantRole(items.MINTER_ROLE(), address(cs));
        // Marketplace needs to burn items
        items.grantRole(items.BURNER_ROLE(), address(mkt));

        // Marketplace needs to mint magic tokens
        magic.grantRole(magic.MARKET_ROLE(), address(mkt));

        // *** TEST-ONLY ROLES ***
        // Grant admin the necessary roles to set up test scenarios directly
        res.grantRole(res.MINTER_ROLE(), admin);
        items.grantRole(items.MINTER_ROLE(), admin);
        vm.stopPrank();
    }

    /// @notice Tests if a user can successfully search for resources.
    function test_Search() public {
        // Ensure cooldown from any previous test is not active
        vm.warp(block.timestamp + cs.SEARCH_COOLDOWN() + 1);

        vm.prank(user);
        cs.search();

        // Check that the user received 3 resources in total
        uint256 totalBalance = 0;
        for (uint i = 1; i <= 6; i++) {
            totalBalance += res.balanceOf(user, i);
        }
        assertEq(totalBalance, 3, "User should have 3 resources after search");
    }

    /// @notice Tests the 60-second cooldown on the search function.
    function test_SearchCooldown() public {
        // Ensure we start with a clean slate for time
        vm.warp(block.timestamp + cs.SEARCH_COOLDOWN() + 1);

        // First search should succeed
        vm.prank(user);
        cs.search();

        // Immediate second search should fail
        vm.prank(user);
        vm.expectRevert("Search is on cooldown");
        cs.search();

        // Warp time forward by the cooldown duration
        vm.warp(block.timestamp + cs.SEARCH_COOLDOWN());

        // Search after cooldown should succeed
        vm.prank(user);
        cs.search();
    }

    /// @notice Tests if a user can craft an item after collecting the required resources.
    function test_Craft() public {
        // Admin mints the required resources directly to the user for the test
        vm.startPrank(admin);
        uint256[] memory ids = new uint256[](3);
        ids[0] = 2; // Iron
        ids[1] = 1; // Wood
        ids[2] = 4; // Leather
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 3;
        amounts[1] = 1;
        amounts[2] = 1;
        res.mintBatch(user, ids, amounts);
        vm.stopPrank();

        // User crafts the item
        vm.prank(user);
        cs.craft(1); // Craft Cossack Sabre (itemType 1)

        assertEq(items.ownerOf(1), user, "User should own the newly crafted item");
    }

    /// @notice Tests that crafting fails if the recipe does not exist.
    function test_CraftRecipeNotExist() public {
        vm.prank(user);
        vm.expectRevert("Recipe does not exist");
        cs.craft(99); // Assuming itemType 99 does not exist
    }

    /// @notice Tests the full marketplace flow: list, purchase, and reward.
    function test_Marketplace() public {
        uint256 tokenId = 1;
        uint256 price = 100 * 10**18;

        // 1. Admin mints an item directly to the user for the test
        vm.prank(admin);
        items.mintTo(user);

        // 2. User lists the item for sale
        vm.prank(user);
        mkt.list(tokenId, price);

        // 3. Another user purchases the item
        vm.prank(buyer);
        mkt.purchase(tokenId);

        // 4. Verify the seller received the magic tokens
        assertEq(magic.balanceOf(user), price, "Seller should receive MAGIC tokens");

        // 5. Verify the item was burned by expecting a revert when checking its owner
        // NOTE: The exact error message/selector for a nonexistent token is used here.
        bytes4 expectedError = bytes4(keccak256("ERC721NonexistentToken(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(expectedError, tokenId));
        items.ownerOf(tokenId);
    }

    /// @notice Tests if a user can delist an item they put on the marketplace.
    function test_Delist() public {
        uint256 tokenId = 1;
        uint256 price = 100 * 10**18;
        // 1. Admin mints an item to the user
        vm.prank(admin);
        items.mintTo(user);

        // 2. User lists the item
        vm.prank(user);
        mkt.list(tokenId, price);

        // 3. User delists the item
        vm.prank(user);
        mkt.delist(tokenId);

        // 4. A buyer attempts to purchase the delisted item, which should fail
        vm.prank(buyer);
        vm.expectRevert("Item not listed for sale");
        mkt.purchase(tokenId);
    }
}
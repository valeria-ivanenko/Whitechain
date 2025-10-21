// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

import {ResourceNFT1155} from "../src/ResourceNFT1155.sol";
import {ItemNFT721} from "../src/ItemNFT721.sol";
import {MagicToken} from "../src/MagicToken.sol";
import {CraftingSearch} from "../src/CraftingSearch.sol";
import {Marketplace} from "../src/Marketplace.sol";

/**
 * @dev Deploys contracts, grants roles, and runs a demo search/craft.
 */
contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        address admin = vm.addr(pk);

        // Deploy baseline contracts
        ResourceNFT1155 res = new ResourceNFT1155(admin);
        ItemNFT721 items = new ItemNFT721(admin);
        MagicToken magic = new MagicToken(admin);
        // Pass addresses to constructors to avoid encoding errors
        CraftingSearch cs = new CraftingSearch(admin, res, items);
        Marketplace mkt = new Marketplace(admin, items, magic);

        // Grant core roles for the game to function
        res.grantRole(res.MINTER_ROLE(), address(cs));
        res.grantRole(res.BURNER_ROLE(), address(cs));

        items.grantRole(items.MINTER_ROLE(), address(cs));
        items.grantRole(items.BURNER_ROLE(), address(mkt)); // Allow Marketplace to burn items

        magic.grantRole(magic.MARKET_ROLE(), address(mkt));

        // --- Post-Deployment Demo Actions ---
        console2.log("--- Performing Demo Search & Craft ---");

        // 1. Perform a search for resources as the admin user
        cs.search();
        console2.log("Admin performed a resource search.");

        // 2. To craft, we need specific resources.
        // For this demo, we'll grant the admin minting rights temporarily...
        res.grantRole(res.MINTER_ROLE(), admin);

        // ...and mint the exact resources needed for a Cossack Sabre.
        // Recipe: 3x Iron (ID 2), 1x Wood (ID 1), 1x Leather (ID 4)
        uint256[] memory ids = new uint256[](3);
        ids[0] = 2; // Iron
        ids[1] = 1; // Wood
        ids[2] = 4; // Leather
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 3;
        amounts[1] = 1;
        amounts[2] = 1;
        res.mintBatch(admin, ids, amounts);
        console2.log("Minted resources for a Cossack Sabre to Admin.");

        // 3. Craft the Cossack Sabre (itemType 1)
        cs.craft(1);
        console2.log("Admin successfully crafted a Cossack Sabre (Token ID 1).");
        console2.log("--- Demo Complete ---");
        // --- End of Demo ---

        vm.stopBroadcast();

        console2.log("--- Deployed Contract Addresses ---");
        console2.log("ResourceNFT1155:", address(res));
        console2.log("ItemNFT721     :", address(items));
        console2.log("MagicToken     :", address(magic));
        console2.log("CraftingSearch :", address(cs));
        console2.log("Marketplace    :", address(mkt));
        console2.log("Admin          :", admin);
    }
}
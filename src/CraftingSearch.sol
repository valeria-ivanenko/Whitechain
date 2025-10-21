// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ResourceNFT1155} from "./ResourceNFT1155.sol";
import {ItemNFT721} from "./ItemNFT721.sol";

contract CraftingSearch is AccessControl {
    ResourceNFT1155 public resources;
    ItemNFT721 public items;

    uint256 public constant SEARCH_COOLDOWN = 60;

    mapping(address => uint256) public lastSearchTime;

    struct Recipe {
        uint256[] resourceIds;
        uint256[] amounts;
    }

    mapping(uint256 => Recipe) internal recipes;

    constructor(
        address admin,
        ResourceNFT1155 _resources,
        ItemNFT721 _items
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        resources = _resources;
        items = _items;

        // Cossack Sabre Recipe
        uint256[] memory cossackSabreResourceIds = new uint256[](3);
        cossackSabreResourceIds[0] = 2; // Iron
        cossackSabreResourceIds[1] = 1; // Wood
        cossackSabreResourceIds[2] = 4; // Leather

        uint256[] memory cossackSabreAmounts = new uint256[](3);
        cossackSabreAmounts[0] = 3;
        cossackSabreAmounts[1] = 1;
        cossackSabreAmounts[2] = 1;

        recipes[1] = Recipe(cossackSabreResourceIds, cossackSabreAmounts);

        // Elder Staff Recipe
        uint256[] memory elderStaffResourceIds = new uint256[](3);
        elderStaffResourceIds[0] = 1; // Wood
        elderStaffResourceIds[1] = 3; // Gold
        elderStaffResourceIds[2] = 6; // Diamond

        uint256[] memory elderStaffAmounts = new uint256[](3);
        elderStaffAmounts[0] = 2;
        elderStaffAmounts[1] = 1;
        elderStaffAmounts[2] = 1;

        recipes[2] = Recipe(elderStaffResourceIds, elderStaffAmounts);
    }

    function getRecipe(uint256 itemType) public view returns (uint256[] memory, uint256[] memory) {
        return (recipes[itemType].resourceIds, recipes[itemType].amounts);
    }

    function search() external {
        require(
            block.timestamp >= lastSearchTime[msg.sender] + SEARCH_COOLDOWN,
            "Search is on cooldown"
        );
        lastSearchTime[msg.sender] = block.timestamp;

        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) {
            ids[i] = (uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, i))) % 6) + 1;
            amounts[i] = 1;
        }

        resources.mintBatch(msg.sender, ids, amounts);
    }

    function craft(uint256 itemType) external {
        Recipe storage recipe = recipes[itemType];
        require(recipe.resourceIds.length > 0, "Recipe does not exist");

        resources.burnBatch(msg.sender, recipe.resourceIds, recipe.amounts);
        items.mintTo(msg.sender);
    }
}
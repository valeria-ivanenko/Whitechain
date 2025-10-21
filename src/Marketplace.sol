// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ItemNFT721} from "./ItemNFT721.sol";
import {MagicToken} from "./MagicToken.sol";

/**
 * @title Marketplace (Template)
 **/
contract Marketplace is AccessControl {
    ItemNFT721 public items;
    MagicToken public magic;

    struct Listing {
        address seller;
        uint256 price;
    }

    mapping(uint256 => Listing) public listings;

    constructor(address admin, ItemNFT721 _items, MagicToken _magic) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        items = _items;
        magic = _magic;
    }

    function list(uint256 tokenId, uint256 price) external {
        require(items.ownerOf(tokenId) == msg.sender, "Not the owner");
        require(price > 0, "Price must be greater than 0");
        listings[tokenId] = Listing(msg.sender, price);
    }

    function delist(uint256 tokenId) external {
        require(listings[tokenId].seller == msg.sender, "Not the seller");
        delete listings[tokenId];
    }

    function purchase(uint256 tokenId) external {
        Listing storage listing = listings[tokenId];
        require(listing.price > 0, "Item not listed for sale");
        items.burn(tokenId);
        magic.mint(listing.seller, listing.price);
        delete listings[tokenId];
    }
}
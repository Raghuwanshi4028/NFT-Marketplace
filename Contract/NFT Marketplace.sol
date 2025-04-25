// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTMarketplace {
    struct Listing {
        address seller;
        address nftAddress;
        uint256 tokenId;
        uint256 price;
    }

    mapping(uint256 => Listing) public listings;
    uint256 public listingCounter;

    event Listed(uint256 listingId, address seller, address nftAddress, uint256 tokenId, uint256 price);
    event Purchased(uint256 listingId, address buyer);
    event Cancelled(uint256 listingId);

    function listNFT(address nftAddress, uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than zero");

        IERC721(nftAddress).transferFrom(msg.sender, address(this), tokenId);

        listings[listingCounter] = Listing(msg.sender, nftAddress, tokenId, price);
        emit Listed(listingCounter, msg.sender, nftAddress, tokenId, price);
        listingCounter++;
    }

    function buyNFT(uint256 listingId) external payable {
        Listing memory item = listings[listingId];
        require(msg.value == item.price, "Incorrect ETH sent");

        payable(item.seller).transfer(msg.value);
        IERC721(item.nftAddress).transferFrom(address(this), msg.sender, item.tokenId);

        delete listings[listingId];
        emit Purchased(listingId, msg.sender);
    }

    function cancelListing(uint256 listingId) external {
        Listing memory item = listings[listingId];
        require(item.seller == msg.sender, "Not your listing");

        IERC721(item.nftAddress).transferFrom(address(this), msg.sender, item.tokenId);
        delete listings[listingId];
        emit Cancelled(listingId);
    }

    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    function getAllListings() external view returns (Listing[] memory) {
        Listing[] memory all = new Listing[](listingCounter);
        for (uint256 i = 0; i < listingCounter; i++) {
            all[i] = listings[i];
        }
        return all;
    }
}

 

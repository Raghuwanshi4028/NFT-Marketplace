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
    event PriceUpdated(uint256 listingId, uint256 newPrice);

    function listNFT(address nftAddress, uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than zero");

        IERC721(nftAddress).transferFrom(msg.sender, address(this), tokenId);

        listings[listingCounter] = Listing(msg.sender, nftAddress, tokenId, price);
        emit Listed(listingCounter, msg.sender, nftAddress, tokenId, price);
        listingCounter++;
    }

    function buyNFT(uint256 listingId) external payable {
        Listing memory item = listings[listingId];
        require(item.seller != address(0), "Listing does not exist");
        require(msg.value == item.price, "Incorrect ETH sent");

        payable(item.seller).transfer(msg.value);
        IERC721(item.nftAddress).transferFrom(address(this), msg.sender, item.tokenId);

        delete listings[listingId];
        emit Purchased(listingId, msg.sender);
    }

    function cancelListing(uint256 listingId) external {
        Listing memory item = listings[listingId];
        require(item.seller != address(0), "Listing does not exist");
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

    // NEW FUNCTIONS 👇

    /// @notice Update the price of an existing listing
    function updateListingPrice(uint256 listingId, uint256 newPrice) external {
        Listing storage item = listings[listingId];
        require(item.seller != address(0), "Listing does not exist");
        require(item.seller == msg.sender, "Not your listing");
        require(newPrice > 0, "Price must be greater than zero");

        item.price = newPrice;
        emit PriceUpdated(listingId, newPrice);
    }

    /// @notice Check if a listing exists
    function isListed(uint256 listingId) public view returns (bool) {
        return listings[listingId].seller != address(0);
    }

    /// @notice Return only active listings (non-deleted)
    function getActiveListings() external view returns (Listing[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < listingCounter; i++) {
            if (listings[i].seller != address(0)) {
                activeCount++;
            }
        }

        Listing[] memory activeListings = new Listing[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < listingCounter; i++) {
            if (listings[i].seller != address(0)) {
                activeListings[index] = listings[i];
                index++;
            }
        }
        return activeListings;
    }

    /// @notice Withdraw your listed NFT without canceling the listing (optional)
    function withdrawNFT(uint256 listingId) external {
        Listing memory item = listings[listingId];
        require(item.seller != address(0), "Listing does not exist");
        require(item.seller == msg.sender, "Not your listing");

        IERC721(item.nftAddress).transferFrom(address(this), msg.sender, item.tokenId);
        delete listings[listingId];
        emit Cancelled(listingId); // Reuse cancel event
    }
}

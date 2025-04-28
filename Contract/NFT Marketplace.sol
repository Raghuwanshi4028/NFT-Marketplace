// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is Ownable {
    struct Listing {
        address seller;
        address nftAddress;
        uint256 tokenId;
        uint256 price;
        bool paused;
    }

    mapping(uint256 => Listing) public listings;
    uint256 public listingCounter;
    uint256 public marketplaceFeePercent = 2; // e.g., 2%

    event Listed(uint256 listingId, address seller, address nftAddress, uint256 tokenId, uint256 price);
    event Purchased(uint256 listingId, address buyer);
    event Cancelled(uint256 listingId);
    event PriceUpdated(uint256 listingId, uint256 newPrice);
    event ListingPaused(uint256 listingId, bool isPaused);
    event FeeUpdated(uint256 newFeePercent);

    constructor() Ownable(msg.sender) {}

    function listNFT(address nftAddress, uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than zero");

        IERC721(nftAddress).transferFrom(msg.sender, address(this), tokenId);

        listings[listingCounter] = Listing(msg.sender, nftAddress, tokenId, price, false);
        emit Listed(listingCounter, msg.sender, nftAddress, tokenId, price);
        listingCounter++;
    }

    function buyNFT(uint256 listingId) external payable {
        Listing memory item = listings[listingId];
        require(item.seller != address(0), "Listing does not exist");
        require(!item.paused, "Listing is paused");
        require(msg.value == item.price, "Incorrect ETH sent");

        uint256 fee = (msg.value * marketplaceFeePercent) / 100;
        uint256 sellerProceeds = msg.value - fee;

        payable(item.seller).transfer(sellerProceeds);
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

    function updateListingPrice(uint256 listingId, uint256 newPrice) external {
        Listing storage item = listings[listingId];
        require(item.seller != address(0), "Listing does not exist");
        require(item.seller == msg.sender, "Not your listing");
        require(newPrice > 0, "Price must be greater than zero");

        item.price = newPrice;
        emit PriceUpdated(listingId, newPrice);
    }

    function isListed(uint256 listingId) public view returns (bool) {
        return listings[listingId].seller != address(0);
    }

    function getActiveListings() external view returns (Listing[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < listingCounter; i++) {
            if (listings[i].seller != address(0) && !listings[i].paused) {
                activeCount++;
            }
        }

        Listing[] memory activeListings = new Listing[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < listingCounter; i++) {
            if (listings[i].seller != address(0) && !listings[i].paused) {
                activeListings[index] = listings[i];
                index++;
            }
        }
        return activeListings;
    }

    function withdrawNFT(uint256 listingId) external {
        Listing memory item = listings[listingId];
        require(item.seller != address(0), "Listing does not exist");
        require(item.seller == msg.sender, "Not your listing");

        IERC721(item.nftAddress).transferFrom(address(this), msg.sender, item.tokenId);
        delete listings[listingId];
        emit Cancelled(listingId);
    }

    /// @notice Pause/unpause a listing
    function togglePauseListing(uint256 listingId) external {
        Listing storage item = listings[listingId];
        require(item.seller != address(0), "Listing does not exist");
        require(item.seller == msg.sender, "Not your listing");

        item.paused = !item.paused;
        emit ListingPaused(listingId, item.paused);
    }

    /// @notice Bulk purchase multiple NFTs
    function bulkBuyNFTs(uint256[] calldata listingIds) external payable {
        uint256 totalPrice = 0;

        // First pass: calculate total
        for (uint256 i = 0; i < listingIds.length; i++) {
            Listing memory item = listings[listingIds[i]];
            require(item.seller != address(0), "Listing does not exist");
            require(!item.paused, "Listing is paused");
            totalPrice += item.price;
        }

        require(msg.value == totalPrice, "Incorrect ETH sent for bulk purchase");

        // Second pass: transfer NFTs
        for (uint256 i = 0; i < listingIds.length; i++) {
            Listing memory item = listings[listingIds[i]];

            uint256 fee = (item.price * marketplaceFeePercent) / 100;
            uint256 sellerProceeds = item.price - fee;

            payable(item.seller).transfer(sellerProceeds);
            IERC721(item.nftAddress).transferFrom(address(this), msg.sender, item.tokenId);

            delete listings[listingIds[i]];
            emit Purchased(listingIds[i], msg.sender);
        }
    }

    /// @notice Owner can update the marketplace fee
    function updateMarketplaceFee(uint256 newFeePercent) external onlyOwner {
        require(newFeePercent <= 10, "Fee too high"); // e.g., Max 10%
        marketplaceFeePercent = newFeePercent;
        emit FeeUpdated(newFeePercent);
    }

    /// @notice Owner can withdraw collected marketplace fees
    function withdrawFees(address payable recipient) external onlyOwner {
        require(address(this).balance > 0, "No fees to withdraw");
        recipient.transfer(address(this).balance);
    }

    /// @notice Emergency delist an NFT (onlyOwner)
    function emergencyDelist(uint256 listingId) external onlyOwner {
        Listing memory item = listings[listingId];
        require(item.seller != address(0), "Listing does not exist");

        IERC721(item.nftAddress).transferFrom(address(this), item.seller, item.tokenId);
        delete listings[listingId];
        emit Cancelled(listingId);
    }
}

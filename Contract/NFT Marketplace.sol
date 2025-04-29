/// @notice Relist a newly purchased NFT
function relistNFT(address nftAddress, uint256 tokenId, uint256 price) external {
    require(price > 0, "Price must be greater than zero");

    IERC721 nft = IERC721(nftAddress);
    require(nft.ownerOf(tokenId) == msg.sender, "You are not the owner");

    nft.transferFrom(msg.sender, address(this), tokenId);

    listings[listingCounter] = Listing(msg.sender, nftAddress, tokenId, price, false);
    emit Listed(listingCounter, msg.sender, nftAddress, tokenId, price);
    listingCounter++;
}
/// @notice Update the NFT address or tokenId of a listing
function updateNFTDetails(uint256 listingId, address newNftAddress, uint256 newTokenId) external {
    Listing storage item = listings[listingId];
    require(item.seller != address(0), "Listing does not exist");
    require(item.seller == msg.sender, "Not your listing");

    IERC721(item.nftAddress).transferFrom(address(this), msg.sender, item.tokenId); // return old NFT
    IERC721(newNftAddress).transferFrom(msg.sender, address(this), newTokenId); // bring new NFT

    item.nftAddress = newNftAddress;
    item.tokenId = newTokenId;
}
bool public marketplacePaused = false;

modifier whenNotPaused() {
    require(!marketplacePaused, "Marketplace is paused");
    _;
}

function toggleMarketplacePause() external onlyOwner {
    marketplacePaused = !marketplacePaused;
}
function listNFT(address nftAddress, uint256 tokenId, uint256 price) external whenNotPaused {
    ...
}

function buyNFT(uint256 listingId) external payable whenNotPaused {
    ...
}
struct Offer {
    address offerer;
    uint256 offerPrice;
}

mapping(uint256 => Offer[]) public offers; // listingId => offers

/// @notice Make an offer for an NFT
function makeOffer(uint256 listingId) external payable {
    Listing memory item = listings[listingId];
    require(item.seller != address(0), "Listing does not exist");
    require(!item.paused, "Listing paused");
    require(msg.value > 0, "Offer must be greater than 0");

    offers[listingId].push(Offer(msg.sender, msg.value));
}

/// @notice Seller can accept an offer
function acceptOffer(uint256 listingId, uint256 offerIndex) external {
    Listing memory item = listings[listingId];
    require(item.seller == msg.sender, "Not your listing");

    Offer memory chosenOffer = offers[listingId][offerIndex];

    uint256 fee = (chosenOffer.offerPrice * marketplaceFeePercent) / 100;
    uint256 sellerProceeds = chosenOffer.offerPrice - fee;

    payable(item.seller).transfer(sellerProceeds);
    IERC721(item.nftAddress).transferFrom(address(this), chosenOffer.offerer, item.tokenId);

    delete listings[listingId];
    delete offers[listingId]; // remove all offers after sale
    emit Purchased(listingId, chosenOffer.offerer);
}

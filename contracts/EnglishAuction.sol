// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "hardhat/console.sol";

interface IERC1155 {
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;
}

error NotTime();
error ZeroBalance();
error NotTheSeller();
error CanNotBidNow();
error TransferFailed();
error BelowMinimumBid();
error BidIsStillActive();
error YouCanNotWithdraw();
error NotTheHighestBidder();
error ContractNotAllowed();
error LowerThanTheHighestBid();
error YouAreNotAllowedToClaim();
error YouAreNotAllowedToWithdraw();

contract EnglishAuction {
    IERC1155 public immutable token;
    address private immutable seller;
    uint256 private immutable tokenId;
    uint256 private immutable amount;
    uint256 private constant MINIMUM_BID = 5 * 10**16;
    uint256 private constant DURATION = 60 * 60 * 24;

    struct Bid {
        address highestBidder;
        uint48 startTime;
        uint48 endTime;
        uint256 highestBid;
    }
    Bid bid;

    mapping(address => uint256) private bids;

    modifier BidEnd() {
        if (block.timestamp < bid.endTime) revert BidIsStillActive();
        _;
    }
    modifier toPlaceBid() {
        if (block.timestamp < bid.startTime || block.timestamp > bid.endTime)
            revert CanNotBidNow();
        if (msg.value < MINIMUM_BID) revert BelowMinimumBid();
        if (msg.sender != tx.origin) revert ContractNotAllowed();
        if (msg.value + bids[msg.sender] <= bid.highestBid)
            revert LowerThanTheHighestBid();
        _;
    }

    constructor(
        address _token,
        uint256 _tokenId,
        uint256 _amount
    ) {
        token = IERC1155(_token);
        seller = payable(msg.sender);
        tokenId = _tokenId;
        amount = _amount;
    }

    function startBid() external {
        uint256 _startTime = block.timestamp;
        if (msg.sender != seller) revert NotTheSeller();
        token.safeTransferFrom(msg.sender, address(this), tokenId, amount, "");
        bid = Bid(
            address(0),
            uint48(block.timestamp),
            uint48(_startTime + DURATION),
            0
        );
        console.log("The start bid time is", block.timestamp);
        console.log("The bid will end at", bid.endTime);
        emit BidStarted(_startTime);
    }

    function placeBid() public payable toPlaceBid {
        uint256 bidValue = bids[msg.sender];
        bid.highestBid = msg.value + bidValue;
        bid.highestBidder = msg.sender;
        bidValue += msg.value;
        bids[msg.sender] = bidValue;
        console.log("The highest bidder is", bid.highestBidder);
        console.log("A bid of", bids[msg.sender], "was placed");
        console.log("The balance of the contract is", address(this).balance);
        emit BidPlaced(msg.sender, bid.highestBid);
    }

    function withdraw() public BidEnd {
        address _highestBidder = bid.highestBidder;
        uint256 bal = bids[msg.sender];
        if (bal == 0) revert ZeroBalance();
        if (msg.sender == _highestBidder) revert YouAreNotAllowedToWithdraw();
        bids[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: bal}("");
        if (!success) revert YouCanNotWithdraw();
        console.log("The ether balance of the caller is ", msg.sender.balance);
    }

    function claim() external BidEnd {
        address bidWinner = bid.highestBidder;
        uint256 _highestBid = bid.highestBid;
        delete bid;
        if (bidWinner != address(0) && msg.sender == bidWinner) {
            (bool success, ) = seller.call{value: _highestBid}("");
            if (!success) {
            token.safeTransferFrom(
                address(this),
                bidWinner,
                tokenId,
                amount,
                ""
            );
            }
        } else if (msg.sender == seller && bidWinner == address(0)) {
            token.safeTransferFrom(address(this), seller, tokenId, amount, "");
        } else {
            revert YouAreNotAllowedToClaim();
        }
        emit BidEnded(bidWinner);
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    //////////////////////////////////////////////////////////////////////////////////////
    //                                 EVENTS                                           //
    //////////////////////////////////////////////////////////////////////////////////////
    event BidStarted(uint256 indexed startTime);
    event BidEnded(address indexed bidWinner);
    event BidPlaced(address indexed bidder, uint256 indexed bidPrice);
}

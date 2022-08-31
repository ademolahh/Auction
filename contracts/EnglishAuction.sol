// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import {Lib} from "./library/Lib.sol";

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
    using Lib for address[];
    IERC1155 public immutable token;
    address public immutable seller;
    uint256 public immutable tokenId;
    uint256 public immutable amount;
    uint256 public constant MINIMUM_BID = 5 * 10**16;
    uint256 public constant DURATION = 60 * 60 * 24;

    struct Bid {
        address highestBidder;
        uint48 startTime;
        uint48 endTime;
        uint256 highestBid;
    }
    Bid bid;

    address[] bidders;

    mapping(address => uint256) public bids;

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
        bid.startTime = uint48(block.timestamp);
        bid.endTime = uint48(_startTime + DURATION);
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

    function updateBids(address _addr) internal {
        address _highestBidder = bid.highestBidder;
        uint256 position = bidders._removeElement(_addr);
        if (msg.sender == _highestBidder) {
            if (position > 0) {
                bid.highestBidder = bidders[position - 1];
            } else {
                bid.highestBidder = address(0);
            }
            bid.highestBid = bids[bid.highestBidder];
        }
    }

    function withdraw() public {
        uint256 bal = bids[msg.sender];
        if (bal == 0) revert ZeroBalance();
        updateBids(msg.sender);
        bids[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: bal}("");
        if (!success) revert YouCanNotWithdraw();
        console.log("The ether balance of the caller is ", msg.sender.balance);
    }

    function claim() external BidEnd {
        address bidWinner = bid.highestBidder;
        uint256 _highestBid = bid.highestBid;
        delete bid;
        if (bidWinner != address(0)) {
            (bool success, ) = seller.call{value: _highestBid}("");
            if (success) {
                token.safeTransferFrom(
                    address(this),
                    bidWinner,
                    tokenId,
                    amount,
                    ""
                );
            }
            emit BidEnded(bidWinner);
        } else {
            token.safeTransferFrom(address(this), seller, tokenId, amount, "");
        }
        console.log("The winner is ", bidWinner);
    }

    function getBidders() external view returns (address[] memory) {
        return bidders;
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

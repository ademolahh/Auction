const { expect } = require("chai");
const { deployments, ethers } = require("hardhat");

describe("English Auction", () => {
  let token, auction, accounts, seller, bidderOne, bidderTwo, bidderThree;
  beforeEach(async () => {
    await deployments.fixture(["all"]);
    token = await ethers.getContract("TestERC1155");
    auction = await ethers.getContract("EnglishAuction");
    accounts = await ethers.getSigners();
    seller = accounts[0];
    bidderOne = accounts[1];
    bidderTwo = accounts[2];
    bidderThree = accounts[3];
  });
  describe("Bid", () => {
    it("start bid", async () => {
      await token.connect(seller).setApprovalForAll(auction.address, true);
      await expect(auction.connect(bidderOne).startBid()).to.be.revertedWith(
        "NotTheSeller()"
      );
      await auction.connect(seller).startBid();
    });
    it("place bid", async () => {
      await expect(
        auction.connect(bidderOne).placeBid({ value: "10000000000000" })
      ).to.be.revertedWith("CanNotBidNow()");
      await token.connect(seller).setApprovalForAll(auction.address, true);
      await auction.connect(seller).startBid();
      await expect(
        auction.connect(bidderOne).placeBid({ value: "10000000000000" })
      ).to.be.revertedWith("BelowMinimumBid()");
      await auction
        .connect(bidderOne)
        .placeBid({ value: "50000000000000000000" });
      await expect(
        auction.connect(bidderThree).placeBid({ value: "5000000000000000000" })
      ).to.be.revertedWith("LowerThanTheHighestBid()");
      await auction
        .connect(bidderTwo)
        .placeBid({ value: "60000000000000000000" });
      await auction
        .connect(bidderOne)
        .placeBid({ value: "11000000000000000000" });
    });
    it("withdraw", async () => {
      await token.connect(seller).setApprovalForAll(auction.address, true);
      await auction.connect(seller).startBid();
      await auction
        .connect(bidderOne)
        .placeBid({ value: "50000000000000000000" });
      await auction
        .connect(bidderTwo)
        .placeBid({ value: "80000000000000000000" });
      await expect(auction.connect(bidderOne).withdraw()).to.be.revertedWith(
        "BidIsStillActive()"
      );
      await network.provider.send("evm_increaseTime", [86400]);
      await network.provider.request({ method: "evm_mine", params: [] });
      await auction.connect(bidderOne).withdraw();
      await auction.connect(bidderTwo).claim();
    });
    it("claim", async () => {
      await token.connect(seller).setApprovalForAll(auction.address, true);
      await auction.connect(seller).startBid();
      await auction
        .connect(bidderOne)
        .placeBid({ value: "50000000000000000000" });
      await auction
        .connect(bidderTwo)
        .placeBid({ value: "60000000000000000000" });
      await auction
        .connect(bidderOne)
        .placeBid({ value: "11000000000000000000" });
      await network.provider.send("evm_increaseTime", [86400]);
      await network.provider.request({ method: "evm_mine", params: [] });
      await expect(auction.connect(bidderTwo).claim()).to.be.revertedWith(
        "YouAreNotAllowedToClaim()"
      );
      await auction.connect(bidderOne).claim();
    });
    it("claim address(0)", async () => {
      await token.connect(seller).setApprovalForAll(auction.address, true);
      await auction.connect(seller).startBid();
      await network.provider.send("evm_increaseTime", [86400]);
      await network.provider.request({ method: "evm_mine", params: [] });
      await expect(auction.connect(bidderTwo).claim()).to.be.revertedWith(
        "YouAreNotAllowedToClaim()"
      );
    });
  });
});

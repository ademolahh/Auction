const { ethers } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { log, deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const token = await ethers.getContract("TestERC1155");

  const args = [token.address, 1, 1];
  const nft = await deploy("EnglishAuction", {
    from: deployer,
    log: true,
    args,
  });
  log(nft.address);
};

module.exports.tags = ["all", "EA"];

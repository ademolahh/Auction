module.exports = async ({ getNamedAccounts, deployments }) => {
  const { log, deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const nft = await deploy("TestERC1155", {
    from: deployer,
    log: true,
    args: [],
  });
  log(nft.address);
};

module.exports.tags = ["all", "test"];

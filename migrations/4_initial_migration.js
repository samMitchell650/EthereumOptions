const ETHPutOption = artifacts.require("ETHPutOption");

module.exports = function(deployer) {
  deployer.deploy(ETHPutOption);
};

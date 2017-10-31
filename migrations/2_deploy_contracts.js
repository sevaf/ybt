var SafeMath = artifacts.require("./math/SafeMath.sol");
var YBTToken = artifacts.require("./token/YBTToken.sol");

module.exports = function(deployer) {
  deployer.deploy(SafeMath);
  deployer.link(SafeMath, YBTToken);
  deployer.deploy(YBTToken, 'YourBit Token', 'YBT', 1000000000000000000000, 18, true, true);
};

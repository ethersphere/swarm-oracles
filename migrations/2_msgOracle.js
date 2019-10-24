const MsgOracle = artifacts.require("MsgOracle");

const initialTTL = 60
module.exports = function(deployer) {
    deployer.deploy(MsgOracle, initialTTL)
}

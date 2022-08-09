const { network } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");
const BASE_FEE = ethers.utils.parseEther("0.25"); //The base fee in LINK
const GAS_PRICE_LINK = 1e9; // (== 1000000000) Calculated value base on the gas price of the transaction

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments;
    const { deployer } = await getNamedAccounts();

    if (developmentChains.includes(network.name)) {
        log("Local network detected - using mocks");
        await deploy("VRFCoordinatorV2Mock", {
            contract: "VRFCoordinatorV2Mock",
            from: deployer,
            args: [BASE_FEE, GAS_PRICE_LINK],
            log: true,
        });
        log("Mock deployed!");
        log("----------------------------------------------------");
    }
};

module.exports.tags = ["all", "mocks"];

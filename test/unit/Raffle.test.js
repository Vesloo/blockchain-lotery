const { assert } = require("chai");
const { getNamedAccounts, ethers } = require("hardhat");
const {
    developmentChains,
    networkConfig,
} = require("../../helper-hardhat-config");

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Raffle", async () => {
          let raffle;
          let mockV2Coordinator;
          const chainId = network.config.chainId;
          const sendValue = ethers.utils.parseEther("0.01");

          beforeEach(async () => {
              const deployer = (await getNamedAccounts()).deployer;
              await deployments.fixture(["all"]);
              raffle = await ethers.getContract("Raffle", deployer);
              mockV2Coordinator = await ethers.getContract(
                  "VRFCoordinatorV2Mock",
                  deployer
              );
          });

          describe("constructor", async () => {
              it("Initializes the raffle correctly", async () => {
                  const raffleState = await raffle.getRaffleState();
                  const interval = await raffle.getInterval();
                  const entranceFee = await raffle.getEntranceFee();
                  const gasLane = await raffle.getGasLane();
                  const callbackGasLimit = await raffle.getCallbackGasLimit();

                  assert.equal(raffleState.toString(), "0");
                  assert.equal(
                      interval.toString(),
                      networkConfig[chainId]["interval"]
                  );
                  assert.equal(
                      entranceFee.toString(),
                      networkConfig[chainId]["entranceFee"]
                  );
                  assert.equal(
                      gasLane.toString(),
                      networkConfig[chainId]["gasLane"]
                  );
                  assert.equal(
                      callbackGasLimit.toString(),
                      networkConfig[chainId]["callbackGasLimit"]
                  );
              });
          });
          //   it("Should enter the raffle if the player pay 0.01 minimum", async () => {
          //       await raffle.enterRaffle({ value: sendValue });
          //       const response = await raffle.getAddressToAmountFunded(deployer);
          //       assert.equal(sendValue.toString(), response.toString());
          //   });
      });

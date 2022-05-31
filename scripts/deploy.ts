// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const FlowInsightERC721NFT = await ethers.getContractFactory("FlowInsightERC721NFT");
  const flowInsightERC721NFT = await FlowInsightERC721NFT.deploy("FlowInsight", "FI");
  await flowInsightERC721NFT.deployed();
  console.log("FlowInsightERC721NFT deployed to:", flowInsightERC721NFT.address);

  let [deployer] = await ethers.getSigners();
  const FlowInsightVault = await ethers.getContractFactory("FlowInsightVault");
  const flowInsightVault = await FlowInsightVault.deploy(deployer.address, deployer.address, 0, 0, deployer.address, 0);
  await flowInsightVault.deployed();
  console.log("FlowInsightVault deployed to:", flowInsightVault.address);

  const FlowInsightMarketplace = await ethers.getContractFactory("FlowInsightMarketplace");
  const flowInsightMarketplace = await FlowInsightMarketplace.deploy(flowInsightVault.address, flowInsightERC721NFT.address);
  await flowInsightMarketplace.deployed();
  console.log("FlowInsightMarketplace deployed to:", flowInsightMarketplace.address);

  await flowInsightERC721NFT.setMarketplace(flowInsightMarketplace.address, true);
  await flowInsightVault.authorizeMarketplace(flowInsightMarketplace.address, true);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

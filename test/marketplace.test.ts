import { expect } from 'chai';
import { ethers } from 'hardhat';
import { BigNumber, Contract, ContractFactory, utils } from 'ethers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address';

import { getGasFeeFromTx } from './utils';

const { provider } = ethers;
const getBalance = provider.getBalance;

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";


describe('Marketplace Contract', () => {

  let deployer: SignerWithAddress;
  let owner: SignerWithAddress;
  let buyer: SignerWithAddress;
  let other: SignerWithAddress;

  let FlowInsightERC721NFT: ContractFactory;
  let flowInsightERC721NFT: Contract;
  let FlowInsightVault: ContractFactory;
  let flowInsightVault: Contract;
  let FlowInsightMarketplace: ContractFactory;
  let flowInsightMarketplace: Contract;

  let nftId: BigNumber;

  before(async () => {
    [deployer, owner, buyer, other] = await ethers.getSigners();

    FlowInsightERC721NFT = await ethers.getContractFactory('FlowInsightERC721NFT');
    flowInsightERC721NFT = await FlowInsightERC721NFT.connect(deployer).deploy('FlowInsight', 'FI');
    await flowInsightERC721NFT.deployed();
    console.log("FlowInsightERC721NFT deployed to: ", flowInsightERC721NFT.address);

    FlowInsightVault = await ethers.getContractFactory('FlowInsightVault');
    flowInsightVault = await FlowInsightVault.connect(deployer).deploy(deployer.address, deployer.address, 0, 0, deployer.address, 0);
    await flowInsightVault.deployed();
    console.log("FlowInsightVault deployed to: ", flowInsightVault.address);

    FlowInsightMarketplace = await ethers.getContractFactory('FlowInsightMarketplace');
    flowInsightMarketplace = await FlowInsightMarketplace.connect(deployer).deploy(flowInsightVault.address, flowInsightERC721NFT.address);
    await flowInsightMarketplace.deployed();
    console.log("FlowInsightMarketplace deployed to: ", flowInsightMarketplace.address);

    // set marketplace
    await flowInsightERC721NFT.setMarketplace(flowInsightMarketplace.address, true);
    await flowInsightVault.authorizeMarketplace(flowInsightMarketplace.address, true);
    // create test NFT
    await flowInsightERC721NFT.createNFT(owner.address, 'testNFT', 'testNFT', '', [], '', '');
    nftId = (await flowInsightERC721NFT.getTotalSupply()).sub(1);
  });

  describe('Trade Test', () => {

    describe('Owner Register NFT Sale', () => {
      it('approves vault to transfer NFT', async () => {
        await expect(flowInsightMarketplace.connect(owner).registerNFTSale(nftId))
          .to.emit(flowInsightERC721NFT, 'Approval');
      });
  
      it('fails when not owner', async () => {
        await expect(flowInsightMarketplace.connect(other).registerNFTSale(nftId))
          .to.revertedWith('not NFT owner');
      });
    });
  
    describe('Buyer Make Offer', () => {
      it('makes offer with ETH', async () => {
        const vaultBalanceBefore = await getBalance(flowInsightVault.address);      
        expect(utils.formatEther(vaultBalanceBefore)).to.equal('0.0');
  
        await expect(flowInsightMarketplace.connect(buyer).makeOfferWithETH(nftId, {value: utils.parseEther('10')}))
          .to.emit(flowInsightMarketplace, 'PaymentCreated')
          .withArgs(0, owner.address, ZERO_ADDRESS, utils.parseEther('10'))
          .to.emit(flowInsightVault, 'PaymentAuthorized')
          .withArgs(0, owner.address, ZERO_ADDRESS, utils.parseEther('10'));
    
        const vaultBalanceAfter = await getBalance(flowInsightVault.address);
        expect(utils.formatEther(vaultBalanceAfter)).to.equal('10.0');
      });

      it('fails when purchase own NFT', async () => {
        await expect(flowInsightMarketplace.connect(owner).makeOfferWithETH(nftId, {value: utils.parseEther('10')}))
          .to.revertedWith('cannot purchase own NFT');
      });
  
      it('fails when purchase with zero NFT', async () => {
        await expect(flowInsightMarketplace.connect(buyer).makeOfferWithETH(nftId))
          .to.revertedWith('insufficient ETH');
      });
    });
    
    describe('Owner Confirm Trade', () => {
      it('confirms trade', async () => {
        // before trade
        expect(await getBalance(flowInsightVault.address)).to.equal(utils.parseEther('10'));
        const ownerBalanceBefore = await owner.getBalance();
        // do trade
        const tx = await flowInsightMarketplace.connect(owner).confirmTrade(nftId, 0);
        await expect(new Promise((resolve) => resolve(tx)))
          .to.emit(flowInsightMarketplace, 'TradeComfirmed')
          .withArgs(0, nftId, owner.address)
          .to.emit(flowInsightVault, 'PaymentExecuted')
          .withArgs(0, owner.address, ZERO_ADDRESS, utils.parseEther('10'));
  
        const gasFee = await getGasFeeFromTx(tx);
        // after trade
        expect(await getBalance(flowInsightVault.address)).to.equal(utils.parseEther('0'));
        const ownerBalanceAfter = await owner.getBalance();
        expect(ownerBalanceAfter.sub(ownerBalanceBefore).add(gasFee)).to.equal(utils.parseEther('10'));
      });
    });
  });
});

import { expect } from 'chai';
import { ethers } from 'hardhat';
import { Contract, ContractFactory, utils } from 'ethers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address';


describe('Vault Contract', () => {

  let deployer: SignerWithAddress;
  let owner: SignerWithAddress;
  let securityGuard: SignerWithAddress;
  let escapeHatchCaller: SignerWithAddress;
  let other: SignerWithAddress;
  let buyer: SignerWithAddress;
  let recipient: SignerWithAddress;

  let FlowInsightERC721NFT: ContractFactory;
  let flowInsightERC721NFT: Contract;
  let FlowInsightVault: ContractFactory;
  let flowInsightVault: Contract;
  let FlowInsightMarketplace: ContractFactory;
  let flowInsightMarketplace: Contract;

  before(async () => {
    [deployer, owner, securityGuard, escapeHatchCaller, other, buyer, recipient] = await ethers.getSigners();

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
  });

  describe('Authority Test', () => {

    describe('Only Owner', () => {

      describe('Set Owner', () => {
        it('changes owner', async () => {
          await expect(flowInsightVault.connect(deployer).changeOwner(owner.address))
            .to.emit(flowInsightVault, 'NewOwner')
            .withArgs(deployer.address, owner.address);
        });

        it('fails when not owner', async () => {
          await expect(flowInsightVault.connect(other).changeOwner(owner.address))
            .to.revertedWith('not owner');
        });
      });

      describe('Set Marketplace', () => {
        it('authorizes marketplace', async () => {
          await expect(flowInsightVault.connect(owner).authorizeMarketplace(flowInsightMarketplace.address, true))
            .to.emit(flowInsightVault, 'MarketplaceAuthorization')
            .withArgs(flowInsightMarketplace.address, true);
        });

        it('fails when not owner', async () => {
          await expect(flowInsightVault.connect(other).authorizeMarketplace(flowInsightMarketplace.address, false))
            .to.revertedWith('not owner');
        });
      });

      describe('Set Security Guard', () => {
        it('sets security guard', async () => {
          expect(await flowInsightVault.connect(owner).setSecurityGuard(securityGuard.address));
        });

        it('fails when not owner', async () => {
          await expect(flowInsightVault.connect(other).setSecurityGuard(securityGuard.address))
            .to.revertedWith('not owner');
        });
      });
    });

    describe('Only EscapeHatchCaller Or Owner', () => {

      describe('Set Escape Caller', () => {
        it('changes escape caller', async () => {
          expect(await flowInsightVault.connect(owner).changeEscapeCaller(escapeHatchCaller.address));
        });

        it('fails when not escapeHatchCaller or owner', async () => {
          await expect(flowInsightVault.connect(other).changeEscapeCaller(escapeHatchCaller.address))
            .to.revertedWith('not escape hatch caller or owner');
        });
      });

      describe('Escape Hatch', () => {
        it('escapes hatch', async () => {
          await expect(flowInsightVault.connect(escapeHatchCaller).escapeHatch())
            .to.emit(flowInsightVault, 'EscapeHatchCalled');
        });

        it('fails when not escapeHatchCaller or owner', async () => {
          await expect(flowInsightVault.connect(other).escapeHatch())
            .to.revertedWith('not escape hatch caller or owner');
        });
      });

      describe('Query Number Of Authorized Payments', () => {
        it('views number of authorized payments', async () => {
          expect(flowInsightVault.connect(escapeHatchCaller).numberOfAuthorizedPayments());
        });

        it('fails when not escapeHatchCaller or owner', async () => {
          await expect(flowInsightVault.connect(other).numberOfAuthorizedPayments())
            .to.revertedWith('not escape hatch caller or owner');
        });
      });

      describe('Query Balances', () => {
        it('gets balances', async () => {
          expect(flowInsightVault.connect(escapeHatchCaller).getBalance());
        });

        it('fails when not escapeHatchCaller or owner', async () => {
          await expect(flowInsightVault.connect(other).getBalance())
            .to.revertedWith('not escape hatch caller or owner');
        });
      });
    });

    describe('Only Allowed Marketplace', () => {

      describe('Authorize Payment', () => {
        it('fails when not allowed marketplace', async () => {
          await expect(flowInsightVault.connect(other).authorizePayment(buyer.address, recipient.address, utils.parseEther('10'), 0))
            .to.revertedWith('not allowed marketplace');
        });
      });
   
      describe('Collect Authorized Payment', () => {
        it('fails when not allowed marketplace', async () => {
          await expect(flowInsightVault.connect(other).collectAuthorizedPayment(0))
            .to.revertedWith('not allowed marketplace');
        });
      });

      describe('Transfer NFT', () => {
        it('fails when not allowed marketplace', async () => {
          await expect(flowInsightVault.connect(other).transferNFT(0, 0, flowInsightERC721NFT.address))
            .to.revertedWith('not allowed marketplace');
        });
      });
    });
  });
});

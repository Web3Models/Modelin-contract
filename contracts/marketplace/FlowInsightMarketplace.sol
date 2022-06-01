// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { SafeMath } from "../lib/SafeMath.sol";
import { ContractGuard } from "../lib/ContractGuard.sol";
import { FlowInsightVault } from "../vault/FlowInsightVault.sol";
import { FlowInsightERC721NFT } from "../nft/FlowInsightERC721NFT.sol";

contract FlowInsightMarketplace is ContractGuard {
    using SafeMath for uint256;

    address payable private vault;
    address private flowInsightNFT;


    /* ========== Modifier ========== */

    modifier onlyNFTOwner(uint256 _nftId) {
        require(msg.sender == FlowInsightERC721NFT(flowInsightNFT).ownerOf(_nftId), "not NFT owner");
        _;
    }

    /* ========== CONSTRUCTOR ========== */

    constructor(address _vault, address _flowInsightNFT) {
        vault = payable(_vault);
        flowInsightNFT = _flowInsightNFT;
    }

    receive() external payable {
        assert(msg.sender == vault); // only accept ETH via fallback from the vault contract
    }

    /* ========== MUTABLE FUNCTIONS ========== */

    function registerNFTSale(uint256 _nftId) external onlyNFTOwner(_nftId) onlyOneBlock {
        // approve vault to transfer NFT
        FlowInsightERC721NFT(flowInsightNFT).approve(vault, _nftId);
    }

    function makeOfferWithETH(uint256 _nftId) external payable onlyOneBlock {
        require (msg.value > 0, "insufficient ETH");
        address owner = FlowInsightERC721NFT(flowInsightNFT).ownerOf(_nftId);
        require(msg.sender != owner, "cannot purchase own NFT");

        // create payment
        uint256 paymentId = FlowInsightVault(vault).authorizePayment(msg.sender, owner, msg.value, 0);
        // ETH send to vault
        FlowInsightVault(vault).receiveEther{value: msg.value}();

        emit PaymentCreated(paymentId, _nftId, msg.sender, address(0), msg.value);
    }

    function makeOfferWithToken(uint256 _nftId, uint256 _tokenAmount) external onlyOneBlock {
        // TODO
    }
    
    function confirmTrade(uint256 _nftId, uint256 _paymentId) external onlyNFTOwner(_nftId) onlyOneBlock {
        // do NFT transfer
        FlowInsightVault(vault).transferNFT(_nftId, _paymentId, flowInsightNFT);
        // ETH send to owner from vault
        FlowInsightVault(vault).collectAuthorizedPayment(_paymentId);

        emit TradeComfirmed(_paymentId, _nftId, msg.sender);
    }

    /* ========== EVENTS ========== */

    event PaymentCreated(
        uint256 indexed paymentId, 
        uint256 indexed nftId, 
        address buyer, 
        address token, 
        uint256 price
    );
    event TradeComfirmed(
        uint256 indexed paymentId, 
        uint256 indexed nftId,
        address owner
    );
}

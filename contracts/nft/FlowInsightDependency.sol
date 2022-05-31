// SPDX-License-Identifier: MIT
// Useful for letting FlowInsight NFT sale on a real-time public e-mall
pragma solidity >=0.8.0 <0.9.0;


import "./FlowInsightMarketplaceManager.sol";


contract FlowInsightDependency {

  address public whitelistSetterAddress;

  FlowInsightMarketplaceManager public marketplaceManager;

  mapping (address => bool) public whitelistedMarketplace;

  constructor() public {
    whitelistSetterAddress = msg.sender;
  }

  modifier onlyWhitelistSetter() {
    require(msg.sender == whitelistSetterAddress, "not a whitelist manager");
    _;
  }

  modifier whenTransferAllowed(address _from, address _to, uint256 _axieId) {
    require(
      address(marketplaceManager) == address(0) ||
        marketplaceManager.isTransferAllowed(_from, _to, _axieId)
    , "can not transfer");
    _;
  }

  modifier onlyMarketplace() {
    require(whitelistedMarketplace[msg.sender], "not in whitelist");
    _;
  }

  /*
   * @dev Setting the whitelist setter address to `address(0)` would be a irreversible process.
   *  This is to lock changes to AIMan's contracts after their development is done.
   */
  function setWhitelistSetter(address _newSetter) external onlyWhitelistSetter {
    whitelistSetterAddress = _newSetter;
  }

  function setMarketplaceManager(address _manager) external onlyWhitelistSetter {
    marketplaceManager = FlowInsightMarketplaceManager(_manager);
  }

  function setMarketplace(address _marketplace, bool _whitelisted) external onlyWhitelistSetter {
    require(whitelistedMarketplace[_marketplace] != _whitelisted, "Repeat setting");
    whitelistedMarketplace[_marketplace] = _whitelisted;
  }

}

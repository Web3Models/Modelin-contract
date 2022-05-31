// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../lib/SafeMath.sol";

import "./IERC721Base.sol";
import "./IERC721Enumerable.sol";
import "./IERC721TokenReceiver.sol";
import "./FlowInsightDependency.sol";
import "../lib/Ownable.sol";


contract FlowInsightERC721BaseEnumerable is IERC721Base, IERC721Enumerable, FlowInsightDependency, Ownable {
  using SafeMath for uint256;

  // @dev Total amount of tokens.
  uint256 private _totalTokens;

  // @dev Mapping from token index to ID.
  mapping (uint256 => uint256) private _overallTokenId;

  // @dev Mapping from token ID to index.
  mapping (uint256 => uint256) private _overallTokenIndex;

  // @dev Mapping from token ID to owner.
  mapping (uint256 => address) private _tokenOwner;

  // @dev For a given owner and a given operator, store whether
  //  the operator is allowed to manage tokens on behalf of the owner.
  mapping (address => mapping (address => bool)) private _tokenOperator;

  // @dev Mapping from token ID to approved address.
  mapping (uint256 => address) private _tokenApproval;

  // @dev Mapping from owner to list of owned token IDs.
  mapping (address => uint256[]) private _ownedTokens;

  // @dev Mapping from token ID to index in the owned token list.
  mapping (uint256 => uint256) private _ownedTokenIndex;

  constructor() public {
    // supportedInterfaces[0x6466353c] = true; // ERC-721 Base
    // supportedInterfaces[0x780e9d63] = true; // ERC-721 Enumerable
  }

  // solium-disable function-order

  modifier mustBeValidToken(uint256 _tokenId) {
    require(_tokenOwner[_tokenId] != address(0), "NFT ID has no ownership");
    _;
  }

  function _isTokenOwner(address _ownerToCheck, uint256 _tokenId) private view returns (bool) {
    return _tokenOwner[_tokenId] == _ownerToCheck;
  }

  function _isTokenOperator(address _operatorToCheck, uint256 _tokenId) private view returns (bool) {
    return whitelistedMarketplace[_operatorToCheck] ||
      _tokenOperator[_tokenOwner[_tokenId]][_operatorToCheck];
  }

  function _isApproved(address _approvedToCheck, uint256 _tokenId) private view returns (bool) {
    return _tokenApproval[_tokenId] == _approvedToCheck;
  }

  modifier onlyTokenOwner(uint256 _tokenId) {
    require(_isTokenOwner(msg.sender, _tokenId), "not NFT ID owner");
    _;
  }

  modifier onlyTokenOwnerOrOperator(uint256 _tokenId) {
    require(_isTokenOwner(msg.sender, _tokenId) || _isTokenOperator(msg.sender, _tokenId), "not NFT ID owner or agent");
    _;
  }

  modifier onlyTokenAuthorized(uint256 _tokenId) {
    require(
      // solium-disable operator-whitespace
      _isTokenOwner(msg.sender, _tokenId) ||
        _isTokenOperator(msg.sender, _tokenId) ||
        _isApproved(msg.sender, _tokenId)
      // solium-enable operator-whitespace
    , "not NFT ID owner or agent or authorized user");
    _;
  }

  // ERC-721 Base

  function balanceOf(address _owner) override external view returns (uint256) {
    require(_owner != address(0), "invalid user address");
    return _ownedTokens[_owner].length;
  }

  function ownerOf(uint256 _tokenId) override external view mustBeValidToken(_tokenId) returns (address) {
    return _tokenOwner[_tokenId];
  }

  function _addTokenTo(address _to, uint256 _tokenId) private {
    require(_to != address(0), "invalid address");

    _tokenOwner[_tokenId] = _to;

    uint256 length = _ownedTokens[_to].length;
    _ownedTokens[_to].push(_tokenId);
    _ownedTokenIndex[_tokenId] = length;
  }

  function _mint(address _to, uint256 _tokenId) internal {
    require(_tokenOwner[_tokenId] == address(0), "NFT ID already has ownership");

    _addTokenTo(_to, _tokenId);

    _overallTokenId[_totalTokens] = _tokenId;
    _overallTokenIndex[_tokenId] = _totalTokens;
    _totalTokens = _totalTokens.add(1);

    emit Transfer(address(0), _to, _tokenId);
  }

  function _removeTokenFrom(address _from, uint256 _tokenId) private {
    require(_from != address(0), "invalid address");

    uint256 _tokenIndex = _ownedTokenIndex[_tokenId];
    uint256 _lastTokenIndex = _ownedTokens[_from].length.sub(1);
    uint256 _lastTokenId = _ownedTokens[_from][_lastTokenIndex];

    _tokenOwner[_tokenId] = address(0);

    // Insert the last token into the position previously occupied by the removed token.
    _ownedTokens[_from][_tokenIndex] = _lastTokenId;
    _ownedTokenIndex[_lastTokenId] = _tokenIndex;

    // Resize the array.
    // delete _ownedTokens[_from][_lastTokenIndex];
    _ownedTokens[_from].pop();

    // Remove the array if no more tokens are owned to prevent pollution.
    if (_ownedTokens[_from].length == 0) {
      delete _ownedTokens[_from];
    }

    // Update the index of the removed token.
    delete _ownedTokenIndex[_tokenId];
  }

  function _burn(uint256 _tokenId) internal {
    address _from = _tokenOwner[_tokenId];

    require(_from != address(0), "NFT ID has no ownership");

    _removeTokenFrom(_from, _tokenId);
    _totalTokens = _totalTokens.sub(1);

    uint256 _tokenIndex = _overallTokenIndex[_tokenId];
    uint256 _lastTokenId = _overallTokenId[_totalTokens];

    delete _overallTokenIndex[_tokenId];
    delete _overallTokenId[_totalTokens];
    _overallTokenId[_tokenIndex] = _lastTokenId;
    _overallTokenIndex[_lastTokenId] = _tokenIndex;

    emit Transfer(_from, address(0), _tokenId);
  }

  function _isContract(address _address) public view returns (bool) {
    uint _size;
    // solium-disable-next-line security/no-inline-assembly
    assembly { _size := extcodesize(_address) }
    return _size > 0;
  }

  function _transferFrom(
    address _from,
    address _to,
    uint256 _tokenId,
    bytes memory _data,
    bool _check
  )
    internal
    mustBeValidToken(_tokenId)
    // onlyTokenAuthorized(_tokenId)
    // whenTransferAllowed(_from, _to, _tokenId)
  {
    require(_isTokenOwner(_from, _tokenId), "not NFT ID owner");
    require(_to != address(0), "invalid address");
    require(_to != _from, "to address is the same as from address");

    _removeTokenFrom(_from, _tokenId);

    delete _tokenApproval[_tokenId];
    emit Approval(_from, address(0), _tokenId);

    _addTokenTo(_to, _tokenId);

    if (_check && _isContract(_to)) {
      IERC721TokenReceiver(_to).onERC721Received{gas:50000}(msg.sender,_from, _tokenId, _data);
    }

    emit Transfer(_from, _to, _tokenId);
  }

  // solium-disable arg-overflow

  function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data) override external payable {
    _transferFrom(_from, _to, _tokenId, _data, true);
  }

  function safeTransferFrom(address _from, address _to, uint256 _tokenId) override external payable {
    _transferFrom(_from, _to, _tokenId, "", true);
  }

  function transferFrom(address _from, address _to, uint256 _tokenId) override external payable {
    _transferFrom(_from, _to, _tokenId, "", false);
  }

  // solium-enable arg-overflow

  function approve(
    address _approved,
    uint256 _tokenId
  )
    override
    external
    payable
    mustBeValidToken(_tokenId)
    onlyTokenOwnerOrOperator(_tokenId)
  {
    address _owner = _tokenOwner[_tokenId];

    require(_owner != _approved, "already owner of NFT ID");
    require(_tokenApproval[_tokenId] != _approved, "already authorized user of NFT ID");

    _tokenApproval[_tokenId] = _approved;

    emit Approval(_owner, _approved, _tokenId);
  }

  function setApprovalForAll(address _operator, bool _approved) override external {
    require(_tokenOperator[msg.sender][_operator] != _approved, "the agent has been set up");
    _tokenOperator[msg.sender][_operator] = _approved;
    emit ApprovalForAll(msg.sender, _operator, _approved);
  }

  function getApproved(uint256 _tokenId) override external view mustBeValidToken(_tokenId) returns (address) {
    return _tokenApproval[_tokenId];
  }

  function isApprovedForAll(address _owner, address _operator) override external view returns (bool) {
    return _tokenOperator[_owner][_operator];
  }

  // ERC-721 Enumerable

  function totalSupply() override external view returns (uint256) {
    return _totalTokens;
  }

  function tokenByIndex(uint256 _index) override external view returns (uint256) {
    require(_index < _totalTokens, "invalid Token index");
    return _overallTokenId[_index];
  }

  function tokenOfOwnerByIndex(address _owner, uint256 _index) override external view returns (uint256 _tokenId) {
    require(_owner != address(0), "invalid owner address");
    require(_index < _ownedTokens[_owner].length, "invalid Token index");
    return _ownedTokens[_owner][_index];
  }

  // utils
  function ownedTokens(address _owner) public view returns (uint256[] memory) 
  {
    require(_owner != address(0), "invalid owner address");
    return _ownedTokens[_owner];
  } 

  function getTotalSupply() public view returns (uint256) {
    return _totalTokens;
  }
}
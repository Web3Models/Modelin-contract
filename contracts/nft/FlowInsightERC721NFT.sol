// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../lib/SafeMath.sol";

import "./FlowInsightERC721BaseEnumerable.sol";
import "./FlowInsightERC721NFTMetadata.sol";

// solium-disable-next-line no-empty-blocks
contract FlowInsightERC721NFT is FlowInsightERC721BaseEnumerable, FlowInsightERC721NFTMetadata {

    using SafeMath for uint256;

    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);
    event NFTCreated(
        uint256 indexed nft_id,
        address indexed owner
    );
    event UpdateKey(string key);
    struct FlowInsightNFT {
        string name;
        string picURL;
        string desc;
        string[] property;
        string key;
        string privURL;
    }

    FlowInsightNFT[] FlowInsight;
    mapping (address => bool) minter;
    mapping (uint8 => uint256[]) creatingNFT;

    constructor (
        string memory _nftName,
        string memory _nftSymbol
    ) public
    {
        nftName = _nftName;
        nftSymbol = _nftSymbol;

    }

    function addMinter(address account) public onlyOwner {
        _addMinter(account);
    }

    function _addMinter(address account) internal {
        require(account != address(0), "invalid address");
        require(!minter[account], "already minter of NFT");

        minter[account] = true;

        emit MinterAdded(account);
    }

    function removeMinter(address account) public onlyOwner {
        _removeMinter(account);
    }

    function _removeMinter(address account) internal {
        require(account != address(0), "invalid address");
        require(minter[account], "not the minter of NFT");

        minter[account] = false;

        emit MinterRemoved(account);
    }

    modifier onlyMinter() {
        require(minter[msg.sender], "not the minter of NFT");
        _;
    }

    function isMinter(address account) public view returns (bool) {
        require(account != address(0), "invalid address");
        bool accountIsMinter = minter[account];
        return accountIsMinter;
    }

    function getNFTMetadata (uint256 _tokenId) 
        public view 
        returns (FlowInsightNFT memory)
    {
        return FlowInsight[_tokenId];
    }

    // When someone buy this NFT, mint one for him
    // Add modifier on-sale or off-sale
    function createNFT(address _to, string memory _name, string memory _picURL, string memory _desc, string[] memory _property, string memory _key, string memory _privURL) public returns (uint256 _FlowInsightId)
    {

        FlowInsightNFT memory _FlowInsight = FlowInsightNFT(_name, _picURL, _desc, _property, _key, _privURL);
        FlowInsight.push(_FlowInsight);
        _FlowInsightId = FlowInsight.length.sub(1);
        _mint(_to, _FlowInsightId);
        // _setTokenUri(_FlowInsightId, _tokenURI);

        emit NFTCreated(_FlowInsightId, _to);

        return _FlowInsightId;
    }

    // Update AES key
    function updateKey(uint256 _tokenId, string memory _key) public returns (uint flag){
        FlowInsight[_tokenId].key = _key;
        return 1;
    }
}
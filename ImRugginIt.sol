// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../ParentContract/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract ImRugginIt is ERC721A, Ownable, ReentrancyGuard {
    using Strings for uint256;

    address public immutable proxyRegistryAddress = address(0xF57B2c51dED3A29e6891aba85459d600256Cf317);
    //Rinkeby: 0xF57B2c51dED3A29e6891aba85459d600256Cf317
    //Mainnet: 0xa5409ec958C83C3f309868babACA7c86DCB077c1

    string public Uri = "";
    string public HiddenUri = "Okay";

    uint256 public pubSale = 1672;
    uint256 public MaxSupply = 2022;
    uint256 public cost = 0.01 ether;

    bytes32 public MerkleRoot;

    bool public Paused = true;
    bool public Revealed = false;
    bool public PubSale = true;

    mapping(address => bool) public FreeMint;
    
    constructor() ERC721A("I'm Ruggin' It", "IRI") {
        _safeMint(msg.sender, 1);
    }

    function mint(bytes32[] memory proof, uint256 _mintAmount) external payable nonReentrant {
        require(!Paused);

        if (PubSale) {
            require(_mintAmount > 0 && _mintAmount < 11, "You can't rug the ruggers.");
            require(msg.value > cost * _mintAmount - 1, "Insufficient funds");
            require(totalSupply() + _mintAmount < pubSale+1);
        }
        else {
            require(_mintAmount == 1);
            require(msg.value > cost - 1, "Insufficient funds");
            require(FreeMint[msg.sender] == false);
            require(totalSupply() + _mintAmount < MaxSupply+1);
            require(MerkleProof.verify(proof, MerkleRoot, keccak256(abi.encodePacked(msg.sender))), "Cringe.");
            FreeMint[msg.sender] = true;
        }
        _safeMint(msg.sender, _mintAmount);
    }
    
    //view
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        if(!Revealed) {
            return HiddenUri;
        }

        string memory baseURI = _baseURI();
        return bytes(baseURI).length != 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : ".json";
    }

    //set
    function setMaxSupply(uint256 _MaxSupply) external onlyOwner {
        MaxSupply = _MaxSupply;
    }

    function setUri(string memory _Uri) external onlyOwner {
        Uri = _Uri;
    }

    function setHiddenUri(string memory _HiddenUri) external onlyOwner {
        HiddenUri = _HiddenUri;
    }

    function setMerkleRoot(bytes32 _MerkleRoot) external onlyOwner {
        MerkleRoot = _MerkleRoot;
    }

    function setPaused(bool _Paused) external onlyOwner {
        Paused = _Paused;
    }

    function setRevealed(bool _Revealed) external onlyOwner {
        Revealed = _Revealed;
    }

    //withdraw
    function withdraw() external payable onlyOwner { 
        address ad1;
        address ad2;

        (bool ys, ) = payable(ad1).call{value: address(this).balance*35/100}("");
        require(ys);

        (bool os, ) = payable(ad2).call{value: address(this).balance}("");
        require(os);
     
    }

    //OpenSea Proxy Approval
    function isApprovedForAll(address _owner, address operator) public view override returns (bool) {
        OpenSeaProxyRegistry proxyRegistry = OpenSeaProxyRegistry(proxyRegistryAddress);
        if(address(proxyRegistry.proxies(_owner)) == operator) {
            return true;
        }
        return super.isApprovedForAll(_owner, operator);
    }
}

contract OwnableDelegateProxy {}
contract OpenSeaProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract Aotaverse is ERC721, Ownable, ReentrancyGuard {
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private supply;

    string private uriPrefix = ""; //ipfs://-CID-/  ///OKAY
    string public hiddenMetadataUri;

    uint256 private cost = 0.12 ether; 
    uint256 public maxSupply = 6666; //6666         ///OKAY
    uint256 public softCap = 6397; //6397           ///OKAY
    uint256 public constant maxMintAmountPerTx = 2;
    uint256 private mode = 1; 

    bool public paused = true; ///OKAY
    bool public revealed = false;

    bytes32 public merkleRoot = 0xc1ba3879f772a545a6cf9b5b67ac504b771d233b9a8ff1dbc25c8bbfa6fa3fbd;

    mapping(address => uint256) public ClaimedWhitelist;
    mapping(address => uint256) public ClaimedMeka;

    address public immutable proxyRegistryAddress = address(0xa5409ec958C83C3f309868babACA7c86DCB077c1); ///OKAY
    //Rinkeby: 0xF57B2c51dED3A29e6891aba85459d600256Cf317
    //Mainnet: 0xa5409ec958C83C3f309868babACA7c86DCB077c1

    address private constant withdrawTo = 0xFe5c087fD87891cA23AB98904d65A92D15A07D45; //funds reserve address ALSO owner ///OKAY

    constructor() ERC721("Aotaverse", "AOTA") ReentrancyGuard() {
        setHiddenMetadataUri("ipfs://QmSmhmLBBWhL12S9UsF4LAPKhtWdVfbj3Y6ByRRB2fc9ie/blind.json"); //blind box
        supply.increment();
        _safeMint(msg.sender, supply.current()); 
    }

    //MODIFIERS
    modifier mintCompliance(uint256 _mintAmount) {
        require(_mintAmount > 0 && _mintAmount < maxMintAmountPerTx+1, "Invalid mint amount");
        require(supply.current() + _mintAmount < softCap+1, "Exceeds Soft Cap");
        _;
    }

    //PAYABLE MINTS
    function mint(bytes32[] memory proof, uint256 _mintAmount) public payable mintCompliance(_mintAmount) nonReentrant {
        require(!paused, "The contract is paused!");
        require(msg.value > cost * _mintAmount -1, "Insufficient funds");
        require(mode != 4, "Mode is post-sale");

        
        if(mode == 1) {
            require(ClaimedMeka[msg.sender] + _mintAmount < 3, "Exceeds meka allowance");
        }
        else if(mode == 2) {
            require(ClaimedWhitelist[msg.sender] + _mintAmount < 3, "Exceeds whitelist allowance");
        }

        if(mode != 3) {
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            require(MerkleProof.verify(proof, merkleRoot, leaf), "Verification failed");
        }  

        if (mode == 1) {
            ClaimedMeka[msg.sender] += _mintAmount;
        }
        else if(mode == 2) {
            ClaimedWhitelist[msg.sender] += _mintAmount;
        }

        _mintLoop(msg.sender, _mintAmount); 
    }

    function mintForAddress(uint256 _mintAmount, address _receiver) public onlyOwner nonReentrant { //ONLY USED TO DISTRIBUTE TO INVESTORS
        require(mode == 4, "Mode is not post-sale"); //Function will only work if mode is set to 4 (post sale)
        require(supply.current() + _mintAmount < maxSupply + 1);
        _mintLoop(_receiver, _mintAmount);
    }

    //VIEWS
    function walletOfOwner(address _owner) public view returns (uint256[] memory) { //pass
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
        uint256 currentTokenId = 1;
        uint256 ownedTokenIndex = 0;

        while (ownedTokenIndex < ownerTokenCount && currentTokenId <= maxSupply) {
            address currentTokenOwner = ownerOf(currentTokenId);

            if (currentTokenOwner == _owner) {
                ownedTokenIds[ownedTokenIndex] = currentTokenId;
                ownedTokenIndex++;
            }
            currentTokenId++;
        }
        return ownedTokenIds;
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) { //pass
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");

        if (revealed == false) {
            return hiddenMetadataUri;
        }

        return bytes(uriPrefix).length > 0
            ? string(abi.encodePacked(uriPrefix, _tokenId.toString(), ".json"))
            : "";
    }

    function totalSupply() public view returns (uint256) { //pass
        return supply.current();
    }

    function getMode() public view returns (uint256) { //pass
        return mode;
    }

    function getCost() public view returns (uint256) { //pass
        return cost;
    }

    //ONLY OWNER SET

    function setMaxSupply(uint256 _MS) public onlyOwner { //pass
        require(_MS > maxSupply, "New MS below previous MS");
        maxSupply = _MS;
    }

    function setSoftCap(uint256 _SC) public onlyOwner { //pass
        require(_SC > softCap, "New SC below previous SC");
        softCap = _SC;
    }

    function togglemode() public onlyOwner { //pass
        if(mode == 1) {
            mode = 2;
            cost = 0.15 ether;
            merkleRoot = 0x5de192325d5f8d30a297ea7bc7431dc29f05b8109ede40e7a270739e94a31eab;
        }
        else if(mode == 2) {
            mode = 3;
            cost = 0.2 ether;
            merkleRoot = bytes32(0x00);
        }
        else if (mode == 3) {
            mode = 4; 
            cost = 0 ether;
        }
        else {
            mode = 1;
            cost = 0.12 ether;
        }
    }
    
    function setRevealed(bool _state) public onlyOwner { //pass
        revealed = _state;
    }

    function setCost(uint256 _newCost) public onlyOwner { //pass wei   //pass
        require(_newCost > 0);
        cost = _newCost;
    }

    function setHiddenMetadataUri(string memory _hiddenMetadataUri) public onlyOwner { //pass
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    function setUriPrefix(string memory _uriPrefix) public onlyOwner { //ipfs://-CID-/    //pass
        uriPrefix = _uriPrefix;
    }

    function setPaused(bool _state) public onlyOwner { //pass
        paused = _state;
    }

    function _mintLoop(address _receiver, uint256 _mintAmount) internal { //pass
        for (uint256 i = 0; i < _mintAmount; i++) {
            supply.increment();
            _safeMint(_receiver, supply.current());
        }
    }

    function withdraw() public payable onlyOwner { //pass
        (bool os, ) = payable(withdrawTo).call{value: address(this).balance}("");
        require(os);
    }

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

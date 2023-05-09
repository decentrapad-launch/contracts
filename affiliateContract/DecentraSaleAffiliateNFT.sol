// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract DecentraSaleAffiliateNFT is ERC721, Pausable, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private tokenId;

    string private baseUriExtended;
    address private signer;
    uint256 public mintPrice;

    // mapping to store the minted addresses
    mapping(address => bool) public alreadyMinted;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _mintPrice,
        string memory _uri
    ) ERC721(_name, _symbol) {
        mintPrice = _mintPrice;
        baseUriExtended = _uri;
    }

    /*
     * mint nft to msg.sender address (caller of function)
     * cannot mint more than 1 nft on an address
     * at the call time total supply should be less than max supply
     * Requirements:
     * '_signature' as an argument
     * Must verify the signature
     */

    function mint(bytes memory _signature) external payable whenNotPaused {
        require(msg.value == mintPrice, "Invalid Price Sent");
        require(verify(signer, msg.sender, _signature), "Invalid signature");
        require(!alreadyMinted[msg.sender], "Already minted");

        tokenId.increment();
        _mint(msg.sender, tokenId.current());
        alreadyMinted[msg.sender] = true;
    }

    /*
     * only owner can set the Uri
     * Requirements:
     * '_baseUri' length should be greater than 0
     */

    function setBaseUri(string memory _baseUri) external onlyOwner {
        require(bytes(_baseUri).length > 0, "Empty Uri not allowed");
        baseUriExtended = _baseUri;
    }

    /*
     * only owner can set the mint price
     */

    function setMintPrice(uint256 _newPrice) external onlyOwner {
        mintPrice = _newPrice;
    }

    /*
     * only owner can set the _signer
     * Requirements:
     * '_signer' should not be a zero address
     */

    function setSigner(address _signer) external onlyOwner {
        require(_signer != address(0), "Signer can't be address(0)");
        signer = _signer;
    }

    /*
     * returns the Base Uri
     */

    function getBaseUri() external view returns (string memory) {
        return baseUriExtended;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseUriExtended;
    }

    /*
     * returns the total number of minted nfts
     */

    function totalSupply() external view returns (uint256) {
        return tokenId.current();
    }

    /*
     * returns the address of the signer
     */

    function getSigner() external view returns (address) {
        return signer;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getMessageHash(address _to) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_to));
    }

    function getEthSignedMessageHash(
        bytes32 _messageHash
    ) private pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }

    function verify(
        address _signer,
        address _to,
        bytes memory signature
    ) private pure returns (bool) {
        bytes32 messageHash = getMessageHash(_to);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        return recoverSigner(ethSignedMessageHash, signature) == _signer;
    }

    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) private pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) private pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}

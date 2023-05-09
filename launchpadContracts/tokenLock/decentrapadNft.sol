// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract DecentrapadLockNFT is ERC721, AccessControl {
    using Strings for uint256;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    string private baseUriExtended;
    uint256 _tokenId;

    constructor() ERC721("DecentrapadLock NFT ", "DPLN") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(address user, uint256 id) external onlyRole(MINTER_ROLE) {
        _mint(user, id);
    }

    function batchMint(
        address[] memory users,
        uint256[] memory ids
    ) external onlyRole(MINTER_ROLE) {
        require(users.length == ids.length, "DecentrapadLock: Invalid length");
        for (uint256 indx = 0; indx < users.length; indx++) {
            _mint(users[indx], ids[indx]);
        }
    }

    function totalSupply() external view returns (uint256) {
        return _tokenId;
    }

    function setBaseURI(string memory baseURI) external {
        require(bytes(baseURI).length > 0, "Cannot be null");
        baseUriExtended = baseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseUriExtended;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControl, ERC721) returns (bool) {
        return
            interfaceId == type(AccessControl).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}

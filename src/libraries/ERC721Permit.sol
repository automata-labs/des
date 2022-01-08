// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";
import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";

import "../interfaces/IERC721Permit.sol";

/// @title ERC721 with permit
/// @notice Nonfungible tokens that support an approve via signature, i.e. permit
abstract contract ERC721Permit is ERC721, IERC721Permit {
    /// @dev Gets the current nonce for a token ID and then increments it, returning the original value
    function _getAndIncrementNonce(uint256 tokenId) internal virtual returns (uint256);

    /// @dev The hash of the name used in the permit signature verification
    bytes32 private immutable namehash;
    /// @dev The chain id that was set at deployment.
    uint256 internal immutable chainid_;
    /// @dev The domain separator that was set at deployment.
    bytes32 internal immutable domainseparator_;

    /// @notice Computes the namehash
    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {
        namehash = keccak256(bytes(name_));
        chainid_ = block.chainid;
        domainseparator_ = _domainseparator(block.chainid);
    }

    /// @notice Returns the permit typehash.
    function PERMIT_TYPEHASH() public pure returns (bytes32) {
        return keccak256("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)");
    }

    /// @inheritdoc IERC721Permit
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return block.chainid == chainid_ ? domainseparator_ : _domainseparator(block.chainid);
    }

    /// @dev Override function to change version.
    function version() public pure virtual returns(string memory) {
        return "1";
    }

    /// @inheritdoc IERC721Permit
    function permit(
        address spender,
        uint256 tokenId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable override {
        require(block.timestamp <= deadline, 'Permit expired');

        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH(),
                        spender,
                        tokenId,
                        _getAndIncrementNonce(tokenId),
                        deadline
                    )
                )
            )
        );
        address owner = ownerOf(tokenId);
        require(spender != owner, 'ERC721Permit: approval to current owner');

        if (Address.isContract(owner)) {
            require(IERC1271(owner).isValidSignature(digest, abi.encodePacked(r, s, v)) == 0x1626ba7e, 'Unauthorized');
        } else {
            address recoveredAddress = ecrecover(digest, v, r, s);
            require(recoveredAddress != address(0), 'Invalid signature');
            require(recoveredAddress == owner, 'Unauthorized');
        }

        _approve(spender, tokenId);
    }

    /// @dev Compute the DOMAIN_SEPARATOR.
    function _domainseparator(uint256 chainid) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                // keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')
                0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                namehash,
                keccak256(bytes(version())),
                chainid,
                address(this)
            )
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./libraries/Header.sol";
import "./libraries/Status.sol";

contract Registry {
    struct Data {
        address erc721;
        uint256 tokenId;
    }

    /// @dev The immutable runtime.
    address public immutable runtime;
    /// @dev The next transaction id.
    uint256 private _id;
    /// @dev All approved factories.
    address[] public nfts;
    /// @dev The mapping of all supported factories.
    mapping(address => bool) public approval;
    /// @dev The mapping of all supported factories.
    mapping(uint256 => Data) public registry;

    constructor(address runtime_) {
        runtime = runtime_;
    }

    function mint(address nft) external {
        require(approval[nft], "NotApproved");
    }
}

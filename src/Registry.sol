// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IProposer.sol";
import "./libraries/Cast.sol";
import "./libraries/Header.sol";
import "./libraries/Firewall.sol";
import "./libraries/Status.sol";

contract Registry is Firewall {
    using Cast for uint256;

    error UnauthorizedNFT();
    error InvalidStatus();

    struct Item {
        address nft; // erc721 token address
        uint96 id; // token id
    }

    /// @dev The immutable runtime.
    address public immutable runtime;
    /// @dev The next transaction id.
    uint256 private _rid;
    /// @dev The mapping of all approved nfts for the registry.
    mapping(address => bool) public approval;
    /// @dev The mapping of all proposals.
    mapping(uint256 => Item) public registry;
    /// @dev The mapping of all proposals.
    mapping(bytes32 => uint32) public instructions;

    constructor(address runtime_) {
        runtime = runtime_;
    }

    function approve(address nft, bool value) external auth {
        approval[nft] = value;
    }

    function create(
        address nft,
        address to,
        Header.Data memory header
    ) external returns (uint256 tid, uint256 rid) {
        if (approval[nft])
            revert UnauthorizedNFT();

        tid = IProposer(nft).mint(to, header);
        registry[(rid = _rid++)] = Item({
            nft: nft,
            id: tid.u96()
        });
    }

    function merge(uint256 rid) external {
        if (IProposer(registry[rid].nft).status(registry[rid].id) != Status.Approved)
            revert InvalidStatus();

        bytes32[] memory hashes = IProposer(registry[rid].nft).hashes(registry[rid].id);
        uint32 maturity = IProposer(registry[rid].nft).maturity(registry[rid].id);

        for (uint256 i = 0; i < hashes.length; i++) {
            instructions[hashes[i]] = maturity;
        }

        IProposer(registry[rid].nft).done(registry[rid].id);
    }

    function run(
        address[] calldata targets,
        uint256[] calldata values,
        string[] calldata signatures,
        bytes[] calldata datas,
        string calldata message,
        bytes32 prevHash
    ) external {
    }
}

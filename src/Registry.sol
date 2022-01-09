// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IProposer.sol";
import "./interfaces/IRuntime.sol";
import "./libraries/Cast.sol";
import "./libraries/Header.sol";
import "./libraries/Firewall.sol";
import "./libraries/Status.sol";
import "./libraries/Transaction.sol";

contract Registry is Firewall {
    using Cast for uint256;
    using Transaction for Transaction.Data;

    error UnauthorizedNFT();
    error InvalidStatus();
    error RunFailed();
    error Premature();

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

    function run(Transaction.Data memory txn, bytes32 prevHash) external {
        if (prevHash != bytes32(0) && instructions[prevHash] != 1)
            revert RunFailed();

        if (instructions[txn.hash(prevHash)] > _blockNumber())
            revert Premature();
        
        IRuntime(runtime).execute(txn.targets, txn.values, txn.calldatas(), txn.message);
        instructions[txn.hash(prevHash)] = 1;
    }

    function _blockNumber() internal view returns (uint32) {
        return uint32(block.number);
    }
}

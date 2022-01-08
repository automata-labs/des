// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ut-0/ERC20.sol";

import "./libraries/Pointer.sol";
import "./libraries/Checkpoint.sol";

contract Attest is ERC20 {
    using Checkpoint for Checkpoint.Data[];
    using Checkpoint for mapping(address => Checkpoint.Data[]);
    using Pointer for Pointer.Data[];
    using Pointer for mapping(address => Pointer.Data[]);

    error InvalidBlockNumber(uint32 blockNumber);

    /// @dev The delegation destination history.
    mapping(address => Pointer.Data[]) internal _pointerOf;
    /// @dev The delegation amount history.
    mapping(address => Checkpoint.Data[]) internal _checkpoints;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_, decimals_) {}

    function magnitude(address account) external view returns (uint256) {
        return _pointerOf[account].length;
    }

    /// @dev Returns the length of pointers and checkpoints.
    function cardinality(address account) external view returns (uint256) {
        return _checkpoints[account].length;
    }

    function pointerOf(address account) external view returns (address) {
        return _pointerOf[account].latest();
    }

    function pointerIn(address account, uint256 blockNumber) external view returns (address) {
        if (blockNumber <= block.number)
            return _pointerOf[account].lookup(blockNumber);
        else
            revert InvalidBlockNumber(uint32(blockNumber));
    }

    function pointerAt(
        address account,
        uint256 index
    ) external view returns (address, uint32, uint32) {
        require(index < _pointerOf[account].length, "OutOfBounds");
        Pointer.Data memory pointer = _pointerOf[account][index];
        return (pointer.value, pointer.startBlock, pointer.endBlock);
    }

    function weightOf(address account) external view returns (uint256) {
        return _checkpoints[account].latest();
    }

    function weightIn(address account, uint256 blockNumber) external view returns (uint256) {
        if (blockNumber <= block.number)
            return _checkpoints[account].lookup(blockNumber);
        else
            revert InvalidBlockNumber(uint32(blockNumber));
    }

    function weightAt(
        address account,
        uint256 index
    ) external view returns (uint160, uint32, uint32) {
        require(index < _checkpoints[account].length, "OutOfBounds");
        Checkpoint.Data memory checkpoint = _checkpoints[account][index];
        return (checkpoint.amount, checkpoint.startBlock, checkpoint.endBlock);
    }

    function mint(address to, uint256 amount) external returns (bool) {
        return _mint(to, amount);
    }

    function burn(address from, uint256 amount) external returns (bool) {
        return _burn(from, amount);
    }

    /// @dev Delegate voting rights to another account.
    function delegate(address to) external {
        _delegate(msg.sender, to);
    }

    function _delegate(address from, address to) internal {
        _checkpoints.move(_pointerOf[from].latest(), to, _balanceOf[from]);
        _pointerOf[from].save(to);
    }

    /// @dev Called on {mint}, {burn}, {transfer} and {transferFrom}.
    /// @dev Should be used to update when transferring shares to a delegated account.
    function _after(address from, address to, uint256 amount) internal override virtual {
        _checkpoints.move(_pointerOf[from].latest(), _pointerOf[to].latest(), amount);
    }
}

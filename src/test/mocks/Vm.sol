// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVm {
    /**
     * Cheatcodes
     */

    /// @dev Returns the cheatcode contract address.
    function vm() external view returns (IVm);

    /// @dev Sets `block.timestamp` to `x`.
    function warp(uint256 x) external;

    /// @dev Sets `block.number` to `x`.
    function roll(uint x) external;

    /// @dev Sets the slot `loc` of contract `c` to `val`.
    function store(address c, bytes32 loc, bytes32 val) external;

    /// @dev Reads the slot `loc` of contract `c`.
    function load(address c, bytes32 loc) external returns (bytes32);

    /// @dev Signs the `digest` using the private key `sk`. Note that signatures produced via `hevm.sign`
    ///     will leak the private key.
    function sign(uint sk, bytes32 digest) external returns (uint8 v, bytes32 r, bytes32 s);

    /// @dev Derives an ethereum address from the private key `sk`. Note that `hevm.addr(0)` will fail with
    ///     `BadCheatCode` as `0` is an invalid ECDSA private key.
    function addr(uint sk) external returns (address);

    /// @dev Executes the arguments as a command in the system shell and returns stdout. Note that this
    ///     cheatcode means test authors can execute arbitrary code on user machines as part of a call to
    ///     `dapp test`, for this reason all calls to `ffi` will fail unless the `--ffi` flag is passed.
    function ffi(string[] calldata data) external returns (bytes memory);

    /// @dev Sets an account's balance
    function deal(address who, uint256 amount) external;

    /// @dev Sets the contract code at some address contract code
    function etch(address where, bytes calldata what) external;

    /// @dev Sets the *next* call's msg.sender to be the input address
    function prank(address sender) external;

    /// @dev Sets all subsequent calls' msg.sender to be the input address until `stopPrank` is called
    function startPrank(address sender) external;

    /// @dev Resets subsequent calls' msg.sender to be `address(this)`
    function stopPrank() external;

    /// @dev Tells the evm to expect that the next call reverts with specified error bytes.
    function expectRevert(bytes calldata expectedError) external;

    /// @dev Expects the next emitted event. Params check topic 1, topic 2, topic 3 and data are the same.
    function expectEmit(bool x, bool y, bool z, bool w) external;

    /**
     * Extensions
     */

    /// @dev Increment `block.number` by `x`.
    function mine(uint256 x) external;

    /// @dev Increment `block.timestamp` by `x`.
    function timetravel(uint256 x) external;

    /// @dev Reset the `block.number` and `block.timestamp`.
    function reset() external;
}

contract Vm is IVm {
    /// @inheritdoc IVm
    IVm public vm = IVm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    /// @inheritdoc IVm
    function warp(uint256 x) public {
        vm.warp(x);
    }

    /// @inheritdoc IVm
    function roll(uint256 x) public {
        vm.roll(x);
    }

    /// @inheritdoc IVm
    function store(address c, bytes32 loc, bytes32 val) public {
        vm.store(c, loc, val);
    }

    /// @inheritdoc IVm
    function load(address c, bytes32 loc) public returns (bytes32) {
        return vm.load(c, loc);
    }

    /// @inheritdoc IVm
    function sign(uint sk, bytes32 digest) public returns (uint8 v, bytes32 r, bytes32 s) {
        (v, r, s) = vm.sign(sk, digest);
    }

    /// @inheritdoc IVm
    function addr(uint sk) public returns (address) {
        return vm.addr(sk);
    }

    /// @inheritdoc IVm
    function ffi(string[] calldata data) public returns (bytes memory) {
        return vm.ffi(data);
    }

    /// @inheritdoc IVm
    function deal(address who, uint256 amount) public {
        vm.deal(who, amount);
    }

    /// @inheritdoc IVm
    function etch(address where, bytes calldata what) public {
        vm.etch(where, what);
    }

    /// @inheritdoc IVm
    function prank(address sender) public {
        vm.prank(sender);
    }

    /// @inheritdoc IVm
    function startPrank(address sender) public {
        vm.startPrank(sender);
    }

    /// @inheritdoc IVm
    function stopPrank() public {
        vm.stopPrank();
    }

    /// @inheritdoc IVm
    function expectRevert(bytes memory expectedError) public {
        vm.expectRevert(expectedError);
    }

    /// @inheritdoc IVm
    function expectEmit(bool x, bool y, bool z, bool w) public {
        vm.expectEmit(x, y, z, w);
    }

    /// @inheritdoc IVm
    function mine(uint256 x) public {
        vm.roll(block.number + x);
    }

    /// @inheritdoc IVm
    function timetravel(uint256 x) public {
        vm.warp(block.timestamp + x);
    }

    /// @inheritdoc IVm
    function reset() public {
        vm.roll(0);
        vm.warp(0);
    }
}

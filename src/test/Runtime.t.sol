// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "ut-0/ERC20.sol";

import "../Runtime.sol";
import "./mocks/Vm.sol";

contract RuntimeTest is DSTest, Vm {
    Runtime public runtime;

    function setUp() public {
        runtime = new Runtime();
    }

    function testCreate() public {
        bytes memory bytecode = abi.encodePacked(
            type(ERC20).creationCode,
            abi.encode("Token", "TOKEN", 18)
        );

        ERC20 erc20 = ERC20(runtime.create(bytecode));
        assertEq(erc20.name(), "Token");
        assertEq(erc20.symbol(), "TOKEN");
        assertEq(erc20.decimals(), 18);
    }

    function testCreate2() public {
        bytes memory bytecode = abi.encodePacked(
            type(ERC20).creationCode,
            abi.encode("Token", "TOKEN", 18)
        );

        ERC20 erc20 = ERC20(runtime.create2(bytecode, 0));
        assertEq(address(erc20), runtime.predict(keccak256(bytecode), 0));
        assertEq(erc20.name(), "Token");
        assertEq(erc20.symbol(), "TOKEN");
        assertEq(erc20.decimals(), 18);
    }

    function testExecuteCreate2() public {
        bytes memory bytecode = abi.encodePacked(
            type(ERC20).creationCode,
            abi.encode("Token", "TOKEN", 18)
        );

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory datas = new bytes[](1);
        string memory message;
        targets[0] = address(runtime);
        values[0] = 0;
        datas[0] = abi.encodePacked(
            bytes4(keccak256(bytes("create2(bytes,bytes32)"))), // selector
            abi.encode(bytecode, bytes32(0)) // encoded arguments
        );
        message = "deploy erc20";

        bytes[] memory results = runtime.execute(targets, values, datas, message);
        assertEq(
            abi.decode(results[0], (address)),
            runtime.predict(keccak256(bytecode), 0)
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "../interfaces/IProposer.sol";
import "../libraries/Status.sol";
import "../Attest.sol";
import "../Proposer.sol";
import "../Runtime.sol";
import "./mocks/Target.sol";
import "./mocks/Vm.sol";

contract RegistryTest is DSTest {
    Runtime public runtime;
    Attest public erc20;
    Proposer public proposer;

    function setUp() public {
        runtime = new Runtime();
        erc20 = new Attest("Token", "TOKEN", 18);
        proposer = new Proposer(address(runtime), address(erc20));
    }
}

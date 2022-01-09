// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Cast {
    function u160(uint256 x) internal pure returns (uint160 y) {
        require (x <= type(uint160).max, "CastOverflow");
        y = uint160(x);
    }

    function u96(uint256 x) internal pure returns (uint96 y) {
        require (x <= type(uint96).max, "CastOverflow");
        y = uint96(x);
    }
}

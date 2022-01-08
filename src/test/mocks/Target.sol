// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Target {
    uint256 public value;

    event Updated(uint256 value_);

    function update(uint256 value_) public {
        value = value_;

        emit Updated(value);
    }
}

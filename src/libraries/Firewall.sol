// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/// @title Firewall
/// @notice A minimal authorization contract.
contract Firewall {
    /// @notice Emitted when an address is authorized.
    event Allowed(address addr);
    /// @notice Emitted when an address is unauthorized.
    event Denied(address addr);

    /// @dev The mapping of all authorized addresses.
    mapping(address => uint256) public rules;

    /// @dev Authorizes the `msg.sender` by default.
    constructor() {
        rules[msg.sender] = type(uint256).max;
    }

    /// @notice Authorize an address.
    /// @dev Can only be called by already authorized contracts.
    function allow(address addr) external virtual {
        require(rules[msg.sender] > 0, "Denied");
        rules[addr] = 1;

        emit Allowed(addr);
    }

    /// @notice Unauthorize an address.
    /// @dev Can only be called by already authorized contracts.
    function deny(address addr) external virtual {
        require(rules[msg.sender] > 0, "Denied");
        rules[addr] = 0;

        emit Denied(addr);
    }

    modifier auth {
        require(rules[msg.sender] > 0, "Denied");
        _;
    }
}

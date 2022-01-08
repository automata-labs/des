// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Transaction.sol";

library Header {
    using Transaction for Transaction.Data;

    struct Data {
        Transaction.Data[] data;
        string title;
        string description;
    }

    function hash(Header.Data memory self) internal pure returns (bytes32[] memory hashes) {
        hashes = new bytes32[](self.data.length);

        for (uint256 i = 0; i < self.data.length; i++) {
            if (i == 0) {
                hashes[i] = self.data[i].hash(bytes32(0));
            } else {
                hashes[i] = self.data[i].hash(hashes[i - 1]);
            }
        }
    }
}

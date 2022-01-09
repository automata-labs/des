// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Transaction {
    struct Data {
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] datas; // assumed to be `abi.encode`ed
        string message;
    }

    function calldatas(Transaction.Data memory self) internal pure returns (bytes[] memory) {
        bytes[] memory datas = new bytes[](self.signatures.length);

        for (uint256 i = 0; i < self.signatures.length; i++) {
            datas[i] = abi.encodePacked(
                // function selector
                bytes4(keccak256(bytes(self.signatures[i]))),
                // encoded arguments
                self.datas[i]
            );
        }

        return datas;
    }

    function tree(Transaction.Data memory self) internal pure returns (bytes32) {
        bytes[] memory datas = new bytes[](self.signatures.length);

        for (uint256 i = 0; i < self.signatures.length; i++) {
            datas[i] = abi.encodePacked(
                // function selector
                bytes4(keccak256(bytes(self.signatures[i]))),
                // encoded arguments
                self.datas[i]
            );
        }

        return keccak256(
            abi.encode(
                self.targets,
                self.values,
                datas,
                self.message
            )
        );
    }

    function hash(Transaction.Data memory self, bytes32 prev) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(tree(self), prev));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IRuntime.sol";
import "./libraries/Firewall.sol";
import "./libraries/Revert.sol";

/// @title Runtime
/// @notice Executes transactions and deploys contracts for the DAO.
contract Runtime is IRuntime, Firewall {
    /// @inheritdoc IRuntime
    function predict(bytes32 bytecodehash, bytes32 salt) external view returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            salt,
                            bytecodehash
                        )
                    )
                )
            )
        );
    }

    /// @inheritdoc IRuntime
    function create(bytes memory bytecode) external returns (address deployment) {
        require(bytecode.length > 0, "BytecodeZero");
        assembly { deployment := create(0, add(bytecode, 32), mload(bytecode)) }
        require(deployment != address(0), "DeployFailed");

        emit Create(deployment);
    }

    /// @inheritdoc IRuntime
    function create2(bytes memory bytecode, bytes32 salt) external returns (address deployment) {
        require(bytecode.length > 0, "BytecodeZero");
        assembly { deployment := create2(0, add(bytecode, 32), mload(bytecode), salt) }
        require(deployment != address(0), "DeployFailed");

        emit Create2(deployment);
    }

    /// @inheritdoc IRuntime
    function call(address target, bytes calldata data) external {
        (bool success, bytes memory returndata) = target.call(data);
    
        if (!success) {
            revert(Revert.getRevertMsg(returndata));
        }

        emit Call(target, data);
    }

    /// @inheritdoc IRuntime
    function execute(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas,
        string calldata message
    ) external returns (bytes[] memory results) {
        require(targets.length == values.length, "Mismatch");
        require(targets.length == datas.length, "Mismatch");
        results = new bytes[](targets.length);

        for (uint256 i = 0; i < targets.length; i++) {
            bool success;

            if (targets[i] != address(this)) {
                (success, results[i]) = targets[i].call{value: values[i]}(datas[i]);
            } else if (targets[i] == address(this)) {
                (success, results[i]) = address(this).delegatecall(datas[i]);
            }

            if (!success) {
                revert(Revert.getRevertMsg(results[i]));
            }
        }

        emit Executed(keccak256(abi.encode(targets, values, datas, message)), message);
    }
}

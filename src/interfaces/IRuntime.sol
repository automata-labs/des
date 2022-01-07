// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRuntime {
    /// @notice Emitted when a contract is deployed using `create`.
    event Create(address deployment);
    /// @notice Emitted when a contract is deployed using `create2`.
    event Create2(address deployment);
    /// @notice Emitted when a single call is executed.
    event Call(address target, bytes data);
    /// @notice Emitted when a transaction batch is executed.
    /// @param hash The hash is calculated similarly to the header hash.
    /// @param message The transaction batch message. Used for logging- and history purposes.
    event Executed(bytes32 indexed hash, string message);

    /// @notice Pre-compute the deterministic of the `create2` function.
    /// @param bytecodehash The hash of the bytecode used for `create2`.
    /// @param salt The salt used in the `create2`.
    /// @return The deterministic deployment address.
    function predict(bytes32 bytecodehash, bytes32 salt) external view returns (address);

    /// @notice Deploy a contract using the `create` opcode.
    /// @param bytecode The bytecode to be deployed as a contract.
    /// @return deployment The non-deterministic deployment address.
    function create(bytes memory bytecode) external returns (address deployment);

    /// @notice Deploy a contract using the `create2` opcode.
    /// @param bytecode The bytecode to be deployed as a contract.
    /// @param salt The salt used in the `create2` opcode.
    /// @return deployment The deterministic deployment address.
    function create2(bytes memory bytecode, bytes32 salt) external returns (address deployment);

    /// @notice Call a contract from the runtime.
    /// @param target The target address.
    /// @param data The calldata.
    function call(address target, bytes calldata data) external;

    /// @notice Execute a transaction batch (an array of transactions).
    /// @dev The message is used for emitting an event for what the transaction did.
    /// @dev The function allows for execution of empty transactions.
    /// @param targets The target addresses.
    /// @param values The ether values to be sent.
    /// @param datas The calldatas.
    /// @param message The transaction message.
    /// @return results The return data of the transaction batch.
    function execute(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas,
        string calldata message
    ) external returns (bytes[] memory results);
}

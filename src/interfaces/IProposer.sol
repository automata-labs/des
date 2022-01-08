// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../libraries/Header.sol";
import "../libraries/Status.sol";

struct Proposal {
    /// @dev The header hash.
    /// @dev Each hash is dependent on the previous hash for preserve sequencial execution.
    bytes32[] hash;

    /// @dev The nonce for permits
    uint96 nonce;
    /// @dev The block when voting starts.
    uint32 start;
    /// @dev The block when two-sided voting ends.
    uint32 end;
    /// @dev The block when one-sided voting ends.
    uint32 trial;
    /// @dev The block when voting ends.
    uint32 finality;
    /// @dev A boolean that controls the one-sided voting.
    ///     - `true`: only `nack` or `pass`
    ///     - `false`: only `ack` or `pass`
    bool side;
    /// @dev If the request is staged.
    bool staged;
    /// @dev The force close variable.
    bool closed;
    /// @dev The force close variable.
    bool merged;

    /// @dev Votes for merging the transaction.
    uint128 ack;
    /// @dev Votes against merging the transaction.
    uint128 nack;
}

interface IProposer {
    /// @notice Returns the immutable runtime.
    function runtime() external view returns (address);

    /// @notice Returns the immutable token.
    function token() external view returns (address);

    /// @notice The minimum amount of token delegations required to `open` a tx.
    function threshold() external view returns (uint128);

    /// @notice The minimum amount of `ack` required for a request to be valid.
    function quorum() external view returns (uint128);

    /// @notice The amount of blocks until a tx goes from draft to open.
    function delay() external view returns (uint32);

    /// @notice The amount of blocks that a tx is open.
    function period() external view returns (uint32);

    /// @notice The amount of blocks that a tx can be contested.
    function window() external view returns (uint32);

    /// @notice The amount of blocks that a tx is extended by when contested.
    function extension() external view returns (uint32);

    /// @notice The amount of blocks until a tx can be executed.
    function ttl() external view returns (uint32);

    /// @notice The amount of blocks until a tx goes stale.
    function lifespan() external view returns (uint32);

    /// @notice Returns a header hash.
    function hash(uint256 tokenId, uint256 index) external view returns (bytes32);

    /// @notice Returns a header hashes.
    function hashes(uint256 tokenId) external view returns (bytes32[] memory);

    /// @notice The mapping from token id to proposal.
    function proposals(uint256 tokenId) external view returns (
        uint96 nonce,
        uint32 start,
        uint32 end,
        uint32 trial,
        uint32 finality,
        bool side,
        bool staged,
        bool closed,
        bool merged,
        uint128 ack,
        uint128 nack
    );

    /// @notice The mapping of total amount of attests for each address.
    function attests(uint256 tokenId, address account) external view returns (uint256);

    /// @notice The function to update contract parameters.
    function set(bytes4 selector, bytes memory data) external;

    /// @notice The next nft token id.
    function next() external view returns (uint256);

    /// @notice Returns the proposal as a struct.
    function proposal(uint256 tokenId) external view returns (Proposal memory);

    /// @notice Returns the block number when a proposal is executable.
    /// @dev The block number is inclusive.
    function maturity(uint256 tokenId) external view returns (uint32);

    /// @notice Returns the block number when a proposal beocmes expired.
    /// @dev The block number is inclusive.
    function expiry(uint256 tokenId) external view returns (uint32);

    /// @notice Returns the status of the proposal.
    function status(uint256 tokenId) external view returns (Status);

    /// @notice Mints a new ERC721 draft proposal.
    function mint(address to, Header.Data calldata header) external returns (uint256 tokenId);

    /// @notice Stages a proposal to be opened by anyone with enough token weight.
    function stage(uint256 tokenId) external;

    /// @notice Unstage a propsal to draft status.
    function unstage(uint256 tokenId) external;

    /// @notice Opens a proposal.
    /// @dev Requires at least `threshold` amount token weight from the `msg.sender` to be callable.
    function open(uint256 tokenId) external;

    /// @notice Close a proposal.
    /// @dev A proposal can be closed except for when the status is `Merged` or `Closed`.
    function close(uint256 tokenId) external;

    /// @notice Mark a proposal as merged.
    /// @dev Expected to be called in the following order: registry -> runtime -> proposal.
    function done(uint256 tokenId) external;

    /// @notice Attest on a proposal with `ack`, `nack` or `abstain`.
    /// @dev The support mapping:
    ///     - `ack` = `0`
    ///     - `nack` = `1`
    ///     - `abstain` = `2`
    function attest(uint256 tokenId, uint8 support, uint96 amount, string memory comment) external;

    /// @notice Contest a proposal after having passed/rejected.
    /// @dev Requires the first cycle to be `ack` majority for the contestation to begin.
    /// @dev The `contest` function can be continuously be called until one side wins.
    function contest(uint256 tokenId) external;

    /// @notice Updates the proposal `hash`es.
    function commit(uint256 tokenId, Header.Data calldata header) external;
}

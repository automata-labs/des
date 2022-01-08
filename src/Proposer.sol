// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IProposer.sol";
import "./libraries/Cast.sol";
import "./libraries/Checkpoint.sol";
import "./libraries/ERC721Permit.sol";
import "./libraries/Header.sol";
import "./libraries/Status.sol";

interface IAttest {
    function weightOf(address account) external view returns (uint256);

    function weightIn(address account, uint256 blockNumber) external view returns (uint256);

    function weightAt(
        address account,
        uint256 index
    ) external view returns (uint160, uint32, uint32);
}

/// @title Proposer
/// @notice Tokenizes proposals as ERC721.
contract Proposer is IProposer, ERC721Permit {
    using Cast for uint256;
    using Header for Header.Data;

    error AttestOverflow();
    error ContestationFailed();
    error InvalidCheckpoint(uint256 index);
    error InvalidChoice(uint8 choice);
    error StatusError(Status status);
    error UndefinedId(uint256 tokenId);
    error UndefinedSelector(bytes4 selector);

    /// @inheritdoc IProposer
    address public immutable runtime;
    /// @inheritdoc IProposer
    address public immutable token;
    /// @inheritdoc IProposer
    uint128 public threshold;
    /// @inheritdoc IProposer
    uint128 public quorum;

    /// @inheritdoc IProposer
    uint32 public delay;
    /// @inheritdoc IProposer
    uint32 public period;
    /// @inheritdoc IProposer
    uint32 public window;
    /// @inheritdoc IProposer
    uint32 public extension;
    /// @inheritdoc IProposer
    uint32 public ttl;
    /// @inheritdoc IProposer
    uint32 public lifespan;

    /// @dev The next minted token id.
    uint256 private _nextId = 0;
    /// @inheritdoc IProposer
    mapping(uint256 => Proposal) public proposals;
    /// @inheritdoc IProposer
    mapping(uint256 => mapping(address => uint256)) public attests;

    constructor(address runtime_, address token_) ERC721Permit(
        "DAO Execution System Proposal NFT-V1",
        "DES-NFT-V1"
    ) {
        runtime = runtime_;
        token = token_;

        delay = 17280; // 3 days pending
        period = 40320; // 7 days to attest
        window = 17280; // 3 days to contest
        extension = 17280; // 3 days of contestation
        ttl = 17280; // 3 days queued
        lifespan = 80640; // 14 days until expiry (when accepted)
    }

    /// @inheritdoc IProposer
    function set(bytes4 selector, bytes memory data) external {
        if (selector == IProposer.threshold.selector)
            threshold = abi.decode(data, (uint128));
        else if (selector == IProposer.threshold.selector)
            quorum = abi.decode(data, (uint128));
        else if (selector == IProposer.delay.selector)
            delay = abi.decode(data, (uint32));
        else if (selector == IProposer.period.selector)
            period = abi.decode(data, (uint32));
        else if (selector == IProposer.window.selector)
            window = abi.decode(data, (uint32));
        else if (selector == IProposer.extension.selector)
            extension = abi.decode(data, (uint32));
        else if (selector == IProposer.ttl.selector)
            ttl = abi.decode(data, (uint32));
        else if (selector == IProposer.lifespan.selector)
            lifespan = abi.decode(data, (uint32));
        else
            revert UndefinedSelector(selector);
    }

    /// @inheritdoc IProposer
    function next() external view returns (uint256) {
        return _nextId;
    }

    /// @inheritdoc IProposer
    function hash(uint256 tokenId, uint256 index) external view returns (bytes32) {
        return proposals[tokenId].hash[index];
    }

    /// @inheritdoc IProposer
    function hashes(uint256 tokenId) external view returns (bytes32[] memory) {
        return proposals[tokenId].hash;
    }

    /// @inheritdoc IProposer
    function proposal(uint256 tokenId) external view returns (Proposal memory) {
        return proposals[tokenId];
    }

    /// @inheritdoc IProposer
    function maturity(uint256 tokenId) public view returns (uint32) {
        return proposals[tokenId].finality + ttl;
    }

    /// @inheritdoc IProposer
    function expiry(uint256 tokenId) public view returns (uint32) {
        return proposals[tokenId].finality + ttl + lifespan;
    }

    /// @inheritdoc IProposer
    function status(uint256 tokenId) public view returns (Status) {
        if (proposals[tokenId].merged)
            return Status.Merged;

        if (proposals[tokenId].closed)
            return Status.Closed;

        if (proposals[tokenId].start == 0) {
            if (proposals[tokenId].staged) {
                return Status.Staged;
            } else {
                return Status.Draft;
            }
        }

        if (_blockNumber() < proposals[tokenId].start)
            return Status.Pending;

        if (_blockNumber() < proposals[tokenId].end)
            return Status.Open;

        if (_blockNumber() < proposals[tokenId].trial)
            return Status.Contesting;

        if (_blockNumber() < proposals[tokenId].finality)
            return Status.Validation;

        if (
            proposals[tokenId].ack > proposals[tokenId].nack &&
            proposals[tokenId].ack > quorum
        ) {
            if (_blockNumber() < maturity(tokenId)) {
                return Status.Queued;
            }

            if (_blockNumber() < expiry(tokenId)) {
                return Status.Approved;
            }
        }

        return Status.Closed;            
    }

    /// @inheritdoc IProposer
    function mint(address to, Header.Data calldata header) external returns (uint256 tokenId) {
        _mint(to, (tokenId = _nextId++));
        _commit(tokenId, header);
    }

    /// @inheritdoc IProposer
    function stage(uint256 tokenId) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Unauthorized");
        require(status(tokenId) == Status.Draft, "NotDraft");
        proposals[tokenId].staged = true;

        emit Stage(msg.sender, tokenId);
    }

    /// @inheritdoc IProposer
    function unstage(uint256 tokenId) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Unauthorized");
        require(status(tokenId) == Status.Staged, "NotStaged");
        proposals[tokenId].staged = false;

        emit Unstage(msg.sender, tokenId);
    }

    /// @inheritdoc IProposer
    function open(uint256 tokenId) external {
        if (_isApprovedOrOwner(msg.sender, tokenId))
            require(status(tokenId) == Status.Draft, "NotDraft");
        else
            require(status(tokenId) == Status.Staged, "NotStaged");

        require(IAttest(token).weightOf(msg.sender) >= threshold, "Insufficient");
        proposals[tokenId].start = uint32(block.number) + delay;
        proposals[tokenId].end = proposals[tokenId].start + period;
        proposals[tokenId].trial = proposals[tokenId].end;
        proposals[tokenId].finality = proposals[tokenId].end + window;

        emit Open(
            msg.sender,
            tokenId,
            proposals[tokenId].start,
            proposals[tokenId].end,
            proposals[tokenId].finality
        );
    }

    /// @inheritdoc IProposer
    function close(uint256 tokenId) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Unauthorized");
        require(
            status(tokenId) != Status.Closed ||
            status(tokenId) != Status.Merged,
            "StatusMismatch"
        );
        proposals[tokenId].closed = true;

        emit Close(msg.sender, tokenId);
    }

    /// @inheritdoc IProposer
    function done(uint256 tokenId) external {
        require(msg.sender == runtime, "Unauthorized");
        require(status(tokenId) == Status.Approved, "NotApproved");
        proposals[tokenId].merged = true;

        emit Merge(tokenId);
    }

    /// @inheritdoc IProposer
    function attest(uint256 tokenId, uint8 support, uint96 amount, string memory comment) external {
        if (!_exists(tokenId))
            revert UndefinedId(tokenId);

        Proposal storage proposal_ = proposals[tokenId];
        Status status_ = status(tokenId);

        if (status_ == Status.Open) {
            if (support > 2) {
                revert InvalidChoice(support);
            }
        } else if (status_ == Status.Contesting) {
            if (proposal_.side) {
                if (support != 1 && support != 2) {
                    revert InvalidChoice(support);
                }
            } else {
                if (support != 0 && support != 2) {
                    revert InvalidChoice(support);
                }
            }
        } else {
            revert StatusError(status_);
        }

        uint160 weight = IAttest(token).weightIn(msg.sender, proposal_.start).u160();

        if (amount > weight - attests[tokenId][msg.sender])
            revert AttestOverflow();

        if (support == 0)
            proposal_.ack += amount;

        if (support == 1)
            proposal_.nack += amount;
        
        attests[tokenId][msg.sender] += amount;

        emit Attest(msg.sender, tokenId, support, amount, comment);
    }

    /// @inheritdoc IProposer
    function contest(uint256 tokenId) external {
        if (status(tokenId) != Status.Validation)
            revert StatusError(status(tokenId));

        if (proposals[tokenId].side && proposals[tokenId].ack > proposals[tokenId].nack)
            revert ContestationFailed();

        if (!proposals[tokenId].side && proposals[tokenId].nack > proposals[tokenId].ack)
            revert ContestationFailed();

        proposals[tokenId].trial = _blockNumber() + extension;
        proposals[tokenId].finality = proposals[tokenId].trial + window;
        proposals[tokenId].side = !proposals[tokenId].side;

        emit Contest(
            msg.sender,
            tokenId,
            proposals[tokenId].trial,
            proposals[tokenId].finality,
            proposals[tokenId].side
        );
    }

    /// @inheritdoc IProposer
    function commit(uint256 tokenId, Header.Data calldata header) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "NotApprovedOrOwner");
        _commit(tokenId, header);
    }

    /// @dev Internal commit function.
    function _commit(uint256 tokenId, Header.Data calldata header) internal {
        require(status(tokenId) == Status.Draft, "NotDraft");
        proposals[tokenId].hash = header.hash();

        emit Commit(msg.sender, tokenId, proposals[tokenId].hash, header);
    }

    /// @dev Increments a proposal nonce used for `ERC721Permit`.
    function _getAndIncrementNonce(uint256 tokenId) internal override returns (uint256) {
        return uint256(proposals[tokenId].nonce++);
    }

    /// @dev Returns a `uint32` casted `block.number`.
    function _blockNumber() internal view returns (uint32) {
        return uint32(block.number);
    }
}

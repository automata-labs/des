// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

contract Proposer is ERC721Permit {
    using Cast for uint256;
    using Header for Header.Data;

    error StatusError(Status status);
    error UndefinedId(uint256 tokenId);
    error InvalidCheckpoint(uint256 index);
    error AttestOverflow();
    error InvalidChoice(uint8 choice);
    error ContestationFailed();

    event Attest(
        address indexed sender,
        uint256 indexed tokenId,
        uint8 support,
        uint256 amount,
        string comment
    );
    
    struct Proposal {
        /// @dev The header hash.
        bytes32[] hash;

        /// @dev the nonce for permits
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

    /// @dev The runtime.
    address public immutable runtime;
    /// @dev The token used for attesting.
    address public immutable token;
    /// @dev The minimum amount of token delegations required to `open` a tx.
    uint128 public threshold;
    /// @dev The minimum amount of `ack` required for a request to be valid.
    uint128 public quorum;

    /// @dev The amount of blocks until a tx goes from draft to open.
    uint32 public delay;
    /// @dev The amount of blocks that a tx is open.
    uint32 public period;
    /// @dev The amount of blocks that a tx can be contested.
    uint32 public window;
    /// @dev The amount of blocks that a tx is extended by when contested.
    uint32 public extension;
    /// @dev The amount of blocks until a tx can be executed.
    uint32 public ttl;
    /// @dev The amount of blocks until a tx goes stale.
    uint32 public lifespan;

    /// @dev The next minted token id.
    uint256 private _nextId = 0;
    /// @dev The mapping from token id to proposal.
    mapping(uint256 => Proposal) public _proposals;
    /// @dev The mapping of total amount of attests for each address.
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

    function set(bytes32 selector, bytes memory data) external {
        if (selector == "threshold")
            threshold = abi.decode(data, (uint128));
        else if (selector == "quorum")
            quorum = abi.decode(data, (uint128));
        else
            revert("Undefined");
    }

    function next() external view returns (uint256) {
        return _nextId;
    }

    function proposals(uint256 tokenId) external view returns (Proposal memory) {
        return _proposals[tokenId];
    }

    function maturity(uint256 tokenId) public view returns (uint32) {
        return _proposals[tokenId].finality + ttl;
    }

    function expiry(uint256 tokenId) public view returns (uint32) {
        return _proposals[tokenId].finality + ttl + lifespan;
    }

    function status(uint256 tokenId) public view returns (Status) {
        if (_proposals[tokenId].merged)
            return Status.Merged;

        if (_proposals[tokenId].closed)
            return Status.Closed;

        if (_proposals[tokenId].start == 0) {
            if (_proposals[tokenId].staged) {
                return Status.Staged;
            } else {
                return Status.Draft;
            }
        }

        if (_blockNumber() < _proposals[tokenId].start)
            return Status.Pending;

        if (_blockNumber() < _proposals[tokenId].end)
            return Status.Open;

        if (_blockNumber() < _proposals[tokenId].trial)
            return Status.Contesting;

        if (_blockNumber() < _proposals[tokenId].finality)
            return Status.Validation;

        if (
            _proposals[tokenId].ack > _proposals[tokenId].nack &&
            _proposals[tokenId].ack > quorum
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

    function mint(address to, Header.Data calldata header) external returns (uint256 tokenId) {
        _mint(to, (tokenId = _nextId++));
        _commit(tokenId, header);
    }

    function stage(uint256 tokenId) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Unauthorized");
        require(status(tokenId) == Status.Draft, "NotDraft");
        _proposals[tokenId].staged = true;
    }

    function unstage(uint256 tokenId) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Unauthorized");
        require(status(tokenId) == Status.Staged, "NotStaged");
        _proposals[tokenId].staged = false;
    }

    function open(uint256 tokenId) external {
        if (_isApprovedOrOwner(msg.sender, tokenId))
            require(status(tokenId) == Status.Draft, "NotDraft");
        else
            require(status(tokenId) == Status.Staged, "NotStaged");

        require(IAttest(token).weightOf(msg.sender) >= threshold, "Insufficient");
        _proposals[tokenId].start = uint32(block.number) + delay;
        _proposals[tokenId].end = _proposals[tokenId].start + period;
        _proposals[tokenId].trial = _proposals[tokenId].end;
        _proposals[tokenId].finality = _proposals[tokenId].end + window;
    }

    function close(uint256 tokenId) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Unauthorized");
        require(
            status(tokenId) != Status.Closed ||
            status(tokenId) != Status.Merged,
            "StatusMismatch"
        );
        _proposals[tokenId].closed = true;
    }

    function done(uint256 tokenId) external {
        require(msg.sender == runtime, "Unauthorized");
        require(status(tokenId) == Status.Approved, "NotApproved");
        _proposals[tokenId].merged = true;
    }

    function attest(
        uint256 tokenId,
        uint8 support,
        uint96 amount,
        string memory comment
    ) external {
        if (!_exists(tokenId))
            revert UndefinedId(tokenId);

        Proposal storage proposal = _proposals[tokenId];
        Status status_ = status(tokenId);

        if (status_ == Status.Open) {
            if (support > 2) {
                revert InvalidChoice(support);
            }
        } else if (status_ == Status.Contesting) {
            if (proposal.side) {
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

        uint160 weight = IAttest(token).weightIn(msg.sender, proposal.start).u160();

        if (amount > weight - attests[tokenId][msg.sender])
            revert AttestOverflow();

        if (support == 0)
            proposal.ack += amount;

        if (support == 1)
            proposal.nack += amount;
        
        attests[tokenId][msg.sender] += amount;

        emit Attest(msg.sender, tokenId, support, amount, comment);
    }

    function contest(uint256 tokenId) external {
        if (status(tokenId) != Status.Validation)
            revert StatusError(status(tokenId));

        if (_proposals[tokenId].side && _proposals[tokenId].ack > _proposals[tokenId].nack)
            revert ContestationFailed();

        if (!_proposals[tokenId].side && _proposals[tokenId].nack > _proposals[tokenId].ack)
            revert ContestationFailed();

        _proposals[tokenId].trial = _blockNumber() + extension;
        _proposals[tokenId].finality = _proposals[tokenId].trial + window;
        _proposals[tokenId].side = !_proposals[tokenId].side;
    }

    function commit(uint256 tokenId, Header.Data calldata header) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "NotApprovedOrOwner");
        _commit(tokenId, header);
    }

    function _commit(uint256 tokenId, Header.Data calldata header) internal {
        require(status(tokenId) == Status.Draft, "NotDraft");
        _proposals[tokenId].hash = header.hash();
    }

    function _getAndIncrementNonce(uint256 tokenId) internal override returns (uint256) {
        return uint256(_proposals[tokenId].nonce++);
    }

    function _blockNumber() internal view returns (uint32) {
        return uint32(block.number);
    }
}

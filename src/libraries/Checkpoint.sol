// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


library Checkpoint {
    struct Data {
        uint160 amount;
        uint32 startBlock;
        uint32 endBlock;
    }

    function latest(Checkpoint.Data[] storage checkpoints) internal view returns (uint256) {
        uint256 len = checkpoints.length;
        return (len == 0) ? 0 : checkpoints[len - 1].amount;
    }

    /// @dev Look up an accounts total voting power.
    function lookup(
        Checkpoint.Data[] storage checkpoints,
        uint256 blockNumber
    ) internal view returns (uint256) {
        uint256 high = checkpoints.length;
        uint256 low = 0;
        while (low < high) {
            uint256 mid = (low & high) + (low ^ high) / 2;
            if (checkpoints[mid].startBlock > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        return high == 0 ? 0 : checkpoints[high - 1].amount;
    }

    /// @dev Create a new checkpoint for a checkpoint array.
    function save(
        Checkpoint.Data[] storage checkpoints,
        function(uint256, uint256) view returns (uint256) op,
        uint256 delta
    ) internal returns (uint256 prev, uint256 next) {
        uint256 len = checkpoints.length;
        prev = len == 0 ? 0 : checkpoints[len - 1].amount;
        next = op(prev, delta);

        if (len > 0 && checkpoints[len - 1].startBlock == block.number) {
            checkpoints[len - 1].amount = uint160(next);
        } else {
            if (len > 0) {
                checkpoints[len - 1].endBlock = uint32(block.number) - uint32(1);
            }

            checkpoints.push(
                Checkpoint.Data({
                    amount: uint160(next),
                    startBlock: uint32(block.number),
                    endBlock: uint32(0)
                })
            );
        }
    }

    /// @dev Move the delegated votes from one account to another.
    function move(
        mapping(address => Checkpoint.Data[]) storage checkpoints,
        address from,
        address to,
        uint256 amount
    ) internal {
        if (from != to && amount > 0) {
            if (from != address(0)) {
                save(checkpoints[from], sub, amount);
            }

            if (to != address(0)) {
                save(checkpoints[to], add, amount);
            }
        }
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Pointer {
    struct Data {
        address value;
        uint32 startBlock;
        uint32 endBlock;
    }

    function latest(Pointer.Data[] storage pointers) internal view returns (address) {
        uint256 len = pointers.length;
        return (len == 0) ? address(0) : pointers[len - 1].value;
    }

    /// @dev Look up an accounts total voting power.
    function lookup(
        Pointer.Data[] storage pointers,
        uint256 blockNumber
    ) internal view returns (address) {
        uint256 high = pointers.length;
        uint256 low = 0;

        while (low < high) {
            uint256 mid = (low & high) + (low ^ high) / 2;
            if (pointers[mid].startBlock > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        if (high == 0)
            return address(0);
        else
            return pointers[high - 1].value;
    }

    /// @dev Create a new checkpoint for a checkpoint array.
    function save(Pointer.Data[] storage pointers, address value) internal {
        uint256 len = pointers.length;

        if (len > 0 && pointers[len - 1].startBlock == block.number) {
            pointers[len - 1].value = value;
        } else {
            if (len > 0) {
                pointers[len - 1].endBlock = uint32(block.number) - uint32(1);
            }

            pointers.push(
                Pointer.Data({
                    value: value,
                    startBlock: uint32(block.number),
                    endBlock: uint32(0)
                })
            );
        }
    }
}

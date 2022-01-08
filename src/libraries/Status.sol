// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

enum Status {
    Draft,
    Staged,
    Pending,
    Open,
    Validation,
    Contesting,
    Queued,
    Approved,
    Merged,
    Closed
}

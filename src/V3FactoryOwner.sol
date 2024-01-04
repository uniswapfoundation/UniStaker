// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

contract V3FactoryOwner {
    address public admin;

    constructor(address _admin) {
        admin = _admin;
    }
}
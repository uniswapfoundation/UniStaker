// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

interface IERC20Mint {
  function mint(address dst, uint256 rawAmount) external;
}

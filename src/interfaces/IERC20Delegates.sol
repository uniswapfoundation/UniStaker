// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IERC20Delegates {
  function allowance(address account, address spender) external view returns (uint256);
  function approve(address spender, uint256 rawAmount) external returns (bool);
  function balanceOf(address account) external view returns (uint256);
  function decimals() external view returns (uint8);
  function symbol() external view returns (string memory);
  function totalSupply() external view returns (uint256);
  function transfer(address dst, uint256 rawAmount) external returns (bool);
  function transferFrom(address src, address dst, uint256 rawAmount) external returns (bool);

  function delegate(address delegatee) external;
  function delegates(address) external view returns (address);
}

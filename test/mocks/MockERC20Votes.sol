// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {IERC20Delegates} from "src/interfaces/IERC20Delegates.sol";

contract MockERC20Votes is IERC20Delegates, ERC20 {
  mapping(address account => address delegate) private delegations;

  constructor() ERC20("Governance Token", "GOV") {}

  function mint(address _account, uint256 _value) public {
    _mint(_account, _value);
  }

  function delegate(address _delegatee) external {
    delegations[msg.sender] = _delegatee;
  }

  function delegates(address _account) external view returns (address) {
    return delegations[_account];
  }

  function allowance(address account, address spender)
    public
    view
    override(IERC20Delegates, ERC20)
    returns (uint256)
  {
    return ERC20.allowance(account, spender);
  }

  function balanceOf(address account)
    public
    view
    override(IERC20Delegates, ERC20)
    returns (uint256)
  {
    return ERC20.balanceOf(account);
  }

  function approve(address spender, uint256 rawAmount)
    public
    override(IERC20Delegates, ERC20)
    returns (bool)
  {
    return ERC20.approve(spender, rawAmount);
  }

  function decimals() public view override(IERC20Delegates, ERC20) returns (uint8) {
    return ERC20.decimals();
  }

  function symbol() public view override(IERC20Delegates, ERC20) returns (string memory) {
    return ERC20.symbol();
  }

  function totalSupply() public view override(IERC20Delegates, ERC20) returns (uint256) {
    return ERC20.totalSupply();
  }

  function transfer(address dst, uint256 rawAmount)
    public
    override(IERC20Delegates, ERC20)
    returns (bool)
  {
    return ERC20.transfer(dst, rawAmount);
  }

  function transferFrom(address src, address dst, uint256 rawAmount)
    public
    override(IERC20Delegates, ERC20)
    returns (bool)
  {
    return ERC20.transferFrom(src, dst, rawAmount);
  }
}

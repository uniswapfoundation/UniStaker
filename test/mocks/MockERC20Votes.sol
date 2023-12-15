// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {IERC20Delegates} from "src/interfaces/IERC20Delegates.sol";

/// @dev An ERC20 token that allows for public minting and mocks the delegation methods used in
/// ERC20Votes governance tokens. It does not included check pointing functionality. This contract
/// is intended only for use as a stand in for contracts that interface with ERC20Votes tokens.
contract ERC20VotesMock is IERC20Delegates, ERC20 {
  /// @dev Track delegations for mocked delegation methods
  mapping(address account => address delegate) private delegations;

  constructor() ERC20("Governance Token", "GOV") {}

  /// @dev Public mint function useful for testing
  function mint(address _account, uint256 _value) public {
    _mint(_account, _value);
  }

  /// @dev Mock delegation method
  function delegate(address _delegatee) external {
    delegations[msg.sender] = _delegatee;
  }

  /// @dev Mock method for fetching to which address the provided account last delegated
  /// via `delegate`
  function delegates(address _account) external view returns (address) {
    return delegations[_account];
  }

  //---------------------------------------------------------------------------------------------//
  // All methods below this line are overridden solely for the sake of disambiguating identical  //
  // method signatures for Solidity. No functionality is implemented and all parameters are      //
  // curried to the standard implementations from OpenZeppelin's ERC20 contract.                 //
  //---------------------------------------------------------------------------------------------//

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

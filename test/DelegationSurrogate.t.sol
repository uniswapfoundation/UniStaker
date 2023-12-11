// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {DelegationSurrogate} from "src/DelegationSurrogate.sol";
import {ERC20VotesMock} from "test/mocks/MockERC20Votes.sol";

contract DelegationSurrogateTest is Test {
  ERC20VotesMock govToken;

  function setUp() public {
    govToken = new ERC20VotesMock();
    vm.label(address(govToken), "Governance Token");
  }

  function __deploy(address _deployer, address _delegatee) public returns (DelegationSurrogate) {
    vm.assume(_deployer != address(0));

    vm.prank(_deployer);
    DelegationSurrogate _surrogate = new DelegationSurrogate(govToken, _delegatee);
    return _surrogate;
  }
}

contract Constructor is DelegationSurrogateTest {
  function testFuzz_DelegatesToDeployer(address _deployer, address _delegatee) public {
    DelegationSurrogate _surrogate = __deploy(_deployer, _delegatee);
    assertEq(_delegatee, govToken.delegates(address(_surrogate)));
  }

  function testFuzz_MaxApprovesDeployerToEnableWithdrawals(
    address _deployer,
    address _delegatee,
    uint256 _amount,
    address _receiver
  ) public {
    vm.assume(_receiver != address(0));

    DelegationSurrogate _surrogate = __deploy(_deployer, _delegatee);
    govToken.mint(address(_surrogate), _amount);

    uint256 _allowance = govToken.allowance(address(_surrogate), _deployer);
    assertEq(_allowance, type(uint256).max);

    vm.prank(_deployer);
    govToken.transferFrom(address(_surrogate), _receiver, _amount);

    assertEq(govToken.balanceOf(_receiver), _amount);
  }
}

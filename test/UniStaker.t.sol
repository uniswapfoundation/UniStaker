// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {UniStaker} from "src/UniStaker.sol";
import {ERC20VotesMock} from "test/mocks/MockERC20Votes.sol";
import {ERC20Fake} from "test/fakes/ERC20Fake.sol";

contract UniStakerTest is Test {
  ERC20Fake rewardToken;
  ERC20VotesMock govToken;
  UniStaker uniStaker;

  function setUp() public {
    rewardToken = new ERC20Fake();
    vm.label(address(rewardToken), "Reward Token");

    govToken = new ERC20VotesMock();
    vm.label(address(govToken), "Governance Token");

    uniStaker = new UniStaker(rewardToken, govToken);
  }
}

contract Constructor is UniStakerTest {
  function test_SetsTheRewardTokenAndStakeToken() public {
    assertEq(address(uniStaker.REWARDS_TOKEN()), address(rewardToken));
    assertEq(address(uniStaker.STAKE_TOKEN()), address(govToken));
  }
}

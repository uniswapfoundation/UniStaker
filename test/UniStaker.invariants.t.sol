// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

import {UniStaker} from "src/UniStaker.sol";
import {UniStakerHandler} from "test/helpers/UniStaker.handler.sol";
import {ERC20VotesMock} from "test/mocks/MockERC20Votes.sol";
import {ERC20Fake} from "test/fakes/ERC20Fake.sol";

contract UniStakerInvariants is Test {
  UniStakerHandler public handler;
  UniStaker public uniStaker;
  ERC20Fake rewardToken;
  ERC20VotesMock govToken;
  address rewardsNotifier;

  function setUp() public {
    // deploy UniStaker
    rewardToken = new ERC20Fake();
    vm.label(address(rewardToken), "Rewards Token");

    govToken = new ERC20VotesMock();
    vm.label(address(govToken), "Governance Token");

    rewardsNotifier = address(0xaffab1ebeef);
    vm.label(rewardsNotifier, "Rewards Notifier");
    uniStaker = new UniStaker(rewardToken, govToken, rewardsNotifier);
    handler = new UniStakerHandler(uniStaker);

    bytes4[] memory selectors = new bytes4[](7);
    selectors[0] = UniStakerHandler.stake.selector;
    selectors[1] = UniStakerHandler.validStakeMore.selector;
    selectors[2] = UniStakerHandler.validWithdraw.selector;
    selectors[3] = UniStakerHandler.warpAhead.selector;
    selectors[4] = UniStakerHandler.claimReward.selector;
    selectors[5] = UniStakerHandler.enableRewardNotifier.selector;
    selectors[6] = UniStakerHandler.notifyRewardAmount.selector;

    targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));

    targetContract(address(handler));
  }

  // Invariants

  function invariant_Sum_of_all_depositor_balances_equals_total_stake() public {
    assertEq(uniStaker.totalStaked(), handler.reduceDepositors(0, this.accumulateDeposits));
  }

  function invariant_Sum_of_beneficiary_earning_power_equals_total_stake() public {
    assertEq(uniStaker.totalStaked(), handler.reduceBeneficiaries(0, this.accumulateEarningPower));
  }

  function invariant_Sum_of_surrogate_balance_equals_total_stake() public {
    assertEq(uniStaker.totalStaked(), handler.reduceDelegates(0, this.accumulateSurrogateBalance));
  }

  function invariant_Cumulative_staked_minus_withdrawals_equals_total_stake() public {
    assertEq(uniStaker.totalStaked(), handler.ghost_stakeSum() - handler.ghost_stakeWithdrawn());
  }

  function invariant_Sum_of_notified_rewards_equals_all_claimed_rewards_plus_rewards_left() public {
    assertEq(
      handler.ghost_rewardsNotified(),
      rewardToken.balanceOf(address(uniStaker)) + handler.ghost_rewardsClaimed()
    );
  }

  function invariant_Unclaimed_reward_LTE_total_rewards() public {
    assertLe(
      handler.reduceBeneficiaries(0, this.accumulateUnclaimedReward),
      rewardToken.balanceOf(address(uniStaker))
    );
  }

  // Used to see distribution of non-reverting calls
  function invariant_callSummary() public view {
    handler.callSummary();
  }

  // Helpers

  function accumulateDeposits(uint256 balance, address depositor) external view returns (uint256) {
    return balance + uniStaker.depositorTotalStaked(depositor);
  }

  function accumulateEarningPower(uint256 earningPower, address caller)
    external
    view
    returns (uint256)
  {
    return earningPower + uniStaker.earningPower(caller);
  }

  function accumulateUnclaimedReward(uint256 unclaimedReward, address beneficiary)
    external
    view
    returns (uint256)
  {
    return unclaimedReward + uniStaker.unclaimedReward(beneficiary);
  }

  function accumulateSurrogateBalance(uint256 balance, address delegate)
    external
    view
    returns (uint256)
  {
    address surrogateAddr = address(uniStaker.surrogates(delegate));
    return balance + IERC20(address(uniStaker.STAKE_TOKEN())).balanceOf(surrogateAddr);
  }
}

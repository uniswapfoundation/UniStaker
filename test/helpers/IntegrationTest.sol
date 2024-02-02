// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {console2} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IUniswapV3PoolOwnerActions} from "src/interfaces/IUniswapV3PoolOwnerActions.sol";
import {ISwapRouter} from "v3-periphery/interfaces/ISwapRouter.sol";
import {ProposalTest} from "test/helpers/ProposalTest.sol";

contract IntegrationTest is ProposalTest {
  function _setupProposals() internal {
    _passQueueAndExecuteProposals();
  }

  function _swapTokens(address tokenIn, address tokenOut, uint256 _amount) internal {
    ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
      tokenIn: tokenIn,
      tokenOut: tokenOut,
      fee: 3000,
      recipient: address(this),
      deadline: block.timestamp + 1000,
      amountIn: _amount,
      amountOutMinimum: 0,
      sqrtPriceLimitX96: 0
    });

    // The call to `exactInputSingle` executes the swap.
    UNISWAP_V3_SWAP_ROUTER.exactInputSingle(params);
  }

  function _setupPayoutToken() internal {
    IERC20 weth = IERC20(payable(WETH_ADDRESS));
    weth.approve(address(v3FactoryOwner), PAYOUT_AMOUNT);
    vm.deal(address(this), PAYOUT_AMOUNT);
    deal(address(weth), address(this), PAYOUT_AMOUNT);
  }

  function _setupSwapToken(uint128 _amountDai) internal returns (uint256) {
    _amountDai = uint128(bound(_amountDai, 1e18, 1_000_000e18));
    IERC20 dai = IERC20(payable(DAI_ADDRESS));
    dai.approve(address(UNISWAP_V3_SWAP_ROUTER), _amountDai);
    deal(address(dai), address(this), _amountDai, true);
    return _amountDai;
  }

  function _generateFees(uint128 _amount) internal {
    uint256 _amountDai = _setupSwapToken(_amount);
    _swapTokens(DAI_ADDRESS, WETH_ADDRESS, _amountDai);
  }

  function _notifyRewards(uint128 _amount) internal {
    _setupPayoutToken();
    _generateFees(_amount);
    v3FactoryOwner.claimFees(IUniswapV3PoolOwnerActions(DAI_WETH_3000_POOL), address(this), 1, 0);
  }

  function _dealStakingToken(address _depositor, uint256 _amount) internal returns (uint256) {
    _amount = bound(_amount, 1, 10_000_000_000e18);
    deal(STAKE_TOKEN_ADDRESS, _depositor, _amount);

    vm.prank(_depositor);
    IERC20(STAKE_TOKEN_ADDRESS).approve(address(uniStaker), _amount);
    return _amount;
  }

  function _jumpAhead(uint256 _seconds) public {
    vm.warp(block.timestamp + _seconds);
  }

  function _jumpAheadByPercentOfRewardDuration(uint256 _percent) public {
    uint256 _seconds = (_percent * uniStaker.REWARD_DURATION()) / 100;
    _jumpAhead(_seconds);
  }

  function _boundToRealisticReward(uint256 _rewardAmount)
    public
    pure
    returns (uint256 _boundedRewardAmount)
  {
    _boundedRewardAmount = bound(_rewardAmount, 200e6, 10_000_000e18);
  }

  function _boundToRealisticStakeAndReward(uint256 _stakeAmount, uint256 _rewardAmount)
    public
    pure
    returns (uint256 _boundedStakeAmount, uint256 _boundedRewardAmount)
  {
    _boundedStakeAmount = _boundToRealisticStake(_stakeAmount);
    _boundedRewardAmount = _boundToRealisticReward(_rewardAmount);
  }

  function _mintTransferAndNotifyReward(uint256 _amount) public {
    deal(address(rewardToken), rewardNotifier, _amount);

    vm.startPrank(rewardNotifier);
    rewardToken.transfer(address(uniStaker), _amount);
    uniStaker.notifyRewardAmount(_amount);
    vm.stopPrank();
  }

  function _mintTransferAndNotifyReward(address _rewardNotifier, uint256 _amount) public {
    vm.assume(_rewardNotifier != address(0));
    deal(address(rewardToken), rewardNotifier, _amount);

    vm.startPrank(_rewardNotifier);
    rewardToken.transfer(address(uniStaker), _amount);
    uniStaker.notifyRewardAmount(_amount);
    vm.stopPrank();
  }

  function _boundToRealisticStake(uint256 _stakeAmount)
    public
    pure
    returns (uint256 _boundedStakeAmount)
  {
    _boundedStakeAmount = bound(_stakeAmount, 0.1e18, 25_000_000e18);
  }

  // Helper methods for dumping contract state related to rewards calculation for debugging
  function __dumpDebugGlobalRewards() public view {
    console2.log("reward balance");
    console2.log(rewardToken.balanceOf(address(uniStaker)));
    console2.log("rewardDuration");
    console2.log(uniStaker.REWARD_DURATION());
    console2.log("rewardEndTime");
    console2.log(uniStaker.rewardEndTime());
    console2.log("lastCheckpointTime");
    console2.log(uniStaker.lastCheckpointTime());
    console2.log("totalStake");
    console2.log(uniStaker.totalStaked());
    console2.log("scaledRewardRate");
    console2.log(uniStaker.scaledRewardRate());
    console2.log("block.timestamp");
    console2.log(block.timestamp);
    console2.log("rewardPerTokenAccumulatedCheckpoint");
    console2.log(uniStaker.rewardPerTokenAccumulatedCheckpoint());
    console2.log("lastTimeRewardDistributed()");
    console2.log(uniStaker.lastTimeRewardDistributed());
    console2.log("rewardPerTokenAccumulated()");
    console2.log(uniStaker.rewardPerTokenAccumulated());
    console2.log("-----------------------------------------------");
  }

  function __dumpDebugDepositorRewards(address _depositor) public view {
    console2.log("earningPower[_depositor]");
    console2.log(uniStaker.earningPower(_depositor));
    console2.log("beneficiaryRewardPerTokenCheckpoint[_depositor]");
    console2.log(uniStaker.beneficiaryRewardPerTokenCheckpoint(_depositor));
    console2.log("unclaimedRewardCheckpoint[_depositor]");
    console2.log(uniStaker.unclaimedRewardCheckpoint(_depositor));
    console2.log("unclaimedReward(_depositor)");
    console2.log(uniStaker.unclaimedReward(_depositor));
    console2.log("-----------------------------------------------");
  }
}

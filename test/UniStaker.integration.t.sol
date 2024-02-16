// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Deploy} from "script/Deploy.s.sol";
import {DeployInput} from "script/DeployInput.sol";

import {V3FactoryOwner} from "src/V3FactoryOwner.sol";
import {UniStaker} from "src/UniStaker.sol";
import {IUniswapV3FactoryOwnerActions} from "src/interfaces/IUniswapV3FactoryOwnerActions.sol";
import {IUniswapV3PoolOwnerActions} from "src/interfaces/IUniswapV3PoolOwnerActions.sol";
import {IUniswapPool} from "test/helpers/interfaces/IUniswapPool.sol";
import {PercentAssertions} from "test/helpers/PercentAssertions.sol";
import {IntegrationTest} from "test/helpers/IntegrationTest.sol";

contract DeployScriptTest is Test, DeployInput {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl("mainnet"), 19_114_228);
  }

  function testFork_DeployStakingContracts() public {
    Deploy _deployScript = new Deploy();
    _deployScript.setUp();
    (V3FactoryOwner v3FactoryOwner, UniStaker uniStaker) = _deployScript.run();

    assertEq(v3FactoryOwner.admin(), UNISWAP_GOVERNOR_TIMELOCK);
    assertEq(address(v3FactoryOwner.FACTORY()), address(UNISWAP_V3_FACTORY_ADDRESS));
    assertEq(address(v3FactoryOwner.PAYOUT_TOKEN()), PAYOUT_TOKEN_ADDRESS);
    assertEq(v3FactoryOwner.payoutAmount(), PAYOUT_AMOUNT);
    assertEq(address(v3FactoryOwner.REWARD_RECEIVER()), address(uniStaker));

    assertEq(address(uniStaker.REWARD_TOKEN()), PAYOUT_TOKEN_ADDRESS);
    assertEq(address(uniStaker.STAKE_TOKEN()), STAKE_TOKEN_ADDRESS);
    assertEq(uniStaker.admin(), UNISWAP_GOVERNOR_TIMELOCK);
    assertTrue(uniStaker.isRewardNotifier(address(v3FactoryOwner)));
  }
}

contract Propose is IntegrationTest {
  function testFork_CorrectlyPassAndExecuteProposal() public {
    IUniswapV3FactoryOwnerActions factory =
      IUniswapV3FactoryOwnerActions(UNISWAP_V3_FACTORY_ADDRESS);

    IUniswapPool wbtcWethPool = IUniswapPool(WBTC_WETH_3000_POOL);
    (,,,,, uint8 oldWbtcWethFeeProtocol,) = wbtcWethPool.slot0();

    IUniswapPool daiWethPool = IUniswapPool(DAI_WETH_3000_POOL);
    (,,,,, uint8 oldDaiWethFeeProtocol,) = daiWethPool.slot0();

    IUniswapPool daiUsdcPool = IUniswapPool(DAI_USDC_100_POOL);
    (,,,,, uint8 oldDaiUsdcFeeProtocol,) = daiUsdcPool.slot0();

    _passQueueAndExecuteProposals();

    (,,,,, uint8 newWbtcWethFeeProtocol,) = wbtcWethPool.slot0();
    (,,,,, uint8 newDaiWethFeeProtocol,) = daiWethPool.slot0();
    (,,,,, uint8 newDaiUsdcFeeProtocol,) = daiUsdcPool.slot0();

    assertEq(factory.owner(), address(v3FactoryOwner));

    assertEq(oldWbtcWethFeeProtocol, 0);
    assertEq(oldDaiWethFeeProtocol, 0);
    assertEq(oldDaiUsdcFeeProtocol, 0);

    // The below assert is based off of the slot0.feeProtocol calculation which can be found at
    // https://github.com/Uniswap/v3-core/blob/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb/contracts/UniswapV3Pool.sol#L843.
    //
    // The calculation is feeProtocol0 + (feeProtocol1 << 4)
    assertEq(newWbtcWethFeeProtocol, 10 + (10 << 4));
    assertEq(newDaiWethFeeProtocol, 10 + (10 << 4));
    assertEq(newDaiUsdcFeeProtocol, 10 + (10 << 4));
  }

  function testForkFuzz_CorrectlyEnableFeeAmountAfterProposalIsExecuted(
    uint24 _fee,
    int24 _tickSpacing
  ) public {
    // These bounds are specified in the pool contract
    // https://github.com/Uniswap/v3-core/blob/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb/contracts/UniswapV3Factory.sol#L61
    _fee = uint24(bound(_fee, 0, 999_999));
    _tickSpacing = int24(bound(_tickSpacing, 1, 16_383));

    IUniswapV3FactoryOwnerActions factory =
      IUniswapV3FactoryOwnerActions(UNISWAP_V3_FACTORY_ADDRESS);
    int24 oldTickSpacing = factory.feeAmountTickSpacing(_fee);
    // If the tick spacing is above 0 it will revert
    vm.assume(oldTickSpacing == 0);

    _passQueueAndExecuteProposals();
    vm.prank(UNISWAP_GOVERNOR_TIMELOCK);
    v3FactoryOwner.enableFeeAmount(_fee, _tickSpacing);

    int24 newTickSpacing = factory.feeAmountTickSpacing(_fee);
    assertEq(newTickSpacing, _tickSpacing, "Tick spacing is incorrect for the set fee");
  }

  function testForkFuzz_RevertIf_EnableFeeAmountFeeIsTooHighAfterProposalIsExecuted(
    uint24 _fee,
    int24 _tickSpacing
  ) public {
    _fee = uint24(bound(_fee, 1_000_000, type(uint24).max));

    _passQueueAndExecuteProposals();

    vm.prank(UNISWAP_GOVERNOR_TIMELOCK);
    vm.expectRevert(bytes(""));
    v3FactoryOwner.enableFeeAmount(_fee, _tickSpacing);
  }

  function testForkFuzz_RevertIf_EnableFeeAmountTickSpacingIsTooHighAfterProposalIsExecuted(
    uint24 _fee,
    int24 _tickSpacing
  ) public {
    _tickSpacing = int24(bound(_tickSpacing, 16_383, type(int24).max));

    _passQueueAndExecuteProposals();

    vm.prank(UNISWAP_GOVERNOR_TIMELOCK);
    vm.expectRevert(bytes(""));
    v3FactoryOwner.enableFeeAmount(_fee, _tickSpacing);
  }

  function testForkFuzz_RevertIf_EnableFeeAmountTickSpacingIsTooLowAfterProposalIsExecuted(
    uint24 _fee,
    int24 _tickSpacing
  ) public {
    _tickSpacing = int24(bound(_tickSpacing, type(int24).min, 0));

    _passQueueAndExecuteProposals();

    vm.prank(UNISWAP_GOVERNOR_TIMELOCK);
    vm.expectRevert(bytes(""));
    v3FactoryOwner.enableFeeAmount(_fee, _tickSpacing);
  }

  function testForkFuzz_CorrectlySwapWethAndNotifyRewardAfterProposalIsExecuted(uint128 _amount)
    public
  {
    IERC20 weth = IERC20(payable(WETH_ADDRESS));
    IUniswapPool daiWethPool = IUniswapPool(DAI_WETH_3000_POOL);

    // Amount should be high enough to generate fees
    _amount = uint128(bound(_amount, 1e18, 1_000_000e18));
    uint256 totalWETH = _amount + PAYOUT_AMOUNT;
    vm.deal(address(this), totalWETH);
    deal(address(weth), address(this), totalWETH);

    weth.approve(address(UNISWAP_V3_SWAP_ROUTER), totalWETH);
    weth.approve(address(v3FactoryOwner), totalWETH);

    _passQueueAndExecuteProposals();
    _swapTokens(WETH_ADDRESS, DAI_ADDRESS, _amount);

    (uint128 token0Fees, uint128 token1Fees) = daiWethPool.protocolFees();

    // We subtract 1 to make sure the requested amount is less then the actual fees
    v3FactoryOwner.claimFees(
      IUniswapV3PoolOwnerActions(DAI_WETH_3000_POOL), address(this), token0Fees, token1Fees - 1
    );

    uint256 balance = IERC20(WETH_ADDRESS).balanceOf(address(this));
    assertEq(balance, uint256(token1Fees - 1));
    assertEq(0, token0Fees);
  }

  function testForkFuzz_CorrectlySwapDaiAndNotifyRewardAfterProposalIsExecuted(uint128 _amount)
    public
  {
    IERC20 weth = IERC20(payable(WETH_ADDRESS));
    IERC20 dai = IERC20(payable(DAI_ADDRESS));
    IUniswapPool daiWethPool = IUniswapPool(DAI_WETH_3000_POOL);

    // Amount should be high enough to generate fees
    _amount = uint128(bound(_amount, 1e18, 1_000_000e18));
    uint256 totalDai = _amount;

    vm.deal(address(this), PAYOUT_AMOUNT);
    deal(address(dai), address(this), totalDai, true);
    deal(address(weth), address(this), PAYOUT_AMOUNT);

    dai.approve(address(UNISWAP_V3_SWAP_ROUTER), totalDai);
    weth.approve(address(v3FactoryOwner), PAYOUT_AMOUNT);

    _passQueueAndExecuteProposals();
    _swapTokens(DAI_ADDRESS, WETH_ADDRESS, _amount);

    (uint128 token0Fees, uint128 token1Fees) = daiWethPool.protocolFees();
    // We subtract 1 to make sure the requested amount is less then the actual fees
    v3FactoryOwner.claimFees(
      IUniswapV3PoolOwnerActions(DAI_WETH_3000_POOL), address(this), token0Fees - 1, token1Fees
    );

    uint256 balance = IERC20(DAI_ADDRESS).balanceOf(address(this));
    assertEq(0, token1Fees);
    assertEq(balance, uint256(token0Fees - 1));
  }

  function testForkFuzz_CorrectlySwapDaiAndWETHThenNotifyRewardAfterProposalIsExecuted(
    uint128 _amountDai,
    uint128 _amountWeth
  ) public {
    IERC20 weth = IERC20(payable(WETH_ADDRESS));
    IERC20 dai = IERC20(payable(DAI_ADDRESS));
    IUniswapPool daiWethPool = IUniswapPool(DAI_WETH_3000_POOL);

    // Amount should be high enough to generate fees
    _amountDai = uint128(bound(_amountDai, 1e18, 1_000_000e18));
    _amountWeth = uint128(bound(_amountWeth, 1e18, 1_000_000e18));
    uint256 totalDai = _amountDai;
    uint256 totalWeth = _amountWeth + PAYOUT_AMOUNT;

    vm.deal(address(this), totalWeth);
    deal(address(dai), address(this), totalDai, true);
    deal(address(weth), address(this), totalWeth);

    dai.approve(address(UNISWAP_V3_SWAP_ROUTER), totalDai);
    weth.approve(address(UNISWAP_V3_SWAP_ROUTER), totalWeth);
    weth.approve(address(v3FactoryOwner), PAYOUT_AMOUNT);

    _passQueueAndExecuteProposals();
    _swapTokens(DAI_ADDRESS, WETH_ADDRESS, totalDai);
    _swapTokens(WETH_ADDRESS, DAI_ADDRESS, _amountWeth);

    uint256 originalDaiBalance = IERC20(DAI_ADDRESS).balanceOf(address(this));
    uint256 originalWethBalance = IERC20(WETH_ADDRESS).balanceOf(address(this)) - PAYOUT_AMOUNT;

    (uint128 token0Fees, uint128 token1Fees) = daiWethPool.protocolFees();
    // We subtract 1 to make sure the requested amount is less then the actual fees
    v3FactoryOwner.claimFees(
      IUniswapV3PoolOwnerActions(DAI_WETH_3000_POOL), address(this), token0Fees - 1, token1Fees - 1
    );

    uint256 daiBalance = IERC20(DAI_ADDRESS).balanceOf(address(this));
    uint256 wethBalance = IERC20(WETH_ADDRESS).balanceOf(address(this));
    assertEq(wethBalance - originalWethBalance, token1Fees - 1);
    assertEq(daiBalance - originalDaiBalance, uint256(token0Fees - 1));
  }
}

contract Stake is IntegrationTest, PercentAssertions {
  function testForkFuzz_CorrectlyStakeAndEarnRewardsAfterFullDuration(
    address _depositor,
    uint256 _amount,
    address _delegatee,
    uint128 _swapAmount
  ) public {
    vm.assume(_depositor != address(0) && _delegatee != address(0) && _amount != 0);
    _passQueueAndExecuteProposals();
    _notifyRewards(_swapAmount);
    _amount = _dealStakingToken(_depositor, _amount);

    vm.prank(_depositor);
    uniStaker.stake(_amount, _delegatee);

    _jumpAheadByPercentOfRewardDuration(101);
    assertLteWithinOnePercent(uniStaker.unclaimedReward(address(_depositor)), PAYOUT_AMOUNT);
  }

  function testForkFuzz_CorrectlyStakeAndClaimRewardsAfterFullDuration(
    address _depositor,
    uint256 _amount,
    address _delegatee,
    uint128 _swapAmount
  ) public {
    vm.assume(_depositor != address(0) && _delegatee != address(0) && _amount != 0);
    // Make sure depositor is not UniStaker
    vm.assume(_depositor != 0xE2307e3710d108ceC7a4722a020a050681c835b3);
    _passQueueAndExecuteProposals();
    _notifyRewards(_swapAmount);
    _amount = _dealStakingToken(_depositor, _amount);

    vm.prank(_depositor);
    uniStaker.stake(_amount, _delegatee);

    _jumpAheadByPercentOfRewardDuration(101);
    IERC20 weth = IERC20(WETH_ADDRESS);
    uint256 oldBalance = weth.balanceOf(_depositor);

    vm.prank(_depositor);
    uniStaker.claimReward();

    uint256 newBalance = weth.balanceOf(_depositor);
    assertLteWithinOnePercent(newBalance - oldBalance, PAYOUT_AMOUNT);
    assertEq(uniStaker.unclaimedReward(address(_depositor)), 0);
  }

  function testForkFuzz_CorrectlyStakeAndEarnRewardsAfterPartialDuration(
    address _depositor,
    uint256 _amount,
    address _delegatee,
    uint128 _swapAmount,
    uint256 _percentDuration
  ) public {
    vm.assume(_depositor != address(0) && _delegatee != address(0) && _amount != 0);
    _percentDuration = bound(_percentDuration, 0, 100);
    _passQueueAndExecuteProposals();
    _notifyRewards(_swapAmount);
    _amount = _dealStakingToken(_depositor, _amount);

    vm.prank(_depositor);
    uniStaker.stake(_amount, _delegatee);

    _jumpAheadByPercentOfRewardDuration(100 - _percentDuration);
    assertLteWithinOnePercent(
      uniStaker.unclaimedReward(address(_depositor)),
      _percentOf(PAYOUT_AMOUNT, 100 - _percentDuration)
    );
  }

  function testForkFuzz_CorrectlyStakeMoreAndEarnRewardsAfterFullDuration(
    address _depositor,
    uint256 _initialAmount,
    uint256 _additionalAmount,
    address _delegatee,
    uint128 _swapAmount,
    uint256 _percentDuration
  ) public {
    vm.assume(_depositor != address(0) && _delegatee != address(0));
    _passQueueAndExecuteProposals();
    _notifyRewards(_swapAmount);
    _initialAmount = _dealStakingToken(_depositor, _initialAmount);
    _percentDuration = bound(_percentDuration, 0, 100);

    vm.prank(_depositor);
    UniStaker.DepositIdentifier _depositId = uniStaker.stake(_initialAmount, _delegatee);

    _jumpAheadByPercentOfRewardDuration(100 - _percentDuration);

    _additionalAmount = _dealStakingToken(_depositor, _additionalAmount);
    vm.prank(_depositor);
    uniStaker.stakeMore(_depositId, _additionalAmount);

    _jumpAheadByPercentOfRewardDuration(_percentDuration);
    assertLteWithinOnePercent(uniStaker.unclaimedReward(address(_depositor)), PAYOUT_AMOUNT);
  }

  function testForkFuzz_CorrectlyWithdrawAllStakedTokensAfterFullDuration(
    address _depositor,
    address _delegatee,
    uint128 _swapAmount,
    uint256 _amount
  ) public {
    vm.assume(_depositor != address(0) && _delegatee != address(0) && _amount != 0);
    // Make sure depositor is not UniStaker
    vm.assume(_depositor != 0xE2307e3710d108ceC7a4722a020a050681c835b3);
    _passQueueAndExecuteProposals();
    _notifyRewards(_swapAmount);
    _amount = _dealStakingToken(_depositor, _amount);

    vm.prank(_depositor);
    UniStaker.DepositIdentifier _depositId = uniStaker.stake(_amount, _delegatee);

    _jumpAheadByPercentOfRewardDuration(101);
    IERC20 weth = IERC20(WETH_ADDRESS);
    IERC20 uni = IERC20(STAKE_TOKEN_ADDRESS);
    uint256 oldWethBalance = weth.balanceOf(_depositor);
    uint256 oldUniBalance = uni.balanceOf(_depositor);

    vm.prank(_depositor);
    uniStaker.withdraw(_depositId, _amount);

    uint256 newWethBalance = weth.balanceOf(_depositor);
    uint256 newUniBalance = uni.balanceOf(_depositor);

    assertLteWithinOnePercent(newWethBalance, oldWethBalance);
    assertLteWithinOnePercent(uniStaker.unclaimedReward(address(_depositor)), PAYOUT_AMOUNT);
    assertLteWithinOnePercent(oldUniBalance, 0);
    assertEq(newUniBalance, _amount);
  }

  function testForkFuzz_CorrectlyWithdrawStakedTokensAfterPartialDuration(
    address _depositor,
    uint256 _amount,
    address _delegatee,
    uint128 _swapAmount,
    uint256 _percentDuration
  ) public {
    vm.assume(_depositor != address(0) && _delegatee != address(0) && _amount != 0);
    _percentDuration = bound(_percentDuration, 0, 100);
    _passQueueAndExecuteProposals();
    _notifyRewards(_swapAmount);
    IERC20 uni = IERC20(STAKE_TOKEN_ADDRESS);
    uint256 oldUniBalance = uni.balanceOf(_depositor);

    _amount = _dealStakingToken(_depositor, _amount);

    vm.prank(_depositor);
    UniStaker.DepositIdentifier _depositId = uniStaker.stake(_amount, _delegatee);

    _jumpAheadByPercentOfRewardDuration(100 - _percentDuration);
    vm.prank(_depositor);
    uniStaker.withdraw(_depositId, _amount);

    uint256 newUniBalance = uni.balanceOf(_depositor);

    assertLteWithinOnePercent(
      uniStaker.unclaimedReward(address(_depositor)),
      _percentOf(PAYOUT_AMOUNT, 100 - _percentDuration)
    );
    assertLteWithinOnePercent(oldUniBalance, 0);
    assertEq(newUniBalance, _amount);
  }
}

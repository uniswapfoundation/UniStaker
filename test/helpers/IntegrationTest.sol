// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {console2, stdStorage, StdStorage} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IUniswapV3PoolOwnerActions} from "src/interfaces/IUniswapV3PoolOwnerActions.sol";
import {ISwapRouter} from "v3-periphery/interfaces/ISwapRouter.sol";
import {ProposalTest} from "test/helpers/ProposalTest.sol";
import {IERC20Mint} from "test/helpers/interfaces/IERC20Mint.sol";

contract IntegrationTest is ProposalTest {
  using stdStorage for StdStorage;

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

  function _dealPayoutTokenAndApproveFactoryOwner() internal {
    IERC20 weth = IERC20(payable(WETH_ADDRESS));
    weth.approve(address(v3FactoryOwner), PAYOUT_AMOUNT);
    vm.deal(address(this), PAYOUT_AMOUNT);
    deal(address(weth), address(this), PAYOUT_AMOUNT);
  }

  function _dealDaiAndApproveRouter(uint128 _amountDai) internal returns (uint256) {
    _amountDai = uint128(bound(_amountDai, 1e18, 1_000_000e18));
    IERC20 dai = IERC20(payable(DAI_ADDRESS));
    dai.approve(address(UNISWAP_V3_SWAP_ROUTER), _amountDai);
    deal(address(dai), address(this), _amountDai, true);
    return _amountDai;
  }

  function _generateFees(uint128 _amount) internal {
    uint256 _amountDai = _dealDaiAndApproveRouter(_amount);
    _swapTokens(DAI_ADDRESS, WETH_ADDRESS, _amountDai);
  }

  function _notifyRewards(uint128 _amount) internal {
    _dealPayoutTokenAndApproveFactoryOwner();
    _generateFees(_amount);
    v3FactoryOwner.claimFees(IUniswapV3PoolOwnerActions(DAI_WETH_3000_POOL), address(this), 1, 0);
  }

  function _dealStakingToken(address _depositor, uint256 _amount) internal returns (uint256) {
    stdstore.target(STAKE_TOKEN_ADDRESS).sig("mintingAllowedAfter()").checked_write(uint256(0));
    _amount = bound(_amount, 1, 2e25); // max mint cap
    IERC20Mint stakeToken = IERC20Mint(STAKE_TOKEN_ADDRESS);

    vm.prank(STAKING_TOKEN_MINTER);
    stakeToken.mint(_depositor, _amount);

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
}

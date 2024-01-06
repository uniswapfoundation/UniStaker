// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {IUniswapV3PoolOwnerActions} from "src/interfaces/IUniswapV3PoolOwnerActions.sol";
import {IUniswapV3FactoryOwnerActions} from "src/interfaces/IUniswapV3FactoryOwnerActions.sol";
import {INotifiableRewardReceiver} from "src/interfaces/INotifiableRewardReceiver.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract V3FactoryOwner {
  using SafeERC20 for IERC20;

  address public admin;
  IUniswapV3FactoryOwnerActions public immutable FACTORY;
  IERC20 public immutable PAYOUT_TOKEN;
  uint256 public immutable PAYOUT_AMOUNT;
  INotifiableRewardReceiver public immutable REWARD_RECEIVER;

  event AdminUpdated(address indexed oldAmin, address indexed newAdmin);
  event FeesClaimed(
    address indexed pool,
    address indexed caller,
    address indexed recipient,
    uint256 amount0,
    uint256 amount1
  );

  error V3FactoryOwner__Unauthorized();
  error V3FactoryOwner__InvalidAddress();

  constructor(
    address _admin,
    IUniswapV3FactoryOwnerActions _factory,
    IERC20 _payoutToken,
    uint256 _payoutAmount,
    INotifiableRewardReceiver _rewardReceiver
  ) {
    if (_admin == address(0)) revert V3FactoryOwner__InvalidAddress();
    admin = _admin;
    FACTORY = _factory;
    PAYOUT_TOKEN = _payoutToken;
    PAYOUT_AMOUNT = _payoutAmount;
    REWARD_RECEIVER = _rewardReceiver;
  }

  function setAdmin(address _newAdmin) external {
    _revertIfNotAdmin();
    if (_newAdmin == address(0)) revert V3FactoryOwner__InvalidAddress();
    emit AdminUpdated(admin, _newAdmin);
    admin = _newAdmin;
  }

  function transferFactoryOwnership(address _newOwner) external {
    _revertIfNotAdmin();
    FACTORY.setOwner(_newOwner);
  }

  function enableFeeAmount(uint24 _fee, int24 _tickSpacing) external {
    _revertIfNotAdmin();
    FACTORY.enableFeeAmount(_fee, _tickSpacing);
  }

  function claimFees(
    IUniswapV3PoolOwnerActions _pool,
    address _recipient,
    uint128 _amount0Requested,
    uint128 _amount1Requested
  ) external {
    PAYOUT_TOKEN.safeTransferFrom(msg.sender, address(REWARD_RECEIVER), PAYOUT_AMOUNT);
    REWARD_RECEIVER.notifyRewardsAmount(PAYOUT_AMOUNT);
    (uint128 _amount0, uint128 _amount1) =
      _pool.collectProtocol(_recipient, _amount0Requested, _amount1Requested);

    emit FeesClaimed(address(_pool), msg.sender, _recipient, _amount0, _amount1);
  }

  function _revertIfNotAdmin() internal view {
    if (msg.sender != admin) revert V3FactoryOwner__Unauthorized();
  }
}

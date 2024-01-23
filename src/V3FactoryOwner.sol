// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {IUniswapV3PoolOwnerActions} from "src/interfaces/IUniswapV3PoolOwnerActions.sol";
import {IUniswapV3FactoryOwnerActions} from "src/interfaces/IUniswapV3FactoryOwnerActions.sol";
import {INotifiableRewardReceiver} from "src/interfaces/INotifiableRewardReceiver.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

/// @title V3FactoryOwner
/// @author ScopeLift
/// @notice A contract that can serve as the owner of the Uniswap v3 factory. This contract itself
/// has an admin. That admin retains the exclusive right to call privileged methods on the v3
/// factory, and on pools which it has deployed, via passthrough methods. This includes the ability
/// to enable fee amounts on the factory, and set protocol fees on individual pools. The admin can
/// also set a new admin.
///
/// One privileged function that is _not_ reserved exclusively for the admin is the ability to
/// collect protocol fees from a pool. This method is instead exposed publicly by this contract's
/// `claimFees` method. That method collects fees from the protocol as long as the caller pays for
/// them with a transfer of a designated amount of a designated token. That payout is forwarded
/// to a rewards receiver.
///
/// In the context of the broader system, it is expected that this contract's REWARD_RECEIVER is
/// a deployment of the `UniStaker` contract. It is expected the admin of this contract will be the
/// Uniswap Governance timelock. It is expected governance will transfer
/// ownership of the factory to an instance of this contract, and turn on protocol fees for select
/// pools. It is also expected a competitive market of seekers will emerge racing to "buy" the fees
/// for an arbitrage opportunity.
contract V3FactoryOwner {
  using SafeERC20 for IERC20;

  /// @notice The address that can call privileged methods, including passthrough owner functions
  /// to the factory itself.
  address public admin;

  /// @notice The instance of the Uniswap v3 factory contract which this contract will own.
  IUniswapV3FactoryOwnerActions public immutable FACTORY;

  /// @notice The ERC-20 token which must be used to pay for fees when claiming pool fees.
  IERC20 public immutable PAYOUT_TOKEN;

  /// @notice The raw amount of the payout token which is paid by a user when claiming pool fees.
  uint256 public immutable PAYOUT_AMOUNT;

  /// @notice The contract that receives the payout and is notified via method call, when pool fees
  /// are claimed.
  INotifiableRewardReceiver public immutable REWARD_RECEIVER;

  /// @notice Emitted when the existing admin designates a new address as the admin.
  event AdminSet(address indexed oldAmin, address indexed newAdmin);

  /// @notice Emitted when a user pays the payout and claims the fees from a given v3 pool.
  /// @param pool The v3 pool from which protocol fees were claimed.
  /// @param caller The address which executes the call to claim the fees.
  /// @param recipient The address to which the claimed pool fees are sent.
  /// @param amount0 The raw amount of token0 fees claimed from the pool.
  /// @param amount1 The raw amount token1 fees claimed from the pool.
  event FeesClaimed(
    address indexed pool,
    address indexed caller,
    address indexed recipient,
    uint256 amount0,
    uint256 amount1
  );

  /// @notice Thrown when an unauthorized account calls a privileged function.
  error V3FactoryOwner__Unauthorized();

  /// @notice Thrown if the proposed admin is the zero address.
  error V3FactoryOwner__InvalidAddress();

  /// @param _admin The initial admin address for this deployment. Cannot be zero address.
  /// @param _factory The v3 factory instance for which this deployment will serve as owner.
  /// @param _payoutToken The ERC-20 token in which payouts will be denominated.
  /// @param _payoutAmount The raw amount of the payout token required to claim fees from a pool.
  /// @param _rewardReceiver The contract that will receive the payout when fees are claimed.
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

  /// @notice Pass the admin role to a new address. Must be called by the existing admin.
  /// @param _newAdmin The address that will be the admin after this call completes.
  function setAdmin(address _newAdmin) external {
    _revertIfNotAdmin();
    if (_newAdmin == address(0)) revert V3FactoryOwner__InvalidAddress();
    emit AdminSet(admin, _newAdmin);
    admin = _newAdmin;
  }

  /// @notice Passthrough method that transfers ownership of the factory from this contract to a
  /// specified new address. Must be called by the admin.
  /// @param _newOwner The address that will serve as the factory's owner after this call
  /// completes.
  function transferFactoryOwnership(address _newOwner) external {
    _revertIfNotAdmin();
    FACTORY.setOwner(_newOwner);
  }

  /// @notice Passthrough method that enables a fee amount on the factory. Must be called by the
  /// admin.
  /// @param _fee The fee param to forward to the factory.
  /// @param _tickSpacing The tick spacing param to forward to the factory.
  /// @dev See docs on IUniswapV3FactoryOwnerActions for more information on forwarded params.
  function enableFeeAmount(uint24 _fee, int24 _tickSpacing) external {
    _revertIfNotAdmin();
    FACTORY.enableFeeAmount(_fee, _tickSpacing);
  }

  /// @notice Passthrough method that sets the protocol fee on a v3 pool. Must be called by the
  /// admin.
  /// @param _pool The Uniswap v3 pool on which the protocol fee is being set.
  /// @param _feeProtocol0 The fee protocol 0 param to forward to the pool.
  /// @param _feeProtocol1 The fee protocol 1 parm to forward to the pool.
  /// @dev See docs on IUniswapV3PoolOwnerActions for more information on forwarded params.
  function setFeeProtocol(
    IUniswapV3PoolOwnerActions _pool,
    uint8 _feeProtocol0,
    uint8 _feeProtocol1
  ) external {
    _revertIfNotAdmin();
    _pool.setFeeProtocol(_feeProtocol0, _feeProtocol1);
  }

  /// @notice Public method that allows any caller to claim the protocol fees accrued by a given
  /// Uniswap v3 pool contract. Caller must pre-approve this factory owner contract on the payout
  /// token contract for at least the payout amount, which is transferred from the caller to the
  /// reward receiver. The reward receiver is "notified" of the payout via a method call. The
  /// protocol fees collected are sent to a receiver of the caller's specification.
  ///
  /// A quick example can help illustrate why an external party, such as an MEV searcher, would be
  /// incentivized to call this method. Imagine, purely for the sake of example, that protocol fees
  /// have been activated for the USDC/USDT stablecoin v3 pool. Imagine also the payout token and
  /// payout amount are WETH and 10e18 respectively. Finally, assume the spot USD price of ETH is
  /// $2,500, and both stablecoins are trading at their $1 peg. As regular users trade against the
  /// USDC/USDT pool, protocol fees amass in the pool contract in both stablecoins. Once the fees
  /// in the pool total more than 25,000 in stablecoins, it becomes profitable for an external
  /// party to arbitrage the fees by calling this method, paying 10 WETH (worth $25K) and getting
  /// more than $25K worth of stablecoins. (This ignores other details, which real searchers would
  /// take into consideration, such as the gas/builder fee they would pay to call the method).
  ///
  /// The same mechanic applies regardless of what the pool currencies, payout token, or payout
  /// amount are. Effectively, as each pool accrues fees, it eventually becomes possible to "buy"
  /// the pool fees for less than they are valued by "paying" the the payout amount of the payout
  /// token.
  /// @param _pool The Uniswap v3 pool contract from which protocol fees are being collected.
  /// @param _recipient The address to which collected protocol fees will be transferred.
  /// @param _amount0Requested The amount0Requested param to forward to the pool's collectProtocol
  /// method.
  /// @param _amount1Requested The amount1Requested param to forward to the pool's collectProtocol
  /// method.
  /// @dev See docs on IUniswapV3PoolOwnerActions for more information on forwarded params.
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

  /// @notice Ensures the msg.sender is the contract admin and reverts otherwise.
  /// @dev Place inside external methods to make them admin-only.
  function _revertIfNotAdmin() internal view {
    if (msg.sender != admin) revert V3FactoryOwner__Unauthorized();
  }
}

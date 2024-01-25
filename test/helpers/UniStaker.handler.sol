// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console} from "forge-std/console.sol";
import {AddressSet, LibAddressSet} from "../helpers/AddressSet.sol";
import {UniStaker} from "src/UniStaker.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

contract UniStakerHandler is CommonBase, StdCheats, StdUtils {
  using LibAddressSet for AddressSet;

  // system setup
  UniStaker public uniStaker;
  IERC20 public stakeToken;
  IERC20 public rewardToken;
  address public admin;

  // actors, deposit state
  address internal currentActor;
  AddressSet internal _depositors;
  AddressSet internal _delegates;
  AddressSet internal _beneficiaries;
  AddressSet internal _surrogates;
  AddressSet internal _rewardNotifiers;
  mapping(address => uint256[]) internal _depositIds;
  mapping(bytes32 => uint256) public calls;

  // ghost vars
  uint256 public ghost_stakeSum;
  uint256 public ghost_stakeWithdrawn;
  uint256 public ghost_depositCount;
  uint256 public ghost_rewardsClaimed;
  uint256 public ghost_rewardsNotified;

  modifier countCall(bytes32 key) {
    calls[key]++;
    _;
  }

  constructor(UniStaker _uniStaker) {
    uniStaker = _uniStaker;
    stakeToken = IERC20(address(_uniStaker.STAKE_TOKEN()));
    rewardToken = IERC20(address(_uniStaker.REWARD_TOKEN()));
    admin = uniStaker.admin();
  }

  function _mintStakeToken(address _to, uint256 _amount) internal {
    vm.assume(_to != address(0));
    deal(address(stakeToken), _to, _amount, true);
  }

  function _mintRewardToken(address _to, uint256 _amount) internal {
    vm.assume(_to != address(0));
    deal(address(rewardToken), _to, _amount, true);
  }

  function enableRewardNotifier(address _notifier) public countCall("enableRewardNotifier") {
    vm.assume(_notifier != address(0));
    _rewardNotifiers.add(_notifier);
    vm.prank(admin);
    uniStaker.setRewardNotifier(_notifier, true);
  }

  function notifyRewardAmount(uint256 _amount, uint256 _actorSeed)
    public
    countCall("notifyRewardAmount")
  {
    _useActor(_rewardNotifiers, _actorSeed);
    vm.assume(currentActor != address(0));
    _amount = bound(_amount, 0, 100_000_000e18);
    _mintRewardToken(currentActor, _amount);
    vm.startPrank(currentActor);
    rewardToken.transfer(address(uniStaker), _amount);
    uniStaker.notifyRewardAmount(_amount);
    vm.stopPrank();
    ghost_rewardsNotified += _amount;
  }

  // TODO: distinguish between valid and invalid stake
  function stake(uint256 _amount, address _delegatee, address _beneficiary)
    public
    countCall("stake")
  {
    _createDepositor();

    _beneficiaries.add(_beneficiary);
    _delegates.add(_delegatee);
    // todo: adjust upper bound
    _amount = bound(_amount, 0, 100_000_000e18);

    // assume user has stake amount
    _mintStakeToken(currentActor, _amount);

    vm.startPrank(currentActor);
    stakeToken.approve(address(uniStaker), _amount);
    uniStaker.stake(_amount, _delegatee, _beneficiary);
    vm.stopPrank();

    // update handler state
    _depositIds[currentActor].push(ghost_depositCount);
    ghost_depositCount++;
    _surrogates.add(address(uniStaker.surrogates(_delegatee)));
    ghost_stakeSum += _amount;
  }

  function validStakeMore(uint256 _amount, uint256 _actorSeed, uint256 _actorDepositSeed)
    public
    countCall("validStakeMore")
  {
    _useActor(_depositors, _actorSeed);
    vm.assume(currentActor != address(0));
    vm.assume(_depositIds[currentActor].length > 0);
    UniStaker.DepositIdentifier _depositId =
      UniStaker.DepositIdentifier.wrap(_getActorRandDepositId(_actorDepositSeed));
    (uint256 _balance,,,) = uniStaker.deposits(_depositId);
    _amount = bound(_amount, 0, _balance);
    vm.startPrank(currentActor);
    stakeToken.approve(address(uniStaker), _amount);
    uniStaker.stakeMore(_depositId, _amount);
    vm.stopPrank();
    ghost_stakeSum += _amount;
  }

  // TODO: include invalid withdrawals
  function validWithdraw(uint256 _amount, uint256 _actorSeed, uint256 _actorDepositSeed)
    public
    countCall("validWithdraw")
  {
    _useActor(_depositors, _actorSeed);
    vm.assume(currentActor != address(0));
    vm.assume(_depositIds[currentActor].length > 0);
    UniStaker.DepositIdentifier _depositId =
      UniStaker.DepositIdentifier.wrap(_getActorRandDepositId(_actorDepositSeed));
    (uint256 _balance,,,) = uniStaker.deposits(_depositId);
    _amount = bound(_amount, 0, _balance);
    vm.startPrank(currentActor);
    uniStaker.withdraw(_depositId, _amount);
    vm.stopPrank();
    ghost_stakeWithdrawn += _amount;
  }

  function claimReward(uint256 _actorSeed) public countCall("claimReward") {
    _useActor(_beneficiaries, _actorSeed);
    vm.startPrank(currentActor);
    uint256 rewardsClaimed = uniStaker.unclaimedRewardCheckpoint(currentActor);
    uniStaker.claimReward();
    vm.stopPrank();
    ghost_rewardsClaimed += rewardsClaimed;
  }

  function warpAhead(uint256 _seconds) public countCall("warpAhead") {
    _seconds = bound(_seconds, 0, uniStaker.REWARD_DURATION() * 2);
    skip(_seconds);
  }

  function _getActorRandDepositId(uint256 _randomDepositSeed) internal view returns (uint256) {
    return _depositIds[currentActor][_randomDepositSeed % _depositIds[currentActor].length];
  }

  function _createDepositor() internal {
    currentActor = msg.sender;
    // Surrogates can't stake. We won't include them as potential depositors.
    vm.assume(!_surrogates.contains(currentActor));
    _depositors.add(msg.sender);
  }

  function _useActor(AddressSet storage _set, uint256 _randomActorSeed) internal {
    currentActor = _set.rand(_randomActorSeed);
  }

  function reduceDepositors(uint256 acc, function(uint256,address) external returns (uint256) func)
    public
    returns (uint256)
  {
    return _depositors.reduce(acc, func);
  }

  function reduceBeneficiaries(
    uint256 acc,
    function(uint256,address) external returns (uint256) func
  ) public returns (uint256) {
    return _beneficiaries.reduce(acc, func);
  }

  function reduceDelegates(uint256 acc, function(uint256,address) external returns (uint256) func)
    public
    returns (uint256)
  {
    return _delegates.reduce(acc, func);
  }

  function callSummary() external view {
    console.log("\nCall summary:");
    console.log("-------------------");
    console.log("stake", calls["stake"]);
    console.log("validStakeMore", calls["validStakeMore"]);
    console.log("validWithdraw", calls["validWithdraw"]);
    console.log("claimReward", calls["claimReward"]);
    console.log("enableRewardNotifier", calls["enableRewardNotifier"]);
    console.log("notifyRewardAmount", calls["notifyRewardAmount"]);
    console.log("warpAhead", calls["warpAhead"]);
    console.log("-------------------\n");
  }

  receive() external payable {}
}

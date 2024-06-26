// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {Vm, Test, stdStorage, StdStorage, console2} from "forge-std/Test.sol";
import {UniStaker, DelegationSurrogate, IERC20, IERC20Delegates} from "src/UniStaker.sol";
import {UniStakerHarness} from "test/harnesses/UniStakerHarness.sol";
import {ERC20VotesMock, ERC20Permit} from "test/mocks/MockERC20Votes.sol";
import {IERC20Errors} from "openzeppelin/interfaces/draft-IERC6093.sol";
import {ERC20Fake} from "test/fakes/ERC20Fake.sol";
import {PercentAssertions} from "test/helpers/PercentAssertions.sol";

contract UniStakerTest is Test, PercentAssertions {
  ERC20Fake rewardToken;
  ERC20VotesMock govToken;
  address admin;
  address rewardNotifier;
  UniStakerHarness uniStaker;
  uint256 SCALE_FACTOR;
  // console2.log(uint(_domainSeparatorV4()))
  bytes32 EIP712_DOMAIN_SEPARATOR = bytes32(
    uint256(
      108_300_748_413_663_721_746_865_897_746_851_483_791_898_864_552_448_882_835_473_754_343_054_398_579_494
    )
  );

  bytes32 constant PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

  event RewardNotifierSet(address indexed account, bool isEnabled);
  event AdminSet(address indexed oldAdmin, address indexed newAdmin);

  mapping(DelegationSurrogate surrogate => bool isKnown) isKnownSurrogate;
  mapping(address depositor => bool isKnown) isKnownDepositor;

  function setUp() public {
    // Set the block timestamp to an arbitrary value to avoid introducing assumptions into tests
    // based on a starting timestamp of 0, which is the default.
    _jumpAhead(1234);

    rewardToken = new ERC20Fake();
    vm.label(address(rewardToken), "Reward Token");

    govToken = new ERC20VotesMock();
    vm.label(address(govToken), "Governance Token");

    rewardNotifier = address(0xaffab1ebeef);
    vm.label(rewardNotifier, "Reward Notifier");

    admin = makeAddr("admin");

    uniStaker = new UniStakerHarness(rewardToken, govToken, admin);
    vm.label(address(uniStaker), "UniStaker");

    vm.prank(admin);
    uniStaker.setRewardNotifier(rewardNotifier, true);

    // Convenience for use in tests
    SCALE_FACTOR = uniStaker.SCALE_FACTOR();
  }

  function _jumpAhead(uint256 _seconds) public {
    vm.warp(block.timestamp + _seconds);
  }

  function _boundMintAmount(uint96 _amount) internal pure returns (uint96) {
    return uint96(bound(_amount, 0, 100_000_000e18));
  }

  function _mintGovToken(address _to, uint96 _amount) internal {
    vm.assume(_to != address(0));
    govToken.mint(_to, _amount);
  }

  function _boundToRealisticStake(uint96 _stakeAmount)
    public
    pure
    returns (uint96 _boundedStakeAmount)
  {
    _boundedStakeAmount = uint96(bound(_stakeAmount, 0.1e18, 25_000_000e18));
  }

  // Remember each depositor and surrogate (as they're deployed) and ensure that there is
  // no overlap between them. This is to prevent the fuzzer from selecting a surrogate as a
  // depositor or vice versa.
  function _assumeSafeDepositorAndSurrogate(address _depositor, address _delegatee) internal {
    DelegationSurrogate _surrogate = uniStaker.surrogates(_delegatee);
    isKnownDepositor[_depositor] = true;
    isKnownSurrogate[_surrogate] = true;

    vm.assume(
      (!isKnownSurrogate[DelegationSurrogate(_depositor)])
        && (!isKnownDepositor[address(_surrogate)])
    );
  }

  function _stake(address _depositor, uint96 _amount, address _delegatee)
    internal
    returns (UniStaker.DepositIdentifier _depositId)
  {
    vm.assume(_delegatee != address(0));

    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _amount);
    _depositId = uniStaker.stake(_amount, _delegatee);
    vm.stopPrank();

    // Called after the stake so the surrogate will exist
    _assumeSafeDepositorAndSurrogate(_depositor, _delegatee);
  }

  function _stake(address _depositor, uint96 _amount, address _delegatee, address _beneficiary)
    internal
    returns (UniStaker.DepositIdentifier _depositId)
  {
    vm.assume(_delegatee != address(0) && _beneficiary != address(0));

    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _amount);
    _depositId = uniStaker.stake(_amount, _delegatee, _beneficiary);
    vm.stopPrank();

    // Called after the stake so the surrogate will exist
    _assumeSafeDepositorAndSurrogate(_depositor, _delegatee);
  }

  function _fetchDeposit(UniStaker.DepositIdentifier _depositId)
    internal
    view
    returns (UniStaker.Deposit memory)
  {
    (uint96 _balance, address _owner, address _delegatee, address _beneficiary) =
      uniStaker.deposits(_depositId);
    return UniStaker.Deposit({
      balance: _balance,
      owner: _owner,
      delegatee: _delegatee,
      beneficiary: _beneficiary
    });
  }

  function _boundMintAndStake(address _depositor, uint96 _amount, address _delegatee)
    internal
    returns (uint96 _boundedAmount, UniStaker.DepositIdentifier _depositId)
  {
    _boundedAmount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _boundedAmount);
    _depositId = _stake(_depositor, _boundedAmount, _delegatee);
  }

  function _boundMintAndStake(
    address _depositor,
    uint96 _amount,
    address _delegatee,
    address _beneficiary
  ) internal returns (uint96 _boundedAmount, UniStaker.DepositIdentifier _depositId) {
    _boundedAmount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _boundedAmount);
    _depositId = _stake(_depositor, _boundedAmount, _delegatee, _beneficiary);
  }

  // Scales first param and divides it by second
  function _scaledDiv(uint256 _x, uint256 _y) public view returns (uint256) {
    return (_x * SCALE_FACTOR) / _y;
  }

  function _sign(uint256 _privateKey, bytes32 _messageHash) internal pure returns (bytes memory) {
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_privateKey, _messageHash);
    return abi.encodePacked(_r, _s, _v);
  }

  function _modifyMessage(bytes32 _message, uint256 _index) internal pure returns (bytes32) {
    _index = bound(_index, 0, 31);
    bytes memory _messageBytes = abi.encodePacked(_message);
    // zero out the byte at the given index, or set it to 1 if it's already zero
    if (_messageBytes[_index] == 0) _messageBytes[_index] = bytes1(uint8(1));
    else _messageBytes[_index] = bytes1(uint8(0));
    return bytes32(_messageBytes);
  }

  function _modifySignature(bytes memory _signature, uint256 _index)
    internal
    pure
    returns (bytes memory)
  {
    _index = bound(_index, 0, _signature.length - 1);
    // zero out the byte at the given index, or set it to 1 if it's already zero
    if (_signature[_index] == 0) _signature[_index] = bytes1(uint8(1));
    else _signature[_index] = bytes1(uint8(0));
    return _signature;
  }
}

contract Constructor is UniStakerTest {
  function test_SetsTheRewardTokenStakeTokenAndRewardNotifier() public {
    assertEq(address(uniStaker.REWARD_TOKEN()), address(rewardToken));
    assertEq(address(uniStaker.STAKE_TOKEN()), address(govToken));
    assertEq(uniStaker.admin(), admin);
  }

  function testFuzz_SetsTheRewardTokenStakeTokenAndOwnerToArbitraryAddresses(
    address _rewardToken,
    address _stakeToken,
    address _admin
  ) public {
    vm.assume(_admin != address(0));
    UniStaker _uniStaker = new UniStaker(IERC20(_rewardToken), IERC20Delegates(_stakeToken), _admin);
    assertEq(address(_uniStaker.REWARD_TOKEN()), address(_rewardToken));
    assertEq(address(_uniStaker.STAKE_TOKEN()), address(_stakeToken));
    assertEq(_uniStaker.admin(), _admin);
  }
}

contract Stake is UniStakerTest {
  function testFuzz_DeploysAndTransfersTokensToANewSurrogateWhenAnAccountStakes(
    address _depositor,
    uint96 _amount,
    address _delegatee
  ) public {
    _amount = uint96(bound(_amount, 1, type(uint96).max));
    _mintGovToken(_depositor, _amount);
    _stake(_depositor, _amount, _delegatee);

    DelegationSurrogate _surrogate = uniStaker.surrogates(_delegatee);

    assertEq(govToken.balanceOf(address(_surrogate)), _amount);
    assertEq(govToken.delegates(address(_surrogate)), _delegatee);
    assertEq(govToken.balanceOf(_depositor), 0);
  }

  function testFuzz_EmitsAStakingDepositEventWhenStakingWithoutASpecifiedBeneficiary(
    address _depositor,
    uint96 _amount,
    address _delegatee
  ) public {
    _amount = uint96(bound(_amount, 1, type(uint96).max));
    _mintGovToken(_depositor, _amount);
    UniStaker.DepositIdentifier depositId = uniStaker.exposed_useDepositId();

    vm.assume(_delegatee != address(0));

    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _amount);
    vm.expectEmit();
    emit UniStaker.StakeDeposited(
      _depositor,
      UniStaker.DepositIdentifier.wrap(UniStaker.DepositIdentifier.unwrap(depositId) + 1),
      _amount,
      _amount
    );

    uniStaker.stake(_amount, _delegatee);
    vm.stopPrank();
  }

  function testFuzz_EmitsABeneficiaryAlteredEventWhenStakingWithoutASpecifiedBeneficiary(
    address _depositor,
    uint96 _amount,
    address _delegatee
  ) public {
    _amount = uint96(bound(_amount, 1, type(uint96).max));
    _mintGovToken(_depositor, _amount);
    UniStaker.DepositIdentifier depositId = uniStaker.exposed_useDepositId();

    vm.assume(_delegatee != address(0));

    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _amount);
    vm.expectEmit();
    emit UniStaker.BeneficiaryAltered(
      UniStaker.DepositIdentifier.wrap(UniStaker.DepositIdentifier.unwrap(depositId) + 1),
      address(0),
      _depositor
    );

    uniStaker.stake(_amount, _delegatee);
    vm.stopPrank();
  }

  function testFuzz_EmitsADelegateeAlteredEventWhenStakingWithoutASpecifiedBeneficiary(
    address _depositor,
    uint96 _amount,
    address _delegatee
  ) public {
    _amount = uint96(bound(_amount, 1, type(uint96).max));
    _mintGovToken(_depositor, _amount);
    UniStaker.DepositIdentifier depositId = uniStaker.exposed_useDepositId();

    vm.assume(_delegatee != address(0));

    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _amount);
    vm.expectEmit();
    emit UniStaker.DelegateeAltered(
      UniStaker.DepositIdentifier.wrap(UniStaker.DepositIdentifier.unwrap(depositId) + 1),
      address(0),
      _delegatee
    );

    uniStaker.stake(_amount, _delegatee);
    vm.stopPrank();
  }

  function testFuzz_EmitsAStakingDepositEventWhenStakingWithASpecifiedBeneficiary(
    address _depositor,
    uint96 _amount,
    address _delegatee,
    address _beneficiary
  ) public {
    _amount = uint96(bound(_amount, 1, type(uint96).max));
    _mintGovToken(_depositor, _amount);
    UniStaker.DepositIdentifier depositId = uniStaker.exposed_useDepositId();

    vm.assume(_delegatee != address(0) && _beneficiary != address(0));

    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _amount);
    vm.expectEmit();
    emit UniStaker.StakeDeposited(
      _depositor,
      UniStaker.DepositIdentifier.wrap(UniStaker.DepositIdentifier.unwrap(depositId) + 1),
      _amount,
      _amount
    );

    uniStaker.stake(_amount, _delegatee, _beneficiary);
    vm.stopPrank();
  }

  function testFuzz_EmitsABeneficiaryAlteredEventWhenStakingWithASpecifiedBeneficiary(
    address _depositor,
    uint96 _amount,
    address _delegatee,
    address _beneficiary
  ) public {
    _amount = uint96(bound(_amount, 1, type(uint96).max));
    _mintGovToken(_depositor, _amount);
    UniStaker.DepositIdentifier depositId = uniStaker.exposed_useDepositId();

    vm.assume(_delegatee != address(0) && _beneficiary != address(0));

    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _amount);
    vm.expectEmit();
    emit UniStaker.BeneficiaryAltered(
      UniStaker.DepositIdentifier.wrap(UniStaker.DepositIdentifier.unwrap(depositId) + 1),
      address(0),
      _beneficiary
    );

    uniStaker.stake(_amount, _delegatee, _beneficiary);
    vm.stopPrank();
  }

  function testFuzz_EmitsADelegateeAlteredEventWhenStakingWithASpecifiedBeneficiary(
    address _depositor,
    uint96 _amount,
    address _delegatee,
    address _beneficiary
  ) public {
    _amount = uint96(bound(_amount, 1, type(uint96).max));
    _mintGovToken(_depositor, _amount);
    UniStaker.DepositIdentifier depositId = uniStaker.exposed_useDepositId();

    vm.assume(_delegatee != address(0) && _beneficiary != address(0));

    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _amount);
    vm.expectEmit();
    emit UniStaker.DelegateeAltered(
      UniStaker.DepositIdentifier.wrap(UniStaker.DepositIdentifier.unwrap(depositId) + 1),
      address(0),
      _delegatee
    );

    uniStaker.stake(_amount, _delegatee, _beneficiary);
    vm.stopPrank();
  }

  function testFuzz_TransfersToAnExistingSurrogateWhenStakedToTheSameDelegatee(
    address _depositor1,
    uint96 _amount1,
    address _depositor2,
    uint96 _amount2,
    address _delegatee
  ) public {
    _amount1 = _boundMintAmount(_amount1);
    _amount2 = _boundMintAmount(_amount2);
    _mintGovToken(_depositor1, _amount1);
    _mintGovToken(_depositor2, _amount2);

    // Perform first stake with this delegatee
    _stake(_depositor1, _amount1, _delegatee);
    // Remember the surrogate which was deployed for this delegatee
    DelegationSurrogate _surrogate = uniStaker.surrogates(_delegatee);

    // Perform the second stake with this delegatee
    _stake(_depositor2, _amount2, _delegatee);

    // Ensure surrogate for this delegatee hasn't changed and has summed stake balance
    assertEq(address(uniStaker.surrogates(_delegatee)), address(_surrogate));
    assertEq(govToken.delegates(address(_surrogate)), _delegatee);
    assertEq(govToken.balanceOf(address(_surrogate)), _amount1 + _amount2);
    assertEq(govToken.balanceOf(_depositor1), 0);
    assertEq(govToken.balanceOf(_depositor2), 0);
  }

  function testFuzz_DeploysAndTransfersTokenToTwoSurrogatesWhenAccountsStakesToDifferentDelegatees(
    address _depositor1,
    uint96 _amount1,
    address _depositor2,
    uint96 _amount2,
    address _delegatee1,
    address _delegatee2
  ) public {
    vm.assume(_delegatee1 != _delegatee2);
    _amount1 = _boundMintAmount(_amount1);
    _amount2 = _boundMintAmount(_amount2);
    _mintGovToken(_depositor1, _amount1);
    _mintGovToken(_depositor2, _amount2);

    // Perform first stake with first delegatee
    _stake(_depositor1, _amount1, _delegatee1);
    // Remember the surrogate which was deployed for first delegatee
    DelegationSurrogate _surrogate1 = uniStaker.surrogates(_delegatee1);

    // Perform second stake with second delegatee
    _stake(_depositor2, _amount2, _delegatee2);
    // Remember the surrogate which was deployed for first delegatee
    DelegationSurrogate _surrogate2 = uniStaker.surrogates(_delegatee2);

    // Ensure surrogates are different with discreet delegation & balances
    assertTrue(_surrogate1 != _surrogate2);
    assertEq(govToken.delegates(address(_surrogate1)), _delegatee1);
    assertEq(govToken.balanceOf(address(_surrogate1)), _amount1);
    assertEq(govToken.delegates(address(_surrogate2)), _delegatee2);
    assertEq(govToken.balanceOf(address(_surrogate2)), _amount2);
    assertEq(govToken.balanceOf(_depositor1), 0);
    assertEq(govToken.balanceOf(_depositor2), 0);
  }

  function testFuzz_UpdatesTheTotalStakedWhenAnAccountStakes(
    address _depositor,
    uint96 _amount,
    address _delegatee
  ) public {
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);

    _stake(_depositor, _amount, _delegatee);

    assertEq(uniStaker.totalStaked(), _amount);
  }

  function testFuzz_UpdatesTheTotalStakedWhenTwoAccountsStake(
    address _depositor1,
    uint96 _amount1,
    address _depositor2,
    uint96 _amount2,
    address _delegatee1,
    address _delegatee2
  ) public {
    _amount1 = _boundMintAmount(_amount1);
    _amount2 = _boundMintAmount(_amount2);
    _mintGovToken(_depositor1, _amount1);
    _mintGovToken(_depositor2, _amount2);

    _stake(_depositor1, _amount1, _delegatee1);
    assertEq(uniStaker.totalStaked(), _amount1);

    _stake(_depositor2, _amount2, _delegatee2);
    assertEq(uniStaker.totalStaked(), _amount1 + _amount2);
  }

  function testFuzz_UpdatesAnAccountsTotalStakedAccounting(
    address _depositor,
    uint96 _amount1,
    uint96 _amount2,
    address _delegatee1,
    address _delegatee2
  ) public {
    _amount1 = _boundMintAmount(_amount1);
    _amount2 = _boundMintAmount(_amount2);
    _mintGovToken(_depositor, _amount1 + _amount2);

    // First stake + check total
    _stake(_depositor, _amount1, _delegatee1);
    assertEq(uniStaker.depositorTotalStaked(_depositor), _amount1);

    // Second stake + check total
    _stake(_depositor, _amount2, _delegatee2);
    assertEq(uniStaker.depositorTotalStaked(_depositor), _amount1 + _amount2);
  }

  function testFuzz_UpdatesDifferentAccountsTotalStakedAccountingIndependently(
    address _depositor1,
    uint96 _amount1,
    address _depositor2,
    uint96 _amount2,
    address _delegatee1,
    address _delegatee2
  ) public {
    vm.assume(_depositor1 != _depositor2);
    _amount1 = _boundMintAmount(_amount1);
    _amount2 = _boundMintAmount(_amount2);
    _mintGovToken(_depositor1, _amount1);
    _mintGovToken(_depositor2, _amount2);

    _stake(_depositor1, _amount1, _delegatee1);
    assertEq(uniStaker.depositorTotalStaked(_depositor1), _amount1);

    _stake(_depositor2, _amount2, _delegatee2);
    assertEq(uniStaker.depositorTotalStaked(_depositor2), _amount2);
  }

  function testFuzz_TracksTheBalanceForASpecificDeposit(
    address _depositor,
    uint96 _amount,
    address _delegatee
  ) public {
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);

    UniStaker.DepositIdentifier _depositId = _stake(_depositor, _amount, _delegatee);
    UniStaker.Deposit memory _deposit = _fetchDeposit(_depositId);
    assertEq(_deposit.balance, _amount);
    assertEq(_deposit.owner, _depositor);
    assertEq(_deposit.delegatee, _delegatee);
  }

  function testFuzz_TracksTheBalanceForDifferentDepositsFromTheSameAccountIndependently(
    address _depositor,
    uint96 _amount1,
    uint96 _amount2,
    address _delegatee1,
    address _delegatee2
  ) public {
    _amount1 = _boundMintAmount(_amount1);
    _amount2 = _boundMintAmount(_amount2);
    _mintGovToken(_depositor, _amount1 + _amount2);

    // Perform both deposits and track their identifiers separately
    UniStaker.DepositIdentifier _depositId1 = _stake(_depositor, _amount1, _delegatee1);
    UniStaker.DepositIdentifier _depositId2 = _stake(_depositor, _amount2, _delegatee2);
    UniStaker.Deposit memory _deposit1 = _fetchDeposit(_depositId1);
    UniStaker.Deposit memory _deposit2 = _fetchDeposit(_depositId2);

    // Check that the deposits have been recorded independently
    assertEq(_deposit1.balance, _amount1);
    assertEq(_deposit1.owner, _depositor);
    assertEq(_deposit1.delegatee, _delegatee1);
    assertEq(_deposit2.balance, _amount2);
    assertEq(_deposit2.owner, _depositor);
    assertEq(_deposit2.delegatee, _delegatee2);
  }

  function testFuzz_TracksTheBalanceForDepositsFromDifferentAccountsIndependently(
    address _depositor1,
    address _depositor2,
    uint96 _amount1,
    uint96 _amount2,
    address _delegatee1,
    address _delegatee2
  ) public {
    _amount1 = _boundMintAmount(_amount1);
    _amount2 = _boundMintAmount(_amount2);
    _mintGovToken(_depositor1, _amount1);
    _mintGovToken(_depositor2, _amount2);

    // Perform both deposits and track their identifiers separately
    UniStaker.DepositIdentifier _depositId1 = _stake(_depositor1, _amount1, _delegatee1);
    UniStaker.DepositIdentifier _depositId2 = _stake(_depositor2, _amount2, _delegatee2);
    UniStaker.Deposit memory _deposit1 = _fetchDeposit(_depositId1);
    UniStaker.Deposit memory _deposit2 = _fetchDeposit(_depositId2);

    // Check that the deposits have been recorded independently
    assertEq(_deposit1.balance, _amount1);
    assertEq(_deposit1.owner, _depositor1);
    assertEq(_deposit1.delegatee, _delegatee1);
    assertEq(_deposit2.balance, _amount2);
    assertEq(_deposit2.owner, _depositor2);
    assertEq(_deposit2.delegatee, _delegatee2);
  }

  function testFuzz_AssignsEarningPowerToDepositorIfNoBeneficiaryIsSpecified(
    address _depositor,
    uint96 _amount,
    address _delegatee
  ) public {
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);

    UniStaker.DepositIdentifier _depositId = _stake(_depositor, _amount, _delegatee);
    UniStaker.Deposit memory _deposit = _fetchDeposit(_depositId);

    assertEq(uniStaker.earningPower(_depositor), _amount);
    assertEq(_deposit.beneficiary, _depositor);
  }

  function testFuzz_AssignsEarningPowerToTheBeneficiaryProvided(
    address _depositor,
    uint96 _amount,
    address _delegatee,
    address _beneficiary
  ) public {
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);

    UniStaker.DepositIdentifier _depositId = _stake(_depositor, _amount, _delegatee, _beneficiary);
    UniStaker.Deposit memory _deposit = _fetchDeposit(_depositId);

    assertEq(uniStaker.earningPower(_beneficiary), _amount);
    assertEq(_deposit.beneficiary, _beneficiary);
  }

  function testFuzz_AssignsEarningPowerToDifferentBeneficiariesForDifferentDepositsFromTheSameDepositor(
    address _depositor,
    uint96 _amount1,
    uint96 _amount2,
    address _delegatee,
    address _beneficiary1,
    address _beneficiary2
  ) public {
    vm.assume(_beneficiary1 != _beneficiary2);
    _amount1 = _boundMintAmount(_amount1);
    _amount2 = _boundMintAmount(_amount2);
    _mintGovToken(_depositor, _amount1 + _amount2);

    // Perform both deposits and track their identifiers separately
    UniStaker.DepositIdentifier _depositId1 =
      _stake(_depositor, _amount1, _delegatee, _beneficiary1);
    UniStaker.DepositIdentifier _depositId2 =
      _stake(_depositor, _amount2, _delegatee, _beneficiary2);
    UniStaker.Deposit memory _deposit1 = _fetchDeposit(_depositId1);
    UniStaker.Deposit memory _deposit2 = _fetchDeposit(_depositId2);

    // Check that the earning power has been recorded independently
    assertEq(_deposit1.beneficiary, _beneficiary1);
    assertEq(uniStaker.earningPower(_beneficiary1), _amount1);
    assertEq(_deposit2.beneficiary, _beneficiary2);
    assertEq(uniStaker.earningPower(_beneficiary2), _amount2);
  }

  function testFuzz_AssignsEarningPowerToTheSameBeneficiarySpecifiedByTwoDifferentDepositors(
    address _depositor1,
    address _depositor2,
    uint96 _amount1,
    uint96 _amount2,
    address _delegatee,
    address _beneficiary
  ) public {
    _amount1 = _boundMintAmount(_amount1);
    _amount2 = _boundMintAmount(_amount2);
    _mintGovToken(_depositor1, _amount1);
    _mintGovToken(_depositor2, _amount2);

    // Perform both deposits and track their identifiers separately
    UniStaker.DepositIdentifier _depositId1 =
      _stake(_depositor1, _amount1, _delegatee, _beneficiary);
    UniStaker.DepositIdentifier _depositId2 =
      _stake(_depositor2, _amount2, _delegatee, _beneficiary);
    UniStaker.Deposit memory _deposit1 = _fetchDeposit(_depositId1);
    UniStaker.Deposit memory _deposit2 = _fetchDeposit(_depositId2);

    assertEq(_deposit1.beneficiary, _beneficiary);
    assertEq(_deposit2.beneficiary, _beneficiary);
    assertEq(uniStaker.earningPower(_beneficiary), _amount1 + _amount2);
  }

  mapping(UniStaker.DepositIdentifier depositId => bool isUsed) isIdUsed;

  function test_NeverReusesADepositIdentifier() public {
    address _depositor = address(0xdeadbeef);
    uint96 _amount = 116;
    address _delegatee = address(0xaceface);

    UniStaker.DepositIdentifier _depositId;

    // Repeat the deposit over and over ensuring a new DepositIdentifier is assigned each time.
    for (uint256 _i; _i < 5000; _i++) {
      // Perform the stake and save the deposit identifier
      _mintGovToken(_depositor, _amount);
      _depositId = _stake(_depositor, _amount, _delegatee);

      // Ensure the identifier hasn't yet been used
      assertFalse(isIdUsed[_depositId]);
      // Record the fact this deposit Id has been used
      isIdUsed[_depositId] = true;
    }

    // Now make a bunch more deposits with different depositors and parameters, continuing to check
    // that the DepositIdentifier is never reused.
    for (uint256 _i; _i < 5000; _i++) {
      // Perform the stake and save the deposit identifier
      _amount = uint96(bound(_amount, 0, 100_000_000_000e18));
      _mintGovToken(_depositor, _amount);
      _depositId = _stake(_depositor, _amount, _delegatee);

      // Ensure the identifier hasn't yet been used
      assertFalse(isIdUsed[_depositId]);
      // Record the fact this deposit Id has been used
      isIdUsed[_depositId] = true;

      // Assign new inputs for the next deposit by hashing the last inputs
      _depositor = address(uint160(uint256(keccak256(abi.encode(_depositor)))));
      _amount = uint96(uint256(keccak256(abi.encode(_amount))));
      _delegatee = address(uint160(uint256(keccak256(abi.encode(_delegatee)))));
    }
  }

  function testFuzz_RevertIf_DelegateeIsTheZeroAddress(address _depositor, uint96 _amount) public {
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);
    govToken.approve(address(uniStaker), _amount);

    vm.prank(_depositor);
    vm.expectRevert(UniStaker.UniStaker__InvalidAddress.selector);
    uniStaker.stake(_amount, address(0));
  }

  function testFuzz_RevertIf_BeneficiaryIsTheZeroAddress(
    address _depositor,
    uint96 _amount,
    address _delegatee
  ) public {
    vm.assume(_delegatee != address(0));

    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);
    govToken.approve(address(uniStaker), _amount);

    vm.prank(_depositor);
    vm.expectRevert(UniStaker.UniStaker__InvalidAddress.selector);
    uniStaker.stake(_amount, _delegatee, address(0));
  }
}

contract PermitAndStake is UniStakerTest {
  using stdStorage for StdStorage;

  function testFuzz_PerformsTheApprovalByCallingPermitThenPerformsStake(
    uint256 _depositorPrivateKey,
    uint96 _depositAmount,
    address _delegatee,
    address _beneficiary,
    uint256 _deadline,
    uint256 _currentNonce
  ) public {
    vm.assume(_delegatee != address(0) && _beneficiary != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _depositAmount = _boundMintAmount(_depositAmount);
    _mintGovToken(_depositor, _depositAmount);

    stdstore.target(address(govToken)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    bytes32 _message = keccak256(
      abi.encode(
        PERMIT_TYPEHASH,
        _depositor,
        address(uniStaker),
        _depositAmount,
        govToken.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", govToken.DOMAIN_SEPARATOR(), _message));
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_depositorPrivateKey, _messageHash);

    vm.prank(_depositor);
    UniStaker.DepositIdentifier _depositId =
      uniStaker.permitAndStake(_depositAmount, _delegatee, _beneficiary, _deadline, _v, _r, _s);
    UniStaker.Deposit memory _deposit = _fetchDeposit(_depositId);

    assertEq(_deposit.balance, _depositAmount);
    assertEq(_deposit.owner, _depositor);
    assertEq(_deposit.delegatee, _delegatee);
    assertEq(_deposit.beneficiary, _beneficiary);
  }

  function testFuzz_SuccessfullyStakeWhenApprovalExistsAndPermitSignatureIsInvalid(
    uint256 _depositorPrivateKey,
    uint96 _depositAmount,
    uint256 _approvalAmount,
    address _delegatee,
    address _beneficiary
  ) public {
    vm.assume(_delegatee != address(0) && _beneficiary != address(0));
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _depositAmount = _boundMintAmount(_depositAmount);
    _approvalAmount = bound(_approvalAmount, _depositAmount, type(uint256).max);
    _mintGovToken(_depositor, _depositAmount);
    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _approvalAmount);
    vm.stopPrank();

    bytes32 _message = keccak256(
      abi.encode(
        PERMIT_TYPEHASH,
        _depositor,
        address(uniStaker),
        _depositAmount,
        1, // intentionally wrong nonce
        block.timestamp
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", govToken.DOMAIN_SEPARATOR(), _message));
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_depositorPrivateKey, _messageHash);

    vm.prank(_depositor);
    uniStaker.permitAndStake(_depositAmount, _delegatee, _beneficiary, block.timestamp, _v, _r, _s);
    assertEq(uniStaker.depositorTotalStaked(_depositor), _depositAmount);
  }

  function testFuzz_RevertIf_ThePermitSignatureIsInvalidAndTheApprovalIsInsufficient(
    address _notDepositor,
    uint256 _depositorPrivateKey,
    uint96 _depositAmount,
    uint256 _approvalAmount,
    address _delegatee,
    address _beneficiary,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _beneficiary != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    vm.assume(_notDepositor != _depositor);
    _depositAmount = _boundMintAmount(_depositAmount) + 1;
    _approvalAmount = bound(_approvalAmount, 0, _depositAmount - 1);
    _mintGovToken(_depositor, _depositAmount);
    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _approvalAmount);
    vm.stopPrank();

    bytes32 _message = keccak256(
      abi.encode(
        PERMIT_TYPEHASH,
        _notDepositor,
        address(uniStaker),
        _depositAmount,
        govToken.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", govToken.DOMAIN_SEPARATOR(), _message));
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_depositorPrivateKey, _messageHash);

    vm.prank(_depositor);
    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(uniStaker),
        _approvalAmount,
        _depositAmount
      )
    );
    uniStaker.permitAndStake(_depositAmount, _delegatee, _beneficiary, _deadline, _v, _r, _s);
  }
}

contract StakeOnBehalf is UniStakerTest {
  using stdStorage for StdStorage;

  function testFuzz_StakesOnBehalfOfAnotherAccount(
    uint256 _depositorPrivateKey,
    address _sender,
    uint96 _depositAmount,
    address _delegatee,
    address _beneficiary,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _beneficiary != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _depositAmount = _boundMintAmount(_depositAmount);
    _mintGovToken(_depositor, _depositAmount);

    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    vm.prank(_depositor);
    govToken.approve(address(uniStaker), _depositAmount);

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.STAKE_TYPEHASH(),
        _depositAmount,
        _delegatee,
        _beneficiary,
        _depositor,
        uniStaker.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.prank(_sender);
    UniStaker.DepositIdentifier _depositId = uniStaker.stakeOnBehalf(
      _depositAmount, _delegatee, _beneficiary, _depositor, _deadline, _signature
    );

    UniStaker.Deposit memory _deposit = _fetchDeposit(_depositId);

    assertEq(_deposit.balance, _depositAmount);
    assertEq(_deposit.owner, _depositor);
    assertEq(_deposit.delegatee, _delegatee);
    assertEq(_deposit.beneficiary, _beneficiary);
  }

  function testFuzz_RevertIf_WrongNonceIsUsed(
    uint256 _depositorPrivateKey,
    address _sender,
    uint96 _depositAmount,
    address _delegatee,
    address _beneficiary,
    uint256 _currentNonce,
    uint256 _suppliedNonce,
    uint256 _deadline
  ) public {
    vm.assume(_currentNonce != _suppliedNonce);
    vm.assume(_delegatee != address(0) && _beneficiary != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _depositAmount = _boundMintAmount(_depositAmount);
    _mintGovToken(_depositor, _depositAmount);

    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    vm.prank(_depositor);
    govToken.approve(address(uniStaker), _depositAmount);

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.STAKE_TYPEHASH(),
        _depositAmount,
        _delegatee,
        _beneficiary,
        _depositor,
        _suppliedNonce,
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.expectRevert(UniStaker.UniStaker__InvalidSignature.selector);
    vm.prank(_sender);
    uniStaker.stakeOnBehalf(
      _depositAmount, _delegatee, _beneficiary, _depositor, _deadline, _signature
    );
  }

  function testFuzz_RevertIf_DeadlineExpired(
    uint256 _depositorPrivateKey,
    address _sender,
    uint96 _depositAmount,
    address _delegatee,
    address _beneficiary,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _beneficiary != address(0) && _sender != address(0));
    _deadline = bound(_deadline, 0, block.timestamp - 1);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _depositAmount = _boundMintAmount(_depositAmount);
    _mintGovToken(_depositor, _depositAmount);

    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    vm.prank(_depositor);
    govToken.approve(address(uniStaker), _depositAmount);

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.STAKE_TYPEHASH(),
        _depositAmount,
        _delegatee,
        _beneficiary,
        _depositor,
        _currentNonce,
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.expectRevert(UniStaker.UniStaker__ExpiredDeadline.selector);
    vm.prank(_sender);
    uniStaker.stakeOnBehalf(
      _depositAmount, _delegatee, _beneficiary, _depositor, _deadline, _signature
    );
  }

  function testFuzz_RevertIf_InvalidSignatureIsPassed(
    uint256 _depositorPrivateKey,
    address _sender,
    uint96 _depositAmount,
    address _delegatee,
    address _beneficiary,
    uint256 _currentNonce,
    uint256 _randomSeed,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _beneficiary != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );
    _depositAmount = _boundMintAmount(_depositAmount);
    _mintGovToken(_depositor, _depositAmount);

    vm.prank(_depositor);
    govToken.approve(address(uniStaker), _depositAmount);

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.STAKE_TYPEHASH(),
        _depositAmount,
        _delegatee,
        _beneficiary,
        _depositor,
        uniStaker.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));

    // Here we use `_randomSeed` as an arbitrary source of randomness to replace a legit parameter
    // with an attack-like one.
    if (_randomSeed % 6 == 0) {
      _depositAmount = uint96(uint256(keccak256(abi.encode(_depositAmount))));
    } else if (_randomSeed % 6 == 1) {
      _delegatee = address(uint160(uint256(keccak256(abi.encode(_delegatee)))));
    } else if (_randomSeed % 6 == 2) {
      _depositor = address(uint160(uint256(keccak256(abi.encode(_depositor)))));
    } else if (_randomSeed % 6 == 3) {
      _messageHash = _modifyMessage(_messageHash, uint256(keccak256(abi.encode(_randomSeed))));
    } else if (_randomSeed % 6 == 4) {
      _deadline = uint256(keccak256(abi.encode(_deadline)));
    }
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);
    if (_randomSeed % 6 == 5) _signature = _modifySignature(_signature, _randomSeed);

    vm.prank(_sender);
    vm.expectRevert(UniStaker.UniStaker__InvalidSignature.selector);
    uniStaker.stakeOnBehalf(
      _depositAmount, _delegatee, _beneficiary, _depositor, _deadline, _signature
    );
  }
}

contract StakeMore is UniStakerTest {
  function testFuzz_TransfersStakeToTheExistingSurrogate(
    address _depositor,
    uint96 _depositAmount,
    uint96 _addAmount,
    address _delegatee,
    address _beneficiary
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _beneficiary);
    UniStaker.Deposit memory _deposit = _fetchDeposit(_depositId);
    DelegationSurrogate _surrogate = uniStaker.surrogates(_deposit.delegatee);

    _addAmount = _boundToRealisticStake(_addAmount);
    _mintGovToken(_depositor, _addAmount);

    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _addAmount);
    uniStaker.stakeMore(_depositId, _addAmount);
    vm.stopPrank();

    assertEq(govToken.balanceOf(address(_surrogate)), _depositAmount + _addAmount);
  }

  function testFuzz_AddsToExistingBeneficiaryEarningPower(
    address _depositor,
    uint96 _depositAmount,
    uint96 _addAmount,
    address _delegatee,
    address _beneficiary
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _beneficiary);

    _addAmount = _boundToRealisticStake(_addAmount);
    _mintGovToken(_depositor, _addAmount);

    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _addAmount);
    uniStaker.stakeMore(_depositId, _addAmount);
    vm.stopPrank();

    assertEq(uniStaker.earningPower(_beneficiary), _depositAmount + _addAmount);
  }

  function testFuzz_AddsToTheTotalStaked(
    address _depositor,
    uint96 _depositAmount,
    uint96 _addAmount,
    address _delegatee,
    address _beneficiary
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _beneficiary);

    _addAmount = _boundToRealisticStake(_addAmount);
    _mintGovToken(_depositor, _addAmount);

    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _addAmount);
    uniStaker.stakeMore(_depositId, _addAmount);
    vm.stopPrank();

    assertEq(uniStaker.totalStaked(), _depositAmount + _addAmount);
  }

  function testFuzz_AddsToDepositorsTotalStaked(
    address _depositor,
    uint96 _depositAmount,
    uint96 _addAmount,
    address _delegatee,
    address _beneficiary
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _beneficiary);

    _addAmount = _boundToRealisticStake(_addAmount);
    _mintGovToken(_depositor, _addAmount);

    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _addAmount);
    uniStaker.stakeMore(_depositId, _addAmount);
    vm.stopPrank();

    assertEq(uniStaker.depositorTotalStaked(_depositor), _depositAmount + _addAmount);
  }

  function testFuzz_AddsToTheDepositBalance(
    address _depositor,
    uint96 _depositAmount,
    uint96 _addAmount,
    address _delegatee,
    address _beneficiary
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _beneficiary);

    _addAmount = _boundToRealisticStake(_addAmount);
    _mintGovToken(_depositor, _addAmount);

    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _addAmount);
    uniStaker.stakeMore(_depositId, _addAmount);
    vm.stopPrank();

    UniStaker.Deposit memory _deposit = _fetchDeposit(_depositId);

    assertEq(_deposit.balance, _depositAmount + _addAmount);
  }

  function testFuzz_EmitsAnEventWhenStakingMore(
    address _depositor,
    uint96 _depositAmount,
    uint96 _addAmount,
    address _delegatee,
    address _beneficiary
  ) public {
    uint96 _totalAdditionalStake;
    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _beneficiary);
    // Second stake
    _boundMintAndStake(_depositor, _depositAmount, _delegatee, _beneficiary);

    _addAmount = _boundToRealisticStake(_addAmount);
    _totalAdditionalStake = _addAmount * 2;
    _mintGovToken(_depositor, _totalAdditionalStake);

    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _addAmount * 2);

    uniStaker.stakeMore(_depositId, _addAmount);

    vm.expectEmit();
    emit UniStaker.StakeDeposited(
      _depositor, _depositId, _addAmount, _depositAmount + _totalAdditionalStake
    );

    uniStaker.stakeMore(_depositId, _addAmount);
    vm.stopPrank();
  }

  function testFuzz_RevertIf_TheCallerIsNotTheDepositor(
    address _depositor,
    address _notDepositor,
    uint96 _depositAmount,
    uint96 _addAmount,
    address _delegatee,
    address _beneficiary
  ) public {
    vm.assume(_notDepositor != _depositor);

    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _beneficiary);

    _addAmount = _boundToRealisticStake(_addAmount);
    _mintGovToken(_depositor, _addAmount);

    vm.prank(_depositor);
    govToken.approve(address(uniStaker), _addAmount);

    vm.prank(_notDepositor);
    vm.expectRevert(
      abi.encodeWithSelector(
        UniStaker.UniStaker__Unauthorized.selector, bytes32("not owner"), _notDepositor
      )
    );
    uniStaker.stakeMore(_depositId, _addAmount);
  }

  function testFuzz_RevertIf_TheDepositIdentifierIsInvalid(
    address _depositor,
    UniStaker.DepositIdentifier _depositId,
    uint96 _addAmount
  ) public {
    vm.assume(_depositor != address(0));
    _addAmount = _boundToRealisticStake(_addAmount);

    // Since no deposits have been made yet, all DepositIdentifiers are invalid, and any call to
    // add stake to one should revert. We rely on the default owner of any uninitialized deposit
    // being address zero, which means the address attempting to alter it won't be able to.
    vm.prank(_depositor);
    vm.expectRevert(
      abi.encodeWithSelector(
        UniStaker.UniStaker__Unauthorized.selector, bytes32("not owner"), _depositor
      )
    );
    uniStaker.stakeMore(_depositId, _addAmount);
  }
}

contract PermitAndStakeMore is UniStakerTest {
  using stdStorage for StdStorage;

  function testFuzz_PerformsTheApprovalByCallingPermitThenPerformsStakeMore(
    uint256 _depositorPrivateKey,
    uint96 _initialDepositAmount,
    uint96 _stakeMoreAmount,
    address _delegatee,
    address _beneficiary,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _beneficiary != address(0));
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);

    UniStaker.DepositIdentifier _depositId;
    (_initialDepositAmount, _depositId) =
      _boundMintAndStake(_depositor, _initialDepositAmount, _delegatee, _beneficiary);

    _stakeMoreAmount = _boundToRealisticStake(_stakeMoreAmount);
    _mintGovToken(_depositor, _stakeMoreAmount);

    stdstore.target(address(govToken)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    // Separate scope to avoid stack to deep errors
    {
      bytes32 _message = keccak256(
        abi.encode(
          PERMIT_TYPEHASH,
          _depositor,
          address(uniStaker),
          _stakeMoreAmount,
          govToken.nonces(_depositor),
          _deadline
        )
      );

      bytes32 _messageHash =
        keccak256(abi.encodePacked("\x19\x01", govToken.DOMAIN_SEPARATOR(), _message));
      (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_depositorPrivateKey, _messageHash);

      vm.prank(_depositor);
      uniStaker.permitAndStakeMore(_depositId, _stakeMoreAmount, _deadline, _v, _r, _s);
    }

    UniStaker.Deposit memory _deposit = _fetchDeposit(_depositId);

    assertEq(_deposit.balance, _initialDepositAmount + _stakeMoreAmount);
    assertEq(_deposit.owner, _depositor);
    assertEq(_deposit.delegatee, _delegatee);
    assertEq(_deposit.beneficiary, _beneficiary);
  }

  function testFuzz_SuccessfullyStakeMoreWhenApprovalExistsAndPermitSignatureIsInvalid(
    uint96 _initialDepositAmount,
    uint96 _stakeMoreAmount,
    uint256 _approvalAmount,
    address _delegatee,
    address _beneficiary
  ) public {
    vm.assume(_delegatee != address(0) && _beneficiary != address(0));
    (address _depositor, uint256 _depositorPrivateKey) = makeAddrAndKey("depositor");
    UniStaker.DepositIdentifier _depositId;
    (_initialDepositAmount, _depositId) =
      _boundMintAndStake(_depositor, _initialDepositAmount, _delegatee, _beneficiary);
    _stakeMoreAmount = uint96(bound(_stakeMoreAmount, 0, type(uint96).max - _initialDepositAmount));
    _approvalAmount = bound(_approvalAmount, _stakeMoreAmount, type(uint256).max);
    _mintGovToken(_depositor, _stakeMoreAmount);
    vm.prank(_depositor);
    govToken.approve(address(uniStaker), _approvalAmount);

    bytes32 _message = keccak256(
      abi.encode(
        PERMIT_TYPEHASH,
        _depositor,
        address(uniStaker),
        _stakeMoreAmount,
        1, // intentionally incorrect nonce, which should be 0
        block.timestamp + 10_000
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", govToken.DOMAIN_SEPARATOR(), _message));

    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_depositorPrivateKey, _messageHash);

    vm.prank(_depositor);
    uniStaker.permitAndStakeMore(_depositId, _stakeMoreAmount, block.timestamp, _v, _r, _s);
    assertEq(uniStaker.depositorTotalStaked(_depositor), _initialDepositAmount + _stakeMoreAmount);
  }

  function testFuzz_RevertIf_CallerIsNotTheDepositOwner(
    address _depositor,
    uint256 _notDepositorPrivateKey,
    uint96 _initialDepositAmount,
    uint96 _stakeMoreAmount,
    address _delegatee,
    address _beneficiary,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _beneficiary != address(0));
    _notDepositorPrivateKey = bound(_notDepositorPrivateKey, 1, 100e18);
    address _notDepositor = vm.addr(_notDepositorPrivateKey);
    vm.assume(_depositor != _notDepositor);
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);

    UniStaker.DepositIdentifier _depositId;
    (_initialDepositAmount, _depositId) =
      _boundMintAndStake(_depositor, _initialDepositAmount, _delegatee, _beneficiary);

    _stakeMoreAmount = _boundToRealisticStake(_stakeMoreAmount);
    _mintGovToken(_depositor, _stakeMoreAmount);

    // Separate scope to avoid stack to deep errors
    {
      bytes32 _message = keccak256(
        abi.encode(
          PERMIT_TYPEHASH,
          _notDepositor,
          address(uniStaker),
          _stakeMoreAmount,
          govToken.nonces(_depositor),
          _deadline
        )
      );

      bytes32 _messageHash =
        keccak256(abi.encodePacked("\x19\x01", govToken.DOMAIN_SEPARATOR(), _message));
      (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_notDepositorPrivateKey, _messageHash);

      vm.prank(_notDepositor);
      vm.expectRevert(
        abi.encodeWithSelector(
          UniStaker.UniStaker__Unauthorized.selector, bytes32("not owner"), _notDepositor
        )
      );
      uniStaker.permitAndStakeMore(_depositId, _stakeMoreAmount, _deadline, _v, _r, _s);
    }
  }

  function testFuzz_RevertIf_ThePermitSignatureIsInvalidAndTheApprovalIsInsufficient(
    uint96 _initialDepositAmount,
    address _delegatee,
    address _beneficiary
  ) public {
    vm.assume(_delegatee != address(0) && _beneficiary != address(0));

    // We can't fuzz the these values because we need to pre-compute the invalid
    // recovered signer so we can expect it in the revert error message thrown
    (address _depositor, uint256 _depositorPrivateKey) = makeAddrAndKey("depositor");
    uint96 _stakeMoreAmount = 1578e18;
    uint256 _deadline = 1e18 days;
    uint256 _wrongNonce = 1;
    uint256 _approvalAmount = _stakeMoreAmount - 1;

    UniStaker.DepositIdentifier _depositId;
    (_initialDepositAmount, _depositId) =
      _boundMintAndStake(_depositor, _initialDepositAmount, _delegatee, _beneficiary);
    _mintGovToken(_depositor, _stakeMoreAmount);
    vm.prank(_depositor);
    govToken.approve(address(uniStaker), _approvalAmount);

    bytes32 _message = keccak256(
      abi.encode(
        PERMIT_TYPEHASH,
        _depositor,
        address(uniStaker),
        _stakeMoreAmount,
        _wrongNonce, // intentionally incorrect nonce, which should be 0
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", govToken.DOMAIN_SEPARATOR(), _message));

    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_depositorPrivateKey, _messageHash);

    vm.prank(_depositor);
    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(uniStaker),
        _approvalAmount,
        _stakeMoreAmount
      )
    );
    uniStaker.permitAndStakeMore(_depositId, _stakeMoreAmount, _deadline, _v, _r, _s);
  }
}

contract StakeMoreOnBehalf is UniStakerTest {
  using stdStorage for StdStorage;

  function testFuzz_StakeMoreOnBehalfOfDepositor(
    uint256 _depositorPrivateKey,
    address _sender,
    uint96 _initialDepositAmount,
    uint96 _stakeMoreAmount,
    address _delegatee,
    address _beneficiary,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _beneficiary != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);

    UniStaker.DepositIdentifier _depositId;
    (_initialDepositAmount, _depositId) =
      _boundMintAndStake(_depositor, _initialDepositAmount, _delegatee, _beneficiary);
    UniStaker.Deposit memory _deposit = _fetchDeposit(_depositId);

    _stakeMoreAmount = _boundToRealisticStake(_stakeMoreAmount);
    _mintGovToken(_depositor, _stakeMoreAmount);

    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _stakeMoreAmount);
    vm.stopPrank();

    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.STAKE_MORE_TYPEHASH(),
        _depositId,
        _stakeMoreAmount,
        _depositor,
        uniStaker.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.prank(_sender);
    uniStaker.stakeMoreOnBehalf(_depositId, _stakeMoreAmount, _depositor, _deadline, _signature);

    _deposit = _fetchDeposit(_depositId);

    assertEq(_deposit.balance, _initialDepositAmount + _stakeMoreAmount);
    assertEq(_deposit.owner, _depositor);
    assertEq(_deposit.delegatee, _delegatee);
    assertEq(_deposit.beneficiary, _beneficiary);
  }

  function testFuzz_RevertIf_WrongNonceIsUsed(
    uint256 _depositorPrivateKey,
    address _sender,
    uint96 _initialDepositAmount,
    uint96 _stakeMoreAmount,
    address _delegatee,
    address _beneficiary,
    uint256 _currentNonce,
    uint256 _suppliedNonce,
    uint256 _deadline
  ) public {
    vm.assume(_currentNonce != _suppliedNonce);
    vm.assume(_delegatee != address(0) && _beneficiary != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _initialDepositAmount = _boundMintAmount(_initialDepositAmount);
    _mintGovToken(_depositor, _initialDepositAmount);
    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    UniStaker.DepositIdentifier _depositId;
    (_initialDepositAmount, _depositId) =
      _boundMintAndStake(_depositor, _initialDepositAmount, _delegatee, _beneficiary);

    _stakeMoreAmount = _boundToRealisticStake(_stakeMoreAmount);
    _mintGovToken(_depositor, _stakeMoreAmount);

    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _stakeMoreAmount);
    vm.stopPrank();

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.STAKE_MORE_TYPEHASH(),
        _depositId,
        _stakeMoreAmount,
        _depositor,
        _suppliedNonce,
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.expectRevert(UniStaker.UniStaker__InvalidSignature.selector);
    vm.prank(_sender);
    uniStaker.stakeMoreOnBehalf(_depositId, _stakeMoreAmount, _depositor, _deadline, _signature);
  }

  function testFuzz_RevertIf_DeadlineExpired(
    uint256 _depositorPrivateKey,
    address _sender,
    uint96 _initialDepositAmount,
    uint96 _stakeMoreAmount,
    address _delegatee,
    address _beneficiary,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _beneficiary != address(0) && _sender != address(0));
    _deadline = bound(_deadline, 0, block.timestamp - 1);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _initialDepositAmount = _boundMintAmount(_initialDepositAmount);
    _mintGovToken(_depositor, _initialDepositAmount);
    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    UniStaker.DepositIdentifier _depositId;
    (_initialDepositAmount, _depositId) =
      _boundMintAndStake(_depositor, _initialDepositAmount, _delegatee, _beneficiary);

    _stakeMoreAmount = _boundToRealisticStake(_stakeMoreAmount);
    _mintGovToken(_depositor, _stakeMoreAmount);

    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _stakeMoreAmount);
    vm.stopPrank();

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.STAKE_MORE_TYPEHASH(),
        _depositId,
        _stakeMoreAmount,
        _depositor,
        _currentNonce,
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.expectRevert(UniStaker.UniStaker__ExpiredDeadline.selector);
    vm.prank(_sender);
    uniStaker.stakeMoreOnBehalf(_depositId, _stakeMoreAmount, _depositor, _deadline, _signature);
  }

  function testFuzz_RevertIf_DepositorIsNotDepositOwner(
    address _sender,
    address _depositor,
    address _notDepositor,
    uint96 _initialDepositAmount,
    uint96 _stakeMoreAmount,
    address _delegatee,
    address _beneficiary,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(
      _delegatee != address(0) && _beneficiary != address(0) && _sender != address(0)
        && _depositor != _notDepositor
    );
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _initialDepositAmount = _boundMintAmount(_initialDepositAmount);
    _mintGovToken(_depositor, _initialDepositAmount);
    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    UniStaker.DepositIdentifier _depositId;
    (_initialDepositAmount, _depositId) =
      _boundMintAndStake(_depositor, _initialDepositAmount, _delegatee, _beneficiary);

    vm.expectRevert(
      abi.encodeWithSelector(
        UniStaker.UniStaker__Unauthorized.selector, bytes32("not owner"), _notDepositor
      )
    );
    vm.prank(_sender);
    uniStaker.stakeMoreOnBehalf(_depositId, _stakeMoreAmount, _notDepositor, _deadline, "");
  }

  function testFuzz_RevertIf_InvalidSignatureIsPassed(
    uint256 _depositorPrivateKey,
    address _sender,
    uint96 _initialDepositAmount,
    uint96 _stakeMoreAmount,
    address _delegatee,
    address _beneficiary,
    uint256 _currentNonce,
    uint256 _randomSeed,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _beneficiary != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _initialDepositAmount = _boundMintAmount(_initialDepositAmount);
    _mintGovToken(_depositor, _initialDepositAmount);
    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    UniStaker.DepositIdentifier _depositId;
    (_initialDepositAmount, _depositId) =
      _boundMintAndStake(_depositor, _initialDepositAmount, _delegatee, _beneficiary);

    _stakeMoreAmount = _boundToRealisticStake(_stakeMoreAmount);
    _mintGovToken(_depositor, _stakeMoreAmount);

    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _stakeMoreAmount);
    vm.stopPrank();

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.STAKE_MORE_TYPEHASH(),
        _depositId,
        _stakeMoreAmount,
        _depositor,
        uniStaker.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));

    // Here we use `_randomSeed` as an arbitrary source of randomness to replace a legit parameter
    // with an attack-like one.
    if (_randomSeed % 4 == 0) {
      _stakeMoreAmount = uint96(uint256(keccak256(abi.encode(_stakeMoreAmount))));
    } else if (_randomSeed % 4 == 1) {
      _messageHash = _modifyMessage(_messageHash, uint256(keccak256(abi.encode(_randomSeed))));
    } else if (_randomSeed % 4 == 2) {
      _deadline = uint256(keccak256(abi.encode(_deadline)));
    }
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);
    if (_randomSeed % 4 == 3) _signature = _modifySignature(_signature, _randomSeed);

    vm.expectRevert(UniStaker.UniStaker__InvalidSignature.selector);
    vm.prank(_sender);
    uniStaker.stakeMoreOnBehalf(_depositId, _stakeMoreAmount, _depositor, _deadline, _signature);
  }
}

contract AlterDelegatee is UniStakerTest {
  function testFuzz_AllowsStakerToUpdateTheirDelegatee(
    address _depositor,
    uint96 _depositAmount,
    address _firstDelegatee,
    address _beneficiary,
    address _newDelegatee
  ) public {
    vm.assume(_newDelegatee != address(0) && _newDelegatee != _firstDelegatee);

    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _firstDelegatee, _beneficiary);
    address _firstSurrogate = address(uniStaker.surrogates(_firstDelegatee));

    vm.prank(_depositor);
    uniStaker.alterDelegatee(_depositId, _newDelegatee);

    UniStaker.Deposit memory _deposit = _fetchDeposit(_depositId);
    address _newSurrogate = address(uniStaker.surrogates(_deposit.delegatee));

    assertEq(_deposit.delegatee, _newDelegatee);
    assertEq(govToken.balanceOf(_newSurrogate), _depositAmount);
    assertEq(govToken.balanceOf(_firstSurrogate), 0);
  }

  function testFuzz_AllowsStakerToReiterateTheirDelegatee(
    address _depositor,
    uint96 _depositAmount,
    address _delegatee,
    address _beneficiary
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _beneficiary);
    address _beforeSurrogate = address(uniStaker.surrogates(_delegatee));

    // We are calling alterDelegatee with the address that is already the delegatee to ensure that
    // doing so does not break anything other than wasting the user's gas
    vm.prank(_depositor);
    uniStaker.alterDelegatee(_depositId, _delegatee);

    UniStaker.Deposit memory _deposit = _fetchDeposit(_depositId);
    address _afterSurrogate = address(uniStaker.surrogates(_deposit.delegatee));

    assertEq(_deposit.delegatee, _delegatee);
    assertEq(_beforeSurrogate, _afterSurrogate);
    assertEq(govToken.balanceOf(_afterSurrogate), _depositAmount);
  }

  function testFuzz_EmitsAnEventWhenADelegateeIsChanged(
    address _depositor,
    uint96 _depositAmount,
    address _firstDelegatee,
    address _beneficiary,
    address _newDelegatee
  ) public {
    vm.assume(_newDelegatee != address(0) && _newDelegatee != _firstDelegatee);

    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _firstDelegatee, _beneficiary);

    vm.expectEmit();
    emit UniStaker.DelegateeAltered(_depositId, _firstDelegatee, _newDelegatee);

    vm.prank(_depositor);
    uniStaker.alterDelegatee(_depositId, _newDelegatee);
  }

  function testFuzz_RevertIf_TheCallerIsNotTheDepositor(
    address _depositor,
    address _notDepositor,
    uint96 _depositAmount,
    address _firstDelegatee,
    address _beneficiary,
    address _newDelegatee
  ) public {
    vm.assume(
      _depositor != _notDepositor && _newDelegatee != address(0) && _newDelegatee != _firstDelegatee
    );

    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _firstDelegatee, _beneficiary);

    vm.prank(_notDepositor);
    vm.expectRevert(
      abi.encodeWithSelector(
        UniStaker.UniStaker__Unauthorized.selector, bytes32("not owner"), _notDepositor
      )
    );
    uniStaker.alterDelegatee(_depositId, _newDelegatee);
  }

  function testFuzz_RevertIf_TheDepositIdentifierIsInvalid(
    address _depositor,
    UniStaker.DepositIdentifier _depositId,
    address _newDelegatee
  ) public {
    vm.assume(_depositor != address(0) && _newDelegatee != address(0));

    // Since no deposits have been made yet, all DepositIdentifiers are invalid, and any call to
    // alter one should revert. We rely on the default owner of any uninitialized deposit being
    // address zero, which means the address attempting to alter it won't be able to.
    vm.prank(_depositor);
    vm.expectRevert(
      abi.encodeWithSelector(
        UniStaker.UniStaker__Unauthorized.selector, bytes32("not owner"), _depositor
      )
    );
    uniStaker.alterDelegatee(_depositId, _newDelegatee);
  }

  function testFuzz_RevertIf_DelegateeIsTheZeroAddress(
    address _depositor,
    uint96 _depositAmount,
    address _delegatee
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) = _boundMintAndStake(_depositor, _depositAmount, _delegatee);

    vm.prank(_depositor);
    vm.expectRevert(UniStaker.UniStaker__InvalidAddress.selector);
    uniStaker.alterDelegatee(_depositId, address(0));
  }
}

contract AlterDelegateeOnBehalf is UniStakerTest {
  using stdStorage for StdStorage;

  function testFuzz_AlterDelegateeOnBehalfOfDepositor(
    uint256 _depositorPrivateKey,
    address _sender,
    uint96 _amount,
    address _delegatee,
    address _beneficiary,
    address _newDelegatee,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(
      _delegatee != address(0) && _beneficiary != address(0) && _sender != address(0)
        && _newDelegatee != address(0)
    );
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);

    UniStaker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _beneficiary);
    UniStaker.Deposit memory _deposit = _fetchDeposit(_depositId);

    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.ALTER_DELEGATEE_TYPEHASH(),
        _depositId,
        _newDelegatee,
        _depositor,
        uniStaker.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.prank(_sender);
    uniStaker.alterDelegateeOnBehalf(_depositId, _newDelegatee, _depositor, _deadline, _signature);

    _deposit = _fetchDeposit(_depositId);

    assertEq(_deposit.delegatee, _newDelegatee);
  }

  function testFuzz_RevertIf_WrongNonceIsUsed(
    uint256 _depositorPrivateKey,
    address _sender,
    uint96 _amount,
    address _delegatee,
    address _beneficiary,
    address _newDelegatee,
    uint256 _currentNonce,
    uint256 _suppliedNonce,
    uint256 _deadline
  ) public {
    vm.assume(_currentNonce != _suppliedNonce);
    vm.assume(
      _delegatee != address(0) && _beneficiary != address(0) && _sender != address(0)
        && _newDelegatee != address(0)
    );
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);
    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    UniStaker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _beneficiary);

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.ALTER_DELEGATEE_TYPEHASH(), _depositId, _newDelegatee, _depositor, _suppliedNonce
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.expectRevert(UniStaker.UniStaker__InvalidSignature.selector);
    vm.prank(_sender);
    uniStaker.alterDelegateeOnBehalf(_depositId, _newDelegatee, _depositor, _deadline, _signature);
  }

  function testFuzz_RevertIf_DeadlineExpired(
    uint256 _depositorPrivateKey,
    address _sender,
    uint96 _amount,
    address _delegatee,
    address _beneficiary,
    address _newDelegatee,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(
      _delegatee != address(0) && _beneficiary != address(0) && _sender != address(0)
        && _newDelegatee != address(0)
    );
    _deadline = bound(_deadline, 0, block.timestamp - 1);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);
    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    UniStaker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _beneficiary);

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.ALTER_DELEGATEE_TYPEHASH(),
        _depositId,
        _newDelegatee,
        _depositor,
        _currentNonce,
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.expectRevert(UniStaker.UniStaker__ExpiredDeadline.selector);
    vm.prank(_sender);
    uniStaker.alterDelegateeOnBehalf(_depositId, _newDelegatee, _depositor, _deadline, _signature);
  }

  function testFuzz_RevertIf_DepositorIsNotDepositOwner(
    address _sender,
    address _depositor,
    address _notDepositor,
    uint96 _amount,
    address _delegatee,
    address _newDelegatee,
    address _beneficiary,
    uint256 _deadline,
    bytes memory _signature
  ) public {
    vm.assume(
      _delegatee != address(0) && _beneficiary != address(0) && _sender != address(0)
        && _depositor != _notDepositor
    );
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);

    UniStaker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _beneficiary);

    vm.expectRevert(
      abi.encodeWithSelector(
        UniStaker.UniStaker__Unauthorized.selector, bytes32("not owner"), _notDepositor
      )
    );
    vm.prank(_sender);
    uniStaker.alterDelegateeOnBehalf(
      _depositId, _newDelegatee, _notDepositor, _deadline, _signature
    );
  }

  function testFuzz_RevertIf_InvalidSignatureIsPassed(
    uint256 _depositorPrivateKey,
    address _sender,
    uint96 _amount,
    address _delegatee,
    address _beneficiary,
    address _newDelegatee,
    uint256 _currentNonce,
    uint256 _randomSeed,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _beneficiary != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);
    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    UniStaker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _beneficiary);

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.ALTER_DELEGATEE_TYPEHASH(),
        _depositId,
        _newDelegatee,
        _depositor,
        uniStaker.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));

    // Here we use `_randomSeed` as an arbitrary source of randomness to replace a legit parameter
    // with an attack-like one.
    if (_randomSeed % 4 == 0) {
      _newDelegatee = address(uint160(uint256(keccak256(abi.encode(_newDelegatee)))));
    } else if (_randomSeed % 4 == 1) {
      _messageHash = _modifyMessage(_messageHash, uint256(keccak256(abi.encode(_randomSeed))));
    } else if (_randomSeed % 4 == 2) {
      _deadline = uint256(keccak256(abi.encode(_deadline)));
    }
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);
    if (_randomSeed % 4 == 3) _signature = _modifySignature(_signature, _randomSeed);

    vm.expectRevert(UniStaker.UniStaker__InvalidSignature.selector);
    vm.prank(_sender);
    uniStaker.alterDelegateeOnBehalf(_depositId, _newDelegatee, _depositor, _deadline, _signature);
  }
}

contract AlterBeneficiary is UniStakerTest {
  function testFuzz_AllowsStakerToUpdateTheirBeneficiary(
    address _depositor,
    uint96 _depositAmount,
    address _delegatee,
    address _firstBeneficiary,
    address _newBeneficiary
  ) public {
    vm.assume(_newBeneficiary != address(0) && _newBeneficiary != _firstBeneficiary);

    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _firstBeneficiary);

    vm.prank(_depositor);
    uniStaker.alterBeneficiary(_depositId, _newBeneficiary);

    UniStaker.Deposit memory _deposit = _fetchDeposit(_depositId);

    assertEq(_deposit.beneficiary, _newBeneficiary);
    assertEq(uniStaker.earningPower(_newBeneficiary), _depositAmount);
    assertEq(uniStaker.earningPower(_firstBeneficiary), 0);
  }

  function testFuzz_AllowsStakerToReiterateTheirBeneficiary(
    address _depositor,
    uint96 _depositAmount,
    address _delegatee,
    address _beneficiary
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _beneficiary);

    // We are calling alterBeneficiary with the address that is already the beneficiary to ensure
    // that doing so does not break anything other than wasting the user's gas
    vm.prank(_depositor);
    uniStaker.alterBeneficiary(_depositId, _beneficiary);

    UniStaker.Deposit memory _deposit = _fetchDeposit(_depositId);

    assertEq(_deposit.beneficiary, _beneficiary);
    assertEq(uniStaker.earningPower(_beneficiary), _depositAmount);
  }

  function testFuzz_EmitsAnEventWhenBeneficiaryAltered(
    address _depositor,
    uint96 _depositAmount,
    address _delegatee,
    address _firstBeneficiary,
    address _newBeneficiary
  ) public {
    vm.assume(_newBeneficiary != address(0) && _newBeneficiary != _firstBeneficiary);

    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _firstBeneficiary);

    vm.expectEmit();
    emit UniStaker.BeneficiaryAltered(_depositId, _firstBeneficiary, _newBeneficiary);

    vm.prank(_depositor);
    uniStaker.alterBeneficiary(_depositId, _newBeneficiary);
  }

  function testFuzz_RevertIf_TheCallerIsNotTheDepositor(
    address _depositor,
    address _notDepositor,
    uint96 _depositAmount,
    address _delegatee,
    address _firstBeneficiary,
    address _newBeneficiary
  ) public {
    vm.assume(
      _notDepositor != _depositor && _newBeneficiary != address(0)
        && _newBeneficiary != _firstBeneficiary
    );

    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _firstBeneficiary);

    vm.prank(_notDepositor);
    vm.expectRevert(
      abi.encodeWithSelector(
        UniStaker.UniStaker__Unauthorized.selector, bytes32("not owner"), _notDepositor
      )
    );
    uniStaker.alterBeneficiary(_depositId, _newBeneficiary);
  }

  function testFuzz_RevertIf_TheDepositIdentifierIsInvalid(
    address _depositor,
    UniStaker.DepositIdentifier _depositId,
    address _newBeneficiary
  ) public {
    vm.assume(_depositor != address(0) && _newBeneficiary != address(0));

    // Since no deposits have been made yet, all DepositIdentifiers are invalid, and any call to
    // alter one should revert. We rely on the default owner of any uninitialized deposit being
    // address zero, which means the address attempting to alter it won't be able to.
    vm.prank(_depositor);
    vm.expectRevert(
      abi.encodeWithSelector(
        UniStaker.UniStaker__Unauthorized.selector, bytes32("not owner"), _depositor
      )
    );
    uniStaker.alterBeneficiary(_depositId, _newBeneficiary);
  }

  function testFuzz_RevertIf_BeneficiaryIsTheZeroAddress(
    address _depositor,
    uint96 _depositAmount,
    address _delegatee
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) = _boundMintAndStake(_depositor, _depositAmount, _delegatee);

    vm.prank(_depositor);
    vm.expectRevert(UniStaker.UniStaker__InvalidAddress.selector);
    uniStaker.alterBeneficiary(_depositId, address(0));
  }
}

contract AlterBeneficiaryOnBehalf is UniStakerTest {
  using stdStorage for StdStorage;

  function testFuzz_AlterBeneficiaryOnBehalfOfDepositor(
    uint256 _depositorPrivateKey,
    address _sender,
    uint96 _amount,
    address _delegatee,
    address _beneficiary,
    address _newBeneficiary,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(
      _delegatee != address(0) && _beneficiary != address(0) && _sender != address(0)
        && _newBeneficiary != address(0)
    );
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);

    UniStaker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _beneficiary);
    UniStaker.Deposit memory _deposit = _fetchDeposit(_depositId);

    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.ALTER_BENEFICIARY_TYPEHASH(),
        _depositId,
        _newBeneficiary,
        _depositor,
        uniStaker.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.prank(_sender);
    uniStaker.alterBeneficiaryOnBehalf(
      _depositId, _newBeneficiary, _depositor, _deadline, _signature
    );

    _deposit = _fetchDeposit(_depositId);

    assertEq(_deposit.beneficiary, _newBeneficiary);
  }

  function testFuzz_RevertIf_WrongNonceIsUsed(
    uint256 _depositorPrivateKey,
    address _sender,
    uint96 _amount,
    address _delegatee,
    address _beneficiary,
    address _newBeneficiary,
    uint256 _currentNonce,
    uint256 _suppliedNonce,
    uint256 _deadline
  ) public {
    vm.assume(_currentNonce != _suppliedNonce);
    vm.assume(
      _delegatee != address(0) && _beneficiary != address(0) && _sender != address(0)
        && _newBeneficiary != address(0)
    );
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);
    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    UniStaker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _beneficiary);

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.ALTER_BENEFICIARY_TYPEHASH(),
        _depositId,
        _newBeneficiary,
        _depositor,
        _suppliedNonce,
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.expectRevert(UniStaker.UniStaker__InvalidSignature.selector);
    vm.prank(_sender);
    uniStaker.alterBeneficiaryOnBehalf(
      _depositId, _newBeneficiary, _depositor, _deadline, _signature
    );
  }

  function testFuzz_RevertIf_DeadlineExpired(
    uint256 _depositorPrivateKey,
    address _sender,
    uint96 _amount,
    address _delegatee,
    address _beneficiary,
    address _newBeneficiary,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(
      _delegatee != address(0) && _beneficiary != address(0) && _sender != address(0)
        && _newBeneficiary != address(0)
    );
    _deadline = bound(_deadline, 0, block.timestamp - 1);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);
    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    UniStaker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _beneficiary);

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.ALTER_BENEFICIARY_TYPEHASH(),
        _depositId,
        _newBeneficiary,
        _depositor,
        _currentNonce,
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.expectRevert(UniStaker.UniStaker__ExpiredDeadline.selector);
    vm.prank(_sender);
    uniStaker.alterBeneficiaryOnBehalf(
      _depositId, _newBeneficiary, _depositor, _deadline, _signature
    );
  }

  function testFuzz_RevertIf_DepositorIsNotDepositOwner(
    address _sender,
    address _depositor,
    address _notDepositor,
    uint96 _amount,
    address _delegatee,
    address _beneficiary,
    address _newBeneficiary,
    uint256 _deadline,
    bytes memory _signature
  ) public {
    vm.assume(
      _delegatee != address(0) && _beneficiary != address(0) && _sender != address(0)
        && _depositor != _notDepositor
    );
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);

    UniStaker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _beneficiary);

    vm.expectRevert(
      abi.encodeWithSelector(
        UniStaker.UniStaker__Unauthorized.selector, bytes32("not owner"), _notDepositor
      )
    );
    vm.prank(_sender);
    uniStaker.alterBeneficiaryOnBehalf(
      _depositId, _newBeneficiary, _notDepositor, _deadline, _signature
    );
  }

  function testFuzz_RevertIf_InvalidSignatureIsPassed(
    uint256 _depositorPrivateKey,
    address _sender,
    uint96 _amount,
    address _delegatee,
    address _beneficiary,
    address _newBeneficiary,
    uint256 _currentNonce,
    uint256 _randomSeed,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _beneficiary != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);
    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    UniStaker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _beneficiary);

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.ALTER_BENEFICIARY_TYPEHASH(),
        _depositId,
        _newBeneficiary,
        _depositor,
        uniStaker.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));

    // Here we use `_randomSeed` as an arbitrary source of randomness to replace a legit parameter
    // with an attack-like one.
    if (_randomSeed % 4 == 0) {
      _newBeneficiary = address(uint160(uint256(keccak256(abi.encode(_newBeneficiary)))));
    } else if (_randomSeed % 4 == 1) {
      _messageHash = _modifyMessage(_messageHash, uint256(keccak256(abi.encode(_randomSeed))));
    } else if (_randomSeed % 4 == 2) {
      _deadline = uint256(keccak256(abi.encode(_deadline)));
    }
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);
    if (_randomSeed % 4 == 3) _signature = _modifySignature(_signature, _randomSeed);

    vm.expectRevert(UniStaker.UniStaker__InvalidSignature.selector);
    vm.prank(_sender);
    uniStaker.alterBeneficiaryOnBehalf(
      _depositId, _newBeneficiary, _depositor, _deadline, _signature
    );
  }
}

contract Withdraw is UniStakerTest {
  function testFuzz_AllowsDepositorToWithdrawStake(
    address _depositor,
    uint96 _depositAmount,
    address _delegatee,
    uint96 _withdrawalAmount
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) = _boundMintAndStake(_depositor, _depositAmount, _delegatee);
    _withdrawalAmount = uint96(bound(_withdrawalAmount, 0, _depositAmount));

    vm.prank(_depositor);
    uniStaker.withdraw(_depositId, _withdrawalAmount);

    UniStaker.Deposit memory _deposit = _fetchDeposit(_depositId);
    address _surrogate = address(uniStaker.surrogates(_deposit.delegatee));

    assertEq(govToken.balanceOf(_depositor), _withdrawalAmount);
    assertEq(_deposit.balance, _depositAmount - _withdrawalAmount);
    assertEq(govToken.balanceOf(_surrogate), _depositAmount - _withdrawalAmount);
  }

  function testFuzz_UpdatesTheTotalStakedWhenAnAccountWithdraws(
    address _depositor,
    uint96 _depositAmount,
    address _delegatee,
    uint96 _withdrawalAmount
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) = _boundMintAndStake(_depositor, _depositAmount, _delegatee);
    _withdrawalAmount = uint96(bound(_withdrawalAmount, 0, _depositAmount));

    vm.prank(_depositor);
    uniStaker.withdraw(_depositId, _withdrawalAmount);

    assertEq(uniStaker.totalStaked(), _depositAmount - _withdrawalAmount);
  }

  function testFuzz_UpdatesTheTotalStakedWhenTwoAccountsWithdraw(
    address _depositor1,
    uint96 _depositAmount1,
    address _delegatee1,
    address _depositor2,
    uint96 _depositAmount2,
    address _delegatee2,
    uint96 _withdrawalAmount1,
    uint96 _withdrawalAmount2
  ) public {
    // Make two separate deposits
    UniStaker.DepositIdentifier _depositId1;
    (_depositAmount1, _depositId1) = _boundMintAndStake(_depositor1, _depositAmount1, _delegatee1);
    UniStaker.DepositIdentifier _depositId2;
    (_depositAmount2, _depositId2) = _boundMintAndStake(_depositor2, _depositAmount2, _delegatee2);

    // Calculate withdrawal amounts
    _withdrawalAmount1 = uint96(bound(_withdrawalAmount1, 0, _depositAmount1));
    _withdrawalAmount2 = uint96(bound(_withdrawalAmount2, 0, _depositAmount2));

    // Execute both withdrawals
    vm.prank(_depositor1);
    uniStaker.withdraw(_depositId1, _withdrawalAmount1);
    vm.prank(_depositor2);
    uniStaker.withdraw(_depositId2, _withdrawalAmount2);

    uint96 _remainingDeposits =
      _depositAmount1 + _depositAmount2 - _withdrawalAmount1 - _withdrawalAmount2;
    assertEq(uniStaker.totalStaked(), _remainingDeposits);
  }

  function testFuzz_UpdatesAnAccountsTotalStakedWhenItWithdrawals(
    address _depositor,
    uint96 _depositAmount1,
    uint96 _depositAmount2,
    address _delegatee1,
    address _delegatee2,
    uint96 _withdrawalAmount
  ) public {
    // Make two separate deposits
    UniStaker.DepositIdentifier _depositId1;
    (_depositAmount1, _depositId1) = _boundMintAndStake(_depositor, _depositAmount1, _delegatee1);
    UniStaker.DepositIdentifier _depositId2;
    (_depositAmount2, _depositId2) = _boundMintAndStake(_depositor, _depositAmount2, _delegatee2);

    // Withdraw part of the first deposit
    _withdrawalAmount = uint96(bound(_withdrawalAmount, 0, _depositAmount1));
    vm.prank(_depositor);
    uniStaker.withdraw(_depositId1, _withdrawalAmount);

    // Ensure the account's total balance + global balance accounting have been updated
    assertEq(
      uniStaker.depositorTotalStaked(_depositor),
      _depositAmount1 + _depositAmount2 - _withdrawalAmount
    );
    assertEq(uniStaker.totalStaked(), _depositAmount1 + _depositAmount2 - _withdrawalAmount);
  }

  function testFuzz_RemovesEarningPowerFromADepositorWhoHadSelfAssignedIt(
    address _depositor,
    uint96 _depositAmount,
    address _delegatee,
    uint96 _withdrawalAmount
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) = _boundMintAndStake(_depositor, _depositAmount, _delegatee);
    _withdrawalAmount = uint96(bound(_withdrawalAmount, 0, _depositAmount));

    vm.prank(_depositor);
    uniStaker.withdraw(_depositId, _withdrawalAmount);

    assertEq(uniStaker.earningPower(_depositor), _depositAmount - _withdrawalAmount);
  }

  function testFuzz_RemovesEarningPowerFromABeneficiary(
    address _depositor,
    uint96 _depositAmount,
    address _delegatee,
    address _beneficiary,
    uint96 _withdrawalAmount
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _beneficiary);
    _withdrawalAmount = uint96(bound(_withdrawalAmount, 0, _depositAmount));

    vm.prank(_depositor);
    uniStaker.withdraw(_depositId, _withdrawalAmount);

    assertEq(uniStaker.earningPower(_beneficiary), _depositAmount - _withdrawalAmount);
  }

  function testFuzz_RemovesEarningPowerFromABeneficiaryAssignedByTwoDepositors(
    address _depositor1,
    address _depositor2,
    uint96 _depositAmount1,
    uint96 _depositAmount2,
    address _delegatee,
    address _beneficiary,
    uint96 _withdrawalAmount1,
    uint96 _withdrawalAmount2
  ) public {
    UniStaker.DepositIdentifier _depositId1;
    (_depositAmount1, _depositId1) =
      _boundMintAndStake(_depositor1, _depositAmount1, _delegatee, _beneficiary);
    _withdrawalAmount1 = uint96(bound(_withdrawalAmount1, 0, _depositAmount1));

    UniStaker.DepositIdentifier _depositId2;
    (_depositAmount2, _depositId2) =
      _boundMintAndStake(_depositor2, _depositAmount2, _delegatee, _beneficiary);
    _withdrawalAmount2 = uint96(bound(_withdrawalAmount2, 0, _depositAmount2));

    vm.prank(_depositor1);
    uniStaker.withdraw(_depositId1, _withdrawalAmount1);

    assertEq(
      uniStaker.earningPower(_beneficiary), _depositAmount1 - _withdrawalAmount1 + _depositAmount2
    );

    vm.prank(_depositor2);
    uniStaker.withdraw(_depositId2, _withdrawalAmount2);

    assertEq(
      uniStaker.earningPower(_beneficiary),
      _depositAmount1 - _withdrawalAmount1 + _depositAmount2 - _withdrawalAmount2
    );
  }

  function testFuzz_RemovesEarningPowerFromDifferentBeneficiariesOfTheSameDepositor(
    address _depositor,
    uint96 _depositAmount1,
    uint96 _depositAmount2,
    address _delegatee,
    address _beneficiary1,
    address _beneficiary2,
    uint96 _withdrawalAmount1,
    uint96 _withdrawalAmount2
  ) public {
    vm.assume(_beneficiary1 != _beneficiary2);

    UniStaker.DepositIdentifier _depositId1;
    (_depositAmount1, _depositId1) =
      _boundMintAndStake(_depositor, _depositAmount1, _delegatee, _beneficiary1);
    _withdrawalAmount1 = uint96(bound(_withdrawalAmount1, 0, _depositAmount1));

    UniStaker.DepositIdentifier _depositId2;
    (_depositAmount2, _depositId2) =
      _boundMintAndStake(_depositor, _depositAmount2, _delegatee, _beneficiary2);
    _withdrawalAmount2 = uint96(bound(_withdrawalAmount2, 0, _depositAmount2));

    vm.prank(_depositor);
    uniStaker.withdraw(_depositId1, _withdrawalAmount1);

    assertEq(uniStaker.earningPower(_beneficiary1), _depositAmount1 - _withdrawalAmount1);
    assertEq(uniStaker.earningPower(_beneficiary2), _depositAmount2);

    vm.prank(_depositor);
    uniStaker.withdraw(_depositId2, _withdrawalAmount2);

    assertEq(uniStaker.earningPower(_beneficiary1), _depositAmount1 - _withdrawalAmount1);
    assertEq(uniStaker.earningPower(_beneficiary2), _depositAmount2 - _withdrawalAmount2);
  }

  function testFuzz_RemovesEarningPowerFromDifferentBeneficiariesAndDifferentDepositors(
    address _depositor1,
    address _depositor2,
    uint96 _depositAmount1,
    uint96 _depositAmount2,
    address _delegatee,
    address _beneficiary1,
    address _beneficiary2,
    uint96 _withdrawalAmount1,
    uint96 _withdrawalAmount2
  ) public {
    vm.assume(_beneficiary1 != _beneficiary2);

    UniStaker.DepositIdentifier _depositId1;
    (_depositAmount1, _depositId1) =
      _boundMintAndStake(_depositor1, _depositAmount1, _delegatee, _beneficiary1);
    _withdrawalAmount1 = uint96(bound(_withdrawalAmount1, 0, _depositAmount1));

    UniStaker.DepositIdentifier _depositId2;
    (_depositAmount2, _depositId2) =
      _boundMintAndStake(_depositor2, _depositAmount2, _delegatee, _beneficiary2);
    _withdrawalAmount2 = uint96(bound(_withdrawalAmount2, 0, _depositAmount2));

    vm.prank(_depositor1);
    uniStaker.withdraw(_depositId1, _withdrawalAmount1);

    assertEq(uniStaker.earningPower(_beneficiary1), _depositAmount1 - _withdrawalAmount1);
    assertEq(uniStaker.earningPower(_beneficiary2), _depositAmount2);

    vm.prank(_depositor2);
    uniStaker.withdraw(_depositId2, _withdrawalAmount2);

    assertEq(uniStaker.earningPower(_beneficiary1), _depositAmount1 - _withdrawalAmount1);
    assertEq(uniStaker.earningPower(_beneficiary2), _depositAmount2 - _withdrawalAmount2);
  }

  function testFuzz_EmitsAnEventWhenThereIsAWithdrawl(
    address _depositor,
    uint96 _depositAmount,
    address _delegatee,
    uint96 _withdrawalAmount
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) = _boundMintAndStake(_depositor, _depositAmount, _delegatee);
    _withdrawalAmount = uint96(bound(_withdrawalAmount, 0, _depositAmount));

    vm.expectEmit();
    emit UniStaker.StakeWithdrawn(_depositId, _withdrawalAmount, _depositAmount - _withdrawalAmount);

    vm.prank(_depositor);
    uniStaker.withdraw(_depositId, _withdrawalAmount);
  }

  function testFuzz_RevertIf_TheWithdrawerIsNotTheDepositor(
    address _depositor,
    uint96 _amount,
    address _delegatee,
    address _notDepositor
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee);
    vm.assume(_depositor != _notDepositor);

    vm.prank(_notDepositor);
    vm.expectRevert(
      abi.encodeWithSelector(
        UniStaker.UniStaker__Unauthorized.selector, bytes32("not owner"), _notDepositor
      )
    );
    uniStaker.withdraw(_depositId, _amount);
  }

  function testFuzz_RevertIf_TheWithdrawalAmountIsGreaterThanTheBalance(
    address _depositor,
    uint96 _amount,
    uint96 _amountOver,
    address _delegatee
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee);
    _amountOver = uint96(bound(_amountOver, 1, type(uint128).max));

    vm.prank(_depositor);
    vm.expectRevert();
    uniStaker.withdraw(_depositId, _amount + _amountOver);
  }
}

contract WithdrawOnBehalf is UniStakerTest {
  using stdStorage for StdStorage;

  function testFuzz_WithdrawOnBehalfOfDepositor(
    uint256 _depositorPrivateKey,
    address _sender,
    uint96 _depositAmount,
    address _delegatee,
    address _beneficiary,
    uint96 _withdrawAmount,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _beneficiary != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);

    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _beneficiary);
    UniStaker.Deposit memory _deposit = _fetchDeposit(_depositId);
    _withdrawAmount = uint96(bound(_withdrawAmount, 0, _depositAmount));

    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.WITHDRAW_TYPEHASH(),
        _depositId,
        _withdrawAmount,
        _depositor,
        uniStaker.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.prank(_sender);
    uniStaker.withdrawOnBehalf(_depositId, _withdrawAmount, _depositor, _deadline, _signature);

    _deposit = _fetchDeposit(_depositId);

    assertEq(_deposit.balance, _depositAmount - _withdrawAmount);
  }

  function testFuzz_RevertIf_WrongNonceIsUsed(
    uint256 _depositorPrivateKey,
    address _sender,
    uint96 _depositAmount,
    address _delegatee,
    address _beneficiary,
    uint96 _withdrawAmount,
    uint256 _currentNonce,
    uint256 _suppliedNonce,
    uint256 _deadline
  ) public {
    vm.assume(_currentNonce != _suppliedNonce);
    vm.assume(_delegatee != address(0) && _beneficiary != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _depositAmount = _boundMintAmount(_depositAmount);
    _mintGovToken(_depositor, _depositAmount);
    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _beneficiary);

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.WITHDRAW_TYPEHASH(),
        _depositId,
        _withdrawAmount,
        _depositor,
        _suppliedNonce,
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.expectRevert(UniStaker.UniStaker__InvalidSignature.selector);
    vm.prank(_sender);
    uniStaker.withdrawOnBehalf(_depositId, _withdrawAmount, _depositor, _deadline, _signature);
  }

  function testFuzz_RevertIf_DeadlineExpired(
    uint256 _depositorPrivateKey,
    address _sender,
    uint96 _depositAmount,
    address _delegatee,
    address _beneficiary,
    uint96 _withdrawAmount,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _beneficiary != address(0) && _sender != address(0));
    _deadline = bound(_deadline, 0, block.timestamp - 1);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _depositAmount = _boundMintAmount(_depositAmount);
    _mintGovToken(_depositor, _depositAmount);
    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _beneficiary);

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.WITHDRAW_TYPEHASH(),
        _depositId,
        _withdrawAmount,
        _depositor,
        _currentNonce,
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.expectRevert(UniStaker.UniStaker__ExpiredDeadline.selector);
    vm.prank(_sender);
    uniStaker.withdrawOnBehalf(_depositId, _withdrawAmount, _depositor, _deadline, _signature);
  }

  function testFuzz_RevertIf_DepositorIsNotDepositOwner(
    address _sender,
    address _depositor,
    address _notDepositor,
    uint96 _amount,
    address _delegatee,
    address _beneficiary,
    uint96 _withdrawAmount,
    uint256 _deadline,
    bytes memory _signature
  ) public {
    vm.assume(
      _delegatee != address(0) && _beneficiary != address(0) && _sender != address(0)
        && _depositor != _notDepositor
    );
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);

    UniStaker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _beneficiary);

    vm.expectRevert(
      abi.encodeWithSelector(
        UniStaker.UniStaker__Unauthorized.selector, bytes32("not owner"), _notDepositor
      )
    );
    vm.prank(_sender);
    uniStaker.withdrawOnBehalf(_depositId, _withdrawAmount, _notDepositor, _deadline, _signature);
  }

  function testFuzz_RevertIf_InvalidSignatureIsPassed(
    uint256 _depositorPrivateKey,
    address _sender,
    uint96 _depositAmount,
    address _delegatee,
    address _beneficiary,
    uint96 _withdrawAmount,
    uint256 _currentNonce,
    uint256 _randomSeed,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _beneficiary != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _depositAmount = _boundMintAmount(_depositAmount);
    _mintGovToken(_depositor, _depositAmount);
    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _beneficiary);

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.WITHDRAW_TYPEHASH(),
        _depositId,
        _withdrawAmount,
        _depositor,
        uniStaker.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));

    // Here we use `_randomSeed` as an arbitrary source of randomness to replace a legit parameter
    // with an attack-like one.
    if (_randomSeed % 4 == 0) {
      _withdrawAmount = uint96(uint256(keccak256(abi.encode(_withdrawAmount))));
    } else if (_randomSeed % 4 == 1) {
      _messageHash = _modifyMessage(_messageHash, uint256(keccak256(abi.encode(_randomSeed))));
    } else if (_randomSeed % 4 == 2) {
      _deadline = uint256(keccak256(abi.encode(_deadline)));
    }
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);
    if (_randomSeed % 4 == 3) _signature = _modifySignature(_signature, _randomSeed);

    vm.expectRevert(UniStaker.UniStaker__InvalidSignature.selector);
    vm.prank(_sender);
    uniStaker.withdrawOnBehalf(_depositId, _withdrawAmount, _depositor, _deadline, _signature);
  }
}

contract SetRewardNotifier is UniStakerTest {
  function testFuzz_AllowsAdminToSetRewardNotifier(address _rewardNotifier, bool _isEnabled) public {
    vm.prank(admin);
    uniStaker.setRewardNotifier(_rewardNotifier, _isEnabled);

    assertEq(uniStaker.isRewardNotifier(_rewardNotifier), _isEnabled);
  }

  function test_AllowsTheAdminToDisableAnActiveRewardNotifier() public {
    vm.prank(admin);
    uniStaker.setRewardNotifier(rewardNotifier, false);

    assertFalse(uniStaker.isRewardNotifier(rewardNotifier));
  }

  function testFuzz_EmitsEventWhenRewardNotifierIsSet(address _rewardNotifier, bool _isEnabled)
    public
  {
    vm.expectEmit();
    emit RewardNotifierSet(_rewardNotifier, _isEnabled);
    vm.prank(admin);
    uniStaker.setRewardNotifier(_rewardNotifier, _isEnabled);
  }

  function testFuzz_RevertIf_TheCallerIsNotTheAdmin(
    address _notAdmin,
    address _newRewardNotifier,
    bool _isEnabled
  ) public {
    vm.assume(_notAdmin != uniStaker.admin());

    vm.prank(_notAdmin);
    vm.expectRevert(
      abi.encodeWithSelector(
        UniStaker.UniStaker__Unauthorized.selector, bytes32("not admin"), _notAdmin
      )
    );
    uniStaker.setRewardNotifier(_newRewardNotifier, _isEnabled);
  }
}

contract SetAdmin is UniStakerTest {
  function testFuzz_AllowsAdminToSetAdmin(address _newAdmin) public {
    vm.assume(_newAdmin != address(0));

    vm.prank(admin);
    uniStaker.setAdmin(_newAdmin);

    assertEq(uniStaker.admin(), _newAdmin);
  }

  function testFuzz_EmitsEventWhenAdminIsSet(address _newAdmin) public {
    vm.assume(_newAdmin != address(0));

    vm.expectEmit();
    emit AdminSet(admin, _newAdmin);

    vm.prank(admin);
    uniStaker.setAdmin(_newAdmin);
  }

  function testFuzz_RevertIf_TheCallerIsNotTheAdmin(address _notAdmin, address _newAdmin) public {
    vm.assume(_notAdmin != uniStaker.admin());

    vm.prank(_notAdmin);
    vm.expectRevert(
      abi.encodeWithSelector(
        UniStaker.UniStaker__Unauthorized.selector, bytes32("not admin"), _notAdmin
      )
    );
    uniStaker.setAdmin(_newAdmin);
  }

  function test_RevertIf_NewAdminAddressIsZeroAddress() public {
    vm.prank(admin);
    vm.expectRevert(UniStaker.UniStaker__InvalidAddress.selector);
    uniStaker.setAdmin(address(0));
  }
}

contract InvalidateNonce is UniStakerTest {
  using stdStorage for StdStorage;

  function testFuzz_SucessfullyIncrementsTheNonceOfTheSender(address _caller, uint256 _initialNonce)
    public
  {
    vm.assume(_caller != address(0));
    vm.assume(_initialNonce != type(uint256).max);

    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_caller).checked_write(
      _initialNonce
    );

    vm.prank(_caller);
    uniStaker.invalidateNonce();

    uint256 currentNonce = uniStaker.nonces(_caller);

    assertEq(currentNonce, _initialNonce + 1, "Current nonce is incorrect");
  }

  function testFuzz_IncreasesTheNonceByTwoWhenCalledTwice(address _caller, uint256 _initialNonce)
    public
  {
    vm.assume(_caller != address(0));
    _initialNonce = bound(_initialNonce, 0, type(uint256).max - 2);

    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_caller).checked_write(
      _initialNonce
    );

    vm.prank(_caller);
    uniStaker.invalidateNonce();

    vm.prank(_caller);
    uniStaker.invalidateNonce();

    uint256 currentNonce = uniStaker.nonces(_caller);

    assertEq(currentNonce, _initialNonce + 2, "Current nonce is incorrect");
  }
}

contract UniStakerRewardsTest is UniStakerTest {
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
    console2.log("scaledUnclaimedRewardCheckpoint[_depositor]");
    console2.log(uniStaker.scaledUnclaimedRewardCheckpoint(_depositor));
    console2.log("unclaimedReward(_depositor)");
    console2.log(uniStaker.unclaimedReward(_depositor));
    console2.log("-----------------------------------------------");
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

  function _boundToRealisticStakeAndReward(uint96 _stakeAmount, uint256 _rewardAmount)
    public
    pure
    returns (uint96 _boundedStakeAmount, uint256 _boundedRewardAmount)
  {
    _boundedStakeAmount = _boundToRealisticStake(_stakeAmount);
    _boundedRewardAmount = _boundToRealisticReward(_rewardAmount);
  }

  function _mintTransferAndNotifyReward(uint256 _amount) public {
    rewardToken.mint(rewardNotifier, _amount);

    vm.startPrank(rewardNotifier);
    rewardToken.transfer(address(uniStaker), _amount);
    uniStaker.notifyRewardAmount(_amount);
    vm.stopPrank();
  }

  function _mintTransferAndNotifyReward(address _rewardNotifier, uint256 _amount) public {
    vm.assume(_rewardNotifier != address(0));
    rewardToken.mint(_rewardNotifier, _amount);

    vm.startPrank(_rewardNotifier);
    rewardToken.transfer(address(uniStaker), _amount);
    uniStaker.notifyRewardAmount(_amount);
    vm.stopPrank();
  }
}

contract NotifyRewardAmount is UniStakerRewardsTest {
  function testFuzz_UpdatesTheRewardRate(uint256 _amount) public {
    _amount = _boundToRealisticReward(_amount);
    _mintTransferAndNotifyReward(_amount);

    uint256 _expectedRewardRate = (SCALE_FACTOR * _amount) / uniStaker.REWARD_DURATION();
    assertEq(uniStaker.scaledRewardRate(), _expectedRewardRate);
  }

  function testFuzz_UpdatesTheRewardRateOnASecondCall(uint256 _amount1, uint256 _amount2) public {
    _amount1 = _boundToRealisticReward(_amount1);
    _amount2 = _boundToRealisticReward(_amount2);

    _mintTransferAndNotifyReward(_amount1);
    uint256 _expectedRewardRate = (SCALE_FACTOR * _amount1) / uniStaker.REWARD_DURATION();
    assertEq(uniStaker.scaledRewardRate(), _expectedRewardRate);

    _mintTransferAndNotifyReward(_amount2);
    _expectedRewardRate = (SCALE_FACTOR * (_amount1 + _amount2)) / uniStaker.REWARD_DURATION();
    assertLteWithinOneUnit(uniStaker.scaledRewardRate(), _expectedRewardRate);
  }

  function testFuzz_UpdatesTheAccumulatorTimestamps(uint256 _amount, uint256 _jumpTime) public {
    _amount = _boundToRealisticReward(_amount);
    _jumpTime = bound(_jumpTime, 0, 50_000 days); // prevent overflow in timestamps
    uint256 _futureTimestamp = block.timestamp + _jumpTime;
    _jumpAhead(_jumpTime);

    _mintTransferAndNotifyReward(_amount);
    uint256 _expectedFinishTimestamp = _futureTimestamp + uniStaker.REWARD_DURATION();

    assertEq(uniStaker.lastCheckpointTime(), _futureTimestamp);
    assertEq(uniStaker.rewardEndTime(), _expectedFinishTimestamp);
  }

  function testFuzz_UpdatesTheCheckpointedRewardPerTokenAccumulator(
    address _depositor,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint256 _durationPercent
  ) public {
    // In order to force calculation of a non-zero, there must be some staked supply, so we do
    // that deposit first
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);
    _boundMintAndStake(_depositor, _stakeAmount, _delegatee);
    // We will jump ahead by some percentage of the duration
    _durationPercent = bound(_durationPercent, 1, 100);

    // Now the contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // Some time elapses
    _jumpAheadByPercentOfRewardDuration(_durationPercent);
    // We make another reward which should write the non-zero reward amount
    _mintTransferAndNotifyReward(_rewardAmount);
    // Sanity check on our test assumptions
    require(
      uniStaker.rewardPerTokenAccumulated() != 0,
      "Broken test assumption: expecting a non-zero reward accumulator"
    );

    // We are not testing the calculation of the reward amount, but only that the value in storage
    // has been updated on reward notification and thus matches the "live" calculation.
    assertEq(uniStaker.rewardPerTokenAccumulatedCheckpoint(), uniStaker.rewardPerTokenAccumulated());
  }

  function testFuzz_AllowsMultipleApprovedRewardNotifiersToNotifyOfRewards(
    uint256 _amount1,
    uint256 _amount2,
    uint256 _amount3,
    address _rewardNotifier1,
    address _rewardNotifier2,
    address _rewardNotifier3
  ) public {
    _amount1 = _boundToRealisticReward(_amount1);
    _amount2 = _boundToRealisticReward(_amount2);
    _amount3 = _boundToRealisticReward(_amount3);

    vm.startPrank(admin);
    uniStaker.setRewardNotifier(_rewardNotifier1, true);
    uniStaker.setRewardNotifier(_rewardNotifier2, true);
    uniStaker.setRewardNotifier(_rewardNotifier3, true);
    vm.stopPrank();

    // The first notifier notifies
    _mintTransferAndNotifyReward(_rewardNotifier1, _amount1);

    // The second notifier notifies
    _mintTransferAndNotifyReward(_rewardNotifier2, _amount2);

    // The third notifier notifies
    _mintTransferAndNotifyReward(_rewardNotifier3, _amount3);
    uint256 _expectedRewardRate =
      (SCALE_FACTOR * (_amount1 + _amount2 + _amount3)) / uniStaker.REWARD_DURATION();
    // because we summed 3 amounts, the rounding error can be as much as 2 units
    assertApproxEqAbs(uniStaker.scaledRewardRate(), _expectedRewardRate, 2);
    assertLe(uniStaker.scaledRewardRate(), _expectedRewardRate);
  }

  function testFuzz_EmitsAnEventWhenRewardsAreNotified(uint256 _amount) public {
    _amount = _boundToRealisticReward(_amount);
    rewardToken.mint(rewardNotifier, _amount);

    vm.startPrank(rewardNotifier);
    rewardToken.transfer(address(uniStaker), _amount);

    vm.expectEmit();
    emit UniStaker.RewardNotified(_amount, rewardNotifier);

    uniStaker.notifyRewardAmount(_amount);
    vm.stopPrank();
  }

  function testFuzz_RevertIf_CallerIsNotTheRewardNotifier(uint256 _amount, address _notNotifier)
    public
  {
    vm.assume(!uniStaker.isRewardNotifier(_notNotifier) && _notNotifier != address(0));
    _amount = _boundToRealisticReward(_amount);

    rewardToken.mint(_notNotifier, _amount);

    vm.startPrank(_notNotifier);
    rewardToken.transfer(address(uniStaker), _amount);
    vm.expectRevert(
      abi.encodeWithSelector(
        UniStaker.UniStaker__Unauthorized.selector, bytes32("not notifier"), _notNotifier
      )
    );
    uniStaker.notifyRewardAmount(_amount);
    vm.stopPrank();
  }

  function testFuzz_RevertIf_RewardAmountIsTooSmall(uint256 _amount) public {
    // If the amount is less than the rewards duration the reward rate will be truncated to 0
    _amount = bound(_amount, 0, uniStaker.REWARD_DURATION() - 1);
    rewardToken.mint(rewardNotifier, _amount);

    vm.startPrank(rewardNotifier);
    rewardToken.transfer(address(uniStaker), _amount);
    vm.expectRevert(UniStaker.UniStaker__InvalidRewardRate.selector);
    uniStaker.notifyRewardAmount(_amount);
    vm.stopPrank();
  }

  function testFuzz_RevertIf_InsufficientRewardsAreTransferredToContract(
    uint256 _amount,
    uint256 _transferPercent
  ) public {
    _amount = _boundToRealisticReward(_amount);
    // Transfer (at most) 99% of the reward amount. We calculate as a percentage rather than simply
    // an amount - 1 because rounding errors when calculating the reward rate, which favor the
    // staking contract can actually allow for something just below the amount to meet the criteria
    _transferPercent = _bound(_transferPercent, 1, 99);

    uint256 _transferAmount = _percentOf(_amount, _transferPercent);
    rewardToken.mint(rewardNotifier, _amount);

    vm.startPrank(rewardNotifier);
    // Something less than the supposed reward is sent
    rewardToken.transfer(address(uniStaker), _transferAmount);
    // The reward notification should revert because the contract doesn't have enough tokens
    vm.expectRevert(UniStaker.UniStaker__InsufficientRewardBalance.selector);
    uniStaker.notifyRewardAmount(_amount);
    vm.stopPrank();
  }
}

contract LastTimeRewardDistributed is UniStakerRewardsTest {
  function test_ReturnsZeroBeforeARewardNotificationHasOccurred() public {
    assertEq(uniStaker.lastTimeRewardDistributed(), 0);
  }

  function testFuzz_ReturnsTheBlockTimestampAfterARewardNotificationButBeforeTheRewardDurationElapses(
    uint256 _amount,
    uint256 _durationPercent
  ) public {
    _amount = _boundToRealisticReward(_amount);
    _mintTransferAndNotifyReward(_amount);

    _durationPercent = bound(_durationPercent, 0, 100);
    _jumpAheadByPercentOfRewardDuration(_durationPercent);

    assertEq(uniStaker.lastTimeRewardDistributed(), block.timestamp);
  }

  function testFuzz_ReturnsTheEndOfTheRewardDurationIfItHasFullyElapsed(
    uint256 _amount,
    uint256 _durationPercent
  ) public {
    _amount = _boundToRealisticReward(_amount);
    _mintTransferAndNotifyReward(_amount);

    uint256 _durationEnd = block.timestamp + uniStaker.REWARD_DURATION();

    _durationPercent = bound(_durationPercent, 101, 1000);
    _jumpAheadByPercentOfRewardDuration(_durationPercent);

    assertEq(uniStaker.lastTimeRewardDistributed(), _durationEnd);
  }

  function testFuzz_ReturnsTheBlockTimestampWhileWithinTheDurationOfASecondReward(
    uint256 _amount,
    uint256 _durationPercent1,
    uint256 _durationPercent2
  ) public {
    _amount = _boundToRealisticReward(_amount);
    // Notification of first reward
    _mintTransferAndNotifyReward(_amount);

    // Some time elapses, which could be more or less than the duration
    _durationPercent1 = bound(_durationPercent1, 0, 200);
    _jumpAheadByPercentOfRewardDuration(_durationPercent1);

    // Notification of the second reward
    _mintTransferAndNotifyReward(_amount);

    // Some more time elapses, this time no more than the duration
    _durationPercent2 = bound(_durationPercent2, 0, 100);
    _jumpAheadByPercentOfRewardDuration(_durationPercent2);

    assertEq(uniStaker.lastTimeRewardDistributed(), block.timestamp);
  }

  function testFuzz_ReturnsTheEndOfTheSecondRewardDurationAfterTwoRewards(
    uint256 _amount,
    uint256 _durationPercent1,
    uint256 _durationPercent2
  ) public {
    _amount = _boundToRealisticReward(_amount);
    // Notification of first reward
    _mintTransferAndNotifyReward(_amount);

    // Some time elapses, which could be more or less than the duration
    _durationPercent1 = bound(_durationPercent1, 0, 200);
    _jumpAheadByPercentOfRewardDuration(_durationPercent1);

    // Notification of the second reward
    _mintTransferAndNotifyReward(_amount);
    uint256 _durationEnd = block.timestamp + uniStaker.REWARD_DURATION();

    // Some more time elapses, placing us beyond the duration of the second reward
    _durationPercent2 = bound(_durationPercent2, 101, 1000);
    _jumpAheadByPercentOfRewardDuration(_durationPercent2);

    assertEq(uniStaker.lastTimeRewardDistributed(), _durationEnd);
  }
}

contract RewardPerTokenAccumulated is UniStakerRewardsTest {
  function testFuzz_ReturnsZeroIfThereHasNeverBeenAReward(
    address _depositor1,
    address _depositor2,
    uint96 _stakeAmount1,
    uint96 _stakeAmount2,
    uint96 _withdrawAmount,
    uint96 _stakeMoreAmount,
    uint256 _durationPercent1
  ) public {
    // We'll perform a few arbitrary actions, such as staking, withdrawing, and staking more.
    // No matter these actions, the reward per token should always be zero since there has never
    // been the notification of a reward.

    // Derive and bound the values we'll use for jumping ahead in time
    uint256 _durationPercent2 = uint256(keccak256(abi.encode(_durationPercent1)));
    uint256 _durationPercent3 = uint256(keccak256(abi.encode(_durationPercent2)));
    _durationPercent1 = bound(_durationPercent1, 0, 200);
    _durationPercent2 = bound(_durationPercent2, 0, 200);
    _durationPercent3 = bound(_durationPercent3, 0, 200);

    // First deposit
    UniStaker.DepositIdentifier _depositId1;
    (_stakeAmount1, _depositId1) = _boundMintAndStake(_depositor1, _stakeAmount1, _depositor1);
    _jumpAheadByPercentOfRewardDuration(_durationPercent1);

    // Second deposit
    (, UniStaker.DepositIdentifier _depositId2) =
      _boundMintAndStake(_depositor2, _stakeAmount2, _depositor2);
    _jumpAheadByPercentOfRewardDuration(_durationPercent2);

    // First depositor withdraws some stake
    _withdrawAmount = uint96(bound(_withdrawAmount, 0, _stakeAmount1));
    vm.prank(_depositor1);
    uniStaker.withdraw(_depositId1, _withdrawAmount);
    _jumpAheadByPercentOfRewardDuration(_durationPercent3);

    // Second depositor adds some stake
    _stakeMoreAmount = _boundToRealisticStake(_stakeMoreAmount);
    govToken.mint(_depositor2, _stakeMoreAmount);
    vm.startPrank(_depositor2);
    govToken.approve(address(uniStaker), _stakeMoreAmount);
    uniStaker.stakeMore(_depositId2, _stakeMoreAmount);
    vm.stopPrank();

    // Reward per token is still just 0
    assertEq(uniStaker.rewardPerTokenAccumulated(), 0);
  }

  function testFuzz_DoesNotChangeWhileNoTokensAreStaked(
    address _depositor,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint256 _durationPercent1,
    uint256 _durationPercent2,
    uint256 _durationPercent3
  ) public {
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);
    _durationPercent1 = _bound(_durationPercent1, 0, 100);
    _durationPercent2 = _bound(_durationPercent2, 0, 200);
    _durationPercent3 = _bound(_durationPercent3, 0, 200);

    // A user deposits staking tokens
    (, UniStaker.DepositIdentifier _depositId) =
      _boundMintAndStake(_depositor, _stakeAmount, _depositor);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // Some time less than the full duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent1);
    // We archive the value here before withdrawing the stake
    uint256 _valueBeforeStakeIsWithdrawn = uniStaker.rewardPerTokenAccumulated();
    // All of the stake is withdrawn
    vm.prank(_depositor);
    uniStaker.withdraw(_depositId, _stakeAmount);
    require(uniStaker.totalStaked() == 0, "Test Invariant violated: expected 0 stake");
    // Some additional time passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent2);
    // The contract is notified of another reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // Even more time passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent2);

    // The value should not have changed since the amount staked became zero
    assertEq(uniStaker.rewardPerTokenAccumulated(), _valueBeforeStakeIsWithdrawn);
  }

  function testFuzz_DoesNotChangeWhileNoRewardsAreBeingDistributed(
    address _depositor,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint96 _withdrawAmount,
    uint256 _durationPercent1,
    uint256 _durationPercent2,
    uint256 _durationPercent3
  ) public {
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);
    _withdrawAmount = uint96(_bound(_withdrawAmount, 0, _stakeAmount));
    _durationPercent1 = _bound(_durationPercent1, 0, 200);
    _durationPercent2 = _bound(_durationPercent2, 0, 200);
    _durationPercent3 = _bound(_durationPercent3, 0, 200);

    // A user deposits staking tokens
    (, UniStaker.DepositIdentifier _depositId) =
      _boundMintAndStake(_depositor, _stakeAmount, _depositor);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // The full duration of the reward notification passes, meaning all rewards have dripped out
    _jumpAheadByPercentOfRewardDuration(101);
    // We archive the value here before anything else happens
    uint256 _valueAfterRewardDurationCompletes = uniStaker.rewardPerTokenAccumulated();
    // Some additional time elapses
    _jumpAheadByPercentOfRewardDuration(_durationPercent1);
    // Some amount of the stake is withdrawn
    vm.prank(_depositor);
    uniStaker.withdraw(_depositId, _withdrawAmount);
    // Some additional time elapses
    _jumpAheadByPercentOfRewardDuration(_durationPercent1);
    // The user makes another deposit
    _boundMintAndStake(_depositor, _stakeAmount, _depositor);
    // Even more time passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent3);

    // The value should not have changed since the rewards stopped dripping out
    assertEq(uniStaker.rewardPerTokenAccumulated(), _valueAfterRewardDurationCompletes);
  }

  function testFuzz_DoesNotChangeIfTimeDoesNotElapse(
    address _depositor,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint96 _withdrawAmount,
    uint256 _durationPercent1
  ) public {
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);
    _withdrawAmount = uint96(_bound(_withdrawAmount, 0, _stakeAmount));
    _durationPercent1 = _bound(_durationPercent1, 0, 200);

    // A user deposits staking tokens
    (, UniStaker.DepositIdentifier _depositId) =
      _boundMintAndStake(_depositor, _stakeAmount, _depositor);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // Some amount of time elapses
    _jumpAheadByPercentOfRewardDuration(_durationPercent1);
    // We archive the value here before anything else happens
    uint256 _valueAfterTimeElapses = uniStaker.rewardPerTokenAccumulated();
    // Some amount of the stake is withdrawn
    vm.prank(_depositor);
    uniStaker.withdraw(_depositId, _withdrawAmount);
    // The contract is notified of another reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // The user makes another deposit
    _boundMintAndStake(_depositor, _stakeAmount, _depositor);

    // The value should not have changed since no additional time has elapsed
    assertEq(uniStaker.rewardPerTokenAccumulated(), _valueAfterTimeElapses);
  }

  function testFuzz_AccruesTheCorrectValueWhenADepositorStakesForSomePortionOfAReward(
    address _depositor,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint256 _durationPercent
  ) public {
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);
    _durationPercent = _bound(_durationPercent, 0, 100);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor, _stakeAmount, _depositor);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // Some time less than the full duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent);

    // The reward per token is the reward by the stake amount proportional to the elapsed time
    uint256 _expected = _percentOf(_scaledDiv(_rewardAmount, _stakeAmount), _durationPercent);
    assertLteWithinOnePercent(uniStaker.rewardPerTokenAccumulated(), _expected);
  }

  function testFuzz_AccruesTheCorrectValueWhenADepositorStakesAfterAReward(
    address _depositor,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint256 _durationPercent
  ) public {
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);
    _durationPercent = _bound(_durationPercent, 0, 100);

    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // Some time less than the full duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent);
    // A user deposits staking tokens
    _boundMintAndStake(_depositor, _stakeAmount, _depositor);
    // The rest of the duration passes
    _jumpAheadByPercentOfRewardDuration(100 - _durationPercent);

    // The reward per token is the reward by the stake amount proportional to the elapsed time
    uint256 _expected = _percentOf(_scaledDiv(_rewardAmount, _stakeAmount), 100 - _durationPercent);
    assertLteWithinOnePercent(uniStaker.rewardPerTokenAccumulated(), _expected);
  }

  function testFuzz_AccruesTheCorrectValueWhenADepositorStakesForARewardDurationAndAnotherDepositorStakesForASecondRewardDuration(
    address _depositor,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint256 _durationPercent
  ) public {
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);
    _durationPercent = _bound(_durationPercent, 100, 1000);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor, _stakeAmount, _depositor);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // The full duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent);
    // The amount of stake exactly doubles
    _boundMintAndStake(_depositor, _stakeAmount, _depositor);
    // The contract is notified of another reward of the same size
    _mintTransferAndNotifyReward(_rewardAmount);
    // The full duration passes for the second reward
    _jumpAheadByPercentOfRewardDuration(_durationPercent);

    // We expect the sum of the reward over the stake, plus the reward over twice the stake
    uint256 _expected =
      _scaledDiv(_rewardAmount, _stakeAmount) + _scaledDiv(_rewardAmount, 2 * _stakeAmount);
    assertLteWithinOnePercent(uniStaker.rewardPerTokenAccumulated(), _expected);
  }

  function testFuzz_AccruesTheCorrectValueWhenTwoDepositorsStakeAtDifferentTimesAndThereAreTwoRewards(
    address _depositor,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint256 _durationPercent1,
    uint256 _durationPercent2
  ) public {
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);
    _durationPercent1 = _bound(_durationPercent1, 0, 100);
    _durationPercent2 = _bound(_durationPercent2, 0, 100);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor, _stakeAmount, _depositor);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // Part of the reward duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent1);
    // The amount of stake exactly doubles
    _boundMintAndStake(_depositor, _stakeAmount, _depositor);
    // The contract is notified of another reward of the same size
    _mintTransferAndNotifyReward(_rewardAmount);
    // Some additional time elapses which is less than the total duration
    _jumpAheadByPercentOfRewardDuration(_durationPercent2);

    // During the first period, the value accrued is equal to to reward amount over the stake amount
    // proportional to the time elapsed
    uint256 _expectedDuration1 =
      _percentOf(_scaledDiv(_rewardAmount, _stakeAmount), _durationPercent1);
    // After the first period, some amount of the first reward remains to be distributed
    uint256 _firstRewardRemainingAmount = _percentOf(_rewardAmount, 100 - _durationPercent1);
    // During the second period, the remaining reward plus the next reward must be divided by the
    // new staked total (2x)
    uint256 _expectedDuration2 = _percentOf(
      _scaledDiv(_firstRewardRemainingAmount + _rewardAmount, 2 * _stakeAmount), _durationPercent2
    );
    // The total expected value is the sum of the value accrued during these two periods
    uint256 _expected = _expectedDuration1 + _expectedDuration2;
    assertLteWithinOnePercent(uniStaker.rewardPerTokenAccumulated(), _expected);
  }

  function testFuzz_AccruesTheCorrectValueWhenADepositorStakesAndWithdrawsDuringARewardDuration(
    address _depositor,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint96 _withdrawalAmount,
    uint256 _durationPercent1,
    uint256 _durationPercent2
  ) public {
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);
    _withdrawalAmount = uint96(_bound(_withdrawalAmount, 0, _stakeAmount - 1));
    _durationPercent1 = _bound(_durationPercent1, 0, 100);
    _durationPercent2 = _bound(_durationPercent2, 0, 100 - _durationPercent1);

    UniStaker.DepositIdentifier _depositId;

    // A user deposits staking tokens
    (, _depositId) = _boundMintAndStake(_depositor, _stakeAmount, _depositor);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // Part of the reward duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent1);
    // Some of the stake is withdrawn
    vm.prank(_depositor);
    uniStaker.withdraw(_depositId, _withdrawalAmount);
    // More of the duration elapses
    _jumpAheadByPercentOfRewardDuration(_durationPercent2);

    uint256 _expectedDuration1 =
      _percentOf(_scaledDiv(_rewardAmount, _stakeAmount), _durationPercent1);
    uint256 _expectedDuration2 =
      _percentOf(_scaledDiv(_rewardAmount, _stakeAmount - _withdrawalAmount), _durationPercent2);
    uint256 _expected = _expectedDuration1 + _expectedDuration2;
    assertLteWithinOnePercent(uniStaker.rewardPerTokenAccumulated(), _expected);
  }

  function testFuzz_AccruesTheCorrectValueWhenTwoDepositorsStakeDifferentAmountsAtDifferentTimesOverTwoRewards(
    address _depositor1,
    address _depositor2,
    uint96 _stakeAmount1,
    uint96 _stakeAmount2,
    uint256 _rewardAmount,
    uint256 _durationPercent1,
    uint256 _durationPercent2,
    uint256 _durationPercent3
  ) public {
    _stakeAmount1 = _boundToRealisticStake(_stakeAmount1);
    _stakeAmount2 = _boundToRealisticStake(_stakeAmount2);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _durationPercent1 = _bound(_durationPercent1, 0, 100);
    _durationPercent2 = _bound(_durationPercent2, 0, 100);
    _durationPercent3 = _bound(_durationPercent2, 0, 100 - _durationPercent2);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor1, _stakeAmount1, _depositor1);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // Part of the reward duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent1);
    // The contract is notified of another reward, resetting the duration
    _mintTransferAndNotifyReward(_rewardAmount);
    // Part of the new reward duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent2);
    // Another user deposits a different number of staking tokens
    _boundMintAndStake(_depositor2, _stakeAmount2, _depositor2);
    // More of the reward duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent3);

    // During the first time period, the expected value is the reward amount over the staked amount,
    // proportional to the time elapsed
    uint256 _expectedDuration1 =
      _percentOf(_scaledDiv(_rewardAmount, _stakeAmount1), _durationPercent1);
    // The rewards after the second notification are the remaining rewards plus the new rewards.
    // We scale them up here to avoid losing precision in our expectation estimates.
    uint256 _scaledRewardsAfterDuration1 = (
      SCALE_FACTOR * _rewardAmount - _percentOf(SCALE_FACTOR * _rewardAmount, _durationPercent1)
    ) + SCALE_FACTOR * _rewardAmount;
    // During the second time period, the expected value is the new reward amount over the staked
    // amount, proportional to the time elapsed
    uint256 _expectedDuration2 =
      _percentOf(_scaledRewardsAfterDuration1 / _stakeAmount1, _durationPercent2);
    // During the third time period, the expected value is the reward amount over the new total
    // staked amount, proportional to the time elapsed
    uint256 _expectedDuration3 =
      _percentOf(_scaledRewardsAfterDuration1 / (_stakeAmount1 + _stakeAmount2), _durationPercent3);

    uint256 _expected = _expectedDuration1 + _expectedDuration2 + _expectedDuration3;
    assertLteWithinOnePercent(uniStaker.rewardPerTokenAccumulated(), _expected);
  }

  function testFuzz_AccruesTheCorrectValueWhenAnArbitraryNumberOfDepositorsStakeDifferentAmountsOverTheCourseOfARewardDuration(
    address _depositor,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint256 _durationPercent
  ) public {
    _rewardAmount = _boundToRealisticReward(_rewardAmount);

    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);

    uint256 _expected;
    uint256 _totalStake;
    uint256 _totalDurationPercent;

    // Now we'll perform an arbitrary number of differently sized deposits
    while (_totalDurationPercent < 100) {
      // On each iteration we derive new values
      _depositor = address(uint160(uint256(keccak256(abi.encode(_depositor)))));
      _stakeAmount = uint96(uint256(keccak256(abi.encode(_stakeAmount))));
      _stakeAmount = _boundToRealisticStake(_stakeAmount);
      _durationPercent = uint256(keccak256(abi.encode(_durationPercent)));
      // We make sure the duration jump on each iteration isn't so small that we slow the test
      // down excessively, but also isn't so big we don't get at least a few iterations.
      _durationPercent = bound(_durationPercent, 10, 33);

      // A user deposits some staking tokens
      _boundMintAndStake(_depositor, _stakeAmount, _depositor);
      _totalStake += _stakeAmount;

      // Part of the reward duration passes
      _jumpAheadByPercentOfRewardDuration(_durationPercent);
      _totalDurationPercent += _durationPercent;

      if (_totalDurationPercent > 100) {
        // If we've jumped ahead past the end of the duration, this will be the last iteration, so
        // the only portion of the time elapsed that contributed to the accrued expected value is
        // the portion before we reached 100% of the duration.
        _durationPercent = 100 - (_totalDurationPercent - _durationPercent);
      }

      // At each iteration, we recalculate and check the accruing value
      _expected += _percentOf(_scaledDiv(_rewardAmount, _totalStake), _durationPercent);
      assertLteWithinOnePercent(uniStaker.rewardPerTokenAccumulated(), _expected);
    }
  }
}

contract UnclaimedReward is UniStakerRewardsTest {
  function testFuzz_CalculatesCorrectEarningsForASingleDepositorThatStakesForFullDuration(
    address _depositor,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount
  ) public {
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor, _stakeAmount, _delegatee);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // The full duration passes
    _jumpAheadByPercentOfRewardDuration(101);

    // The user should have earned all the rewards
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor), _rewardAmount);
  }

  function testFuzz_CalculatesCorrectEarningsWhenASingleDepositorAssignsABeneficiaryAndStakesForFullDuration(
    address _depositor,
    address _delegatee,
    address _beneficiary,
    uint96 _stakeAmount,
    uint256 _rewardAmount
  ) public {
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);

    // A user deposits staking tokens w/ a beneficiary
    _boundMintAndStake(_depositor, _stakeAmount, _delegatee, _beneficiary);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // The full duration passes
    _jumpAheadByPercentOfRewardDuration(101);

    // The beneficiary should have earned all the rewards
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_beneficiary), _rewardAmount);
  }

  function testFuzz_CalculatesCorrectEarningsWhenASingleDepositorUpdatesTheirBeneficiary(
    address _depositor,
    address _delegatee,
    address _beneficiary1,
    address _beneficiary2,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint256 _percentDuration
  ) public {
    vm.assume(
      _beneficiary1 != _beneficiary2 && _beneficiary1 != address(0) && _beneficiary2 != address(0)
    );

    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);
    _percentDuration = bound(_percentDuration, 0, 100);

    // A user deposits staking tokens w/ a beneficiary
    (, UniStaker.DepositIdentifier _depositId) =
      _boundMintAndStake(_depositor, _stakeAmount, _delegatee, _beneficiary1);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // Part of the rewards duration passes
    _jumpAheadByPercentOfRewardDuration(_percentDuration);
    // The depositor alters their beneficiary
    vm.prank(_depositor);
    uniStaker.alterBeneficiary(_depositId, _beneficiary2);
    // The rest of the duration elapses
    _jumpAheadByPercentOfRewardDuration(100 - _percentDuration);

    // The beneficiary should have earned all the rewards
    assertLteWithinOnePercent(
      uniStaker.unclaimedReward(_beneficiary1), _percentOf(_rewardAmount, _percentDuration)
    );
    assertLteWithinOnePercent(
      uniStaker.unclaimedReward(_beneficiary2), _percentOf(_rewardAmount, 100 - _percentDuration)
    );
  }

  function testFuzz_CalculatesCorrectEarningsForASingleUserThatDepositsStakeForPartialDuration(
    address _depositor,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint256 _durationPercent
  ) public {
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);
    _durationPercent = bound(_durationPercent, 0, 100);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor, _stakeAmount, _delegatee);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // One third of the duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent);

    // The user should have earned one third of the rewards
    assertLteWithinOnePercent(
      uniStaker.unclaimedReward(_depositor), _percentOf(_rewardAmount, _durationPercent)
    );
  }

  function testFuzz_CalculatesCorrectEarningsForASingleUserThatDepositsPartiallyThroughTheDuration(
    address _depositor,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount
  ) public {
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);

    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // Two thirds of the duration time passes
    _jumpAheadByPercentOfRewardDuration(66);
    // A user deposits staking tokens
    _boundMintAndStake(_depositor, _stakeAmount, _delegatee);
    // The rest of the duration elapses
    _jumpAheadByPercentOfRewardDuration(34);

    // The user should have earned 1/3rd of the rewards
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor), _percentOf(_rewardAmount, 34));
  }

  function testFuzz_CalculatesCorrectEarningsForASingleUserStakeForPartialDurationWithABeneficiary(
    address _depositor,
    address _delegatee,
    address _beneficiary,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint256 _durationPercent
  ) public {
    vm.assume(_beneficiary != address(0));

    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);
    _durationPercent = bound(_durationPercent, 0, 100);

    // A user deposits staking tokens and assigns a beneficiary
    _boundMintAndStake(_depositor, _stakeAmount, _delegatee, _beneficiary);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // Some portion of the duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent);

    // The beneficiary should have earned a portion of the rewards equal to the amount of the
    // duration that has passed
    assertLteWithinOnePercent(
      uniStaker.unclaimedReward(_beneficiary), _percentOf(_rewardAmount, _durationPercent)
    );
  }

  function testFuzz_CalculatesCorrectEarningsForASingleUserThatDepositsPartiallyThroughTheDurationWithABeneficiary(
    address _depositor,
    address _delegatee,
    address _beneficiary,
    uint96 _stakeAmount,
    uint256 _rewardAmount
  ) public {
    vm.assume(_beneficiary != address(0));
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);

    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // Two thirds of the duration time passes
    _jumpAheadByPercentOfRewardDuration(66);
    // A user deposits staking tokens and assigns a beneficiary
    _boundMintAndStake(_depositor, _stakeAmount, _delegatee, _beneficiary);
    // The rest of the duration elapses
    _jumpAheadByPercentOfRewardDuration(34);

    // The beneficiary should have earned 1/3rd of the reward
    assertLteWithinOnePercent(
      uniStaker.unclaimedReward(_beneficiary), _percentOf(_rewardAmount, 34)
    );
  }

  function testFuzz_CalculatesCorrectEarningsForASingleUserThatDepositsStakeForTheFullDurationWithNoNewRewards(
    address _depositor,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint16 _noRewardsSkip
  ) public {
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor, _stakeAmount, _delegatee);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);

    // The full duration passes
    _jumpAheadByPercentOfRewardDuration(100);
    // Time moves forward with no rewards
    _jumpAheadByPercentOfRewardDuration(_noRewardsSkip);

    // Send new rewards, which should have no impact on the amount earned until time elapses
    _mintTransferAndNotifyReward(_rewardAmount);

    // The user should have earned all the rewards
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor), _rewardAmount);
  }

  function testFuzz_CalculatesCorrectEarningsForASingleUserThatDepositsStakeForTheFullDurationWithDelayedReward(
    address _depositor,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint16 _noRewardsSkip
  ) public {
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor, _stakeAmount, _delegatee);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);

    // The full duration passes
    _jumpAheadByPercentOfRewardDuration(100);
    // Time moves forward with no rewards
    _jumpAheadByPercentOfRewardDuration(_noRewardsSkip);

    // Send new rewards
    _mintTransferAndNotifyReward(_rewardAmount);
    // We end another full duration
    _jumpAheadByPercentOfRewardDuration(100);

    // The user should have earned all the rewards
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor), _rewardAmount * 2);
  }

  function testFuzz_CalculatesCorrectEarningsWhenASingleDepositorUpdatesTheirBeneficiaryWithNoNewRewards(
    address _depositor,
    address _delegatee,
    address _beneficiary1,
    address _beneficiary2,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint256 _percentDuration,
    uint16 _noRewardsSkip
  ) public {
    vm.assume(
      _beneficiary1 != _beneficiary2 && _beneficiary1 != address(0) && _beneficiary2 != address(0)
    );

    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);
    _percentDuration = bound(_percentDuration, 0, 100);

    // A user deposits staking tokens w/ a beneficiary
    (, UniStaker.DepositIdentifier _depositId) =
      _boundMintAndStake(_depositor, _stakeAmount, _delegatee, _beneficiary1);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // Part of the rewards duration passes
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    // The depositor alters their beneficiary
    vm.prank(_depositor);
    uniStaker.alterBeneficiary(_depositId, _beneficiary2);

    // The rest of the duration elapses
    _jumpAheadByPercentOfRewardDuration(100 - _percentDuration);

    // Skip ahead with no rewards
    _jumpAheadByPercentOfRewardDuration(_noRewardsSkip);

    // Send new rewards, which should have no impact on the amount earned until time elapses
    _mintTransferAndNotifyReward(_rewardAmount);

    // The beneficiaries should have earned all the rewards for the first duration
    assertLteWithinOnePercent(
      uniStaker.unclaimedReward(_beneficiary1), _percentOf(_rewardAmount, _percentDuration)
    );
    assertLteWithinOnePercent(
      uniStaker.unclaimedReward(_beneficiary2), _percentOf(_rewardAmount, 100 - _percentDuration)
    );
  }

  function testFuzz_CalculatesCorrectEarningsForASingleUserThatDepositsStakeForTheFullDurationAndClaims(
    address _depositor,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint256 _durationPercent
  ) public {
    vm.assume(_depositor != address(uniStaker));
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);
    _durationPercent = bound(_durationPercent, 0, 100);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor, _stakeAmount, _delegatee);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);

    // The full duration passes
    _jumpAheadByPercentOfRewardDuration(101);

    // The depositor claims the rewards
    vm.prank(_depositor);
    uniStaker.claimReward();

    // Send new rewards
    _mintTransferAndNotifyReward(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_durationPercent);

    uint256 balance = uniStaker.REWARD_TOKEN().balanceOf(address(_depositor));

    // The depositors balance should reflect the first full duration
    assertLteWithinOnePercent(balance, _rewardAmount);
    // The depositor should have earned a portion of the rewards equal to the amount of the next
    // duration that has passed.
    assertLteWithinOnePercent(
      uniStaker.unclaimedReward(_depositor), _percentOf(_rewardAmount, _durationPercent)
    );
  }

  function testFuzz_CalculatesCorrectEarningsForASingleUserThatDepositsStakeForThePartialDurationAndClaims(
    address _depositor,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint256 _durationPercent
  ) public {
    vm.assume(_depositor != address(uniStaker));
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);
    _durationPercent = bound(_durationPercent, 0, 100);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor, _stakeAmount, _delegatee);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);

    // The full duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent);

    // The depositor claims the reward
    vm.prank(_depositor);
    uniStaker.claimReward();

    // We skip ahead to the end of the duration
    _jumpAheadByPercentOfRewardDuration(100 - _durationPercent);

    uint256 balance = uniStaker.REWARD_TOKEN().balanceOf(address(_depositor));

    // The depositors balance should match the portion of the duration that passed before the
    // rewards were claimed
    assertLteWithinOnePercent(balance, _percentOf(_rewardAmount, _durationPercent));
    // The depositor earned the portion of the reward after the rewards were claimed
    assertLteWithinOnePercent(
      uniStaker.unclaimedReward(_depositor), _percentOf(_rewardAmount, 100 - _durationPercent)
    );
  }

  function testFuzz_CalculatesCorrectEarningsForTwoUsersThatDepositEqualStakeForFullDuration(
    address _depositor1,
    address _depositor2,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount
  ) public {
    vm.assume(_depositor1 != _depositor2);
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor1, _stakeAmount, _delegatee);
    // Some time passes
    _jumpAhead(3000);
    // Another depositor deposits the same number of staking tokens
    _boundMintAndStake(_depositor2, _stakeAmount, _delegatee);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // The full duration passes
    _jumpAheadByPercentOfRewardDuration(101);

    // Each user should have earned half of the rewards
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor1), _percentOf(_rewardAmount, 50));
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor2), _percentOf(_rewardAmount, 50));
  }

  function testFuzz_CalculatesCorrectEarningsForTwoUsersWhenOneStakesMorePartiallyThroughTheDuration(
    address _depositor1,
    address _depositor2,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount
  ) public {
    vm.assume(_depositor1 != _depositor2);
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);

    // A user deposits staking tokens
    (, UniStaker.DepositIdentifier _depositId1) =
      _boundMintAndStake(_depositor1, _stakeAmount, _delegatee);
    // Some time passes
    _jumpAhead(3000);
    // Another depositor deposits the same number of staking tokens
    _boundMintAndStake(_depositor2, _stakeAmount, _delegatee);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // One third of the duration passes
    _jumpAheadByPercentOfRewardDuration(34);
    // The first user triples their deposit by staking 2x more
    _mintGovToken(_depositor1, 2 * _stakeAmount);
    vm.startPrank(_depositor1);
    govToken.approve(address(uniStaker), 2 * _stakeAmount);
    uniStaker.stakeMore(_depositId1, 2 * _stakeAmount);
    vm.stopPrank();
    // The rest of the duration passes
    _jumpAheadByPercentOfRewardDuration(66);

    // Depositor 1 earns half the reward for one third the time and three quarters for two thirds of
    // the time
    uint256 _depositor1ExpectedEarnings =
      _percentOf(_percentOf(_rewardAmount, 50), 34) + _percentOf(_percentOf(_rewardAmount, 75), 66);
    // Depositor 2 earns half the reward for one third the time and one quarter for two thirds of
    // the time
    uint256 _depositor2ExpectedEarnings =
      _percentOf(_percentOf(_rewardAmount, 50), 34) + _percentOf(_percentOf(_rewardAmount, 25), 66);

    // Each user should have earned half of the rewards
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor1), _depositor1ExpectedEarnings);
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor2), _depositor2ExpectedEarnings);
  }

  function testFuzz_CalculatesCorrectEarningsForTwoUsersThatDepositEqualStakeForFullDurationAndBothClaim(
    address _depositor1,
    address _depositor2,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount
  ) public {
    vm.assume(_depositor1 != _depositor2);
    vm.assume(_depositor1 != address(uniStaker) && _depositor2 != address(uniStaker));
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor1, _stakeAmount, _delegatee);
    // Some time passes
    _jumpAhead(3000);
    // Another depositor deposits the same number of staking tokens
    _boundMintAndStake(_depositor2, _stakeAmount, _delegatee);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // The full duration passes
    _jumpAheadByPercentOfRewardDuration(101);

    // Depositor 1 claims
    vm.prank(_depositor1);
    uniStaker.claimReward();

    // Depositor 2 claims
    vm.prank(_depositor2);
    uniStaker.claimReward();

    uint256 depositor1Balance = uniStaker.REWARD_TOKEN().balanceOf(address(_depositor1));
    uint256 depositor2Balance = uniStaker.REWARD_TOKEN().balanceOf(address(_depositor2));

    // Each depositors balance should be half of the reward
    assertLteWithinOnePercent(depositor1Balance, _percentOf(_rewardAmount, 50));
    assertLteWithinOnePercent(depositor2Balance, _percentOf(_rewardAmount, 50));

    // Each user should have earned nothing since they both claimed their rewards
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor1), 0);
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor2), 0);
  }

  function testFuzz_CalculatesCorrectEarningsForTwoUsersWhenOneStakesMorePartiallyThroughTheDurationAndOneClaims(
    address _depositor1,
    address _depositor2,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount
  ) public {
    vm.assume(_depositor1 != _depositor2);
    vm.assume(_depositor1 != address(uniStaker) && _depositor2 != address(uniStaker));
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);

    // A user deposits staking tokens
    (, UniStaker.DepositIdentifier _depositId1) =
      _boundMintAndStake(_depositor1, _stakeAmount, _delegatee);
    // Some time passes
    _jumpAhead(3000);
    // Another depositor deposits the same number of staking tokens
    _boundMintAndStake(_depositor2, _stakeAmount, _delegatee);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // One third of the duration passes
    _jumpAheadByPercentOfRewardDuration(34);
    // The first depositor claims their reward
    vm.prank(_depositor1);
    uniStaker.claimReward();
    // The first depositor triples their deposit by staking 2x more
    _mintGovToken(_depositor1, 2 * _stakeAmount);
    vm.startPrank(_depositor1);
    govToken.approve(address(uniStaker), 2 * _stakeAmount);
    uniStaker.stakeMore(_depositId1, 2 * _stakeAmount);
    vm.stopPrank();
    // The rest of the duration passes
    _jumpAheadByPercentOfRewardDuration(66);

    // Depositor 1 earns three quarters of the reward for two thirds of the time
    uint256 _depositor1ExpectedEarnings = _percentOf(_percentOf(_rewardAmount, 75), 66);
    // Depositor 2 earns half the reward for one third the time and one quarter for two thirds of
    // the time
    uint256 _depositor2ExpectedEarnings =
      _percentOf(_percentOf(_rewardAmount, 50), 34) + _percentOf(_percentOf(_rewardAmount, 25), 66);

    uint256 depositor1Balance = uniStaker.REWARD_TOKEN().balanceOf(address(_depositor1));
    uint256 depositor2Balance = uniStaker.REWARD_TOKEN().balanceOf(address(_depositor2));

    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor1), _depositor1ExpectedEarnings);
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor2), _depositor2ExpectedEarnings);

    // Depositor 1 should have received the reward they earned from before they claimed
    assertLteWithinOnePercent(depositor1Balance, _percentOf(_percentOf(_rewardAmount, 50), 34));
    // Depositor 2 should not have received anything because they did not claim
    assertLteWithinOnePercent(depositor2Balance, 0);
  }

  function testFuzz_CalculatesCorrectEarningsForFourUsersThatDepositEqualStakeForFullDurationWhereOneIsABeneficiaryOfTwoOthers(
    address _depositor1,
    address _depositor2,
    address _depositor3,
    address _depositor4,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount
  ) public {
    vm.assume(
      _depositor1 != _depositor2 && _depositor1 != _depositor2 && _depositor2 != _depositor3
        && _depositor1 != _depositor3 && _depositor1 != _depositor4 && _depositor2 != _depositor4
        && _depositor3 != _depositor4
    );
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor1, _stakeAmount, _delegatee);
    // Some time passes
    _jumpAhead(3000);
    // Another depositor deposits the same number of staking tokens
    _boundMintAndStake(_depositor2, _stakeAmount, _delegatee);
    // Some time passes
    _jumpAhead(3000);
    // Another depositor deposits and adds the first depositor as the beneficiary
    _boundMintAndStake(_depositor3, _stakeAmount, _delegatee, _depositor1);
    // Some time passes
    _jumpAhead(3000);
    // Another depositor deposits and adds the first depositor as the beneficiary
    _boundMintAndStake(_depositor4, _stakeAmount, _delegatee, _depositor1);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // The full duration passes
    _jumpAheadByPercentOfRewardDuration(101);

    // The first depositor has earn 3/4 of the and depositor 2 should earn a quarter of the reward
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor1), _percentOf(_rewardAmount, 75));
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor2), _percentOf(_rewardAmount, 25));
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor3), 0);
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor4), 0);
  }

  function testFuzz_CalculatesCorrectEarningsForFourUsersWhenOneStakesMorePartiallyThroughTheDurationAndTwoBeneficiaries(
    address _depositor1,
    address _depositor2,
    address _depositor3,
    address _depositor4,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount
  ) public {
    vm.assume(
      _depositor1 != _depositor2 && _depositor1 != _depositor2 && _depositor2 != _depositor3
        && _depositor1 != _depositor3 && _depositor1 != _depositor4 && _depositor2 != _depositor4
        && _depositor3 != _depositor4
    );
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);

    // A user deposits staking tokens
    (, UniStaker.DepositIdentifier _depositId1) =
      _boundMintAndStake(_depositor1, _stakeAmount, _delegatee);
    // Some time passes
    _jumpAhead(3000);
    // Another depositor deposits the same number of staking tokens
    _boundMintAndStake(_depositor2, _stakeAmount, _delegatee);
    // Some time passes
    _jumpAhead(3000);
    // Another depositor deposits the same number of staking tokens and adds the second depositor as
    // a beneficiary
    _boundMintAndStake(_depositor3, _stakeAmount, _delegatee, _depositor2);
    // Some time passes
    _jumpAhead(3000);
    // Another depositor deposits the same number of staking tokens and adds the first depositor as
    // a beneficiary
    _boundMintAndStake(_depositor4, _stakeAmount, _delegatee, _depositor1);

    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // One third of the duration passes
    _jumpAheadByPercentOfRewardDuration(34);
    // The first user doubles their stake
    _mintGovToken(_depositor1, _stakeAmount);
    vm.startPrank(_depositor1);
    govToken.approve(address(uniStaker), _stakeAmount);
    uniStaker.stakeMore(_depositId1, _stakeAmount);
    vm.stopPrank();
    // The rest of the duration passes
    _jumpAheadByPercentOfRewardDuration(66);

    // Depositor 1 earns half the reward for one third the time and three fifths for two thirds of
    // the time
    uint256 _depositor1ExpectedEarnings =
      _percentOf(_percentOf(_rewardAmount, 50), 34) + _percentOf(_percentOf(_rewardAmount, 60), 66);
    // Depositor 2 earns half the reward for one third the time and two fifths for two thirds of
    // the time
    uint256 _depositor2ExpectedEarnings =
      _percentOf(_percentOf(_rewardAmount, 50), 34) + _percentOf(_percentOf(_rewardAmount, 40), 66);

    // The third and fourth depositor earn nothing because they are sending their rewards to a
    // beneficiary
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor1), _depositor1ExpectedEarnings);
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor2), _depositor2ExpectedEarnings);
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor3), 0);
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor4), 0);
  }

  function testFuzz_CalculatesCorrectEarningsForFourUsersWhenTwoStakeMorePartiallyThroughTheDurationAndOneBeneficiary(
    address _depositor1,
    address _depositor2,
    address _depositor3,
    address _depositor4,
    uint96 _stakeAmount,
    uint256 _rewardAmount
  ) public {
    vm.assume(
      _depositor1 != _depositor2 && _depositor1 != _depositor2 && _depositor2 != _depositor3
        && _depositor1 != _depositor3 && _depositor1 != _depositor4 && _depositor2 != _depositor4
        && _depositor3 != _depositor4
    );
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);

    // A user deposits staking tokens
    (, UniStaker.DepositIdentifier _depositId1) =
      _boundMintAndStake(_depositor1, _stakeAmount, _depositor1);
    // Some time passes
    _jumpAhead(3000);
    // Another depositor deposits the same number of staking tokens
    (, UniStaker.DepositIdentifier _depositId2) =
      _boundMintAndStake(_depositor2, _stakeAmount, _depositor1);
    // Some time passes
    _jumpAhead(3000);
    // Another depositor deposits the same number of staking tokens
    (, UniStaker.DepositIdentifier _depositId3) =
      _boundMintAndStake(_depositor3, _stakeAmount, _depositor1);
    // Some time passes
    _jumpAhead(3000);
    // Another depositor deposits the same number of staking tokens
    _boundMintAndStake(_depositor4, _stakeAmount, _depositor1);

    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // One quarter of the duration passes
    _jumpAheadByPercentOfRewardDuration(25);
    // The first user doubles their deposit
    _mintGovToken(_depositor1, _stakeAmount);
    vm.startPrank(_depositor1);
    govToken.approve(address(uniStaker), _stakeAmount);
    uniStaker.stakeMore(_depositId1, _stakeAmount);
    vm.stopPrank();

    // Another quarter of the duration passes
    _jumpAheadByPercentOfRewardDuration(25);
    // The second users doubles their deposit
    vm.startPrank(_depositor2);
    _mintGovToken(_depositor2, _stakeAmount);
    vm.startPrank(_depositor2);
    govToken.approve(address(uniStaker), _stakeAmount);
    uniStaker.stakeMore(_depositId2, _stakeAmount);
    vm.stopPrank();

    // The third user changes their beneficiary
    vm.startPrank(_depositor3);
    uniStaker.alterBeneficiary(_depositId3, _depositor1);
    vm.stopPrank();

    // The first depositor withdraws half of their deposit
    vm.startPrank(_depositor1);
    uniStaker.withdraw(_depositId1, _stakeAmount);
    vm.stopPrank();

    // The rest of the duration passes
    _jumpAheadByPercentOfRewardDuration(50);

    // Depositor 1 earns 25% of the reward for one quarter of the time and 40% of the reward three
    // quarter of the time
    uint256 _depositor1ExpectedEarnings =
      _percentOf(_percentOf(_rewardAmount, 25), 25) + _percentOf(_percentOf(_rewardAmount, 40), 75);
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor1), _depositor1ExpectedEarnings);

    // Depositor 2 earns a quarter of the reward for one quarter of the time, a fifth of the
    // reward one quarter of the time, and 40 percent of the reward half the time
    uint256 _depositor2ExpectedEarnings = _percentOf(_percentOf(_rewardAmount, 25), 25)
      + _percentOf(_percentOf(_rewardAmount, 20), 25) + _percentOf(_percentOf(_rewardAmount, 40), 50);
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor2), _depositor2ExpectedEarnings);

    // Depositor 3 earns 25% of the reward for a quarter of the time, 20% of the reward a quarter of
    // the time and no reward half the time.
    uint256 _depositor3ExpectedEarnings =
      _percentOf(_percentOf(_rewardAmount, 25), 25) + _percentOf(_percentOf(_rewardAmount, 20), 25);
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor3), _depositor3ExpectedEarnings);

    // Depositor 4 earns 25% of the reward for a quarter of the time, 20% of the reward 3 quarters
    // of the time.
    uint256 _depositor4ExpectedEarnings =
      _percentOf(_percentOf(_rewardAmount, 25), 25) + _percentOf(_percentOf(_rewardAmount, 20), 75);
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor4), _depositor4ExpectedEarnings);
  }

  function testFuzz_CalculatesCorrectEarningsWhenAUserStakesThroughTheDurationAndAnotherStakesPartially(
    address _depositor1,
    address _depositor2,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount
  ) public {
    vm.assume(_depositor1 != _depositor2);
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);

    // The first user stakes some tokens
    _boundMintAndStake(_depositor1, _stakeAmount, _delegatee);
    // A small amount of time passes
    _jumpAhead(3000);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // Two thirds of the duration time elapses
    _jumpAheadByPercentOfRewardDuration(66);
    // A second user stakes the same amount of tokens
    _boundMintAndStake(_depositor2, _stakeAmount, _delegatee);
    // The rest of the duration elapses
    _jumpAheadByPercentOfRewardDuration(34);

    // Depositor 1 earns the full rewards for 2/3rds of the time & 1/2 the reward for 1/3rd of the
    // time
    uint256 _depositor1ExpectedEarnings =
      _percentOf(_rewardAmount, 66) + _percentOf(_percentOf(_rewardAmount, 50), 34);
    // Depositor 2 earns 1/2 the rewards for 1/3rd of the duration time
    uint256 _depositor2ExpectedEarnings = _percentOf(_percentOf(_rewardAmount, 50), 34);

    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor1), _depositor1ExpectedEarnings);
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor2), _depositor2ExpectedEarnings);
  }

  function testFuzz_CalculatesCorrectEarningsWhenAUserDepositsAndThereAreTwoRewards(
    address _depositor,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount1,
    uint256 _rewardAmount2
  ) public {
    (_stakeAmount, _rewardAmount1) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount1);
    (_stakeAmount, _rewardAmount2) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount2);

    // A user stakes tokens
    _boundMintAndStake(_depositor, _stakeAmount, _delegatee);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount1);
    // Two thirds of duration elapses
    _jumpAheadByPercentOfRewardDuration(66);
    // The contract is notified of a new reward, which restarts the reward the duration
    _mintTransferAndNotifyReward(_rewardAmount2);
    // Another third of the duration time elapses
    _jumpAheadByPercentOfRewardDuration(34);

    // For the first two thirds of the duration, the depositor earned all of the rewards being
    // dripped out. Then more rewards were distributed. This resets the period. For the next
    // period, which we chose to be another third of the duration, the depositor continued to earn
    // all of the rewards being dripped, which now comprised of the remaining third of the first
    // reward plus the second reward.
    uint256 _depositorExpectedEarnings = _percentOf(_rewardAmount1, 66)
      + _percentOf(_percentOf(_rewardAmount1, 34) + _rewardAmount2, 34);
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor), _depositorExpectedEarnings);
  }

  function testFuzz_CalculatesCorrectEarningsWhenTwoUsersDepositForPartialDurationsAndThereAreTwoRewards(
    address _depositor1,
    address _depositor2,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount1,
    uint256 _rewardAmount2
  ) public {
    vm.assume(_depositor1 != _depositor2);
    (_stakeAmount, _rewardAmount1) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount1);
    (_stakeAmount, _rewardAmount2) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount2);

    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount1);
    // One quarter of the duration elapses
    _jumpAheadByPercentOfRewardDuration(25);
    // A user stakes some tokens
    _boundMintAndStake(_depositor1, _stakeAmount, _delegatee);
    // Another 40 percent of the duration time elapses
    _jumpAheadByPercentOfRewardDuration(40);
    // Another user stakes some tokens
    _boundMintAndStake(_depositor2, _stakeAmount, _delegatee);
    // Another quarter of the duration elapses
    _jumpAheadByPercentOfRewardDuration(25);
    // The contract receives another reward, resetting the duration
    _mintTransferAndNotifyReward(_rewardAmount2);
    // Another 20 percent of the duration elapses
    _jumpAheadByPercentOfRewardDuration(20);

    // The second depositor earns:
    // * Half the rewards distributed (split with depositor 1) over 1/4 of the duration, where the
    //   rewards being earned are all from the first reward notification
    // * Half the rewards (split with depositor 1) over 1/5 of the duration, where the rewards
    //   being earned are the remaining 10% of the first reward notification, plus the second
    //   reward notification
    uint256 _depositor2ExpectedEarnings = _percentOf(_percentOf(_rewardAmount1, 25), 50)
      + _percentOf(_percentOf(_percentOf(_rewardAmount1, 10) + _rewardAmount2, 20), 50);

    // The first depositor earns the same amount as the second depositor, since they had the same
    // stake and thus split the rewards during the period where both were staking. But the first
    // depositor also earned all of the rewards for 40% of the duration, where the rewards being
    // earned were from the first reward notification.
    uint256 _depositor1ExpectedEarnings =
      _percentOf(_rewardAmount1, 40) + _depositor2ExpectedEarnings;

    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor1), _depositor1ExpectedEarnings);
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor2), _depositor2ExpectedEarnings);
  }

  function testFuzz_CalculatesCorrectEarningsWhenTwoUsersDepositDifferentAmountsForPartialDurationsAndThereAreTwoRewards(
    address _depositor1,
    address _depositor2,
    address _delegatee,
    uint96 _stakeAmount1,
    uint96 _stakeAmount2,
    uint256 _rewardAmount1,
    uint256 _rewardAmount2
  ) public {
    vm.assume(_depositor1 != _depositor2);
    (_stakeAmount1, _rewardAmount1) = _boundToRealisticStakeAndReward(_stakeAmount1, _rewardAmount1);
    (_stakeAmount2, _rewardAmount2) = _boundToRealisticStakeAndReward(_stakeAmount2, _rewardAmount2);

    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount1);
    // One quarter of the duration elapses
    _jumpAheadByPercentOfRewardDuration(25);
    // A user stakes some tokens
    _boundMintAndStake(_depositor1, _stakeAmount1, _delegatee);
    // Another 40 percent of the duration time elapses
    _jumpAheadByPercentOfRewardDuration(40);
    // Another user stakes some tokens
    _boundMintAndStake(_depositor2, _stakeAmount2, _delegatee);
    // Another quarter of the duration elapses
    _jumpAheadByPercentOfRewardDuration(25);
    // The contract receives another reward, resetting the duration
    _mintTransferAndNotifyReward(_rewardAmount2);
    // Another 20 percent of the duration elapses
    _jumpAheadByPercentOfRewardDuration(20);

    // The total staked by both depositors together
    uint256 _combinedStake = _stakeAmount1 + _stakeAmount2;
    // These are the total rewards distributed by the contract after the second depositor adds
    // their stake. It is the first reward for a quarter of the duration, plus the remaining 10% of
    // the first reward, plus the second reward, for a fifth of the duration.
    uint256 _combinedPhaseExpectedTotalRewards = _percentOf(_rewardAmount1, 25)
      + _percentOf(_percentOf(_rewardAmount1, 10) + _rewardAmount2, 20);

    // The second depositor should earn a share of the combined phase reward scaled by their
    // portion of the total stake.
    uint256 _depositor2ExpectedEarnings =
      (_stakeAmount2 * _combinedPhaseExpectedTotalRewards) / _combinedStake;

    // The first depositor earned all of the rewards for 40% of the duration, where the rewards
    // were from the first reward notification. The first depositor also earns a share of the
    // combined phase rewards proportional to his share of the stake.
    uint256 _depositor1ExpectedEarnings = _percentOf(_rewardAmount1, 40)
      + (_stakeAmount1 * _combinedPhaseExpectedTotalRewards) / _combinedStake;

    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor1), _depositor1ExpectedEarnings);
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor2), _depositor2ExpectedEarnings);
  }

  // Could potentially add duration
  function testFuzz_CalculatesCorrectEarningsWhenAUserDepositsAndThereAreThreeRewards(
    address _depositor,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount1,
    uint256 _rewardAmount2,
    uint256 _rewardAmount3
  ) public {
    (_stakeAmount, _rewardAmount1) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount1);
    (_stakeAmount, _rewardAmount2) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount2);
    (_stakeAmount, _rewardAmount3) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount3);

    // A user stakes tokens
    _boundMintAndStake(_depositor, _stakeAmount, _delegatee);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount1);
    // Two thirds of duration elapses
    _jumpAheadByPercentOfRewardDuration(40);
    // The contract is notified of a new reward, which restarts the reward the duration
    _mintTransferAndNotifyReward(_rewardAmount2);
    // Another third of the duration time elapses
    _jumpAheadByPercentOfRewardDuration(30);
    _mintTransferAndNotifyReward(_rewardAmount3);

    _jumpAheadByPercentOfRewardDuration(30);

    // For the first 40% of the duration, the depositor earned all of the rewards being
    // dripped out. Then more rewards were distributed. This resets the period. For the next
    // period, which we chose to be 30% of the duration, the depositor continued to earn
    // all of the rewards being dripped, which now comprised of the remaining 60% of the first
    // reward plus the second reward. For the next period, which we chose to be another 30% of the
    // duration, the depositor continued to earn the rewards of the previous period, which now
    // comprised of the remaining 70% of second period reward plus 30% of the third reward.
    uint256 _depositorExpectedEarnings = _percentOf(_rewardAmount1, 40)
      + _percentOf(_percentOf(_rewardAmount1, 60) + _rewardAmount2, 30)
      + _percentOf(
        _percentOf(_percentOf(_rewardAmount1, 60) + _rewardAmount2, 70) + _rewardAmount3, 30
      );
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor), _depositorExpectedEarnings);
  }

  function testFuzz_CalculatesCorrectEarningsWhenTwoUsersDepositForPartialDurationsAndThereAreThreeRewards(
    address _depositor1,
    address _depositor2,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount1,
    uint256 _rewardAmount2,
    uint256 _rewardAmount3
  ) public {
    vm.assume(_depositor1 != _depositor2);
    (_stakeAmount, _rewardAmount1) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount1);
    (_stakeAmount, _rewardAmount2) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount2);
    (_stakeAmount, _rewardAmount3) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount3);

    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount1);
    // One quarter of the duration elapses
    _jumpAheadByPercentOfRewardDuration(25);
    // A user stakes some tokens
    _boundMintAndStake(_depositor1, _stakeAmount, _delegatee);
    // Another 20 percent of the duration time elapses
    _jumpAheadByPercentOfRewardDuration(20);
    // Another user stakes some tokens
    _boundMintAndStake(_depositor2, _stakeAmount, _delegatee);
    // Another 20 percent of the duration time elapses
    _jumpAheadByPercentOfRewardDuration(20);
    // The contract receives another reward, resetting the duration
    _mintTransferAndNotifyReward(_rewardAmount2);
    // Another 20 percent of the duration elapses
    _jumpAheadByPercentOfRewardDuration(20);
    // The contract receives another reward, resetting the duration
    _mintTransferAndNotifyReward(_rewardAmount3);
    // Another 20 percent of the duration elapses
    _jumpAheadByPercentOfRewardDuration(20);

    // The second depositor earns:
    // * Half the rewards distributed (split with depositor 1) over 1/5 of the duration, where the
    //   rewards being earned are all from the first reward notification
    // * Half the rewards (split with depositor 1) over 1/5 of the duration, where the rewards
    //   being earned are the remaining 35% of the first reward notification, plus 20% the second
    //   reward notification
    // * Half the rewards (split with depositor 1) over 1/5 the duration where the rewards being
    // earned
    //   are 20% of the previous reward and the third reward
    uint256 _depositor2ExpectedEarnings = _percentOf(_percentOf(_rewardAmount1, 20), 50)
      + _percentOf(_percentOf(_percentOf(_rewardAmount1, 35) + _rewardAmount2, 20), 50)
      + _percentOf(
        _percentOf(
          _percentOf(_percentOf(_rewardAmount1, 35) + _rewardAmount2, 80) + _rewardAmount3, 20
        ),
        50
      );

    // // The first depositor earns the same amount as the second depositor, since they had the same
    // // stake and thus split the rewards during the period where both were staking. But the first
    // // depositor also earned all of the rewards for 20% of the duration, where the rewards being
    // // earned were from the first reward notification.
    uint256 _depositor1ExpectedEarnings =
      _percentOf(_rewardAmount1, 20) + _depositor2ExpectedEarnings;

    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor1), _depositor1ExpectedEarnings);
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor2), _depositor2ExpectedEarnings);
  }

  function testFuzz_CalculatesCorrectEarningsWhenTwoUsersDepositDifferentAmountsForPartialDurationsAndThereAreThreeRewards(
    address _depositor1,
    address _depositor2,
    address _delegatee,
    uint96 _stakeAmount1,
    uint96 _stakeAmount2,
    uint256 _rewardAmount1,
    uint256 _rewardAmount2,
    uint256 _rewardAmount3
  ) public {
    vm.assume(_depositor1 != _depositor2);
    (_stakeAmount1, _rewardAmount1) = _boundToRealisticStakeAndReward(_stakeAmount1, _rewardAmount1);
    (_stakeAmount2, _rewardAmount2) = _boundToRealisticStakeAndReward(_stakeAmount2, _rewardAmount2);
    (_stakeAmount2, _rewardAmount3) = _boundToRealisticStakeAndReward(_stakeAmount2, _rewardAmount3);

    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount1);
    // One quarter of the duration elapses
    _jumpAheadByPercentOfRewardDuration(25);
    // A user stakes some tokens
    _boundMintAndStake(_depositor1, _stakeAmount1, _delegatee);
    // Another 40 percent of the duration time elapses
    _jumpAheadByPercentOfRewardDuration(20);
    // Another user stakes some tokens
    _boundMintAndStake(_depositor2, _stakeAmount2, _delegatee);
    // Another quarter of the duration elapses
    _jumpAheadByPercentOfRewardDuration(20);
    // The contract receives another reward, resetting the duration
    _mintTransferAndNotifyReward(_rewardAmount2);
    // Another quarter of the duration elapses
    _jumpAheadByPercentOfRewardDuration(20);
    // The contract receives another reward, resetting the duration
    _mintTransferAndNotifyReward(_rewardAmount3);
    // Another 20 percent of the duration elapses
    _jumpAheadByPercentOfRewardDuration(20);

    // The total staked by both depositors together
    uint256 _combinedStake = _stakeAmount1 + _stakeAmount2;
    // These are the total rewards distributed by the contract after the second depositor adds
    // their stake. It is the first reward for a fifth of the duration, plus the remaining 35% of
    // the first reward, plus 20% the second reward, for a fifth of the duration, plus the 80% of
    // the previous amount plus the third reward for 20% of the duration.
    uint256 _combinedPhaseExpectedTotalRewards = _percentOf(_rewardAmount1, 20)
      + _percentOf(_percentOf(_rewardAmount1, 35) + _rewardAmount2, 20)
      + _percentOf(
        _percentOf(_percentOf(_rewardAmount1, 35) + _rewardAmount2, 80) + _rewardAmount3, 20
      );

    // The second depositor should earn a share of the combined phase reward scaled by their
    // portion of the total stake.
    uint256 _depositor2ExpectedEarnings =
      (_stakeAmount2 * _combinedPhaseExpectedTotalRewards) / _combinedStake;

    // The first depositor earned all of the rewards for 20% of the duration, where the rewards
    // were from the first reward notification. The first depositor also earns a share of the
    // combined phase rewards proportional to his share of the stake.
    uint256 _depositor1ExpectedEarnings = _percentOf(_rewardAmount1, 20)
      + (_stakeAmount1 * _combinedPhaseExpectedTotalRewards) / _combinedStake;

    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor1), _depositor1ExpectedEarnings);
    assertLteWithinOnePercent(uniStaker.unclaimedReward(_depositor2), _depositor2ExpectedEarnings);
  }

  function testFuzz_CalculatesEarningsThatAreLessThanOrEqualToRewardsReceived(
    address _depositor1,
    address _depositor2,
    address _delegatee,
    uint96 _stakeAmount1,
    uint96 _stakeAmount2,
    uint256 _rewardAmount,
    uint256 _durationPercent
  ) public {
    vm.assume(_depositor1 != _depositor2);

    (_stakeAmount1, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount1, _rewardAmount);
    _stakeAmount2 = _boundToRealisticStake(_stakeAmount2);
    _durationPercent = bound(_durationPercent, 0, 100);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor1, _stakeAmount1, _delegatee);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // A portion of the duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent);
    // Another user deposits stake
    _boundMintAndStake(_depositor2, _stakeAmount2, _delegatee);
    // The rest of the duration elapses
    _jumpAheadByPercentOfRewardDuration(100 - _durationPercent);

    uint256 _earned1 = uniStaker.unclaimedReward(_depositor1);
    uint256 _earned2 = uniStaker.unclaimedReward(_depositor2);

    // Rewards earned by depositors should always at most equal to the actual reward amount
    assertLteWithinOnePercent(_earned1 + _earned2, _rewardAmount);
  }

  function test_CalculatesEarningsInAWayThatMitigatesRewardGriefing() public {
    address _depositor1 = makeAddr("Depositor 1");
    address _depositor2 = makeAddr("Depositor 2");
    address _depositor3 = makeAddr("Depositor 3");
    address _delegatee = makeAddr("Delegatee");
    address _attacker = makeAddr("Attacker");

    uint96 _smallDepositAmount = 0.1e18;
    uint96 _largeDepositAmount = 25_000_000e18;
    _mintGovToken(_depositor1, _smallDepositAmount);
    _mintGovToken(_depositor2, _smallDepositAmount);
    _mintGovToken(_depositor3, _largeDepositAmount);
    uint256 _rewardAmount = 1e14;
    rewardToken.mint(rewardNotifier, _rewardAmount);

    // The contract is notified of a reward
    vm.startPrank(rewardNotifier);
    rewardToken.transfer(address(uniStaker), _rewardAmount);
    uniStaker.notifyRewardAmount(_rewardAmount);
    vm.stopPrank();

    // User deposit staking tokens
    _stake(_depositor1, _smallDepositAmount, _delegatee);
    _stake(_depositor2, _smallDepositAmount, _delegatee);
    _stake(_depositor3, _largeDepositAmount, _delegatee);

    // Every block _attacker deposits 0 stake and assigns _depositor1 as beneficiary, thus leading
    // to frequent updates of the reward checkpoint for _depositor1, during which rounding errors
    // could accrue.
    UniStaker.DepositIdentifier _depositId = _stake(_attacker, 0, _delegatee, _depositor1);
    for (uint256 i = 0; i < 1000; ++i) {
      _jumpAhead(12);
      vm.prank(_attacker);
      uniStaker.stakeMore(_depositId, 0);
    }

    // Despite the attempted griefing attack, the unclaimed rewards for the two depositors should
    // be ~the same.
    assertLteWithinOnePercent(
      uniStaker.unclaimedReward(_depositor1), uniStaker.unclaimedReward(_depositor2)
    );
  }
}

contract ClaimReward is UniStakerRewardsTest {
  function testFuzz_SendsRewardsEarnedToTheUser(
    address _depositor,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint256 _durationPercent
  ) public {
    vm.assume(_depositor != address(uniStaker));

    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);
    _durationPercent = bound(_durationPercent, 0, 100);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor, _stakeAmount, _delegatee);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // A portion of the duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent);

    uint256 _earned = uniStaker.unclaimedReward(_depositor);

    vm.prank(_depositor);
    uniStaker.claimReward();

    assertEq(rewardToken.balanceOf(_depositor), _earned);
  }

  function testFuzz_ReturnsClaimedRewardAmount(
    address _depositor,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint256 _durationPercent
  ) public {
    vm.assume(_depositor != address(uniStaker));

    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);
    _durationPercent = bound(_durationPercent, 0, 100);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor, _stakeAmount, _delegatee);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // A portion of the duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent);

    uint256 _earned = uniStaker.unclaimedReward(_depositor);

    vm.prank(_depositor);
    uint256 _claimedAmount = uniStaker.claimReward();

    assertEq(_earned, _claimedAmount);
  }

  function testFuzz_ResetsTheRewardsEarnedByTheUser(
    address _depositor,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint256 _durationPercent
  ) public {
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);
    _durationPercent = bound(_durationPercent, 0, 100);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor, _stakeAmount, _delegatee);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // A portion of the duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent);

    vm.prank(_depositor);
    uniStaker.claimReward();

    assertEq(uniStaker.unclaimedReward(_depositor), 0);
  }

  function testFuzz_EmitsAnEventWhenRewardsAreClaimed(
    address _depositor,
    address _delegatee,
    uint96 _stakeAmount,
    uint256 _rewardAmount,
    uint256 _durationPercent
  ) public {
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);
    _durationPercent = bound(_durationPercent, 1, 100);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor, _stakeAmount, _delegatee);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // A portion of the duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent);

    uint256 _earned = uniStaker.unclaimedReward(_depositor);

    vm.expectEmit();
    emit UniStaker.RewardClaimed(_depositor, _earned);

    vm.prank(_depositor);
    uniStaker.claimReward();
  }
}

contract ClaimRewardOnBehalf is UniStakerRewardsTest {
  using stdStorage for StdStorage;

  function testFuzz_ClaimRewardOnBehalfOfBeneficiary(
    uint256 _beneficiaryPrivateKey,
    address _sender,
    uint96 _depositAmount,
    uint256 _durationPercent,
    uint256 _rewardAmount,
    address _delegatee,
    address _depositor,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _depositor != address(0) && _sender != address(0));
    _beneficiaryPrivateKey = bound(_beneficiaryPrivateKey, 1, 100e18);
    address _beneficiary = vm.addr(_beneficiaryPrivateKey);

    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_depositAmount, _rewardAmount);
    _durationPercent = bound(_durationPercent, 0, 100);

    // A user deposits staking tokens
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _beneficiary);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // A portion of the duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent);
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);

    uint256 _earned = uniStaker.unclaimedReward(_beneficiary);

    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_beneficiary).checked_write(
      _currentNonce
    );

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.CLAIM_REWARD_TYPEHASH(), _beneficiary, uniStaker.nonces(_beneficiary), _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_beneficiaryPrivateKey, _messageHash);

    vm.prank(_sender);
    uniStaker.claimRewardOnBehalf(_beneficiary, _deadline, _signature);

    assertEq(rewardToken.balanceOf(_beneficiary), _earned);
  }

  function testFuzz_ReturnsClaimedRewardAmount(
    uint256 _beneficiaryPrivateKey,
    address _sender,
    uint96 _depositAmount,
    uint256 _durationPercent,
    uint256 _rewardAmount,
    address _delegatee,
    address _depositor,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _depositor != address(0) && _sender != address(0));
    _beneficiaryPrivateKey = bound(_beneficiaryPrivateKey, 1, 100e18);
    address _beneficiary = vm.addr(_beneficiaryPrivateKey);

    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_depositAmount, _rewardAmount);
    _durationPercent = bound(_durationPercent, 0, 100);

    // A user deposits staking tokens
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _beneficiary);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // A portion of the duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent);
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);

    uint256 _earned = uniStaker.unclaimedReward(_beneficiary);

    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_beneficiary).checked_write(
      _currentNonce
    );

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.CLAIM_REWARD_TYPEHASH(), _beneficiary, uniStaker.nonces(_beneficiary), _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_beneficiaryPrivateKey, _messageHash);

    vm.prank(_sender);
    uint256 _claimedAmount = uniStaker.claimRewardOnBehalf(_beneficiary, _deadline, _signature);

    assertEq(_earned, _claimedAmount);
  }

  function testFuzz_RevertIf_WrongNonceIsUsed(
    uint256 _beneficiaryPrivateKey,
    address _sender,
    uint96 _depositAmount,
    uint256 _durationPercent,
    uint256 _rewardAmount,
    address _delegatee,
    address _depositor,
    uint256 _currentNonce,
    uint256 _suppliedNonce,
    uint256 _deadline
  ) public {
    vm.assume(_currentNonce != _suppliedNonce);
    vm.assume(_delegatee != address(0) && _depositor != address(0) && _sender != address(0));
    _beneficiaryPrivateKey = bound(_beneficiaryPrivateKey, 1, 100e18);
    address _beneficiary = vm.addr(_beneficiaryPrivateKey);

    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_depositAmount, _rewardAmount);
    _durationPercent = bound(_durationPercent, 0, 100);

    // A user deposits staking tokens
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _beneficiary);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // A portion of the duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent);
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);

    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_beneficiary).checked_write(
      _currentNonce
    );

    bytes32 _message = keccak256(
      abi.encode(uniStaker.CLAIM_REWARD_TYPEHASH(), _beneficiary, _suppliedNonce, _deadline)
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_beneficiaryPrivateKey, _messageHash);

    vm.expectRevert(UniStaker.UniStaker__InvalidSignature.selector);
    vm.prank(_sender);
    uniStaker.claimRewardOnBehalf(_beneficiary, _deadline, _signature);
  }

  function testFuzz_RevertIf_DeadlineExpired(
    uint256 _beneficiaryPrivateKey,
    address _sender,
    uint96 _depositAmount,
    uint256 _durationPercent,
    uint256 _rewardAmount,
    address _delegatee,
    address _depositor,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _depositor != address(0) && _sender != address(0));
    _beneficiaryPrivateKey = bound(_beneficiaryPrivateKey, 1, 100e18);
    address _beneficiary = vm.addr(_beneficiaryPrivateKey);

    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_depositAmount, _rewardAmount);
    _durationPercent = bound(_durationPercent, 0, 100);

    // A user deposits staking tokens
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _beneficiary);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // A portion of the duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent);
    _deadline = bound(_deadline, 0, block.timestamp - 1);

    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_beneficiary).checked_write(
      _currentNonce
    );

    bytes32 _message = keccak256(
      abi.encode(uniStaker.CLAIM_REWARD_TYPEHASH(), _beneficiary, _currentNonce, _deadline)
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_beneficiaryPrivateKey, _messageHash);

    vm.expectRevert(UniStaker.UniStaker__ExpiredDeadline.selector);
    vm.prank(_sender);
    uniStaker.claimRewardOnBehalf(_beneficiary, _deadline, _signature);
  }

  function testFuzz_RevertIf_InvalidSignatureIsPassed(
    uint256 _beneficiaryPrivateKey,
    address _sender,
    uint96 _depositAmount,
    address _depositor,
    address _delegatee,
    uint256 _currentNonce,
    uint256 _randomSeed,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _depositor != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _beneficiaryPrivateKey = bound(_beneficiaryPrivateKey, 1, 100e18);
    address _beneficiary = vm.addr(_beneficiaryPrivateKey);
    _depositAmount = _boundMintAmount(_depositAmount);
    _mintGovToken(_depositor, _depositAmount);
    stdstore.target(address(uniStaker)).sig("nonces(address)").with_key(_beneficiary).checked_write(
      _currentNonce
    );

    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _beneficiary);

    bytes32 _message = keccak256(
      abi.encode(
        uniStaker.CLAIM_REWARD_TYPEHASH(), _beneficiary, uniStaker.nonces(_beneficiary), _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));

    // Here we use `_randomSeed` as an arbitrary source of randomness to replace a legit
    // parameter with an attack-like one.
    if (_randomSeed % 4 == 0) {
      _beneficiary = address(uint160(uint256(keccak256(abi.encode(_beneficiary)))));
    } else if (_randomSeed % 4 == 1) {
      _messageHash = _modifyMessage(_messageHash, uint256(keccak256(abi.encode(_randomSeed))));
    } else if (_randomSeed % 4 == 2) {
      _deadline = uint256(keccak256(abi.encode(_deadline)));
    }
    bytes memory _signature = _sign(_beneficiaryPrivateKey, _messageHash);
    if (_randomSeed % 4 == 3) _signature = _modifySignature(_signature, _randomSeed);

    vm.expectRevert(UniStaker.UniStaker__InvalidSignature.selector);
    vm.prank(_sender);
    uniStaker.claimRewardOnBehalf(_beneficiary, _deadline, _signature);
  }
}

contract _FetchOrDeploySurrogate is UniStakerRewardsTest {
  function testFuzz_EmitsAnEventWhenASurrogateIsDeployed(address _delegatee) public {
    vm.assume(_delegatee != address(0));
    vm.recordLogs();
    uniStaker.exposed_fetchOrDeploySurrogate(_delegatee);

    Vm.Log[] memory logs = vm.getRecordedLogs();
    DelegationSurrogate _surrogate = uniStaker.surrogates(_delegatee);

    assertEq(logs[1].topics[0], keccak256("SurrogateDeployed(address,address)"));
    assertEq(logs[1].topics[1], bytes32(uint256(uint160(_delegatee))));
    assertEq(logs[1].topics[2], bytes32(uint256(uint160(address(_surrogate)))));
  }
}

contract Multicall is UniStakerRewardsTest {
  function _encodeStake(address _delegatee, uint96 _stakeAmount)
    internal
    pure
    returns (bytes memory)
  {
    return
      abi.encodeWithSelector(bytes4(keccak256("stake(uint96,address)")), _stakeAmount, _delegatee);
  }

  function _encodeStake(address _delegatee, uint96 _stakeAmount, address _beneficiary)
    internal
    pure
    returns (bytes memory)
  {
    return abi.encodeWithSelector(
      bytes4(keccak256("stake(uint96,address,address)")), _stakeAmount, _delegatee, _beneficiary
    );
  }

  function _encodeStakeMore(UniStaker.DepositIdentifier _depositId, uint96 _stakeAmount)
    internal
    pure
    returns (bytes memory)
  {
    return abi.encodeWithSelector(
      bytes4(keccak256("stakeMore(uint256,uint96)")), _depositId, _stakeAmount
    );
  }

  function _encodeWithdraw(UniStaker.DepositIdentifier _depositId, uint96 _amount)
    internal
    pure
    returns (bytes memory)
  {
    return
      abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256,uint96)")), _depositId, _amount);
  }

  function _encodeAlterBeneficiary(UniStaker.DepositIdentifier _depositId, address _beneficiary)
    internal
    pure
    returns (bytes memory)
  {
    return abi.encodeWithSelector(
      bytes4(keccak256("alterBeneficiary(uint256,address)")), _depositId, _beneficiary
    );
  }

  function _encodeAlterDelegatee(UniStaker.DepositIdentifier _depositId, address _delegatee)
    internal
    pure
    returns (bytes memory)
  {
    return abi.encodeWithSelector(
      bytes4(keccak256("alterDelegatee(uint256,address)")), _depositId, _delegatee
    );
  }

  function testFuzz_CanUseMulticallToStakeMultipleTimes(
    address _depositor,
    address _delegatee1,
    address _delegatee2,
    uint96 _stakeAmount1,
    uint96 _stakeAmount2
  ) public {
    _stakeAmount1 = _boundToRealisticStake(_stakeAmount1);
    _stakeAmount2 = _boundToRealisticStake(_stakeAmount2);
    vm.assume(_delegatee1 != address(0) && _delegatee2 != address(0));
    _mintGovToken(_depositor, _stakeAmount1 + _stakeAmount2);

    vm.prank(_depositor);
    govToken.approve(address(uniStaker), _stakeAmount1 + _stakeAmount2);

    bytes[] memory _calls = new bytes[](2);
    _calls[0] = _encodeStake(_delegatee1, _stakeAmount1);
    _calls[1] = _encodeStake(_delegatee2, _stakeAmount2);
    vm.prank(_depositor);
    uniStaker.multicall(_calls);
    assertEq(uniStaker.depositorTotalStaked(_depositor), _stakeAmount1 + _stakeAmount2);
  }

  function testFuzz_CanUseMulticallToStakeAndAlterBeneficiaryAndDelegatee(
    address _depositor,
    address _delegatee0,
    address _delegatee1,
    address _beneficiary0,
    address _beneficiary1,
    uint96 _stakeAmount0,
    uint96 _stakeAmount1,
    uint256 _timeElapsed
  ) public {
    _stakeAmount0 = _boundToRealisticStake(_stakeAmount0);
    _stakeAmount1 = _boundToRealisticStake(_stakeAmount1);

    vm.assume(
      _depositor != address(0) && _delegatee0 != address(0) && _delegatee1 != address(0)
        && _beneficiary0 != address(0) && _beneficiary1 != address(0)
    );
    _mintGovToken(_depositor, _stakeAmount0 + _stakeAmount1);

    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _stakeAmount0 + _stakeAmount1);

    // first, do initial stake without multicall
    UniStaker.DepositIdentifier _depositId =
      uniStaker.stake(_stakeAmount0, _delegatee0, _beneficiary0);

    // some time goes by...
    vm.warp(_timeElapsed);

    // now I want to stake more, and also change my delegatee and beneficiary
    bytes[] memory _calls = new bytes[](3);
    _calls[0] = _encodeStakeMore(_depositId, _stakeAmount1);
    _calls[1] = _encodeAlterBeneficiary(_depositId, _beneficiary1);
    _calls[2] = _encodeAlterDelegatee(_depositId, _delegatee1);
    uniStaker.multicall(_calls);
    vm.stopPrank();

    (uint96 _amountResult,, address _delegateeResult, address _beneficiaryResult) =
      uniStaker.deposits(_depositId);
    assertEq(uniStaker.depositorTotalStaked(_depositor), _stakeAmount0 + _stakeAmount1);
    assertEq(_amountResult, _stakeAmount0 + _stakeAmount1);
    assertEq(_delegateeResult, _delegatee1);
    assertEq(_beneficiaryResult, _beneficiary1);
  }
}

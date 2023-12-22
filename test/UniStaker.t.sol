// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {UniStaker, DelegationSurrogate, IERC20, IERC20Delegates} from "src/UniStaker.sol";
import {ERC20VotesMock} from "test/mocks/MockERC20Votes.sol";
import {ERC20Fake} from "test/fakes/ERC20Fake.sol";

contract UniStakerTest is Test {
  ERC20Fake rewardToken;
  ERC20VotesMock govToken;
  UniStaker uniStaker;

  function setUp() public {
    // set the block timestamp to a random value to avoid introducing assumptions into tests based
    // on a starting timestamp of 0, which is the default
    _jumpAhead(1234);

    rewardToken = new ERC20Fake();
    vm.label(address(rewardToken), "Reward Token");

    govToken = new ERC20VotesMock();
    vm.label(address(govToken), "Governance Token");

    uniStaker = new UniStaker(rewardToken, govToken);
    vm.label(address(uniStaker), "UniStaker");
  }

  function _jumpAhead(uint256 _seconds) public {
    vm.warp(block.timestamp + _seconds);
  }

  function _boundMintAmount(uint256 _amount) internal view returns (uint256) {
    return bound(_amount, 0, 100_000_000_000e18);
  }

  function _mintGovToken(address _to, uint256 _amount) internal {
    vm.assume(_to != address(0));
    govToken.mint(_to, _amount);
  }

  function _stake(address _depositor, uint256 _amount, address _delegatee)
    internal
    returns (UniStaker.DepositIdentifier _depositId)
  {
    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _amount);
    _depositId = uniStaker.stake(_amount, _delegatee);
    vm.stopPrank();
  }

  function _stake(address _depositor, uint256 _amount, address _delegatee, address _beneficiary)
    internal
    returns (UniStaker.DepositIdentifier _depositId)
  {
    vm.startPrank(_depositor);
    govToken.approve(address(uniStaker), _amount);
    _depositId = uniStaker.stake(_amount, _delegatee, _beneficiary);
    vm.stopPrank();
  }

  function _fetchDeposit(UniStaker.DepositIdentifier _depositId)
    internal
    view
    returns (UniStaker.Deposit memory)
  {
    (uint256 _balance, address _owner, address _delegatee, address _beneficiary) =
      uniStaker.deposits(_depositId);
    return UniStaker.Deposit({
      balance: _balance,
      owner: _owner,
      delegatee: _delegatee,
      beneficiary: _beneficiary
    });
  }

  function _boundMintAndStake(address _depositor, uint256 _amount, address _delegatee)
    internal
    returns (uint256 _boundedAmount, UniStaker.DepositIdentifier _depositId)
  {
    _boundedAmount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _boundedAmount);
    _depositId = _stake(_depositor, _boundedAmount, _delegatee);
  }

  function _boundMintAndStake(
    address _depositor,
    uint256 _amount,
    address _delegatee,
    address _beneficiary
  ) internal returns (uint256 _boundedAmount, UniStaker.DepositIdentifier _depositId) {
    _boundedAmount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _boundedAmount);
    _depositId = _stake(_depositor, _boundedAmount, _delegatee, _beneficiary);
  }
}

contract Constructor is UniStakerTest {
  function test_SetsTheRewardTokenAndStakeToken() public {
    assertEq(address(uniStaker.REWARDS_TOKEN()), address(rewardToken));
    assertEq(address(uniStaker.STAKE_TOKEN()), address(govToken));
  }

  function testFuzz_SetsTheRewardTokenAndStakeTokenToArbitraryAddresses(
    address _rewardToken,
    address _stakeToken
  ) public {
    UniStaker _uniStaker = new UniStaker(IERC20(_rewardToken), IERC20Delegates(_stakeToken));
    assertEq(address(_uniStaker.REWARDS_TOKEN()), address(_rewardToken));
    assertEq(address(_uniStaker.STAKE_TOKEN()), address(_stakeToken));
  }
}

contract Stake is UniStakerTest {
  function testFuzz_DeploysAndTransfersTokensToANewSurrogateWhenAnAccountStakes(
    address _depositor,
    uint256 _amount,
    address _delegatee
  ) public {
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);
    _stake(_depositor, _amount, _delegatee);

    DelegationSurrogate _surrogate = uniStaker.surrogates(_delegatee);

    assertEq(govToken.balanceOf(address(_surrogate)), _amount);
    assertEq(govToken.delegates(address(_surrogate)), _delegatee);
    assertEq(govToken.balanceOf(_depositor), 0);
  }

  function testFuzz_TransfersToAnExistingSurrogateWhenStakedToTheSameDelegatee(
    address _depositor1,
    uint256 _amount1,
    address _depositor2,
    uint256 _amount2,
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

    // Ensure surrogate for this delegatee hasn't changed and has 2x the balance
    assertEq(address(uniStaker.surrogates(_delegatee)), address(_surrogate));
    assertEq(govToken.delegates(address(_surrogate)), _delegatee);
    assertEq(govToken.balanceOf(address(_surrogate)), _amount1 + _amount2);
    assertEq(govToken.balanceOf(_depositor1), 0);
    assertEq(govToken.balanceOf(_depositor2), 0);
  }

  function testFuzz_DeploysAndTransfersTokenToTwoSurrogatesWhenAccountsStakesToDifferentDelegatees(
    address _depositor1,
    uint256 _amount1,
    address _depositor2,
    uint256 _amount2,
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

  function testFuzz_UpdatesTheTotalSupplyWhenAnAccountStakes(
    address _depositor,
    uint256 _amount,
    address _delegatee
  ) public {
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);

    _stake(_depositor, _amount, _delegatee);

    assertEq(uniStaker.totalSupply(), _amount);
  }

  function testFuzz_UpdatesTheTotalSupplyWhenTwoAccountsStake(
    address _depositor1,
    uint256 _amount1,
    address _depositor2,
    uint256 _amount2,
    address _delegatee1,
    address _delegatee2
  ) public {
    _amount1 = _boundMintAmount(_amount1);
    _amount2 = _boundMintAmount(_amount2);
    _mintGovToken(_depositor1, _amount1);
    _mintGovToken(_depositor2, _amount2);

    _stake(_depositor1, _amount1, _delegatee1);
    assertEq(uniStaker.totalSupply(), _amount1);

    _stake(_depositor2, _amount2, _delegatee2);
    assertEq(uniStaker.totalSupply(), _amount1 + _amount2);
  }

  function testFuzz_UpdatesAnAccountsTotalDepositsWhenItStakes(
    address _depositor,
    uint256 _amount1,
    uint256 _amount2,
    address _delegatee1,
    address _delegatee2
  ) public {
    _amount1 = _boundMintAmount(_amount1);
    _amount2 = _boundMintAmount(_amount2);
    _mintGovToken(_depositor, _amount1 + _amount2);

    // First stake + check total
    _stake(_depositor, _amount1, _delegatee1);
    assertEq(uniStaker.totalDeposits(_depositor), _amount1);

    // Second stake + check total
    _stake(_depositor, _amount2, _delegatee2);
    assertEq(uniStaker.totalDeposits(_depositor), _amount1 + _amount2);
  }

  function testFuzz_UpdatesDifferentAccountsTotalDepositsIndependently(
    address _depositor1,
    uint256 _amount1,
    address _depositor2,
    uint256 _amount2,
    address _delegatee1,
    address _delegatee2
  ) public {
    vm.assume(_depositor1 != _depositor2);
    _amount1 = _boundMintAmount(_amount1);
    _amount2 = _boundMintAmount(_amount2);
    _mintGovToken(_depositor1, _amount1);
    _mintGovToken(_depositor2, _amount2);

    _stake(_depositor1, _amount1, _delegatee1);
    assertEq(uniStaker.totalDeposits(_depositor1), _amount1);

    _stake(_depositor2, _amount2, _delegatee2);
    assertEq(uniStaker.totalDeposits(_depositor2), _amount2);
  }

  function testFuzz_TracksTheBalanceForASpecificDeposit(
    address _depositor,
    uint256 _amount,
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
    uint256 _amount1,
    uint256 _amount2,
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
    uint256 _amount1,
    uint256 _amount2,
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
    uint256 _amount,
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
    uint256 _amount,
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
    uint256 _amount1,
    uint256 _amount2,
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
    uint256 _amount1,
    uint256 _amount2,
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
    uint256 _amount = 116;
    address _delegatee = address(0xaceface);

    UniStaker.DepositIdentifier _depositId;

    for (uint256 _i; _i < 10_000; _i++) {
      // Perform the stake and save the deposit identifier
      _amount = _bound(_amount, 0, 100_000_000_000e18);
      _mintGovToken(_depositor, _amount);
      _depositId = _stake(_depositor, _amount, _delegatee);

      // Ensure the identifier hasn't yet been used
      assertFalse(isIdUsed[_depositId]);
      // Record the fact this deposit Id has been used
      isIdUsed[_depositId] = true;

      // Reset all the inputs for the next deposit by hashing the last inputs
      _depositor = address(uint160(uint256(keccak256(abi.encode(_depositor)))));
      _amount = uint256(keccak256(abi.encode(_amount)));
      _delegatee = address(uint160(uint256(keccak256(abi.encode(_delegatee)))));
    }
  }
}

contract Withdraw is UniStakerTest {
  function testFuzz_AllowsDepositorToWithdrawFullStake(
    address _depositor,
    uint256 _amount,
    address _delegatee
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee);

    vm.prank(_depositor);
    uniStaker.withdraw(_depositId, _amount);

    UniStaker.Deposit memory _deposit = _fetchDeposit(_depositId);

    assertEq(govToken.balanceOf(_depositor), _amount);
    assertEq(_deposit.balance, 0);
  }

  function testFuzz_AllowsDepositorToWithdrawPartialStake(
    address _depositor,
    uint256 _depositAmount,
    address _delegatee,
    uint256 _withdrawalAmount
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) = _boundMintAndStake(_depositor, _depositAmount, _delegatee);
    _withdrawalAmount = bound(_withdrawalAmount, 0, _depositAmount);

    vm.prank(_depositor);
    uniStaker.withdraw(_depositId, _withdrawalAmount);

    UniStaker.Deposit memory _deposit = _fetchDeposit(_depositId);

    assertEq(govToken.balanceOf(_depositor), _withdrawalAmount);
    assertEq(_deposit.balance, _depositAmount - _withdrawalAmount);
  }

  function testFuzz_UpdatesTheTotalSupplyWhenAnAccountWithdraws(
    address _depositor,
    uint256 _depositAmount,
    address _delegatee,
    uint256 _withdrawalAmount
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) = _boundMintAndStake(_depositor, _depositAmount, _delegatee);
    _withdrawalAmount = bound(_withdrawalAmount, 0, _depositAmount);

    vm.prank(_depositor);
    uniStaker.withdraw(_depositId, _withdrawalAmount);

    assertEq(uniStaker.totalSupply(), _depositAmount - _withdrawalAmount);
  }

  function testFuzz_UpdatesTheTotalSupplyWhenTwoAccountsWithdraw(
    address _depositor1,
    uint256 _depositAmount1,
    address _delegatee1,
    address _depositor2,
    uint256 _depositAmount2,
    address _delegatee2,
    uint256 _withdrawalAmount1,
    uint256 _withdrawalAmount2
  ) public {
    // Make two separate deposits
    UniStaker.DepositIdentifier _depositId1;
    (_depositAmount1, _depositId1) = _boundMintAndStake(_depositor1, _depositAmount1, _delegatee1);
    UniStaker.DepositIdentifier _depositId2;
    (_depositAmount2, _depositId2) = _boundMintAndStake(_depositor2, _depositAmount2, _delegatee2);

    // Calculate withdrawal amounts
    _withdrawalAmount1 = bound(_withdrawalAmount1, 0, _depositAmount1);
    _withdrawalAmount2 = bound(_withdrawalAmount2, 0, _depositAmount2);

    // Execute both withdrawals
    vm.prank(_depositor1);
    uniStaker.withdraw(_depositId1, _withdrawalAmount1);
    vm.prank(_depositor2);
    uniStaker.withdraw(_depositId2, _withdrawalAmount2);

    uint256 _remainingDeposits =
      _depositAmount1 + _depositAmount2 - _withdrawalAmount1 - _withdrawalAmount2;
    assertEq(uniStaker.totalSupply(), _remainingDeposits);
  }

  function testFuzz_UpdatesAnAccountsTotalDepositsWhenItWithdrawals(
    address _depositor,
    uint256 _depositAmount1,
    uint256 _depositAmount2,
    address _delegatee1,
    address _delegatee2,
    uint256 _withdrawalAmount
  ) public {
    // Make two separate deposits
    UniStaker.DepositIdentifier _depositId1;
    (_depositAmount1, _depositId1) = _boundMintAndStake(_depositor, _depositAmount1, _delegatee1);
    UniStaker.DepositIdentifier _depositId2;
    (_depositAmount2, _depositId2) = _boundMintAndStake(_depositor, _depositAmount2, _delegatee2);

    // Withdraw part of the first deposit
    _withdrawalAmount = bound(_withdrawalAmount, 0, _depositAmount1);
    vm.prank(_depositor);
    uniStaker.withdraw(_depositId1, _withdrawalAmount);

    // Ensure the account's total balance + global balance accounting have been updated
    assertEq(
      uniStaker.totalDeposits(_depositor), _depositAmount1 + _depositAmount2 - _withdrawalAmount
    );
    assertEq(uniStaker.totalSupply(), _depositAmount1 + _depositAmount2 - _withdrawalAmount);
  }

  function testFuzz_RemovesFullEarningPowerFromADepositorWhoHadSelfAssignedIt(
    address _depositor,
    uint256 _amount,
    address _delegatee
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee);

    vm.prank(_depositor);
    uniStaker.withdraw(_depositId, _amount);

    assertEq(uniStaker.earningPower(_depositor), 0);
  }

  function testFuzz_RemovesPartialEarningPowerFromADepositorWhoHadSelfAssignedIt(
    address _depositor,
    uint256 _depositAmount,
    address _delegatee,
    uint256 _withdrawalAmount
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) = _boundMintAndStake(_depositor, _depositAmount, _delegatee);
    _withdrawalAmount = bound(_withdrawalAmount, 0, _depositAmount);

    vm.prank(_depositor);
    uniStaker.withdraw(_depositId, _withdrawalAmount);

    assertEq(uniStaker.earningPower(_depositor), _depositAmount - _withdrawalAmount);
  }

  function testFuzz_RemovesFullEarningPowerFromABeneficiary(
    address _depositor,
    uint256 _amount,
    address _delegatee,
    address _beneficiary
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _beneficiary);

    vm.prank(_depositor);
    uniStaker.withdraw(_depositId, _amount);

    assertEq(uniStaker.earningPower(_beneficiary), 0);
  }

  function testFuzz_RemovesPartialEarningPowerFromABeneficiary(
    address _depositor,
    uint256 _depositAmount,
    address _delegatee,
    address _beneficiary,
    uint256 _withdrawalAmount
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _beneficiary);
    _withdrawalAmount = bound(_withdrawalAmount, 0, _depositAmount);

    vm.prank(_depositor);
    uniStaker.withdraw(_depositId, _withdrawalAmount);

    assertEq(uniStaker.earningPower(_beneficiary), _depositAmount - _withdrawalAmount);
  }

  function testFuzz_RemovesPartialEarningPowerFromABeneficiaryAssignedByTwoDepositors(
    address _depositor1,
    address _depositor2,
    uint256 _depositAmount1,
    uint256 _depositAmount2,
    address _delegatee,
    address _beneficiary,
    uint256 _withdrawalAmount1,
    uint256 _withdrawalAmount2
  ) public {
    UniStaker.DepositIdentifier _depositId1;
    (_depositAmount1, _depositId1) =
      _boundMintAndStake(_depositor1, _depositAmount1, _delegatee, _beneficiary);
    _withdrawalAmount1 = bound(_withdrawalAmount1, 0, _depositAmount1);

    UniStaker.DepositIdentifier _depositId2;
    (_depositAmount2, _depositId2) =
      _boundMintAndStake(_depositor2, _depositAmount2, _delegatee, _beneficiary);
    _withdrawalAmount2 = bound(_withdrawalAmount2, 0, _depositAmount2);

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

  function testFuzz_RemovesPartialEarningPowerFromDifferentBeneficiariesOfTheSameDepositor(
    address _depositor,
    uint256 _depositAmount1,
    uint256 _depositAmount2,
    address _delegatee,
    address _beneficiary1,
    address _beneficiary2,
    uint256 _withdrawalAmount1,
    uint256 _withdrawalAmount2
  ) public {
    vm.assume(_beneficiary1 != _beneficiary2);

    UniStaker.DepositIdentifier _depositId1;
    (_depositAmount1, _depositId1) =
      _boundMintAndStake(_depositor, _depositAmount1, _delegatee, _beneficiary1);
    _withdrawalAmount1 = bound(_withdrawalAmount1, 0, _depositAmount1);

    UniStaker.DepositIdentifier _depositId2;
    (_depositAmount2, _depositId2) =
      _boundMintAndStake(_depositor, _depositAmount2, _delegatee, _beneficiary2);
    _withdrawalAmount2 = bound(_withdrawalAmount2, 0, _depositAmount2);

    vm.prank(_depositor);
    uniStaker.withdraw(_depositId1, _withdrawalAmount1);

    assertEq(uniStaker.earningPower(_beneficiary1), _depositAmount1 - _withdrawalAmount1);
    assertEq(uniStaker.earningPower(_beneficiary2), _depositAmount2);

    vm.prank(_depositor);
    uniStaker.withdraw(_depositId2, _withdrawalAmount2);

    assertEq(uniStaker.earningPower(_beneficiary1), _depositAmount1 - _withdrawalAmount1);
    assertEq(uniStaker.earningPower(_beneficiary2), _depositAmount2 - _withdrawalAmount2);
  }

  function testFuzz_RemovesPartialEarningPowerFromDifferentBeneficiariesAndDifferentDepositors(
    address _depositor1,
    address _depositor2,
    uint256 _depositAmount1,
    uint256 _depositAmount2,
    address _delegatee,
    address _beneficiary1,
    address _beneficiary2,
    uint256 _withdrawalAmount1,
    uint256 _withdrawalAmount2
  ) public {
    vm.assume(_beneficiary1 != _beneficiary2);

    UniStaker.DepositIdentifier _depositId1;
    (_depositAmount1, _depositId1) =
      _boundMintAndStake(_depositor1, _depositAmount1, _delegatee, _beneficiary1);
    _withdrawalAmount1 = bound(_withdrawalAmount1, 0, _depositAmount1);

    UniStaker.DepositIdentifier _depositId2;
    (_depositAmount2, _depositId2) =
      _boundMintAndStake(_depositor2, _depositAmount2, _delegatee, _beneficiary2);
    _withdrawalAmount2 = bound(_withdrawalAmount2, 0, _depositAmount2);

    vm.prank(_depositor1);
    uniStaker.withdraw(_depositId1, _withdrawalAmount1);

    assertEq(uniStaker.earningPower(_beneficiary1), _depositAmount1 - _withdrawalAmount1);
    assertEq(uniStaker.earningPower(_beneficiary2), _depositAmount2);

    vm.prank(_depositor2);
    uniStaker.withdraw(_depositId2, _withdrawalAmount2);

    assertEq(uniStaker.earningPower(_beneficiary1), _depositAmount1 - _withdrawalAmount1);
    assertEq(uniStaker.earningPower(_beneficiary2), _depositAmount2 - _withdrawalAmount2);
  }

  function testFuzz_RevertIf_TheWithdrawerIsNotTheDepositor(
    address _depositor,
    uint256 _amount,
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
    uint256 _amount,
    address _delegatee
  ) public {
    UniStaker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee);

    vm.prank(_depositor);
    vm.expectRevert();
    uniStaker.withdraw(_depositId, _amount + 1);
  }
}

contract UniStakerRewardsTest is UniStakerTest {

  // Because there will be (expected) rounding errors in the amount of rewards earned, this helper
  // checks that the two integers are provided are within 1% of the lesser of the two numbers.
  function assertLteWithinOnePercent(uint256 a, uint256 b) public {
    if (a > b) {
      emit log("Error: a <= b not satisfied");
      emit log_named_uint("  Expected", b);
      emit log_named_uint("    Actual", a);

      fail();
    }

    uint256 minBound = (b * 9900) / 10_000;

    if (b < minBound) {
      emit log("Error: a >= 0.99 * b not satisfied");
      emit log_named_uint("  Expected", b);
      emit log_named_uint("    Actual", a);
      emit log_named_uint("  minBound", minBound);

      fail();
    }
  }

  function percentOf(uint256 _amount, uint256 _percent) public pure returns (uint256 _percentOf) {
    _percentOf = (_percent * _amount) / 100;
  }

  // Helper methods for dumping contract state related to rewards calculation for debugging
  function __dumpDebugGlobalRewards() public view {
    console2.log("rewardDuration");
    console2.log(uniStaker.rewardDuration());
    console2.log("finishAt");
    console2.log(uniStaker.finishAt());
    console2.log("updatedAt");
    console2.log(uniStaker.updatedAt());
    console2.log("totalSupply");
    console2.log(uniStaker.totalSupply());
    console2.log("rewardRate");
    console2.log(uniStaker.rewardRate());
    console2.log("block.timestamp");
    console2.log(block.timestamp);
    console2.log("rewardPerTokenStored");
    console2.log(uniStaker.rewardPerTokenStored());
    console2.log("lastTimeRewardApplicable()");
    console2.log(uniStaker.lastTimeRewardApplicable());
    console2.log("rewardPerToken()");
    console2.log(uniStaker.rewardPerToken());
    console2.log("-----------------------------------------------");
  }

  function __dumpDebugDepositorRewards(address _depositor) public view {
    console2.log("earningPower[_depositor]");
    console2.log(uniStaker.earningPower(_depositor));
    console2.log("userRewardPerTokenPaid[_depositor]");
    console2.log(uniStaker.userRewardPerTokenPaid(_depositor));
    console2.log("rewards[_depositor]");
    console2.log(uniStaker.rewards(_depositor));
    console2.log("earned(_depositor)");
    console2.log(uniStaker.earned(_depositor));
    console2.log("-----------------------------------------------");
  }

  function _jumpAheadByPercentOfRewardDuration(uint256 _percent) public {
    uint256 _seconds = (_percent * uniStaker.rewardDuration()) / 100;
    _jumpAhead(_seconds);
  }

  function _boundToRealisticStakeAndReward(
    uint256 _stakeAmount,
    uint256 _rewardAmount)
    public
    view
    returns (uint256 _boundedStakeAmount, uint256 _boundedRewardAmount) {
      _boundedStakeAmount = bound(_stakeAmount, 1e18, 1_000_000e18);
      _boundedRewardAmount = bound(_rewardAmount, 200e6, 10_000_000e6);
  }

  function _mintTransferAndNotifyReward(uint256 _amount) public {
    address _notifier = address(0xace);
    rewardToken.mint(_notifier, _amount);

    vm.startPrank(_notifier);
    rewardToken.transfer(address(uniStaker), _amount);
    uniStaker.notifyRewardsAmount(_amount);
    vm.stopPrank();
  }
}

contract Earned is UniStakerRewardsTest {

  function testFuzz_CalculatesCorrectEarningsForASingleDepositorThatStakesForFullDuration(
    address _depositor,
    address _delegatee,
    uint256 _stakeAmount,
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
    assertLteWithinOnePercent(uniStaker.earned(_depositor), _rewardAmount);
  }

  function testFuzz_CalculatesCorrectEarningsForASingleUserThatDepositsStakeForPartialDuration(
    address _depositor,
    address _delegatee,
    uint256 _stakeAmount,
    uint256 _rewardAmount
  ) public {
    (_stakeAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_stakeAmount, _rewardAmount);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor, _stakeAmount, _delegatee);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // One third of the duration passes
    _jumpAheadByPercentOfRewardDuration(33);

    // The user should have earned one third of the rewards
    assertLteWithinOnePercent(uniStaker.earned(_depositor), percentOf(_rewardAmount, 33));
  }

  function testFuzz_CalculatesCorrectEarningsForTwoUsersThatDepositEqualStakeForFullDuration(
    address _depositor1,
    address _depositor2,
    address _delegatee,
    uint256 _stakeAmount,
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
    assertLteWithinOnePercent(uniStaker.earned(_depositor1), percentOf(_rewardAmount, 50));
    assertLteWithinOnePercent(uniStaker.earned(_depositor2), percentOf(_rewardAmount, 50));
  }

  function testFuzz_CalculatesCorrectEarningsForASingleUserThatDepositsPartiallyThroughTheDuration(
    address _depositor,
    address _delegatee,
    uint256 _stakeAmount,
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
    assertLteWithinOnePercent(uniStaker.earned(_depositor), percentOf(_rewardAmount, 34));
  }

  function testFuzz_CalculatesCorrectEarningsWhenAUserStakesThroughTheDurationAndAnotherStakesPartially(
    address _depositor1,
    address _depositor2,
    address _delegatee,
    uint256 _stakeAmount,
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

    // Depositor 1 earns the full rewards for 2/3rds of the time & 1/2 the reward for 1/3rd of the time
    uint256 _depositor1ExpectedEarnings = percentOf(_rewardAmount, 66) + percentOf(percentOf(_rewardAmount, 50), 34);
    // Depositor 2 earns 1/2 the rewards for 1/3rd of the duration time
    uint256 _depositor2ExpectedEarnings = percentOf(percentOf(_rewardAmount, 50), 34);

    assertLteWithinOnePercent(uniStaker.earned(_depositor1), _depositor1ExpectedEarnings);
    assertLteWithinOnePercent(uniStaker.earned(_depositor2), _depositor2ExpectedEarnings);
  }

  function testFuzz_CalculatesCorrectEarningsWhenAUserDepositsAndThereAreMultipleRewards(
    address _depositor,
    address _delegatee,
    uint256 _stakeAmount,
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
    uint256 _depositorExpectedEarnings = percentOf(_rewardAmount1, 66) + percentOf(percentOf(_rewardAmount1, 34) + _rewardAmount2, 34);
    assertLteWithinOnePercent(uniStaker.earned(_depositor), _depositorExpectedEarnings);
  }
}

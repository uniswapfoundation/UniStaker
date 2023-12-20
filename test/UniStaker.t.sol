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
    rewardToken = new ERC20Fake();
    vm.label(address(rewardToken), "Reward Token");

    govToken = new ERC20VotesMock();
    vm.label(address(govToken), "Governance Token");

    uniStaker = new UniStaker(rewardToken, govToken);
    vm.label(address(uniStaker), "UniStaker");
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

contract StakingScenarios is UniStakerTest {

  function _dump(address _depositor) public view {
    console2.log("rewardDuration");
    console2.log(uniStaker.rewardDuration());
    console2.log("finishAt");
    console2.log(uniStaker.finishAt());
    console2.log("updatedAt");
    console2.log(uniStaker.updatedAt());
    console2.log("rewardRate");
    console2.log(uniStaker.rewardRate());
    console2.log("block.timestamp");
    console2.log(block.timestamp);
    console2.log("rewardPerTokenStored");
    console2.log(uniStaker.rewardPerTokenStored());
    console2.log("userRewardPerTokenPaid[_depositor]");
    console2.log(uniStaker.userRewardPerTokenPaid(_depositor));
    console2.log("rewards[_depositor]");
    console2.log(uniStaker.rewards(_depositor));
    console2.log("earned(_depositor)");
    console2.log(uniStaker.earned(_depositor));
    console2.log("lastTimeRewardApplicable()");
    console2.log(uniStaker.lastTimeRewardApplicable());
    console2.log("rewardPerToken()");
    console2.log(uniStaker.rewardPerToken());
    console2.log("-----------------------------------------------");
  }

  function assertWithinOnePercent(uint256 _x, uint256 _y) public {
    uint256 _difference;
    uint256 _greater;

    if (_x >= _y) {
      _difference = _x - _y;
      _greater = _x;
    } else {
      _difference = _y - _x;
      _greater = _y;
    }

    uint256 _percentDiff = (_difference * 100) / _greater;
    assertTrue(_percentDiff <= 1);
  }

  function test_ASingleUserDepositsAllStakeForTheEntireDuration() public {
    address _depositor = address(0xde80517);
    uint256 _stakeAmount = 1000e18;
    uint256 _rewardAmount = 500e6;

    vm.warp(block.timestamp + 1234);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor, _stakeAmount, address(0x1));
    // The contract is notified of a reward
    uniStaker.notifyRewardsAmount(_rewardAmount);

    // Jump in time past the reward duration
    vm.warp(block.timestamp + uniStaker.rewardDuration() + 1);

    _dump(_depositor);

    assertWithinOnePercent(uniStaker.earned(_depositor), _rewardAmount);
  }

  function test_ASingleUserDepositsAllStakeForPartialDuration() public {
    address _depositor = address(0xde80517);
    uint256 _stakeAmount = 1000e18;
    uint256 _rewardAmount = 500e6;

    vm.warp(block.timestamp + 1234);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor, _stakeAmount, address(0x1));
    // The contract is notified of a reward
    uniStaker.notifyRewardsAmount(_rewardAmount);

    // Jump one third through the reward duration
    vm.warp(block.timestamp + uniStaker.rewardDuration() / 3 + 1);

    _dump(_depositor);

    assertWithinOnePercent(uniStaker.earned(_depositor), _rewardAmount / 3);
  }

  function test_TwoUsersDepositDepositEqualStakeForTheEntireDuration() public {
    address _depositor1 = address(0xace);
    address _depositor2 = address(0xcafe);
    uint256 _stakeAmount = 1000e18;
    uint256 _rewardAmount = 500e6;

    vm.warp(block.timestamp + 1234);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor1, _stakeAmount, address(0x1));
    // Some time passes
    vm.warp(block.timestamp + 3000);
    // Another depositor deposits the same number of staking tokens
    _boundMintAndStake(_depositor2, _stakeAmount, address(0x1));
    // The contract is notified of a reward
    uniStaker.notifyRewardsAmount(_rewardAmount);

    // Jump in time past the reward duration
    vm.warp(block.timestamp + uniStaker.rewardDuration() + 1);

    _dump(_depositor1);
    _dump(_depositor2);

    assertWithinOnePercent(uniStaker.earned(_depositor1), _rewardAmount / 2);
    assertWithinOnePercent(uniStaker.earned(_depositor2), _rewardAmount / 2);
  }

  function test_ASingleUserDepositsPartiallyThroughTheDuration() public {
    address _depositor = address(0xde80517);
    uint256 _stakeAmount = 1000e18;
    uint256 _rewardAmount = 500e6;
    vm.warp(block.timestamp + 1234);

    // The contract is notified of a reward
    uniStaker.notifyRewardsAmount(_rewardAmount);
    // Jump forward 2/3rds through the duration
    vm.warp(block.timestamp + (2 * uniStaker.rewardDuration()) / 3);
    // A user deposits staking tokens
    _boundMintAndStake(_depositor, _stakeAmount, address(0x1));
    // Jump to the end of the duration
    vm.warp(block.timestamp + uniStaker.rewardDuration() / 3);

    assertWithinOnePercent(uniStaker.earned(_depositor), _rewardAmount / 3);
  }

  function test_OneUserStakesThroughTheDurationAndAnotherStakesTowardTheEnd() public {
    address _depositor1 = address(0xace);
    address _depositor2 = address(0xcafe);
    uint256 _stakeAmount = 1000e18;
    uint256 _rewardAmount = 500e6;
    vm.warp(block.timestamp + 1234);

    // The first user stakes some tokens
    _boundMintAndStake(_depositor1, _stakeAmount, address(0x1));
    // Some time passes
    vm.warp(block.timestamp + 3000);
    // The contract is notified of the first reward
    uniStaker.notifyRewardsAmount(_rewardAmount);
    // Jump forward 2/3rds through the duration
    vm.warp(block.timestamp + (2* uniStaker.rewardDuration()) / 3);
    // A second user stakes the same amount of tokens
    _boundMintAndStake(_depositor2, _stakeAmount, address(0x1));
    // Jump to the end of the duration
    vm.warp(block.timestamp + uniStaker.rewardDuration() / 3);

    // Depositor 1 earns the full rewards for 2/3rds of the time & 1/2 the reward for 1/3rd of the time
    uint256 _depositor1ExpectedEarnings = (2 * _rewardAmount) / 3 + _rewardAmount / 6;
    // Depositor 2 earns 1/2 the rewards for 1/3rd of the duration time
    uint256 _depositor2ExpectedEarnings = _rewardAmount / 6;

    assertWithinOnePercent(uniStaker.earned(_depositor1), _depositor1ExpectedEarnings);
    assertWithinOnePercent(uniStaker.earned(_depositor2), _depositor2ExpectedEarnings);
  }

  function test_ASingleUserDepositsAllStakeAcrossMultipleRewards() public {
    address _depositor = address(0xde80517);
    uint256 _stakeAmount = 1000e18;
    uint256 _rewardAmount1 = 500e6;
    uint256 _rewardAmount2 = 1500e6;
    vm.warp(block.timestamp + 1234);

    // A user deposits staking tokens
    _boundMintAndStake(_depositor, _stakeAmount, address(0x1));
    // The contract is notified of a reward
    uniStaker.notifyRewardsAmount(_rewardAmount1);
    // Jump 2/3rds through the current duration
    vm.warp(block.timestamp + (2 * uniStaker.rewardDuration()) / 3);
    // The contract is notified of a new reward, this resets the duration
    uniStaker.notifyRewardsAmount(_rewardAmount2);
    // Jump forward another 1/3rd of the duration
    vm.warp(block.timestamp + uniStaker.rewardDuration() / 3);

    // The depositor should have earned the full rewards for 2/3rds of the duration, then for a
    // period of 1/3rd of the duration, earned the full rewards, which comprised of 1/3rd of the
    // first reward and the full second reward
    uint256 _depositorExpectedEarnings = (2 * _rewardAmount1) / 3 + ((_rewardAmount1 / 3) + _rewardAmount2) / 3;
    assertWithinOnePercent(uniStaker.earned(_depositor), _depositorExpectedEarnings);
  }
}

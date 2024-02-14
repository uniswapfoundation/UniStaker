// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Deploy} from "script/Deploy.s.sol";
import {DeployInput} from "script/DeployInput.sol";

import {V3FactoryOwner} from "src/V3FactoryOwner.sol";
import {UniStaker} from "src/UniStaker.sol";
import {ProposalTest} from "test/helpers/ProposalTest.sol";
import {IUniswapV3FactoryOwnerActions} from "src/interfaces/IUniswapV3FactoryOwnerActions.sol";
import {IUniswapPool} from "test/helpers/interfaces/IUniswapPool.sol";

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
    assertEq(v3FactoryOwner.PAYOUT_AMOUNT(), PAYOUT_AMOUNT);
    assertEq(address(v3FactoryOwner.REWARD_RECEIVER()), address(uniStaker));

    assertEq(address(uniStaker.REWARD_TOKEN()), PAYOUT_TOKEN_ADDRESS);
    assertEq(address(uniStaker.STAKE_TOKEN()), STAKE_TOKEN_ADDRESS);
    assertEq(uniStaker.admin(), UNISWAP_GOVERNOR_TIMELOCK);
    assertTrue(uniStaker.isRewardNotifier(address(v3FactoryOwner)));
  }
}

contract Propose is ProposalTest {
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

    assertEq(newWbtcWethFeeProtocol, 10 + (10 << 4));
    assertEq(newDaiWethFeeProtocol, 10 + (10 << 4));
    assertEq(newDaiUsdcFeeProtocol, 10 + (10 << 4));
  }
}

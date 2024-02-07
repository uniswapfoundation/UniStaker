// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {Vm, Test, console2} from "forge-std/Test.sol";
import {Deploy} from "script/Deploy.s.sol";
import {DeployInput} from "script/DeployInput.sol";

import {V3FactoryOwner} from "src/V3FactoryOwner.sol";
import {UniStaker} from "src/UniStaker.sol";
import {ProposalTest} from "test/helpers/ProposalTest.sol";
import {IUniswapV3PoolOwnerActions} from "src/interfaces/IUniswapV3PoolOwnerActions.sol";
import {IUniswapV3FactoryOwnerActions} from "src/interfaces/IUniswapV3FactoryOwnerActions.sol";
import {IUniswapPool} from "test/helpers/interfaces/IUniswapPool.sol";

contract DeployScriptTest is Test, DeployInput {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl("mainnet"));
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
  function testFuzz_CorrectlyPassAndExecutreProposal() public {
    _passAndQueueUniswapProposal();
    _executeProposal();

    IUniswapV3FactoryOwnerActions factory =
      IUniswapV3FactoryOwnerActions(UNISWAP_V3_FACTORY_ADDRESS);

    IUniswapPool wbtcWethPool = IUniswapPool(WBTC_WETH_3000_POOL);
    (,,,,, uint8 wbtcWethFeeProtocol,) = wbtcWethPool.slot0();

    IUniswapPool daiWethPool = IUniswapPool(DAI_WETH_3000_POOL);
    (,,,,, uint8 daiWethFeeProtocol,) = wbtcWethPool.slot0();

    IUniswapPool daiUsdcPool = IUniswapPool(DAI_USDC_100_POOL);
    (,,,,, uint8 daiUsdcFeeProtocol,) = wbtcWethPool.slot0();

    assertEq(factory.owner(), address(v3FactoryOwner));

    assertEq(wbtcWethFeeProtocol, 10 + (10 << 4));
    assertEq(daiWethFeeProtocol, 10 + (10 << 4));
    assertEq(daiUsdcFeeProtocol, 10 + (10 << 4));
  }
}

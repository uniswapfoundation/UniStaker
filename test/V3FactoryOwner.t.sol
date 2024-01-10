// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {V3FactoryOwner} from "src/V3FactoryOwner.sol";

contract V3FactoryOwnerTest is Test {
  V3FactoryOwner factoryOwner;
  address admin = makeAddr("Admin");

  event AdminUpdated(address indexed oldAmin, address indexed newAdmin);

  function setUp() public {
    factoryOwner = new V3FactoryOwner(admin);
    vm.label(address(factoryOwner), "Factory Owner");
  }
}

contract Constructor is V3FactoryOwnerTest {
  function test_SetsTheAdmin() public {
    assertEq(factoryOwner.admin(), admin);
  }

  function testFuzz_SetTheAdminToAnArbitraryAddress(address _admin) public {
    vm.assume(_admin != address(0));
    V3FactoryOwner _factoryOwner = new V3FactoryOwner(_admin);
    assertEq(_factoryOwner.admin(), _admin);
  }

  function test_RevertIf_TheAdminIsAddressZero() public {
    vm.expectRevert(V3FactoryOwner.V3FactoryOwner__InvalidAddress.selector);
    new V3FactoryOwner(address(0));
  }
}

contract SetAdmin is V3FactoryOwnerTest {
  function testFuzz_UpdatesTheAdminWhenCalledByTheCurrentAdmin(address _newAdmin) public {
    vm.assume(_newAdmin != address(0));

    vm.prank(admin);
    factoryOwner.setAdmin(_newAdmin);

    assertEq(factoryOwner.admin(), _newAdmin);
  }

  function testFuzz_EmitsAnEventWhenUpdatingTheAdmin(address _newAdmin) public {
    vm.assume(_newAdmin != address(0));

    vm.expectEmit(true, true, true, true);
    vm.prank(admin);
    emit AdminUpdated(admin, _newAdmin);
    factoryOwner.setAdmin(_newAdmin);
  }

  function testFuzz_RevertIf_TheCallerIsNotTheCurrentAdmin(address _notAdmin, address _newAdmin)
    public
  {
    vm.assume(_notAdmin != admin);

    vm.expectRevert(V3FactoryOwner.V3FactoryOwner__Unauthorized.selector);
    vm.prank(_notAdmin);
    factoryOwner.setAdmin(_newAdmin);
  }

  function test_RevertIf_TheNewAdminIsAddressZero() public {
    vm.prank(admin);

    vm.expectRevert(V3FactoryOwner.V3FactoryOwner__InvalidAddress.selector);
    factoryOwner.setAdmin(address(0));
  }
}

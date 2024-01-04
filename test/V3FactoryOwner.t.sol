// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {V3FactoryOwner} from "src/V3FactoryOwner.sol";

contract V3FactoryOwnerTest is Test {
    V3FactoryOwner factoryOwner;
    address admin = address(0xb055beef);

    function setUp() public {
        vm.label(admin, "Admin");

        factoryOwner = new V3FactoryOwner(admin);
        vm.label(address(factoryOwner), "Factory Owner");
    }
}

contract Constructor is V3FactoryOwnerTest {
    function test_SetsTheAdmin() public {
        assertEq(factoryOwner.admin(), admin);
    }

    function testFuzz_SetTheAdminToAnArbitraryAddress(address _admin) public {
        V3FactoryOwner _factoryOwner = new V3FactoryOwner(_admin);
        assertEq(_factoryOwner.admin(), _admin);
    }
}

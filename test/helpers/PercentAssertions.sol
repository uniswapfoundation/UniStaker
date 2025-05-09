// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

contract PercentAssertions is Test {
  // Because there will be (expected) rounding errors in the amount of rewards earned, this helper
  // checks that the truncated number is lesser and within 1% of the expected number.
  function assertLteWithinOnePercent(uint256 a, uint256 b) public {
    if (a > b) {
      emit log("Error: a <= b not satisfied");
      emit log_named_uint("  Expected", b);
      emit log_named_uint("    Actual", a);

      fail();
    }

    uint256 minBound = (b * 9900) / 10_000;

    if (a < minBound) {
      emit log("Error: a >= 0.99 * b not satisfied");
      emit log_named_uint("  Expected", b);
      emit log_named_uint("    Actual", a);
      emit log_named_uint("  minBound", minBound);

      fail();
    }
  }

  function _percentOf(uint256 _amount, uint256 _percent) public pure returns (uint256) {
    // For cases where the percentage is less than 100, we calculate the percentage by
    // taking the inverse percentage and subtracting it. This effectively rounds _up_ the
    // value by putting the truncation on the opposite side. For example, 92% of 555 is 510.6.
    // Calculating it in this way would yield (555 - 44) = 511, instead of 510.
    if (_percent < 100) return _amount - ((100 - _percent) * _amount) / 100;
    else return (_percent * _amount) / 100;
  }

  // This helper is for normal rounding errors, i.e. if the number might be truncated down by 1
  function assertLteWithinOneUnit(uint256 a, uint256 b) public {
    if (a > b) {
      emit log("Error: a <= b not satisfied");
      emit log_named_uint("  Expected", b);
      emit log_named_uint("    Actual", a);

      fail();
    }

    uint256 minBound = b - 1;

    if (!((a == b) || (a == minBound))) {
      emit log("Error: a == b || a  == b-1");
      emit log_named_uint("  Expected", b);
      emit log_named_uint("    Actual", a);

      fail();
    }
  }
}

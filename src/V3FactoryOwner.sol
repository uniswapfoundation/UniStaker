// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

contract V3FactoryOwner {
  address public admin;

  event AdminUpdated(address indexed oldAmin, address indexed newAdmin);

  error V3FactoryOwner__Unauthorized();

  constructor(address _admin) {
    admin = _admin;
  }

  function setAdmin(address _newAdmin) external {
    _revertIfNotAdmin();
    emit AdminUpdated(admin, _newAdmin);
    admin = _newAdmin;
  }

  function _revertIfNotAdmin() internal view {
    if (msg.sender != admin) revert V3FactoryOwner__Unauthorized();
  }
}

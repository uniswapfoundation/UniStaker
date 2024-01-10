// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

contract V3FactoryOwner {
  address public admin;

  event AdminUpdated(address indexed oldAmin, address indexed newAdmin);

  error V3FactoryOwner__Unauthorized();
  error V3FactoryOwner__InvalidAddress();

  constructor(address _admin) {
    if (_admin == address(0)) revert V3FactoryOwner__InvalidAddress();
    admin = _admin;
  }

  function setAdmin(address _newAdmin) external {
    _revertIfNotAdmin();
    if (_newAdmin == address(0)) revert V3FactoryOwner__InvalidAddress();
    emit AdminUpdated(admin, _newAdmin);
    admin = _newAdmin;
  }

  function _revertIfNotAdmin() internal view {
    if (msg.sender != admin) revert V3FactoryOwner__Unauthorized();
  }
}

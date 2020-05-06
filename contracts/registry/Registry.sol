pragma solidity ^0.5.0;

import "./RegistryAbstract.sol";


/// @title Registry to whitelist contributors
/// @author Nelson Melina
contract Registry is RegistryAbstract {
    /// @notice Map of contributors, contributors[address]
    mapping(address => ContributorInfo) contributors;

    /// @param _admins (address[]) List of admins for the Registry contract.
    constructor(address[] memory _admins) public RegistryAbstract(_admins) {}

    /// @notice Register a list of contributors and the amount of CSTK token they are allowed to own.
    /// @dev wallets and allowed need to be in the same order
    /// @param wallets (address[]) List of contributors' addresses to be registered
    /// @param allowed (uint256[]) List of allowed amounts for each contributors.
    function registerContributors(
        address[] memory wallets,
        uint256[] memory allowed
    ) public onlyAdmin {
        require(
            wallets.length == allowed.length,
            "wallets and allowed values need to be the same length"
        );
        for (uint256 i = 0; i < wallets.length; ++i) {
            require(wallets[i] != address(0), "address cannot be address(0)");
            ContributorInfo memory newContributor = ContributorInfo(
                wallets[i],
                allowed[i],
                true
            );
            contributors[newContributor.wallet] = newContributor;
            emit ContributorAdded(newContributor.wallet);
        }
    }

    /// @notice Remove contributors from the registry.
    /// @param wallets (address[]) List of contributors to be removed.
    function removeContributors(address[] memory wallets) public onlyAdmin {
        for (uint256 i = 0; i < wallets.length; ++i) {
            require(wallets[i] != address(0), "Cannot be zero address");
            delete contributors[wallets[i]].wallet;
            delete contributors[wallets[i]].allowed;
            delete contributors[wallets[i]].active;
            delete contributors[wallets[i]];
            emit ContributorRemoved(wallets[i]);
        }
    }

    /// @param wallet (address)
    /// @return allowed (uint256) returns the amount of CSTK token that `wallet` is allowed to own.
    function getAllowed(address wallet) public view returns (uint256 allowed) {
        return contributors[wallet].allowed;
    }

    /// @param wallet (address)
    /// @return TRUE if `wallet` is a contributor.
    function isContributor(address wallet) public view returns (bool) {
        return contributors[wallet].active;
    }
}

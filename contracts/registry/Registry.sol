pragma solidity ^0.5.17;

import "./AdminRole.sol";

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/GSN/Context.sol";

/// @title Registry tracks trusted contributors: accounts and their max trust.
// Max trust will determine the maximum amount of tokens the account can obtain.
/// @author Nelson Melina
contract Registry is Context, AdminRole {
    using EnumerableSet for EnumerableSet.AddressSet;

    //
    // STORAGE:
    //

    // EnumerableSet of all trusted accounts:
    EnumerableSet.AddressSet internal accounts;

    // CS token contract
    IERC20 internal cstkToken;

    // Minter contract address
    address public minterContract;

    // Mapping of account => contributor max trust:
    mapping(address => uint256) maxTrusts;

    // Mapping of account => contributor pending balance:
    mapping(address => uint256) pendingBalances;

    //
    // EVENTS:
    //

    /// @dev Emit when a contributor has been added:
    event ContributorAdded(address adr);

    /// @dev Emit when a contributor has been removed:
    event ContributorRemoved(address adr);

    /// @dev Emit when a contributor's pending balance is changed:
    event PendingBalanceChanged(address indexed adr, uint256 pendingBalance);

    /// @dev Emit when a contributor's pending balance is cleared:
    event PendingBalanceCleared(
        address indexed adr,
        uint256 consumedPendingBalance
    );

    /// @dev Emit when minter contract address is set
    event MinterContractSet(address indexed adr);

    //
    // CONSTRUCTOR:
    //

    /// @dev Construct the Registry,
    /// @param _admins (address[]) List of admins for the Registry contract.
    /// @param _cstkTokenAddress (address) CS token deployed contract address
    constructor(address[] memory _admins, address _cstkTokenAddress)
        public
        AdminRole(_admins)
    {
        cstkToken = IERC20(_cstkTokenAddress);
    }

    modifier onlyMinter() {
        require(
            _msgSender() == minterContract,
            "Caller is not Minter Contract"
        );
        _;
    }

    //
    // EXTERNAL FUNCTIONS:
    //

    /// @notice Register a contributor and set a non-zero max trust.
    /// @dev Can only be called by Admin role.
    /// @param _adr (address) The address to register as contributor
    /// @param _maxTrust (uint256) The amount to set as max trust
    function registerContributor(address _adr, uint256 _maxTrust)
        external
        onlyAdmin
    {
        _register(_adr, _maxTrust);
    }

    /// @notice Remove an existing contributor.
    /// @dev Can only be called by Admin role.
    /// @param _adr (address) Address to remove
    function removeContributor(address _adr) external onlyAdmin {
        _remove(_adr);
    }

    /// @notice Register a list of contributors with max trust amounts.
    /// @dev Can only be called by Admin role.
    /// @param _cnt (uint256) Number of contributors to add
    /// @param _adrs (address[]) Addresses to register as contributors
    /// @param _trusts (uint256[]) Max trust values to set to each contributor (in order)
    function registerContributors(
        uint256 _cnt,
        address[] calldata _adrs,
        uint256[] calldata _trusts
    ) external onlyAdmin {
        require(_adrs.length == _cnt, "Invalid number of addresses");
        require(_trusts.length == _cnt, "Invalid number of trust values");

        for (uint256 i = 0; i < _cnt; i++) {
            _register(_adrs[i], _trusts[i]);
        }
    }

    /// @notice Return all registered contributor addresses.
    /// @return contributors (address[]) Adresses of all contributors
    function getContributors()
        external
        view
        returns (address[] memory contributors)
    {
        return EnumerableSet.enumerate(accounts);
    }

    /// @notice Return contributor information about all accounts in the Registry.
    /// @return contrubutors (address[]) Adresses of all contributors
    /// @return trusts (uint256[]) Max trust values for all contributors, in order.
    function getContributorInfo()
        external
        view
        returns (address[] memory contributors, uint256[] memory trusts)
    {
        contributors = EnumerableSet.enumerate(accounts);
        uint256 len = contributors.length;

        trusts = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            trusts[i] = maxTrusts[contributors[i]];
        }
        return (contributors, trusts);
    }

    /// @notice Return the max trust of an address, or 0 if the address is not a contributor.
    /// @param _adr (address) Address to check
    /// @return allowed (uint256) Max trust of the address, or 0 if not a contributor.
    function getMaxTrust(address _adr)
        external
        view
        returns (uint256 maxTrust)
    {
        return maxTrusts[_adr];
    }

    /// @notice Return the pending balance of an address, or 0 if the address is not a contributor.
    /// @param _adr (address) Address to check
    /// @return pendingBalance (uint256) Pending balance of the address, or 0 if not a contributor.
    function getPendingBalance(address _adr)
        external
        view
        returns (uint256 pendingBalance)
    {
        pendingBalance = pendingBalances[_adr];
    }

    // @notice Set minter contract address
    // @param _minterContract (address) Address to set
    function setMinterContract(address _minterContract) external onlyAdmin {
        minterContract = _minterContract;

        emit MinterContractSet(_minterContract);
    }
    // @notice Set pending balance of an address
    // @param _adr (address) Address to set
    // @param _pendingBalance (uint256) Pending balance of the address
    function setPendingBalance(address _adr, uint256 _pendingBalance)
        external
        onlyAdmin
    {
        _setPendingBalance(_adr, _pendingBalance);
    }

    /// @notice Set a list of contributors pending balance
    /// @dev Can only be called by Admin role.
    /// @param _cnt (uint256) Number of contributors to set pending balance
    /// @param _adrs (address[]) Addresses to set pending balance
    /// @param _pendingBalances (uint256[]) Pending balance values to set to each contributor (in order)
    function setPendingBalances(
        uint256 _cnt,
        address[] calldata _adrs,
        uint256[] calldata _pendingBalances
    ) external onlyAdmin {
        require(_adrs.length == _cnt, "Invalid number of addresses");
        require(_pendingBalances.length == _cnt, "Invalid number of trust values");

        for (uint256 i = 0; i < _cnt; i++) {
            _setPendingBalance(_adrs[i], _pendingBalances[i]);
        }
    }

    function clearPendingBalance(address _adr)
        external
        onlyMinter
    {
        require(
            _adr != address(0),
            "Cannot consume pending balance for zero balance"
        );

        uint256 pendingBalance = pendingBalances[_adr];
        delete pendingBalances[_adr];

        emit PendingBalanceCleared(_adr, pendingBalance);
    }

    //
    // INTERNAL FUNCTIONS:
    //

    function _register(address _adr, uint256 _trust) internal {
        require(_adr != address(0), "Cannot register zero address");
        require(_trust != 0, "Cannot set a max trust of 0");

        require(
            EnumerableSet.add(accounts, _adr),
            "Contributor already registered"
        );
        maxTrusts[_adr] = _trust;

        emit ContributorAdded(_adr);
    }

    function _remove(address _adr) internal {
        require(_adr != address(0), "Cannot remove zero address");
        require(maxTrusts[_adr] != 0, "Address is not a contributor");

        EnumerableSet.remove(accounts, _adr);
        delete maxTrusts[_adr];
        delete pendingBalances[_adr];

        emit ContributorRemoved(_adr);
    }

    function _setPendingBalance(address _adr, uint256 _pendingBalance) internal {
        require(
            _adr != address(0),
            "Cannot set pending balance for zero balance"
        );
        require(maxTrusts[_adr] != 0, "Address is not a contributor");
        require(
            cstkToken.balanceOf(_adr) == 0,
            "User has activated his membership"
        );

        pendingBalances[_adr] = _pendingBalance;

        emit PendingBalanceChanged(_adr, _pendingBalance);
    }
}

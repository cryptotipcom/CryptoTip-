// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract CTPToken is Initializable, ERC20Upgradeable, OwnableUpgradeable, ERC20BurnableUpgradeable, UUPSUpgradeable {
    
    address private _stakingContract;
    uint256 private _maxTransferAmount;

    struct VestingInfo {
        uint256 releaseTime;
        uint256 amount;
    }
    mapping(address => VestingInfo) private _vesting;

    event TokensVested(address indexed beneficiary, uint256 amount, uint256 releaseTime);
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event StakingContractUpdated(address indexed stakingContract);
    event MaxTransferAmountUpdated(uint256 maxTransferAmount);
    event TradingEnabled(bool status);

    function initialize(address initialOwner, address stakingContractAddress, uint256 maxTransferAmount) public initializer {
        require(initialOwner != address(0), "Initial owner cannot be zero address");
        require(stakingContractAddress != address(0), "Staking contract cannot be zero address");
        require(maxTransferAmount > 0, "Max transfer amount must be greater than zero");

        __ERC20_init("CryptoTip CPT", "CPT");
        __Ownable_init(initialOwner);
        __ERC20Burnable_init();
        __UUPSUpgradeable_init();

        _stakingContract = stakingContractAddress;
        _maxTransferAmount = maxTransferAmount;
        _mint(initialOwner, 1_000_000_000 * 10**decimals()); // Mint 1 billion tokens
    }

    function enableTrading() external onlyOwner {
        tradingEnabled = true;
        emit TradingEnabled(true);
    }

    function vestTokens(address beneficiary, uint256 amount, uint256 releaseTime) external onlyOwner {
        require(beneficiary != address(0), "Beneficiary cannot be the zero address");
        require(releaseTime > block.timestamp, "Release time must be in the future");
        require(_vesting[beneficiary].amount == 0, "Beneficiary already has vested tokens");
        require(balanceOf(owner()) >= amount, "Insufficient balance");

        _vesting[beneficiary] = VestingInfo({releaseTime: releaseTime, amount: amount});
        _transfer(owner(), address(this), amount); // Lock tokens in the contract
        emit TokensVested(beneficiary, amount, releaseTime);
    }

    function releaseVestedTokens() external {
    // Cache storage variable in memory for gas efficiency
    VestingInfo storage vestingData = _vesting[msg.sender];

    require(block.timestamp >= vestingData.releaseTime, "Tokens are still locked");

    uint256 amount = vestingData.amount;
    require(amount > 0, "No tokens to release");

    // Set amount to zero before emitting the event
    vestingData.amount = 0;

    // Emit event to log the token release
    emit TokensReleased(msg.sender, amount);
}

    function setStakingContract(address stakingContractAddress) external onlyOwner {
        require(stakingContractAddress != address(0), "Staking contract cannot be zero address");
        _stakingContract = stakingContractAddress;
        emit StakingContractUpdated(stakingContractAddress);
    }

    function updateMaxTxAmount(uint256 newAmount) external onlyOwner {
        require(newAmount > 0, "Max transfer amount must be greater than zero");
        _maxTransferAmount = newAmount;
        emit MaxTransferAmountUpdated(newAmount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // 👇 **New Variables Must Be Added at the End**
    bool public tradingEnabled;
    mapping(address => uint256) private _lastTransaction;
}

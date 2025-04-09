//SPDX-License Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";


/**
 * @title RebaseToken
 * @author Storm-contract
 * @notice This is going to be a croos-chain rebase token that incentivises users to deposit into a vault and gain intersest and rewards.
 * @notice The interset rate in the contract can only decrease.
 * @notice Each user will have their own interest rate that is the global interest rate at the time of depositing.
 */
contract RebaseToken is ERC20, Ownable, AccessControl{
    error RebaseToken__InterestRateOnlyDecrease(uint256, uint256);

    uint256 public constant PRECISION_FACTOR = 1e18;
    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8; // 5% interest rate
    mapping (address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimeStamp;
    bytes32 private constant MINR_AND_BURN_ROLE = keccak256("MINR_AND_BURN_ROLE");
    
    event InterestRateSet(uint256 _newInterestRate);

    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {
        
    }

    function grantMintAndBurnRole(address _user) external onlyOwner {
        // Grant the MINR_AND_BURN_ROLE to the specified user
        // This function can only be called by the owner of the contract
        _grantRole(MINR_AND_BURN_ROLE, _user);
    }

    function setIntersetRate(uint256 _newInterestRate) external onlyOwner {
        // Set the interest rate for the contract
        // This function can only be called by the owner of the contract
        // The interest rate can only be decreased
        if (_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate =_newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    function principalBalanceOf(address _user) external view returns (uint256) {
        // Get the principal balance of the user
        return super.balanceOf(_user);
    }

    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external onlyRole(MINR_AND_BURN_ROLE) {
        // Mint new tokens to the specified address
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = _userInterestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice This function is used to burn tokens from the specified address.
     * @param _from The address from which the tokens will be burned.
     * @param _amount ?The amount of tokens to burn.
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINR_AND_BURN_ROLE) {
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @notice This function is used to transfer tokens from the caller to the specified address.
     * @param _recepient The address to which the tokens will be transferred.
     * @param _amount The amount of tokens to transfer.
     * @return bool Returns true if the transfer was successful, false otherwise.
     */
    function transfer(address _recepient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recepient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recepient) == 0) {
            s_userInterestRate[_recepient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recepient, _amount);
    }

    /**
     * @notice This function is used to transfer tokens from one address to another.
     * @param _sender The address from which the tokens will be transferred.
     * @param _recepient The address to which the tokens will be transferred.
     * @param _amount The amount of tokens to transfer.
     * @return bool Returns true if the transfer was successful, false otherwise.
     */
    function transferFrom(address _sender, address _recepient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recepient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recepient) == 0) {
            s_userInterestRate[_recepient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recepient, _amount);
    }

    function balanceOf(address _user) public view override returns (uint256) {
        //Get the current principle balance of the user
        // multiply the balance by the interest rate to get the interest accrued
        return super.balanceOf(_user) * _calculatedUserAccumulatedInterestSinceLastTimestamp(_user) / 1e18;
    }

    function _mintAccruedInterest(address _user) internal {
        // Mint new tokens to the specified address based on the interest rate
        uint256 previousPrincipalBalnce = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceIcrease = currentBalance - previousPrincipalBalnce;
        s_userLastUpdatedTimeStamp[_user] = block.timestamp;
        _mint(_user, balanceIcrease);
        
    }

    function _calculatedUserAccumulatedInterestSinceLastTimestamp(address _user) internal view returns (uint256 liniarInterest) {
        // Calculate the interest accrued since the last timestamp
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimeStamp[_user];
        return liniarInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
        
        
    }

    function getUserInterestRate(address _user) external view returns (uint256) {
        // Get the interest rate for the specified user
        return s_userInterestRate[_user];
    }

    function getInterestRate () external view returns (uint256) {
        // Get the interest rate for the contract
        return s_interestRate;
    }

}
//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {iRebaseToken} from "./Interfaces/iRebaseToken.sol";

contract Vault {

    error Vault__RedeemFailed();
    
    iRebaseToken private immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    constructor(iRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    /**
     * @notice Deposit ether into the vault and mint rebase tokens to the user.
     * @dev The amount of ether deposited is equal to the amount of rebase tokens minted.
     * 
     */
    function deposit() external payable {
        i_rebaseToken.mint(msg.sender, msg.value, i_rebaseToken.getInterestRate());
        emit Deposit(msg.sender, msg.value);
    }

    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        i_rebaseToken.burn(msg.sender, _amount);
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
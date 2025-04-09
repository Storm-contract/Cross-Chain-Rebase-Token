//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/interfaces/IERC20.sol";

contract BridgeTokensScript is Script{
    function run(address receiver, address tokenToSendAddress, uint64 destChainSelector, address ccipRouterAddress, uint256 amountToSend, address linkAddress) public {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: tokenToSendAddress, // 0x0 for native token
            amount: amountToSend // Amount to send
        });
        vm.startBroadcast();
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: linkAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit:0}))
        });
        uint256 ccipFee = IRouterClient(ccipRouterAddress).getFee(destChainSelector, message);
        IERC20(linkAddress).approve(ccipRouterAddress, ccipFee);
        IERC20(tokenToSendAddress).approve(ccipRouterAddress, amountToSend);
        IRouterClient(ccipRouterAddress).ccipSend(destChainSelector, message);
        vm.stopBroadcast();
    }
}
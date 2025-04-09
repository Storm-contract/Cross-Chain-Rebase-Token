//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {RebaseToken} from "../src/Rebase-Token.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {CCIPLocalSimulatorFork} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/interfaces/IERC20.sol";
import {Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";

import {iRebaseToken} from "../src/Interfaces/iRebaseToken.sol";


contract TokenAndPoolDeployer is Script {
    function run() public returns (RebaseToken token, RebaseTokenPool pool) {
        // Deploy the RebaseToken contract
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        );
        vm.startBroadcast();
        token = new RebaseToken();
        pool = new RebaseTokenPool(
            IERC20(address(token)),
            new address[](0),
            networkDetails.rmnProxyAddress,
            networkDetails.routerAddress
        );
        token.grantMintAndBurnRole(address(pool));
        RegistryModuleOwnerCustom(networkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(token));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(token));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(address(token), address(pool));
        vm.stopBroadcast();
    }
}

contract VaultDeployer is Script {
    function run (address _rebaseToken) public returns (Vault vault) {
        // Deploy the Vault contract and grant mint and burn roles to it
        vm.startBroadcast();
        vault = new Vault(iRebaseToken(_rebaseToken));
        iRebaseToken(_rebaseToken).grantMintAndBurnRole(address(vault));
        vm.stopBroadcast();
    }
}
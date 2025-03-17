// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Bridgeable} from "./ERC20Bridgeable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Poop is ERC20, ERC20Bridgeable, Ownable {
    address internal constant SUPERCHAIN_TOKEN_BRIDGE = 0x4200000000000000000000000000000000000028;
    error Unauthorized();

    constructor(address initialOwner)
        ERC20("Poop", "POOP")
        Ownable(initialOwner)
    {}

    /**
     * @dev Checks if the caller is the predeployed SuperchainTokenBridge. Reverts otherwise.
     *
     * IMPORTANT: The predeployed SuperchainTokenBridge is only available on chains in the Superchain.
     */
    function _checkTokenBridge(address caller) internal pure override {
        if (caller != SUPERCHAIN_TOKEN_BRIDGE) revert Unauthorized();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

contract Factory {
    event Deployed(address addr);

    function deploy(uint256 _salt, address _owner) external {
        address addr;
        bytes memory bytecode = type(Poop).creationCode;
        bytes memory initCode = abi.encodePacked(bytecode, abi.encode(_owner));

        assembly {
            addr := create2(0, add(initCode, 0x20), mload(initCode), _salt)
        }
        require(addr != address(0), "Deployment failed");

        emit Deployed(addr);
    }

    function computeAddress(uint256 _salt, address _deployer, address _owner) external pure returns (address) {
        bytes memory bytecode = type(Poop).creationCode;
        bytes memory initCode = abi.encodePacked(bytecode, abi.encode(_owner));
        bytes32 bytecodeHash = keccak256(initCode);

        return address(uint160(uint(keccak256(abi.encodePacked(
            bytes1(0xff),
            _deployer,
            _salt,
            bytecodeHash
        )))));
    }
}

// Layout of Contract:
// license
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Exchange} from "./Exchange.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Factory {
    /*//////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////*/
    mapping(address => address) public s_tokenToExchange;
    mapping(address => address) public s_exchangeToToken;
    address[] public s_exchangeAddresses;

    /*//////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////*/
    event newExchangeAddressCreated(address indexed exchangeAddress);
    /*//////////////////////////////////////////////////////////
                             ERRORS
    //////////////////////////////////////////////////////////*/

    function createExchange(
        address _tokenAddress
    ) public returns (address exchangeAddress) {
        require(_tokenAddress != address(0), "INVALID TOKEN");
        require(
            s_tokenToExchange[_tokenAddress] == address(0),
            "Already has an exchange"
        );
        string memory name = ERC20(_tokenAddress).name();
        string memory symbol = ERC20(_tokenAddress).symbol();
        bytes memory bytecode = abi.encodePacked(type(Exchange).creationCode , abi.encode(_tokenAddress,address(this),name,symbol));
        bytes32 salt = keccak256(abi.encodePacked(_tokenAddress));
        assembly {
            exchangeAddress := create2(
                0,
                add(bytecode, 32),
                mload(bytecode),
                salt
            )
        }
        s_tokenToExchange[_tokenAddress] = exchangeAddress;
        s_exchangeToToken[exchangeAddress] = _tokenAddress;
        s_exchangeAddresses.push(exchangeAddress);
        emit newExchangeAddressCreated(exchangeAddress);
    }

    function getExchange(address _tokenAddress) public view returns (address) {
        return s_tokenToExchange[_tokenAddress];
    }

    function getToken(address _exchangeAddress) public view returns (address) {
        return s_exchangeToToken[_exchangeAddress];
    }
}

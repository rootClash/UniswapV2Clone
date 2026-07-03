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

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IFactory} from "../src/interfaces/IFactory.sol";

contract Exchange is ERC20 {
    /*//////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////*/

    error Exchange__InvalidTokenAddress();
    error Exchange__InsufficientOutputAmount();
    error Exchange__InsufficientLiquidity();
    error Exchange__InvalidReserves();
    error Exchange__InvalidTokenAmount();
    error Exchange__TokenTransferedFailed();
    error Exchange__InsufficientEthAmount();
    error Exchange__InputAmountLessThenExpected(
        uint256 etheInput,
        uint256 ExpectedTokenAmount
    );
    error Exchange__LiquidityPoolCannotBeZero();
    /*//////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////*/
    IERC20 private immutable i_token;
    IFactory private immutable factory;
    uint256 private s_ethReserve;
    uint256 private s_tokenReserve;
    uint256 private constant MIN_ETH_TO_DEPOSIT = 1_000_000_000;
    /*//////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////*/

    event AddLiquidity(
        address indexed provider,
        uint256 ethAmount,
        uint256 tokenAmount
    );
    event RemoveLiquidity(
        address indexed provider,
        uint256 ethAmount,
        uint256 tokenAmount
    );
    event TokenPurchase(
        address indexed buyer,
        uint256 ethSold,
        uint256 tokensBought
    );
    event EthPurchase(
        address indexed buyer,
        uint256 tokensSold,
        uint256 ethBought
    );

    /*//////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////*/

    constructor(
        address _token,
        address _factoryAddress,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        if (_token == address(0)) revert Exchange__InvalidTokenAddress();
        i_token = IERC20(_token);
        factory = IFactory(_factoryAddress);
    }

    /*//////////////////////////////////////////////////////////
                            LIQUIDITY LOGIC
    //////////////////////////////////////////////////////////*/

    function addLiquidity(
        uint256 _tokenAmount
    ) public payable returns (uint256 liquidityMinted) {
        if (_tokenAmount == 0) {
            revert Exchange__InvalidTokenAmount();
        }

        uint256 ethBalance = address(this).balance - msg.value;
        uint256 tokenBalance = i_token.balanceOf(address(this));

        if (s_ethReserve == 0 && s_tokenReserve == 0) {
            if (msg.value < MIN_ETH_TO_DEPOSIT) {
                revert Exchange__InsufficientEthAmount();
            }

            s_ethReserve += msg.value;
            s_tokenReserve += _tokenAmount;

            _mint(msg.sender, msg.value);
            bool success = i_token.transferFrom(
                msg.sender,
                address(this),
                _tokenAmount
            );
            if (!success) {
                revert Exchange__TokenTransferedFailed();
            }
            liquidityMinted = msg.value;
        } else {
            uint256 expectedTokenAmount = (msg.value * tokenBalance) /
                ethBalance;

            if (_tokenAmount < expectedTokenAmount) {
                revert Exchange__InputAmountLessThenExpected(
                    _tokenAmount,
                    expectedTokenAmount
                );
            }

            liquidityMinted = (msg.value * totalSupply()) / ethBalance;
            s_ethReserve += msg.value;
            s_tokenReserve += _tokenAmount;
            _mint(msg.sender, liquidityMinted);
            bool success = i_token.transferFrom(
                msg.sender,
                address(this),
                _tokenAmount
            );
            if (!success) {
                revert Exchange__TokenTransferedFailed();
            }
        }

        emit AddLiquidity(msg.sender, msg.value, _tokenAmount);
        return liquidityMinted;
    }

    function removeLiquidity(
        uint256 _lpAmount
    ) public returns (uint256 ethAmount, uint256 tokenAmount) {
        // TODO: calculate proportional payout, burn LP tokens, transfer out
        if (_lpAmount == 0) {
            revert Exchange__LiquidityPoolCannotBeZero();
        }
        // liquidityBalance of user check kro
        
        // fir ethWithdrawn and tokensWithdrawn calculate kro
        // then stateVariable of ethReserve and tokenReserve update kro
        // then _burn use kro to burn the function
        // then send kro token user ko


    }

    /*//////////////////////////////////////////////////////////
                            PRICING LOGIC
    //////////////////////////////////////////////////////////*/

    function getReserve() public view returns (uint256 ethReserve , uint256 tokenReserve) {
        return (s_ethReserve , s_tokenReserve);

    }

    function getInputPrice(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        // TODO: constant product formula, 0.3% fee
    }

    function getOutputPrice(
        uint256 outputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        // TODO: inverse of getInputPrice
    }

    /*//////////////////////////////////////////////////////////
                              SWAP LOGIC
    //////////////////////////////////////////////////////////*/

    function ethToTokenSwap(uint256 _minTokens) public payable {
        // TODO
    }

    function tokenToEthSwap(uint256 _tokensSold, uint256 _minEth) public {
        // TODO
    }

    function tokenToTokenSwap(
        uint256 _tokensSold,
        uint256 _minTokensBought,
        address _targetToken
    ) public {
        // TODO: look up target Exchange via factory, route through ETH internally
    }
}

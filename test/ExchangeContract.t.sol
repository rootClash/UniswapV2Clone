// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Exchange} from "../src/Exchange.sol";
import {Factory} from "../src/Factory.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockDAI", "MDAI") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract TestExchange is Test {
    ERC20Mock internal erc20;
    MockERC20 internal mockERC20;
    Factory internal factory;
    Exchange internal exchange;
    Exchange internal exchange_2;
    address liquidityProvider_1 = makeAddr("liquidityProvider_1");
    address liquidityProvider_2 = makeAddr("liquidityProvider_2");
    address user3 = makeAddr("user3");

    function setUp() public {
        erc20 = new ERC20Mock();
        mockERC20 = new MockERC20();
        factory = new Factory();

        address exchangeAddress1 = factory.createExchange(address(erc20));
        exchange = Exchange(exchangeAddress1);
        console.log("exchange address : ", exchangeAddress1);

        erc20.mint(liquidityProvider_1, 200e18);
        erc20.mint(user3, 10e18);

        // creating another exchange for tokenToToken swap
        address exchangeAddress2 = factory.createExchange(address(mockERC20));
        exchange_2 = Exchange(exchangeAddress2);
        console.log("exchange address 2 : ", exchangeAddress2);

        mockERC20.mint(liquidityProvider_2, 200e18);
    }

    function testAddLiquidity() public {

        vm.deal(liquidityProvider_1, 100 ether);
        vm.startPrank(liquidityProvider_1);
        erc20.approve(address(exchange), 100e18);
        vm.expectEmit(true, false, false, true, address(exchange));
        emit Exchange.AddLiquidity(liquidityProvider_1, 100 ether, 100 ether);
        uint256 liquidity = exchange.addLiquidity{value: 100 ether}(100 ether);
        vm.stopPrank();

        assert(address(exchange).balance == 100 ether);
        assert(exchange.balanceOf(liquidityProvider_1) == 100 ether);
    }

    function testAddLiquidityAfterLiquidity() public {
        vm.deal(liquidityProvider_1, 200 ether);
        vm.startPrank(liquidityProvider_1);
        erc20.approve(address(exchange), type(uint256).max);
        uint256 firstLiquidity = exchange.addLiquidity{value: 100 ether}(
            100 ether
        );
        console.log(
            "liquidityProvider_1 LP Tokens (1st deposit):",
            firstLiquidity
        );
        console.log(
            "Exchange's ERC20Mock Balance:",
            erc20.balanceOf(address(exchange))
        );
        console.log("Exchange's ETH Balance:", address(exchange).balance);

        uint256 expectedliquidity = (100 ether * exchange.totalSupply()) /
            address(exchange).balance;
        console.log("Expected LP Tokens:", expectedliquidity);

        uint256 secondLiquidity = exchange.addLiquidity{value: 100 ether}(
            100 ether
        );
        console.log(
            "liquidityProvider_1 LP Tokens (2nd deposit):",
            secondLiquidity
        );

        // The amount of LP tokens minted is proportional to the existing supply.
        // For a 1:1 deposit, the second liquidity amount should equal the first.
        assertEq(secondLiquidity, firstLiquidity);
        assert(address(exchange).balance == 200 ether);
        assert(
            exchange.balanceOf(liquidityProvider_1) ==
                firstLiquidity + secondLiquidity
        );
        vm.stopPrank();
    }

    function testFactory() public {
        address exchangeAddr = factory.createExchange(address(erc20));
        assert(factory.getExchange(address(erc20)) == exchangeAddr);
    }

    function testRemoveLiquidity() public {
        vm.deal(liquidityProvider_1, 200 ether);
        vm.startPrank(liquidityProvider_1);
        erc20.approve(address(exchange), type(uint256).max);
        uint256 firstLiquidity = exchange.addLiquidity{value: 100 ether}(
            100 ether
        );
        (uint256 ethWithdraw, uint256 tokenWithdraw) = exchange.removeLiquidity(
            firstLiquidity
        );
        vm.stopPrank();
        assert(ethWithdraw == 100 ether);
        assert(tokenWithdraw == 100 ether);
    }

    function test_getInputPrice() public {
        uint256 inputPrice = exchange.getInputPrice(1 ether, 10 ether, 500e18);
        console.log("input price :", inputPrice);
    }

    function test_getOutputPrice() public {
        uint256 outputPrice = exchange.getOutputPrice(
            1 ether,
            10 ether,
            500e18
        );
        console.log("output price :", outputPrice);
    }

    function test_ethTokenSwap() public {
        vm.deal(liquidityProvider_1, 200 ether);
        vm.startPrank(liquidityProvider_1);
        erc20.approve(address(exchange), type(uint256).max);
        uint256 firstLiquidity = exchange.addLiquidity{value: 100 ether}(
            100 ether
        );
        vm.stopPrank();

        vm.deal(address(0x12), 10 ether);
        uint256 balanceOfUser = erc20.balanceOf(address(0x12));
        (uint256 ethReserve, uint256 tokenReserve) = exchange.getReserve();
        uint256 invariantBefore = ethReserve * tokenReserve;
        console.log("Eth Reserve before : ", ethReserve);
        console.log("Token Reserve before : ", tokenReserve);
        uint256 expectedToken = exchange.getInputPrice(
            1 ether,
            ethReserve,
            tokenReserve
        );
        vm.startPrank(address(0x12));
        exchange.ethToTokenSwap{value: 1 ether}(expectedToken);
        vm.stopPrank();
        (uint256 ethReserveAfter, uint256 tokenReserveAfter) = exchange
            .getReserve();
        uint256 invariantAfter = ethReserveAfter * tokenReserveAfter;
        console.log("Eth Reserve : ", ethReserveAfter);
        console.log("Tokens Reserve : ", tokenReserveAfter);
        assert(erc20.balanceOf(address(0x12)) > balanceOfUser);
        assertGe(invariantAfter, invariantBefore);
    }

    function test_tokenEthSwap() public {
        uint256 _tokenToSwap = 10e18;
        uint256 minEth = 1e15;
        vm.deal(liquidityProvider_1, 200 ether);
        vm.startPrank(liquidityProvider_1);
        erc20.approve(address(exchange), type(uint256).max);
        exchange.addLiquidity{value: 100 ether}(100 ether);
        vm.stopPrank();

        vm.startPrank(user3);
        erc20.approve(address(exchange), _tokenToSwap);
        (uint256 ethReserve, uint256 tokenReserve) = exchange.getReserve();
        console.log("eth reserve : ", ethReserve);
        console.log("token reserve : ", tokenReserve);
        uint256 etheBalanceBefore = address(user3).balance;
        uint256 tokenBalanceBefore = erc20.balanceOf(user3);
        console.log("ether balance before : ", etheBalanceBefore);
        console.log("token balance before : ", tokenBalanceBefore);

        exchange.tokenToEthSwap(_tokenToSwap, minEth);
        (uint256 ethReserveAfter, uint256 tokenReserveAfter) = exchange
            .getReserve();
        console.log("eth reserve after : ", ethReserveAfter);
        console.log("token reserve after : ", tokenReserveAfter);

        uint256 etherBalanceAfter = address(user3).balance;
        uint256 tokenBalanceAfter = erc20.balanceOf(user3);
        console.log("ether balance after : ", etherBalanceAfter);
        console.log("token balance after : ", tokenBalanceAfter);
        vm.stopPrank();
        assert(etherBalanceAfter > etheBalanceBefore);
        assert(tokenBalanceAfter < tokenBalanceBefore);
    }

    function test_tokenToTokenSwap() public {
    
        // add the liquidity in first exchange by liquidityProvider_1
        vm.deal(liquidityProvider_1, 200 ether);
        vm.startPrank(liquidityProvider_1);
        erc20.approve(address(exchange), type(uint256).max);
        exchange.addLiquidity{value: 100 ether}(100e18);
        vm.stopPrank();

        // create a exchange 2 and add the liquidity
        vm.deal(liquidityProvider_2, 200 ether);
        vm.startPrank(liquidityProvider_2);
        mockERC20.approve(address(exchange_2), type(uint256).max);
        exchange_2.addLiquidity{value: 200 ether}(50e18);
        vm.stopPrank();

        vm.deal(user3, 49 ether);
        (uint256 ethReserve, uint256 tokenReserve) = exchange.getReserve();
        uint256 expectedToken = exchange.getInputPrice(
            49 ether,
            ethReserve,
            tokenReserve
        );
        vm.startPrank(user3);
        exchange.ethToTokenSwap{value: 49 ether}(expectedToken);

        // User now has `expectedToken` of erc20, and wants to swap them for mockERC20
        erc20.approve(address(exchange), expectedToken);

        // new eth reserve
        (uint256 ethReserveAfter, uint256 tokenReserveAfter) = exchange
            .getReserve();

        // amount of eth will be out
        uint256 ethFromPool = exchange.getInputPrice(
            expectedToken,
            tokenReserveAfter,
            ethReserveAfter
        );
        (uint256 ex_ethPool, uint256 ex_tokenPool) = exchange_2.getReserve();

        uint256 ex_tokenBought = exchange_2.getInputPrice(
            ethFromPool,
            ex_ethPool,
            ex_tokenPool
        );

        uint256 userMockBalanceBefore = mockERC20.balanceOf(user3);

        exchange.tokenToTokenSwap(
            expectedToken,
            ex_tokenBought,
            address(mockERC20)
        );

        uint256 userMockBalanceAfter = mockERC20.balanceOf(user3);
        vm.stopPrank();

        assertGe(mockERC20.balanceOf(address(exchange_2)), 0);
        assert(userMockBalanceAfter > userMockBalanceBefore);
    }
}

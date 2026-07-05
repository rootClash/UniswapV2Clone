// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {Exchange} from "../src/Exchange.sol";
import {Factory} from "../src/Factory.sol";

contract TestExchange is Test {
    ERC20Mock internal erc20;
    Factory internal factory;
    Exchange internal exchange;
    address user1 = makeAddr("user1");
    function setUp() public {
        erc20 = new ERC20Mock();
        factory = new Factory();
        exchange = new Exchange(
            address(erc20),
            address(factory),
            "ERC20Mock",
            "E20M"
        );
        erc20.mint(user1, 200e18);
    }

    function testAddLiquidity() public {
        vm.deal(user1, 100 ether);
        vm.startPrank(user1);
        erc20.approve(address(exchange), 100e18);
        vm.expectEmit(true, false, false, true, address(exchange));
        emit Exchange.AddLiquidity(user1, 100 ether, 100 ether);
        uint256 liquidity = exchange.addLiquidity{value: 100 ether}(100 ether);
        vm.stopPrank();

        assert(address(exchange).balance == 100 ether);
        assert(exchange.balanceOf(user1) == 100 ether);
    }

    function testAddLiquidityAfterLiquidity() public {
        vm.deal(user1, 200 ether);
        vm.startPrank(user1);
        erc20.approve(address(exchange), type(uint256).max);
        uint256 firstLiquidity = exchange.addLiquidity{value: 100 ether}(
            100 ether
        );
        console.log("User1 LP Tokens (1st deposit):", firstLiquidity);
        console.log(
            "Exchange's ERC20Mock Balance:",
            erc20.balanceOf(address(exchange))
        );
        console.log("Exchange's ETH Balance:", address(exchange).balance);

        uint256 expectedliquidity = (100 ether * exchange.totalSupply()) / address(exchange).balance;
        console.log("Expected LP Tokens:", expectedliquidity);

        uint256 secondLiquidity = exchange.addLiquidity{value: 100 ether}(
            100 ether
        );
        console.log("User1 LP Tokens (2nd deposit):", secondLiquidity);

        // The amount of LP tokens minted is proportional to the existing supply.
        // For a 1:1 deposit, the second liquidity amount should equal the first.
        assertEq(secondLiquidity, firstLiquidity);
        assert(address(exchange).balance == 200 ether);
        assert(exchange.balanceOf(user1) == firstLiquidity + secondLiquidity);
        vm.stopPrank();
    }

    function testFactory() public {
        address exchangeAddr = factory.createExchange(address(erc20));
        assert(factory.getExchange(address(erc20)) == exchangeAddr);
    }

    function testRemoveLiquidity() public {
        vm.deal(user1, 200 ether);
        vm.startPrank(user1);
        erc20.approve(address(exchange), type(uint256).max);
        uint256 firstLiquidity = exchange.addLiquidity{value: 100 ether}(
            100 ether
        );
        (uint256 ethWithdraw , uint256 tokenWithdraw) = exchange.removeLiquidity(firstLiquidity);
        vm.stopPrank();
        assert(ethWithdraw == 100 ether);
        assert(tokenWithdraw == 100 ether);
    }

    function test_getInputPrice() public {
        uint256 inputPrice = exchange.getInputPrice(1 ether, 10 ether, 500e18);
        console.log("input price :" , inputPrice);
    }

    function test_getOutputPrice() public {
        uint256 outputPrice = exchange.getOutputPrice(1 ether, 10 ether, 500e18);
        console.log("output price :" , outputPrice);
    }

    function test_ethTokenSwap() public {
        vm.deal(user1, 200 ether);
        vm.startPrank(user1);
        erc20.approve(address(exchange), type(uint256).max);
        uint256 firstLiquidity = exchange.addLiquidity{value: 100 ether}(
            100 ether
        );
        vm.stopPrank();

        vm.deal(address(0x12) , 10 ether);
        uint256 balanceOfUser = erc20.balanceOf(address(0x12));
        (uint256 ethReserve , uint256 tokenReserve) = exchange.getReserve();
        uint256 invariantBefore = ethReserve * tokenReserve;
        console.log("Eth Reserve before : ",ethReserve);
        console.log("Token Reserve before : ", tokenReserve);
        uint256 expectedToken = exchange.getInputPrice(1 ether, ethReserve, tokenReserve);
        vm.startPrank(address(0x12));
        exchange.ethToTokenSwap{value : 1 ether}(expectedToken);
        vm.stopPrank();
        (uint256 ethReserveAfter , uint256 tokenReserveAfter) = exchange.getReserve();
        uint256 invariantAfter = ethReserveAfter * tokenReserveAfter;
        console.log("Eth Reserve : ", ethReserveAfter);
        console.log("Tokens Reserve : ", tokenReserveAfter);
        assert(erc20.balanceOf(address(0x12)) > balanceOfUser );
        assertGe(invariantAfter , invariantBefore);
    }
}   

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";
import {Exchange} from "src/Exchange.sol";
import {Factory} from "src/Factory.sol";
import {Token} from "src/Token.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract Test_Factory is Test {
    Factory factory;
    Token token;

    function setUp() public {
        factory = new Factory();
        token = new Token("Token", "TKN", 1_000_000);
    }

    function test_createExchange_ItDeploysAnExchange() public {
        Exchange exchange = Exchange(factory.createExchange(address(token)));
        assertEq(exchange.name(), "Zuniswap-V1");
        assertEq(exchange.symbol(), "ZUNI-V1");
        assertEq(exchange.tokenAddress(), address(token));
        assertEq(exchange.factoryAddress(), address(factory));
    }

    function test_createExchange_ItDoesntAllowZeroAddress() public {
        vm.expectRevert("invalid token address");
        factory.createExchange(address(0));
    }

    function test_createExchange_ItFailsWhenExchangeExists() public {
        factory.createExchange(address(token));
        vm.expectRevert("exchange already exists");
        factory.createExchange(address(token));
    }

    function test_getExchange_ItReturnsExchangeAddressByTokenAddress() public {
        address exchange = factory.createExchange(address(token));
        assertEq(factory.getExchange(address(token)), exchange);
    }
}

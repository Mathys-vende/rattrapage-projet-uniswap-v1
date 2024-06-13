// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";
import {Exchange} from "src/Exchange.sol";
import {Token} from "src/Token.sol";

contract Test_Exchange is Test {
    uint256 constant TOKEN_MAX_SUPPLY = 1_000_000 ether;

    Token public token;
    Exchange public exchange;

    address owner = address(this);
    address user = address(0xc2ba);

    function setUp() public virtual {
        token = new Token("Token", "TKN", TOKEN_MAX_SUPPLY);
        exchange = new Exchange(address(token));

        deal(user, 1_000_000 ether);
    }

    receive() external payable {}
}

contract Test_Exchange_Deployment is Test_Exchange {
    function test_ItIsDeployed() public view {
        assertEq(exchange.tokenAddress(), address(token));
    }
}

contract Test_Exchange_AddLiquidity is Test_Exchange {
    function test_ItAddsLiquidity() public {
        token.approve(address(exchange), 200 ether);
        exchange.addLiquidity{value: 100 ether}(200 ether);

        assertEq(address(exchange).balance, 100 ether);
        assertEq(exchange.getReserve(), 200 ether);
    }

    function test_ItAllowsZeroAmounts() public {
        token.approve(address(exchange), 0);
        exchange.addLiquidity{value: 0}(0);

        assertEq(address(exchange).balance, 0);
        assertEq(exchange.getReserve(), 0);
    }
}

contract Test_Exchange_GetTokenAmount is Test_Exchange {
    function test_ItReturnsCorrectTokenAmount() public {
        token.approve(address(exchange), 2000 ether);
        exchange.addLiquidity{value: 1000 ether}(2000 ether);

        assertEq(exchange.getTokenAmount(1 ether), 1.998001998001998001 ether);
        assertEq(exchange.getTokenAmount(100 ether), 181.818181818181818181 ether);
        assertEq(exchange.getTokenAmount(1000 ether), 1000 ether);
    }
}

contract Test_Exchange_GetEtherAmount is Test_Exchange {
    function test_ItReturnsCorrectEtherAmount() public {
        token.approve(address(exchange), 2000 ether);
        exchange.addLiquidity{value: 1000 ether}(2000 ether);

        assertEq(exchange.getEthAmount(2 ether), 0.999000999000999 ether);
        assertEq(exchange.getEthAmount(100 ether), 47.619047619047619047 ether);
        assertEq(exchange.getEthAmount(2000 ether), 500 ether);
    }
}

contract Test_Exchange_EthToTokenSwap is Test_Exchange {
    function setUp() public override {
        super.setUp();
        token.approve(address(exchange), 2000 ether);
        exchange.addLiquidity{value: 1000 ether}(2000 ether);
    }

    function test_ItTransfersAtLeastMinAmountOfTokens() public {
        uint256 userBalanceBefore = user.balance;

        vm.prank(user);
        exchange.ethToTokenSwap{value: 1 ether}(1.99 ether);

        uint256 userBalanceAfter = user.balance;

        assertEq(userBalanceBefore - userBalanceAfter, 1 ether);
        assertEq(token.balanceOf(user), 1.998001998001998001 ether);
        assertEq(address(exchange).balance, 1001 ether);
        assertEq(token.balanceOf(address(exchange)), 1998.001998001998001999 ether);
    }

    function test_ItFailsWhenOutputAmountIsLessThanMinAmount() public {
        vm.expectRevert("insufficient output amount");
        exchange.ethToTokenSwap{value: 1 ether}(2 ether);
    }

    function test_ItAllowsZeroSwaps() public {
        vm.prank(user);
        exchange.ethToTokenSwap{value: 0}(0);

        assertEq(token.balanceOf(user), 0);
        assertEq(address(exchange).balance, 1000 ether);
        assertEq(token.balanceOf(address(exchange)), 2000 ether);
    }
}

contract Test_Exchange_TokenToEthSwap is Test_Exchange {
    function setUp() public override {
        super.setUp();
        token.transfer(user, 2 ether);
        vm.prank(user);
        token.approve(address(exchange), 2 ether);

        token.approve(address(exchange), 2000 ether);
        exchange.addLiquidity{value: 1000 ether}(2000 ether);
    }

    function test_ItTransfersAtLeastMinAmountOfTokens() public {
        uint256 userBalanceBefore = user.balance;

        vm.prank(user);
        exchange.tokenToEthSwap(2 ether, 0.9 ether);

        uint256 userBalanceAfter = user.balance;

        assertEq(userBalanceAfter - userBalanceBefore, 0.999000999000999 ether);
        assertEq(token.balanceOf(user), 0 ether);
        assertEq(address(exchange).balance, 999.000999000999001 ether);
        assertEq(token.balanceOf(address(exchange)), 2002 ether);
    }

    function test_ItFailsWhenOutputAmountIsLessThanMinAmount() public {
        vm.expectRevert("insufficient output amount");
        vm.prank(user);
        exchange.tokenToEthSwap(2 ether, 1 ether);
    }

    function test_ItAllowsZeroSwaps() public {
        uint256 userBalanceBefore = user.balance;
        vm.prank(user);
        exchange.tokenToEthSwap(0, 0);

        assertEq(user.balance, userBalanceBefore);
        assertEq(token.balanceOf(user), 2 ether);
        assertEq(address(exchange).balance, 1000 ether);
        assertEq(token.balanceOf(address(exchange)), 2000 ether);
    }
}

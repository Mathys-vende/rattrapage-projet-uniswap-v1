// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";
import {Exchange} from "src/Exchange.sol";
import {Factory} from "src/Factory.sol";
import {Token} from "src/Token.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

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
        assertEq(exchange.name(), "Zuniswap-V1");
        assertEq(exchange.symbol(), "ZUNI-V1");
        assertEq(exchange.totalSupply(), 0);
        assertEq(exchange.tokenAddress(), address(token));
        assertEq(exchange.factoryAddress(), owner);
    }
}

contract Test_Exchange_AddLiquidity_EmptyReserves is Test_Exchange {
    function test_ItAddsLiquidity() public {
        token.approve(address(exchange), 200 ether);
        exchange.addLiquidity{value: 100 ether}(200 ether);

        assertEq(address(exchange).balance, 100 ether);
        assertEq(exchange.getReserve(), 200 ether);
    }

    function test_ItMintsLPTokens() public {
        token.approve(address(exchange), 200 ether);
        exchange.addLiquidity{value: 100 ether}(200 ether);

        assertEq(address(exchange).balance, 100 ether);
        assertEq(exchange.totalSupply(), 100 ether);
    }

    function test_ItAllowsZeroAmounts() public {
        token.approve(address(exchange), 0);
        exchange.addLiquidity{value: 0}(0);

        assertEq(address(exchange).balance, 0);
        assertEq(exchange.getReserve(), 0);
    }
}

contract Test_Exchange_AddLiquidity_ExistingReserves is Test_Exchange {
    function setUp() public override {
        super.setUp();
        token.approve(address(exchange), 300 ether);
        exchange.addLiquidity{value: 100 ether}(200 ether);
    }

    function test_ItPreservesExchangeRate() public {
        exchange.addLiquidity{value: 50 ether}(200 ether);

        assertEq(address(exchange).balance, 150 ether);
        assertEq(exchange.getReserve(), 300 ether);
    }

    function test_ItMintsLPTokens() public {
        exchange.addLiquidity{value: 50 ether}(200 ether);

        assertEq(address(exchange).balance, 150 ether);
        assertEq(exchange.totalSupply(), 150 ether);
    }

    function test_ItFailsWhenNotEnoughTokens() public {
        // vm.expectRevert(
        //     abi.encodePacked(Exchange.InsufficientTokenAmount.selector, 50 ether, 50 ether)
        // );
        // vm.expectRevert("insufficient token amount");
        vm.expectRevert(); // TODO: replace with the above line
        exchange.addLiquidity{value: 50 ether}(50 ether);
    }
}

contract Test_Exchange_RemoveLiquidity is Test_Exchange {
    function setUp() public override {
        super.setUp();
        token.approve(address(exchange), 300 ether);
        exchange.addLiquidity{value: 100 ether}(200 ether);
    }

    function test_ItRemovesSomeLiquidity() public {
        uint256 userEtherBalanceBefore = owner.balance;
        uint256 userTokenBalanceBefore = token.balanceOf(owner);

        exchange.removeLiquidity(25 ether);

        assertEq(exchange.getReserve(), 150 ether);
        assertEq(address(exchange).balance, 75 ether);

        uint256 userEtherBalanceAfter = address(owner).balance;
        uint256 userTokenBalanceAfter = token.balanceOf(owner);

        assertEq(userEtherBalanceAfter - userEtherBalanceBefore, 25 ether);
        assertEq(userTokenBalanceAfter - userTokenBalanceBefore, 50 ether);
    }

    function test_ItRemovesAllLiquidity() public {
        uint256 userEtherBalanceBefore = address(owner).balance;
        uint256 userTokenBalanceBefore = token.balanceOf(owner);

        exchange.removeLiquidity(100 ether);

        assertEq(exchange.getReserve(), 0);
        assertEq(address(exchange).balance, 0);

        uint256 userEtherBalanceAfter = address(owner).balance;
        uint256 userTokenBalanceAfter = token.balanceOf(owner);

        assertEq(userEtherBalanceAfter - userEtherBalanceBefore, 100 ether);
        assertEq(userTokenBalanceAfter - userTokenBalanceBefore, 200 ether);
    }

    function test_ItPaysForProvidedLiquidity() public {
        uint256 userEtherBalanceBefore = address(owner).balance;
        uint256 userTokenBalanceBefore = token.balanceOf(owner);

        vm.prank(user);
        exchange.ethToTokenSwap{value: 10 ether}(18 ether);

        exchange.removeLiquidity(100 ether);

        assertEq(exchange.getReserve(), 0);
        assertEq(address(exchange).balance, 0);
        assertEq(token.balanceOf(user), 18.01637852593266606 ether);

        uint256 userEtherBalanceAfter = address(owner).balance;
        uint256 userTokenBalanceAfter = token.balanceOf(owner);

        assertEq(userEtherBalanceAfter - userEtherBalanceBefore, 110 ether);
        assertEq(userTokenBalanceAfter - userTokenBalanceBefore, 181.98362147406733394 ether);
    }

    function test_ItBurnsLPTokens() public {
        uint256 userLPTokenBalanceBefore = exchange.balanceOf(owner);

        exchange.removeLiquidity(25 ether);

        assertEq(exchange.balanceOf(owner), userLPTokenBalanceBefore - 25 ether);
        assertEq(exchange.totalSupply(), 75 ether);
    }

    function test_ItDoesntAllowInvalidAmount() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, owner, exchange.balanceOf(owner), uint256(100.1 ether)
            )
        );
        exchange.removeLiquidity(100.1 ether);
    }
}

contract Test_Exchange_GetTokenAmount is Test_Exchange {
    function test_ItReturnsCorrectTokenAmount() public {
        token.approve(address(exchange), 2000 ether);
        exchange.addLiquidity{value: 1000 ether}(2000 ether);

        assertEq(exchange.getTokenAmount(1 ether), 1.978041738678708079 ether);
        assertEq(exchange.getTokenAmount(100 ether), 180.1637852593266606 ether);
        assertEq(exchange.getTokenAmount(1000 ether), 994.974874371859296482 ether);
    }
}

contract Test_Exchange_GetEtherAmount is Test_Exchange {
    function test_ItReturnsCorrectEtherAmount() public {
        token.approve(address(exchange), 2000 ether);
        exchange.addLiquidity{value: 1000 ether}(2000 ether);

        assertEq(exchange.getEthAmount(2 ether), 0.989020869339354039 ether);
        assertEq(exchange.getEthAmount(100 ether), 47.16531681753215817 ether);
        assertEq(exchange.getEthAmount(2000 ether), 497.487437185929648241 ether);
    }
}

contract Test_Exchange_EthToTokenTransfer is Test_Exchange {
    function setUp() public override {
        super.setUp();
        token.approve(address(exchange), 2000 ether);
        exchange.addLiquidity{value: 1000 ether}(2000 ether);
    }

    function test_ItTransfersAtLeastMinAmountOfTokens() public {
        address user2 = address(0x1234);

        uint256 userBalanceBefore = user.balance;

        vm.prank(user);
        exchange.ethToTokenTransfer{value: 1 ether}(1.97 ether, user2);

        uint256 userBalanceAfter = user.balance;

        assertEq(userBalanceBefore - userBalanceAfter, 1 ether);
        assertEq(token.balanceOf(user2), 1.978041738678708079 ether);
        assertEq(address(exchange).balance, 1001 ether);
        assertEq(token.balanceOf(address(exchange)), 1998.021958261321291921 ether);
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
        exchange.ethToTokenSwap{value: 1 ether}(1.97 ether);

        uint256 userBalanceAfter = user.balance;

        assertEq(userBalanceBefore - userBalanceAfter, 1 ether);
        assertEq(token.balanceOf(user), 1.978041738678708079 ether);
        assertEq(address(exchange).balance, 1001 ether);
        assertEq(token.balanceOf(address(exchange)), 1998.021958261321291921 ether);
    }

    function test_ItAffectedExchangeRate() public {
        assertEq(exchange.getTokenAmount(10 ether), 19.605901574413308248 ether);

        exchange.ethToTokenSwap{value: 10 ether}(9 ether);

        assertEq(exchange.getTokenAmount(10 ether), 19.223356774598792281 ether);
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
        token.transfer(user, 22 ether);
        vm.prank(user);
        token.approve(address(exchange), 22 ether);

        token.approve(address(exchange), 2000 ether);
        exchange.addLiquidity{value: 1000 ether}(2000 ether);
    }

    function test_ItTransfersAtLeastMinAmountOfTokens() public {
        uint256 userBalanceBefore = user.balance;
        uint256 exchangeBalanceBefore = address(exchange).balance;

        vm.prank(user);
        exchange.tokenToEthSwap(2 ether, 0.9 ether);

        uint256 userBalanceAfter = user.balance;

        assertEq(userBalanceAfter - userBalanceBefore, 0.989020869339354039 ether);
        assertEq(token.balanceOf(user), 20 ether);
        assertEq(exchangeBalanceBefore - address(exchange).balance, 0.989020869339354039 ether);
        assertEq(token.balanceOf(address(exchange)), 2002 ether);
    }

    function test_ItAffectsExchangeRate() public {
        assertEq(exchange.getEthAmount(20 ether), 9.802950787206654124 ether);

        vm.prank(user);
        exchange.tokenToEthSwap(20 ether, 9 ether);

        assertEq(exchange.getEthAmount(20 ether), 9.61167838729939614 ether);
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
        assertEq(token.balanceOf(user), 22 ether);
        assertEq(address(exchange).balance, 1000 ether);
        assertEq(token.balanceOf(address(exchange)), 2000 ether);
    }
}

contract Test_Exchange_TokenToTokenSwap is Test {
    address owner = address(this);
    address user = address(0xc2ba);

    function test_ItSwapsTokenForToken() public {
        deal(user, 1_000_000 ether);

        Factory factory = new Factory();
        Token token = new Token("TokenA", "AAA", 1_000_000 ether);

        vm.prank(user);
        Token token2 = new Token("TokenB", "BBBB", 1_000_000 ether);

        Exchange exchange = Exchange(factory.createExchange(address(token)));

        vm.prank(user);
        Exchange exchange2 = Exchange(factory.createExchange(address(token2)));

        token.approve(address(exchange), 2_000 ether);
        exchange.addLiquidity{value: 1_000 ether}(2_000 ether);

        vm.startPrank(user);
        token2.approve(address(exchange2), 1_000 ether);
        exchange2.addLiquidity{value: 1_000 ether}(1_000 ether);
        vm.stopPrank();

        assertEq(token2.balanceOf(owner), 0);

        token.approve(address(exchange), 10 ether);
        exchange.tokenToTokenSwap(10 ether, 4.8 ether, address(token2));
        assertEq(token2.balanceOf(owner), 4.852698493489877956 ether);

        assertEq(token.balanceOf(user), 0);

        vm.startPrank(user);
        token2.approve(address(exchange2), 10 ether);
        exchange2.tokenToTokenSwap(10 ether, 19.6 ether, address(token));
        vm.stopPrank();

        assertEq(token.balanceOf(user), 19.602080509528011079 ether);
    }
}

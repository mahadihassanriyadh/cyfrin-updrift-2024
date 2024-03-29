// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

// import {Test, console} from "forge-std/Test.sol";
import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("User");
    uint256 constant SEND_VALUE = 5 ether; // 1e17 wei
    uint256 constant STARTING_BALANCE = 8e18; // 8 ether
    uint256 constant GAS_PRICE = 1; // 1 wei

    function setUp() external {
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();

        // give some funds to the fake user
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMinUsdIsFive() public {
        assertEq(fundMe.MIN_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughEth() public {
        vm.expectRevert(); // the next line should revert
        fundMe.fund{value: 1e8}(); // sending 0 wei or 1e8 wei which is <= 5$, should revert
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testFundUpdatesFundedDataStructure() public funded {
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddFundersToArrayOfFunders() public funded {
        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert(); // the next line should revert, it will skip the vm.prank(USER) line, it only works for tx
        vm.prank(USER);
        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded {
        // Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingContractBalance = address(fundMe).balance;

        // Act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingContractBalance = address(fundMe).balance;

        assertEq(
            endingOwnerBalance,
            startingOwnerBalance + startingContractBalance
        );
        assertEq(endingContractBalance, 0);
    }

    function testWithdrawFromMultipleFunders() public funded {
        // Arrange
        uint160 numOfFunders = 10;
        uint160 startingFunderIdx = 1;
        for (uint160 i = startingFunderIdx; i < numOfFunders; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingContractBalance = address(fundMe).balance;

        // Act
        uint256 gasStart = gasleft(); // gasLeft() is a built-in solidify function
        vm.txGasPrice(GAS_PRICE);
        /* 
            vm.startPrank(fundMe.getOwner());
            fundMe.withdraw();
            vm.stopPrank(); 
        */
        // this is the same as the above 3 lines
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice; // tx.gasprice is a built-in solidify variable that gives us the current gas price
        console.log("Gas used: ", gasUsed);

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingContractBalance = address(fundMe).balance;

        assertEq(
            endingOwnerBalance,
            startingOwnerBalance + startingContractBalance
        );
        assertEq(endingContractBalance, 0);
    }

    function testWithdrawFromMultipleFundersCheaper() public funded {
        // Arrange
        uint160 numOfFunders = 10;
        uint160 startingFunderIdx = 1;
        for (uint160 i = startingFunderIdx; i < numOfFunders; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingContractBalance = address(fundMe).balance;

        // Act
        uint256 gasStart = gasleft(); // gasLeft() is a built-in solidify function
        vm.txGasPrice(GAS_PRICE);
        /* 
            vm.startPrank(fundMe.getOwner());
            fundMe.withdraw();
            vm.stopPrank(); 
        */
        // this is the same as the above 3 lines
        vm.prank(fundMe.getOwner());
        fundMe.cheaperWithdraw();

        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice; // tx.gasprice is a built-in solidify variable that gives us the current gas price
        console.log("Gas used: ", gasUsed);

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingContractBalance = address(fundMe).balance;

        assertEq(
            endingOwnerBalance,
            startingOwnerBalance + startingContractBalance
        );
        
        assertEq(endingContractBalance, 0);
    }
}

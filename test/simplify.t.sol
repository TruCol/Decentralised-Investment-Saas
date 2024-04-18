// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23 <0.9.0;
import { console2 } from "forge-std/src/console2.sol";

// Used to run the tests
import { PRBTest } from "@prb/test/src/PRBTest.sol";
import { StdCheats } from "forge-std/src/StdCheats.sol";

// Import the main contract that is being tested.
import { DecentralisedInvestmentManager } from "../src/DecentralisedInvestmentManager.sol";

// Import the paymentsplitter that has the shares for the investors.
import { CustomPaymentSplitter } from "../src/CustomPaymentSplitter.sol";

// Import contract that is an attribute of main contract to test the attribute.
import { TierInvestment } from "../src/TierInvestment.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract SimplifiedTest is PRBTest, StdCheats {
  address internal projectLeadAddress;
  address private _investorWallet;
  address private _userWallet;
  DecentralisedInvestmentManager private _dim;

  /// @dev A function invoked before each test case is run.
  function setUp() public virtual {
    // Instantiate the attribute for the contract-under-test.
    projectLeadAddress = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    uint256 projectLeadFracNumerator = 4;
    uint256 projectLeadFracDenominator = 10;
    // assertEq(address(projectLeadAddress).balance, 43);
    _dim = new DecentralisedInvestmentManager(projectLeadFracNumerator, projectLeadFracDenominator, address(0));

    _investorWallet = address(uint160(uint256(keccak256(bytes("1")))));
    deal(_investorWallet, 8000000 wei);
    _userWallet = address(uint160(uint256(keccak256(bytes("2")))));
    deal(_userWallet, 100002 wei);

    // Print the addresses to console.
    console2.log("projectLeadAddress=    ", projectLeadAddress);
    console2.log("_investorWallet=       ", _investorWallet);
    console2.log("_userWallet=           ", _userWallet, "\n");
  }

  /// @dev Test to simulate a larger balance using `deal`.
  function testInvestorGetsSaasRevenue() public {
    uint256 startBalance = _investorWallet.balance;
    uint256 investmentAmount = 20_000 wei;

    // Send investment directly from the investor wallet.
    console2.log("_dim balance before=", address(_dim).balance);
    vm.deal(address(_investorWallet), startBalance);
    vm.prank(address(_investorWallet));
    _dim.receiveInvestment{ value: investmentAmount }();

    uint256 endBalance = _investorWallet.balance;

    // Assert that user balance decreased by the investment amount
    assertEq(
      startBalance - endBalance,
      investmentAmount,
      "investmentAmount not equal to difference in investorWalletBalance"
    );
    console2.log("startBalance=", startBalance);
    console2.log("endBalance=", endBalance);
    console2.log("investmentAmount=", investmentAmount);
    console2.log("_dim balance after=", address(_dim).balance);

    // Assert can make saas payment.
    uint256 saasPaymentAmount = 5000 wei;
    console2.log("_userWallet", _userWallet);
    // Directly call the function on the deployed contract.
    _dim.receiveSaasPayment{ value: saasPaymentAmount }();
    (bool paymentSuccess, bytes memory paymentResult) = _userWallet.call{ value: saasPaymentAmount }(
      abi.encodeWithSelector(_dim.receiveSaasPayment.selector)
    );

    // Get the payment splitter from the _dim contract.
    CustomPaymentSplitter paymentSplitter = _dim.getPaymentSplitter();
    // Assert the investor is added as a payee to the paymentSplitter.
    assertTrue(paymentSplitter.isPayee(_investorWallet), "The _investorWallet is not recognised as payee.");

    // Assert investor can retrieve saas revenue fraction.
    // assertEq(paymentSplitter.released(_investorWallet), 5);
  }
}

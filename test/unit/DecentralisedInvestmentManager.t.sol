// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import { PRBTest } from "@prb/test/src/PRBTest.sol";
import { StdCheats } from "forge-std/src/StdCheats.sol";
import { InitialiseDim } from "test/InitialiseDim.sol";
import { ExposedDecentralisedInvestmentManager } from "test/unit/ExposedDecentralisedInvestmentManager.sol";
import { DecentralisedInvestmentManager } from "./../../src/DecentralisedInvestmentManager.sol";
import { Helper } from "./../../src/Helper.sol";
import { SaasPaymentProcessor } from "./../../src/SaasPaymentProcessor.sol";
import { Tier } from "./../../src/Tier.sol";
import { TierInvestment } from "./../../src/TierInvestment.sol";

interface IDecentralisedInvestmentManagerTest {
  function setUp() external;

  function testProjectLeadFracNumerator() external;

  function testEmptyTiers() external;

  function testReturnFunds() external;

  function testZeroInvestmentThrowsError() external;

  function testTierGap() external;

  function testZeroSAASPayment() external;

  function testReachedCeiling() external;

  function testIncreaseCurrentMultipleInstantly() external;

  function testWithdraw() external;

  function testAllocateDoesNotAcceptZeroAmountAllocation() external;

  function testDifferenceInSAASPayoutAndCumulativeReturnThrowsError() external;

  function testPerformSaasRevenueAllocation() external;

  function testPerformSaasRevenueAllocationToNonPayee() external;
}

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract DecentralisedInvestmentManagerTest is PRBTest, StdCheats, IDecentralisedInvestmentManagerTest {
  address internal _projectLead;
  address private _investorWallet;
  address private _userWallet;

  DecentralisedInvestmentManager private _dim;
  uint256 private _projectLeadFracNumerator;
  uint256 private _projectLeadFracDenominator;
  SaasPaymentProcessor private _saasPaymentProcessor;
  Helper private _helper;
  ExposedDecentralisedInvestmentManager private _exposedDim;

  /// @dev A function invoked before each test case is run.
  function setUp() public override {
    _projectLeadFracNumerator = 4;
    _projectLeadFracDenominator = 10;
    _projectLead = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256[] memory ceilings = new uint256[](3);
    ceilings[0] = 4 ether;
    ceilings[1] = 15 ether;
    ceilings[2] = 30 ether;
    uint8[] memory multiples = new uint8[](3);
    multiples[0] = 10;
    multiples[1] = 5;
    multiples[2] = 2;
    InitialiseDim initDim = new InitialiseDim({
      ceilings: ceilings,
      multiples: multiples,
      raisePeriod: 12 weeks,
      investmentTarget: 3 ether,
      projectLead: _projectLead,
      projectLeadFracNumerator: _projectLeadFracNumerator,
      projectLeadFracDenominator: 10
    });
    _dim = initDim.getDim();
    _exposedDim = initDim.getExposedDim();

    // Assert the _cumReceivedInvestments is 0 after Initialisation.
    assertEq(_dim.getCumReceivedInvestments(), 0);

    _investorWallet = payable(address(uint160(uint256(keccak256(bytes("1"))))));
    deal(_investorWallet, 5555 ether);
    _userWallet = address(uint160(uint256(keccak256(bytes("2")))));
    deal(_userWallet, 100 ether);
  }

  /// @dev Test to simulate a larger balance using `deal`.
  function testProjectLeadFracNumerator() public override {
    assertEq(_dim.getProjectLeadFracNumerator(), _projectLeadFracNumerator);
  }

  function testEmptyTiers() public override {
    // Test empty tiers are not allowed.
    Tier[] memory emptyTiers = new Tier[](0);
    // vm.expectRevert(bytes("You must provide at least one tier."));
    vm.expectRevert(abi.encodeWithSignature("ProvideAtLeastOneTier(string,uint256)", "Provide at least one tier.", 0));

    new DecentralisedInvestmentManager({
      tiers: emptyTiers,
      projectLeadFracNumerator: _projectLeadFracNumerator,
      projectLeadFracDenominator: _projectLeadFracDenominator,
      projectLead: _projectLead,
      raisePeriod: 12 weeks,
      investmentTarget: 3 ether
    });
  }

  function testReturnFunds() public override {
    assertEq(_investorWallet.balance, 5555 ether, "_investorWallet balance unexpected before investment.");
    vm.prank(_investorWallet);
    _dim.receiveInvestment{ value: 5555 ether }();
    assertEq(_investorWallet.balance, 5525 ether, "_investorWallet balance after investment was unexpected.");
  }

  function testZeroInvestmentThrowsError() public override {
    // vm.expectRevert(bytes("The amount invested was not larger than 0."));
    vm.expectRevert(
      abi.encodeWithSignature("InvestmentAmountTooSmall(string,uint256)", "Investments should be 1 or larger", 0)
    );
    _dim.receiveInvestment{ value: 0 ether }();
  }

  function testTierGap() public override {
    // storage Tier[] gappedTiers;`
    Tier[] memory gappedTiers = new Tier[](3); // Assuming maximum of 2 tiers

    Tier tier0 = new Tier(0, 5, 10);
    Tier tier1 = new Tier(6, 15, 5);
    Tier tier2 = new Tier(20, 25, 6);

    gappedTiers[0] = tier0;
    gappedTiers[1] = tier1;
    gappedTiers[2] = tier2;

    vm.expectRevert(
      abi.encodeWithSignature(
        "CeilingPreviousTierNotEqualToFloorNextTier(string,uint256,uint256)",
        "Ceiling previous tier not equal to floor next tier.",
        5,
        6
      )
    );
    _dim = new DecentralisedInvestmentManager({
      tiers: gappedTiers,
      projectLeadFracNumerator: _projectLeadFracNumerator,
      projectLeadFracDenominator: _projectLeadFracDenominator,
      projectLead: _projectLead,
      raisePeriod: 12 weeks,
      investmentTarget: 3 ether
    });
  }

  function testZeroSAASPayment() public override {
    // vm.expectRevert(bytes("The SAAS payment was not larger than 0."));
    vm.expectRevert(abi.encodeWithSignature("SAASPaymentSmallerThanOne(string,uint256)", "SAAS payment below 1.", 0));
    // vm.prank(address(_userWallet));
    // Directly call the function on the deployed contract.
    _dim.receiveSaasPayment{ value: 0 }();
  }

  function testReachedCeiling() public override {
    // vm.expectRevert(bytes("Investment ceiling reached after processing. Remaining funds are returned to investor."));
    vm.prank(_investorWallet);
    _dim.receiveInvestment{ value: 31 ether }();
  }

  function testIncreaseCurrentMultipleInstantly() public override {
    _dim.receiveInvestment{ value: 20 ether }();

    vm.expectRevert(
      abi.encodeWithSignature(
        "OnlyProjectLeadCanIncreaseCurrentMultiple(string,address,address)",
        "Only projectLead can increase multiple.",
        _projectLead,
        address(0)
      )
    );
    vm.prank(address(0));
    _dim.increaseCurrentMultipleInstantly(1);

    // vm.expectRevert(bytes("The new multiple was not larger than the old multiple."));
    vm.expectRevert(
      abi.encodeWithSignature(
        "CanOnlyIncreaseMultiple(string,uint256,uint256)",
        "New multiple not larger than old multiple.",
        2,
        1
      )
    );
    vm.prank(_projectLead);
    _dim.increaseCurrentMultipleInstantly(1);
  }

  function testWithdraw() public override {
    // vm.expectRevert(bytes("Insufficient contract balance"));

    vm.expectRevert(
      abi.encodeWithSignature(
        "InsufficientContractBalanceForWithdraw(string,uint256,uint256)",
        "Insufficient contract balance for withdrawal.",
        address(_projectLead).balance,
        500 ether
      )
    );
    vm.prank(_projectLead);
    _dim.withdraw(500 ether);

    _dim.receiveInvestment{ value: 20 ether }();

    // vm.expectRevert(bytes("Withdraw attempted by someone other than project lead."));
    vm.expectRevert(
      abi.encodeWithSignature(
        "OnlyProjectLeadCanWithdraw(string,address,address)",
        "Only projectLead can withdraw.",
        address(this),
        _projectLead
      )
    );
    _dim.withdraw(1);
  }

  function testAllocateDoesNotAcceptZeroAmountAllocation() public override {
    vm.prank(_projectLead);
    // vm.expectRevert(bytes("The amount invested was not larger than 0."));
    vm.expectRevert(
      abi.encodeWithSignature("InvestmentAmountTooLow(string,uint256)", "Investment needs to be at least 1.", 0)
    );
    _exposedDim.allocateInvestment(0, payable(address(0)));
  }

  function testDifferenceInSAASPayoutAndCumulativeReturnThrowsError() public override {
    _saasPaymentProcessor = new SaasPaymentProcessor();

    uint256 saasRevenueForInvestors = 2;
    uint256 cumRemainingInvestorReturn0 = 0;

    vm.expectRevert(
      abi.encodeWithSignature(
        "CumulativePayoutMismatch(string,uint256,uint256)",
        "cumulativePayout (~+1) not equal to saasRevenueForInvestors",
        cumRemainingInvestorReturn0,
        saasRevenueForInvestors
      )
    );

    TierInvestment[] memory emptyTierInvestments = new TierInvestment[](0);
    (TierInvestment[] memory returnTiers, uint256[] memory returnAmounts) = _saasPaymentProcessor
      .computeInvestorReturns(_helper, emptyTierInvestments, saasRevenueForInvestors, cumRemainingInvestorReturn0);
    // Perform the allocations.
    uint256 nrOfTiers = returnTiers.length;
    for (uint256 i = 0; i < nrOfTiers; ++i) {
      vm.prank(address(_dim));
      _exposedDim.performSaasRevenueAllocation(returnAmounts[i], returnTiers[i].getInvestor());
    }

    // Perform the allocations.
    nrOfTiers = returnTiers.length;
    for (uint256 i = 0; i < nrOfTiers; ++i) {
      vm.prank(address(_dim));
      _exposedDim.performSaasRevenueAllocation(returnAmounts[i], returnTiers[i].getInvestor());
    }
  }

  function testPerformSaasRevenueAllocation() public override {
    _saasPaymentProcessor = new SaasPaymentProcessor();
    _helper = new Helper();

    uint256 amountAboveContractBalance = 1;
    address receivingWallet = address(0);

    vm.prank(address(_dim));
    // vm.expectRevert(bytes("Error: Insufficient contract balance."));
    vm.expectRevert(
      abi.encodeWithSignature(
        "NotEnoughBalanceToAllocateSaasRevenue(string,uint256,uint256)",
        "Insufficient contract balance.",
        address(_dim).balance,
        amountAboveContractBalance // amount
      )
    );
    _exposedDim.performSaasRevenueAllocation(amountAboveContractBalance, receivingWallet);

    vm.prank(address(_dim));
    // vm.expectRevert(bytes("The SAAS revenue allocation amount was not larger than 0."));
    vm.expectRevert(
      abi.encodeWithSignature(
        "CannotAllocateLessSAASThanOne(string,uint256)",
        "SAAS revenue allocation smaller than 1",
        0
      )
    );
    _exposedDim.performSaasRevenueAllocation(0, receivingWallet);
  }

  function testPerformSaasRevenueAllocationToNonPayee() public override {
    _saasPaymentProcessor = new SaasPaymentProcessor();
    _helper = new Helper();

    address receivingWallet = address(0);
    deal(address(_exposedDim), 20);
    assertFalse(_exposedDim.getPaymentSplitter().isPayee(receivingWallet));
    _exposedDim.performSaasRevenueAllocation(10, receivingWallet);
  }
}

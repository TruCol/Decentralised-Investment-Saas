// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "forge-std/src/console2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/src/Vm.sol" as vm;
import { PRBTest } from "@prb/test/src/PRBTest.sol";
import { StdCheats } from "forge-std/src/StdCheats.sol";

import { DecentralisedInvestmentManager } from "../../../../src/DecentralisedInvestmentManager.sol";
import { Helper } from "../../../../src/Helper.sol";
import { TestMathHelper } from "test/TestMathHelper.sol";
import { TestInitialisationHelper } from "../../../TestInitialisationHelper.sol";
import { TestFileLogging } from "../../../TestFileLogging.sol";
import { IterableMapping } from "../../../IterableMapping.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "test/TestConstants.sol";

/**
Stores the counters used to track how often the different branches of the tests are covered.*/
struct HitRatesReturnAll {
  uint256 didNotreachInvestmentCeiling;
  uint256 didReachInvestmentCeiling;
  uint256 validInitialisations;
  uint256 validInvestments;
  uint256 invalidInitialisations;
  uint256 invalidInvestments;
  uint256 investmentOverflow;
}

interface IFuzzDebug {
  function setUp() external;

  function testRandomNrOfInvestments(
    address projectLead,
    uint256 projectLeadFracNumerator,
    uint256 projectLeadFracDenominator,
    uint256 investmentTarget,
    uint32 additionalWaitPeriod,
    uint32 raisePeriod,
    uint8 randNrOfInvestmentTiers,
    uint8 randNrOfInvestments,
    uint256[_MAX_NR_OF_TIERS] memory randomCeilings,
    uint8[_MAX_NR_OF_TIERS] memory randomMultiples,
    uint256[_MAX_NR_OF_INVESTMENTS] memory randomInvestments
  ) external;
}

contract FuzzDebug is PRBTest, StdCheats, IFuzzDebug {
  using IterableMapping for IterableMapping.Map;
  IterableMapping.Map private _map;

  address internal _projectLead;
  TestInitialisationHelper private _testInitialisationHelper;
  TestFileLogging private _testFileLogging;
  Helper private _helper;
  TestMathHelper private _testMathHelper;

  /** @dev Creates an empty struct with the counters for each test case set to 0. */
  // solhint-disable-next-line foundry-test-functions
  function _updateHitRates(HitRatesReturnAll memory hitRates) internal {
    _map.set("didNotreachInvestmentCeiling", hitRates.didNotreachInvestmentCeiling);
    _map.set("didReachInvestmentCeiling", hitRates.didReachInvestmentCeiling);
    _map.set("validInitialisations", hitRates.validInitialisations);
    _map.set("validInvestments", hitRates.validInvestments);
    _map.set("invalidInitialisations", hitRates.invalidInitialisations);
    _map.set("invalidInvestments", hitRates.invalidInvestments);
    _map.set("investmentOverflow", hitRates.investmentOverflow);
  }

  function setUp() public virtual override {
    _helper = new Helper();
    _testInitialisationHelper = new TestInitialisationHelper();
    _testFileLogging = new TestFileLogging();
    _testMathHelper = new TestMathHelper();

    // Delete the temp file.
    if (vm.isFile(_LOG_TIME_CREATOR)) {
      vm.removeFile(_LOG_TIME_CREATOR);
    }
  }

  /**
  @dev The investor has invested 0.5 eth, and the investment target is 0.6 eth after 12 weeks.
  So the investment target is not reached, so all the funds should be returned.
   */
  function testRandomNrOfInvestments(
    address projectLead,
    uint256 projectLeadFracNumerator,
    uint256 projectLeadFracDenominator,
    uint256 investmentTarget,
    uint32 additionalWaitPeriod,
    uint32 raisePeriod,
    uint8 randNrOfInvestmentTiers,
    uint8 randNrOfInvestments,
    uint256[_MAX_NR_OF_TIERS] memory randomCeilings,
    uint8[_MAX_NR_OF_TIERS] memory randomMultiples,
    uint256[_MAX_NR_OF_INVESTMENTS] memory randomInvestments
  ) public virtual override {
    // Declare variables used for initialisation of the dim contract.
    uint8[] memory multiples;
    uint256[] memory sameNrOfCeilings;
    uint256[] memory investmentAmounts;

    // Initialise map with using a HitRatesReturnAll struct with 0 as values.
    _updateHitRates({
      hitRates: HitRatesReturnAll({
        didNotreachInvestmentCeiling: 0,
        didReachInvestmentCeiling: 0,
        validInitialisations: 0,
        validInvestments: 0,
        invalidInitialisations: 0,
        invalidInvestments: 0,
        investmentOverflow: 0
      })
    });
    // Export/initialise the hitrates to file, if the file does not exist, then read out the file with the HitRates.
    (string memory hitRateFilePath, bytes memory data) = _testFileLogging.updateLogFile(
      _map.getKeys(),
      _map.getValues()
    );
    // Unpack HitRate data from file into HitRatesReturnAll object.
    HitRatesReturnAll memory updatedHitrates = abi.decode(data, (HitRatesReturnAll));
    // Update the hit rate mapping using the HitRatesReturnAll object.
    _updateHitRates({ hitRates: updatedHitrates });

    // Get a random number of random multiples and random ceilings by cutting off the random arrays of fixed length.
    (multiples, sameNrOfCeilings) = _testInitialisationHelper.getRandomMultiplesAndCeilings({
      randomCeilings: randomCeilings,
      randomMultiples: randomMultiples,
      randNrOfInvestmentTiers: randNrOfInvestmentTiers
    });

    investmentAmounts = _testMathHelper.getShortenedArray({
      someArray: randomInvestments,
      nrOfDesiredElements: randNrOfInvestments
    });
    if (!_testMathHelper.sumOfNrsThrowsOverFlow({ numbers: investmentAmounts })) {
      // Map the investment target to the range (0, maximum(Ceilings)) to ensure the investment target can be reached.
      investmentTarget = (investmentTarget % sameNrOfCeilings[sameNrOfCeilings.length - 1]) + 1;

      // Initialise the dim contract, if the random parameters are invalid, an non-random dim is initialised for typing.
      (bool hasInitialisedRandomDim, DecentralisedInvestmentManager someDim) = _testInitialisationHelper
        .initialiseRandomDim({
          projectLead: projectLead,
          projectLeadFracNumerator: projectLeadFracNumerator,
          projectLeadFracDenominator: projectLeadFracDenominator,
          raisePeriod: raisePeriod,
          investmentTarget: investmentTarget,
          ceilings: sameNrOfCeilings,
          multiples: multiples
        });

      // Check if the initialised dim is random or non-random value.
      if (hasInitialisedRandomDim) {
        _map.set("validInitialisations", _map.get("validInitialisations") + 1);

        // Check if one is able to safely make the random number of investments safely.
        (uint256 successCount, uint256 failureCount) = _testInitialisationHelper.performRandomInvestments({
          dim: someDim,
          investmentAmounts: investmentAmounts
        });

        if (failureCount == 0) {
          // Compute cumulative investment.
          uint256 cumInvestmentAmount = _testMathHelper.computeSumOfArray({ numbers: investmentAmounts });

          // Store that this random run was for a valid investment, (track it to export it later).
          _map.set("validInvestments", _map.get("validInvestments") + 1);

          // Call the actual function that performs the test on the initialised dim contract.
          _followUpTriggerReturnAll({
            dim: someDim,
            projectLead: projectLead,
            cumInvestmentAmount: cumInvestmentAmount,
            investmentTarget: investmentTarget,
            additionalWaitPeriod: additionalWaitPeriod,
            raisePeriod: raisePeriod,
            maxTierCeiling: sameNrOfCeilings[sameNrOfCeilings.length - 1]
          });
        } else {
          _map.set("invalidInvestments", _map.get("invalidInvestments") + 1);
        }
      } else {
        // Store that this random run did not permit a valid dim initialisation.
        _map.set("invalidInitialisations", _map.get("invalidInitialisations") + 1);
      }
    } else {
      _map.set("investmentOverflow", _map.get("investmentOverflow") + 1);
    }
    emit Log("Outputting File");
    string memory serialisedTextString = _testFileLogging.convertHitRatesToString(_map.getKeys(), _map.getValues());
    _testFileLogging.overwriteFileContent(serialisedTextString, hitRateFilePath);
    emit Log("Outputted File");
  }

  /**
  Tests whether the triggerReturnAll() function returns all funds from the dim contract if the investment ceiling is
  reached. Otherwise it verifies the triggerReturnAll() function throws an error saying the investment target is
  reached.

  To ensure the funds can be returned, the vm automatically simulates a fast forward of the time to beyond the raise
  period.
  @dev This is the actual test that this file executes. */
  // solhint-disable-next-line foundry-test-functions
  function _followUpTriggerReturnAll(
    DecentralisedInvestmentManager dim,
    address projectLead,
    uint256 investmentTarget,
    uint256 cumInvestmentAmount,
    uint32 additionalWaitPeriod,
    uint32 raisePeriod,
    uint256 maxTierCeiling // HitRatesReturnAll memory hitRates
  ) internal {
    if (cumInvestmentAmount >= investmentTarget) {
      // Track that the investment ceiling was reached.
      _map.set("didReachInvestmentCeiling", _map.get("didReachInvestmentCeiling") + 1);

      // Only the projectLead can trigger the return of all funds.
      vm.prank(projectLead);

      // For testing purposes, time is simulated to beyond the raise period. Another test will test calls before the raise period.
      // solhint-disable-next-line not-rely-on-time
      vm.warp(block.timestamp + raisePeriod + additionalWaitPeriod);

      // If the investment target is reached, the funds should not be returnable, because the project lead should
      // ensure the work is done to retrieve the funds.
      vm.expectRevert(
        abi.encodeWithSignature(
          "InvestmentTargetReached(string,uint256,uint256)",
          "Investment target reached!",
          _helper.minimum(maxTierCeiling, cumInvestmentAmount),
          investmentTarget
        )
      );
      dim.triggerReturnAll();
    } else {
      // Track that the investment ceiling was not reached by the randnom values.
      _map.set("didNotreachInvestmentCeiling", _map.get("didNotreachInvestmentCeiling") + 1);

      // TODO: Verify the dim contract contains the investment funds.

      vm.prank(projectLead);
      // solhint-disable-next-line not-rely-on-time
      vm.warp(block.timestamp + raisePeriod + additionalWaitPeriod);
      dim.triggerReturnAll();

      // Verify the funds from the dim contract were not in the dim contract anymore.
      assertEq(address(dim).balance, 0 ether, "The dim did not contain 0 ether after returning all investments.");

      // TODO: verify the investors have retrieved their investments.
    }
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23;

import { Tier } from "../../src/Tier.sol";
import { DecentralisedInvestmentManager } from "../../src/DecentralisedInvestmentManager.sol";
import "forge-std/src/console2.sol"; // Import the console library

// interface Interface {
// function allocateInvestment() external;
// }

contract ExposedDecentralisedInvestmentManager is DecentralisedInvestmentManager {
  constructor(
    Tier[] memory tiers,
    uint256 projectLeadFracNumerator,
    uint256 projectLeadFracDenominator,
    address projectLeadAddress,
    uint32 _raisePeriod,
    uint256 _investmentTarget
  )
    public
    DecentralisedInvestmentManager(
      tiers,
      projectLeadFracNumerator,
      projectLeadFracDenominator,
      projectLeadAddress,
      _raisePeriod,
      _investmentTarget
    )
  {
    // Additional logic for ExposedDecentralisedInvestmentManager if needed
  }

  function allocateInvestment(uint256 investmentAmount, address investorWallet) public {
    return _allocateInvestment(investmentAmount, investorWallet);
  }

  function performSaasRevenueAllocation(uint256 amount, address receivingWallet) public {
    return _performSaasRevenueAllocation(amount, receivingWallet);
  }
}

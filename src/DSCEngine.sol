// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title DSCEngine
 * @author Bohr
 * The system is designed to be as minimal as possible, and have the tonkens maintain a 
 * 1 token = $1 peg.
 * This stablecoin has the properties:
 * - Exogenous Collateral
 * - Dollar Pegged
 * - Algoritmically Stable
 * 
 * It is similar to DAI if DAI had no governance, no fees, and was only backed by wETH and wBTC
 * 
 * Our DSC system should always be "overcollateralized". At no point, should the value of all collateral <= the $ backed balue of all the DSC.
 * 
 * @notice This contract is the core of the DSC System. It handles all the logic for minting and 
 * redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is VERY loosely based on the MakerDAO DSS (DAI) system.
*/
contract DSCEngine {
    
    // at here, we can also create a interface for DSCEngine
    
    function depositCollateralAndMintDsc() external {}

    function depositCollateral() external {}

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    function mintDsc() external {}

    // When collateral is going to liquidate, but borrower have no enough DAI to redeem collateral, then the borrower can use this function
    // to pay some DSC back, make the liquidate threshold higher
    function burnDsc() external {}

    function liquidate() external {}

    function gethealthFactor() external view {}

}
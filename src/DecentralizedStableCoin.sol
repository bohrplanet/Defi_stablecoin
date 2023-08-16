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

import {ERC20Burnable, ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/*
 * @title DecentralizedStableCoin
 * @author Bohr
 * Collateral: Exogenous (ETH & BTC)
 * Minting: Algorithmic
 * Relative Stablility: Pegged to USD
 *
 * This is the contract meant to be governed by ESCEngine. This contract is just ERC20
 * implementation of our stablecoin system.
 *
 */
contract DecentralizedStableCoin is ERC20Burnable {
    constructor() ERC20("DecentralizedStableCoin", "DSC") {}
}

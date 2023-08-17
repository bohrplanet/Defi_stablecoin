// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
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

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

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
contract DSCEngine is ReentrancyGuard {
    ////////////////////
    // Errors         //
    ////////////////////
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressMustBeSameLength(
        uint256 tokenAddressesLength, uint256 priceFeedAddressLength
    );
    error DSCEngine__TokenNotAllowed(address token);
    error DSCEngine__TransferFailed();

    ////////////////////
    // State Variables//
    ////////////////////
    // use mapping to remember the accepted token is Chainlink price feed address
    mapping(address token => address token_Price_Feed) private s_priceFeeds;

    // 2D mapping to remember user's collateral
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;

    DecentralizedStableCoin private immutable i_dsc;

    ////////////////////
    // Events         //
    ////////////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    ////////////////////
    // Modifiers      //
    ////////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    // only accept wETH and wBTC
    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__TokenNotAllowed(token);
        }
        _;
    }

    ////////////////////
    // Functions      //
    ////////////////////
    // Since different Chain will have different contract address, so we need tell this contract
    // what our token address is, we can complete this function using Script, then no matter which EVM chain
    // this contract is deployed on, it can be deployed directly
    constructor(
        address[] memory tokenAddresses, // Accepted token address
        address[] memory priceFeedsAddresses, // Accepted token Chainlink Price Feed address
        address dscTokenAddress // Our stable coin address
    ) ReentrancyGuard() {
        if (tokenAddresses.length != priceFeedsAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressMustBeSameLength(
                tokenAddresses.length, priceFeedsAddresses.length
            );
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedsAddresses[i];
        }

        // DecentralizedStableCoin(dscTokenAddress) is different from new DecentralizedStableCoin(dscTokenAddress)
        // DecentralizedStableCoin(dscTokenAddress) looks like type casting, tell EVM dscTokenAddress is a DecentralizedStableCoin contract,
        // This contract import a DecentralizedStableCoin contract which already deployed, dscTokenAddress is the address of this contract.
        // new DecentralizedStableCoin(dscTokenAddress) is deploy a new DecentralizedStableCoin contract
        i_dsc = DecentralizedStableCoin(dscTokenAddress);
    }

    /////////////////////////////
    // External Functions      //
    /////////////////////////////
    function depositCollateralAndMintDsc() external {}

    /**
     * @notice follows CEI checks effict interaction
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     * When the contract need interact with other contract, need add nonReentrant modifier
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;

        // emit when statua updated
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);

        // get the collateral token from meg.sender
        // Since the collateral token is a ERC20 token, that means it must implement IERC20 interface
        // so we can invoke IERC20 function, in this case is transferFrom function
        // Remember, when we have contract address, and contract function name(ABI), then we can call any function we want!
        // In this case, we know collateral token is ERC20 token, and we know token address, it is enough to call!
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    /**
     * @notice follows CEI check, effect, interact
     * @param amountDscToMint The amount of decentralized stablecoin to mint
     * 
    */
    function mintDsc(uint256 amountDscToMint) external moreThanZero(amountDscToMint) nonReentrant {

    }

    // When collateral is going to liquidate, but borrower have no enough DAI to redeem collateral, then the borrower can use this function
    // to pay some DSC back, make the liquidate threshold higher
    function burnDsc() external {}

    function liquidate() external {}

    function gethealthFactor() external view {}
}

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
import {AggregatorV3Interface} from
    "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

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
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();

    ////////////////////
    // State Variables//
    ////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    // use mapping to remember the accepted token is Chainlink price feed address
    mapping(address token => address token_Price_Feed) private s_priceFeeds;

    // 2D mapping to remember user's collateral
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    ////////////////////
    // Events         //
    ////////////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed user, address indexed token, uint256 indexed amount);

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
            s_collateralTokens.push(tokenAddresses[i]);
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

    /**
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     * @param amountDscToMint the amount of decentralized stablecoin to mint
     * @notice this function will deposit your collateral and mint DSC in one transtraction
     */
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /**
     * @notice follows CEI checks effict interaction
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     * When the contract need interact with other contract, need add nonReentrant modifier
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
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




    // in order to redeem collaterl:
    // 1. health factor must be over 1 AFTER collateral pulled
    // follows CEI
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral) external moreThanZero(amountCollateral) nonReentrant{

        // new version Solidity will help dev to check unsafe math
        s_collateralDeposited[msg.sender][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(msg.sender, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice follows CEI check, effect, interact
     * @param amountDscToMint The amount of decentralized stablecoin to mint
     *
     */
    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;

        // if user minted too much, revert
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    // When collateral is going to liquidate, but borrower have no enough DAI to redeem collateral, then the borrower can use this function
    // to pay some DSC back, make the liquidate threshold higher
    function burnDsc(uint256 amount) external moreThanZero(amount){

        s_DSCMinted[msg.sender] -= amount;
        bool success = i_dsc.transferFrom(msg.sender, address(this), amount);
        // This condition is hypothtically unreachable
        if (!success) {
            revert DSCEngine__TransferFailed();
        }

        // We know that only the owner of DCS contract can call burn function
        // At here, the user call this contract's burnDsc function, and DSCEngine contract call DSC's burn function
        // DSCEngine is the owner of DSC contract, so it is OK to call the burn function
        i_dsc.burn(amount);
    }

    function liquidate() external {}

    function gethealthFactor() external view {}

    ///////////////////////////////////////
    // Private & Internal view Functions //
    ///////////////////////////////////////

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValueInUsd(user);
    }

    /**
     * Returns how close to liquidation a user is
     * If a user gose below 1, then they can get liquidated
     */
    function _healthFactor(address user) private view returns (uint256) {
        // total DSC minted
        // total collateral VALUE
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        // return (collateralValueInUsd  / totalDscMinted);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        // Really be careful about the decimal, remember Solidity can not handle double type
        // So if we find that a value maybe more than 1, and small than 0, then we can multiply 1e18
        // in this case, collateralAdjustedForThreshold is a uint256, and totalDscMinted is also uint256
        // so we nned multiply 1e18 to keep the presicion
        return (collateralAdjustedForThreshold * PRECISION / totalDscMinted);
    }

    // 1. Check health factor (d othey have enough collateral?)
    // 2. Revert if they don't
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    ///////////////////////////////////////
    // Public & External view Functions  //
    ///////////////////////////////////////
    function getAccountCollateralValueInUsd(address user) public view returns (uint256 totalCollateralValueInUsd) {
        // loop through each collateral token, get the amount user have deposited, and map it to
        // the price, to get the USD value
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // 1 ETH = $1000
        // The returned value from Chainlink will be 1000 * 1e8
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION; // (1000 * 1e8 * (1e10)) * 1000 * 1e18;
    }
}

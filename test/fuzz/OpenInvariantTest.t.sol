// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.19;

// // Have our invariant aka properties

// // invariants

// // 1. The total supply of DSC should be less than the total value of collateral
// // 2. Getter view functions should never revert

// import {Test, console} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {DeployDSC} from "../../script/DeployDSC.s.sol";
// import {DSCEngine} from "../../src/DSCEngine.sol";
// import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// contract InvariantsTest is StdInvariant, Test {
//     DeployDSC deployer;
//     DSCEngine dsce;
//     DecentralizedStableCoin dsc;
//     HelperConfig config;
//     address weth;
//     address wbtc;

//     function setUp() external {
//         deployer = new DeployDSC();
//         (dsc, dsce, config) = deployer.run();
//         (,, weth, wbtc,) = config.activeNetworkConfig();
//         targetContract(address(dsce));
//     }

//     // So, the sequence to test this case is this test will go to target contract, and randomly call the functions in target contract X time, and every time,
//     // it will call Y times functions, then call invariant_protocolMustHaveMoreValueThanTotalSupply function, and run the logic in this function,
//     // finally, run assert function.
//     // So we will see lots of reverts, because when this test call target contract functions, it will use some random parameter, for example,
//     // a function need a address, it should be a token address, but this test used a random address, so this function reverted.
//     function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
//         // get the value of all the collateral in the protocol
//         // compare it to all the debt (dsc)
//         uint256 totalSupply = dsc.totalSupply();
//         uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsce));
//         uint256 totalBtcDeposited = IERC20(wbtc).balanceOf(address(wbtc));

//         uint256 wethValue = dsce.getUsdValue(weth, totalWethDeposited);
//         uint256 wbtcValue = dsce.getUsdValue(wbtc, totalBtcDeposited);

//         console.log("weth value:", wethValue);
//         assert(wethValue + wbtcValue >= totalSupply);
//     }
// }

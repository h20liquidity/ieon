// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Vm} from "forge-std/Vm.sol";
import {IRouteProcessor} from "src/interface/IRouteProcessor.sol"; 
import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    IOrderBookV3,
    IO,
    OrderV2,
    OrderConfigV2,
    TakeOrderConfigV2,
    TakeOrdersConfigV2
} from "rain.orderbook/src/interface/unstable/IOrderBookV3.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

// Strategy Params
uint256 constant TRANCHE_RESERVE_BASE_AMOUNT = 1000e18 ;
uint256 constant TRANCHE_RESERVE_BASE_IO_RATIO = 315e18;
uint256 constant SPREAD_RATIO = 101e16;
uint256 constant TRANCHE_EDGE_THRESHOLD = 2e17;
uint256 constant INITIAL_TRANCHE_SPACE = 0;
uint256 constant TRANCHE_SPACE_SNAP_THRESHOLD = 1e12;


/// @dev https://polygonscan.com/address/0xE7eb31f23A5BefEEFf76dbD2ED6AdC822568a5d2
IRouteProcessor constant ROUTE_PROCESSOR = IRouteProcessor(address(0xE7eb31f23A5BefEEFf76dbD2ED6AdC822568a5d2));

uint256 constant VAULT_ID = uint256(keccak256("vault"));

// IEON token holder.
address constant POLYGON_IEON_HOLDER = 0xd6756f5aF54486Abda6bd9b1eee4aB0dBa7C3ef2;
// USDT token holder.
address constant POLYGON_USDT_HOLDER = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
// Wrapped native token holder.
address constant POLYGON_WETH_HOLDER = 0xbAd24a42b621eED9033409736219c01bF0d8500F;

address constant POLYGON_IEON_ADMIN = 0x3a7bD65AB95678eB2A3a8d37962E89f42a6968c7;


/// @dev https://polygonscan.com/address/0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32
address constant UNI_V2_FACTORY = 0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32;

/// @dev https://polygonscan.com/address/0xd0e9c8f5Fae381459cf07Ec506C1d2896E8b5df6
IERC20 constant IEON_TOKEN = IERC20(0xd0e9c8f5Fae381459cf07Ec506C1d2896E8b5df6);

/// @dev https://polygonscan.com/address/0xc2132D05D31c914a87C6611C10748AEb04B58e8F
IERC20 constant USDT_TOKEN = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);

/// @dev https://polygonscan.com/address/0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270
IERC20 constant WETH_TOKEN = IERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

/// @dev https://docs.sushi.com/docs/Products/Classic%20AMM/Deployment%20Addresses
address constant POLYGON_SUSHI_V2_ROUTER = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;

function getUniV3TradeSellRoute(address toAddress) pure returns (bytes memory){
    bytes memory ROUTE_PRELUDE =
    hex"02d0e9c8f5fae381459cf07ec506c1d2896e8b5df601ffff00316bc12871c807020ef8c1bc7771061c4e7a04ed00";
    return abi.encode(bytes.concat(ROUTE_PRELUDE, abi.encodePacked(toAddress)));
}

function getUniV3TradeBuyRoute(address toAddress)  pure returns (bytes memory){
    bytes memory ROUTE_PRELUDE = 
    hex"020d500b1d8e8ef31e21c99d1db9a6444d3adf127001ffff00316bc12871c807020ef8c1bc7771061c4e7a04ed01";
    return abi.encode(bytes.concat(ROUTE_PRELUDE, abi.encodePacked(toAddress)));    
}

function polygonIeonIo() pure returns (IO memory) {
    return IO(address(IEON_TOKEN), 18, VAULT_ID);
}

function polygonWethIo() pure returns (IO memory) {
    return IO(address(WETH_TOKEN), 18, VAULT_ID);
}

library LibTrancheSpreadOrders {
    using Strings for address;
    using Strings for uint256;


    function getTrancheTestSpreadOrder(
        Vm vm,
        address orderBookSubparser,
        uint256 testTrancheSpace,
        uint256 spreadRatio
    )
        internal
        returns (bytes memory trancheRefill)
    {
        string[] memory ffi = new string[](35);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "lib/h20.pubstrats/src/tranche-spread.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "calculate-io";
        ffi[7] = "--entrypoint";
        ffi[8] = "handle-io";
        ffi[9] = "--bind";
        ffi[10] = "distribution-token=0xd0e9c8f5Fae381459cf07Ec506C1d2896E8b5df6";
        ffi[11] = "--bind";
        ffi[12] = "reserve-token=0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
        ffi[13] = "--bind";
        ffi[14] = "get-tranche-space='get-test-tranche-space";
        ffi[15] = "--bind";
        ffi[16] = "set-tranche-space='set-test-tranche-space";
        ffi[17] = "--bind";
        ffi[18] = string.concat("test-tranche-space=", testTrancheSpace.toString());
        ffi[19] = "--bind";
        ffi[20] = "tranche-reserve-amount-growth='tranche-reserve-amount-growth-constant";
        ffi[21] = "--bind";
        ffi[22] = string.concat("tranche-reserve-amount-base=", TRANCHE_RESERVE_BASE_AMOUNT.toString());
        ffi[23] = "--bind";
        ffi[24] = "tranche-reserve-io-ratio-growth='tranche-reserve-io-ratio-linear";
        ffi[25] = "--bind";
        ffi[26] = string.concat("tranche-reserve-io-ratio-base=", TRANCHE_RESERVE_BASE_IO_RATIO.toString());
        ffi[27] = "--bind";
        ffi[28] = string.concat("spread-ratio=", spreadRatio.toString());
        ffi[29] = "--bind";
        ffi[30] = string.concat("tranche-space-edge-guard-threshold=", TRANCHE_EDGE_THRESHOLD.toString());
        ffi[31] = "--bind";
        ffi[32] = string.concat("initial-tranche-space=", INITIAL_TRANCHE_SPACE.toString());
        ffi[33] = "--bind";
        ffi[34] = string.concat("tranche-space-snap-threshold=", TRANCHE_SPACE_SNAP_THRESHOLD.toString());
        
        
        trancheRefill = bytes.concat(getSubparserPrelude(orderBookSubparser), vm.ffi(ffi));
    }

    function getTrancheSpreadOrder(
        Vm vm,
        address orderBookSubparser
    )
        internal
        returns (bytes memory trancheRefill)
    {
        string[] memory ffi = new string[](33);
        ffi[0] = "rain";
        ffi[1] = "dotrain";
        ffi[2] = "compose";
        ffi[3] = "-i";
        ffi[4] = "lib/h20.pubstrats/src/tranche-spread.rain";
        ffi[5] = "--entrypoint";
        ffi[6] = "calculate-io";
        ffi[7] = "--entrypoint";
        ffi[8] = "handle-io";
        ffi[9] = "--bind";
        ffi[10] = "distribution-token=0xd0e9c8f5Fae381459cf07Ec506C1d2896E8b5df6";
        ffi[11] = "--bind";
        ffi[12] = "reserve-token=0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
        ffi[13] = "--bind";
        ffi[14] = "get-tranche-space='get-real-tranche-space";
        ffi[15] = "--bind";
        ffi[16] = "set-tranche-space='set-real-tranche-space";
        ffi[17] = "--bind";
        ffi[18] = "tranche-reserve-amount-growth='tranche-reserve-amount-growth-constant";
        ffi[19] = "--bind";
        ffi[20] = string.concat("tranche-reserve-amount-base=", TRANCHE_RESERVE_BASE_AMOUNT.toString());
        ffi[21] = "--bind";
        ffi[22] = "tranche-reserve-io-ratio-growth='tranche-reserve-io-ratio-linear";
        ffi[23] = "--bind";
        ffi[24] = string.concat("tranche-reserve-io-ratio-base=", TRANCHE_RESERVE_BASE_IO_RATIO.toString());
        ffi[25] = "--bind";
        ffi[26] = string.concat("spread-ratio=", SPREAD_RATIO.toString());
        ffi[27] = "--bind";
        ffi[28] = string.concat("tranche-space-edge-guard-threshold=", TRANCHE_EDGE_THRESHOLD.toString());
        ffi[29] = "--bind";
        ffi[30] = string.concat("initial-tranche-space=", INITIAL_TRANCHE_SPACE.toString());
        ffi[31] = "--bind";
        ffi[32] = string.concat("tranche-space-snap-threshold=", TRANCHE_SPACE_SNAP_THRESHOLD.toString());
        
        
        trancheRefill = bytes.concat(getSubparserPrelude(orderBookSubparser), vm.ffi(ffi));
    }

    function getSubparserPrelude(address obSubparser) internal pure returns (bytes memory) {
        bytes memory RAINSTRING_OB_SUBPARSER =
            bytes(string.concat("using-words-from ", obSubparser.toHexString(), " "));
        return RAINSTRING_OB_SUBPARSER;
    }
}


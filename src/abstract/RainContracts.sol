// SPDX-License-Identifier: CAL
pragma solidity ^0.8.19;

import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {RainterpreterParserNPE2} from "rain.orderbook/lib/rain.interpreter/src/concrete/RainterpreterParserNPE2.sol";
import {RainterpreterStoreNPE2} from "rain.orderbook/lib/rain.interpreter/src/concrete/RainterpreterStoreNPE2.sol";
import {RainterpreterNPE2} from "rain.orderbook/lib/rain.interpreter/src/concrete/RainterpreterNPE2.sol";
import {
    RainterpreterExpressionDeployerNPE2,
    RainterpreterExpressionDeployerNPE2ConstructionConfig
} from "rain.orderbook/lib/rain.interpreter/src/concrete/RainterpreterExpressionDeployerNPE2.sol";
import {IParserV1} from "rain.orderbook/lib/rain.interpreter/src/interface/IParserV1.sol";
import {IInterpreterStoreV1} from "rain.orderbook/lib/rain.interpreter/src/interface/IInterpreterStoreV1.sol";
import {IInterpreterStoreV2} from "rain.orderbook/lib/rain.interpreter/src/interface/unstable/IInterpreterStoreV2.sol";
import {
    IInterpreterV2,
    SourceIndexV2
} from "rain.orderbook/lib/rain.interpreter/src/interface/unstable/IInterpreterV2.sol";
import {IExpressionDeployerV3} from
    "rain.orderbook/lib/rain.interpreter/src/interface/unstable/IExpressionDeployerV3.sol";
import {OrderBook} from "rain.orderbook/src/concrete/ob/OrderBook.sol";
import {ISubParserV2} from "rain.orderbook/lib/rain.interpreter/src/interface/unstable/ISubParserV2.sol";
import {OrderBookSubParser} from "rain.orderbook/src/concrete/parser/OrderBookSubParser.sol";
import {UniswapWords} from "rain.uniswap/src/concrete/UniswapWords.sol";
import {RouteProcessorOrderBookV3ArbOrderTaker} from
    "rain.orderbook/src/concrete/arb/RouteProcessorOrderBookV3ArbOrderTaker.sol";
import {IOrderBookV3ArbOrderTaker} from "rain.orderbook/src/interface/unstable/IOrderBookV3ArbOrderTaker.sol";
import {EvaluableConfigV3, SignedContextV1} from "rain.interpreter/interface/IInterpreterCallerV2.sol";
import {OrderBookV3ArbOrderTakerConfigV1} from "rain.orderbook/src/abstract/OrderBookV3ArbOrderTaker.sol";
import {ICloneableFactoryV2} from "src/interface/ICloneableFactoryV2.sol";
import {IOrderBookV3, ROUTE_PROCESSOR} from "src/TrancheMirror.sol";
import "rain.uniswap/src/lib/v3/LibDeploy.sol";

abstract contract RainContracts {
    IParserV1 public PARSER;
    IInterpreterV2 public INTERPRETER;
    IInterpreterStoreV2 public STORE;
    IExpressionDeployerV3 public EXPRESSION_DEPLOYER;
    IOrderBookV3 public ORDERBOOK;
    ISubParserV2 public ORDERBOOK_SUPARSER;
    ISubParserV2 public UNISWAP_WORDS;
    IOrderBookV3ArbOrderTaker public ARB_IMPLEMENTATION;
    IOrderBookV3ArbOrderTaker public ARB_INSTANCE;
    ICloneableFactoryV2 public CLONE_FACTORY;

    function deployParser() public {
        PARSER = new RainterpreterParserNPE2();
    }

    function deployStore() public {
        STORE = new RainterpreterStoreNPE2();
    }

    function deployInterpreter() public {
        INTERPRETER = new RainterpreterNPE2();
    }

    function deployExpressionDeployer(Vm vm, address interpreter, address store, address parser) public {
        bytes memory constructionMeta = vm.readFileBinary(
            "lib/rain.orderbook/lib/rain.interpreter/meta/RainterpreterExpressionDeployerNPE2.rain.meta"
        );

        EXPRESSION_DEPLOYER = new RainterpreterExpressionDeployerNPE2(
            RainterpreterExpressionDeployerNPE2ConstructionConfig(
                address(interpreter), address(store), address(parser), constructionMeta
            )
        );
    }

    function deployOrderBook() public {
        ORDERBOOK = new OrderBook();
    }

    function deployOrderBookSubparser() public {
        ORDERBOOK_SUPARSER = new OrderBookSubParser();
    }

    function deployUniswapWords(Vm vm) public {
        UNISWAP_WORDS = LibDeploy.newUniswapWords(vm);
    }

    function deployArbInstance(Vm vm, address cloneFactory) public {
        ARB_IMPLEMENTATION = new RouteProcessorOrderBookV3ArbOrderTaker();
        CLONE_FACTORY = ICloneableFactoryV2(cloneFactory);

        address ARB_INSTANCE_ADDRESS;
        {
            bytes memory ungatedArbExpression = "";
            (bytes memory bytecode, uint256[] memory constants) = PARSER.parse(ungatedArbExpression);
            bytes memory implementationData = abi.encode(address(ROUTE_PROCESSOR));
            EvaluableConfigV3 memory evaluableConfig = EvaluableConfigV3(EXPRESSION_DEPLOYER, bytecode, constants);
            OrderBookV3ArbOrderTakerConfigV1 memory cloneConfig =
                OrderBookV3ArbOrderTakerConfigV1(address(ORDERBOOK), evaluableConfig, implementationData);
            bytes memory encodedConfig = abi.encode(cloneConfig);

            vm.recordLogs();
            CLONE_FACTORY.clone(address(ARB_IMPLEMENTATION), encodedConfig);
            Vm.Log[] memory entries = vm.getRecordedLogs();
            for (uint256 j = 0; j < entries.length; j++) {
                if (entries[j].topics[0] == keccak256("NewClone(address,address,address)")) {
                    (,, ARB_INSTANCE_ADDRESS) = abi.decode(entries[j].data, (address, address, address));
                }
            }
            ARB_INSTANCE = IOrderBookV3ArbOrderTaker(ARB_INSTANCE_ADDRESS);
        }
    }
}

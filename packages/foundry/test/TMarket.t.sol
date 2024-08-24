// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./USDc.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/TMarket.sol";
import "CMTAT/contracts/CMTAT_PROXY.sol";
import "CMTAT/contracts/CMTAT_STANDALONE.sol";
import "CMTAT/contracts/deployment/CMTAT_TP_FACTORY.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TmarketTest is Test {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    CMTAT_PROXY mmproxy;
    CMTAT_TP_FACTORY cmtatTPFactory;

    TMarket public tMarket;

    address immutable factoryAdmin = vm.addr(1);
    address immutable proxyAdminOwner = vm.addr(10);
    address immutable tokenAdmin = vm.addr(2);
    address immutable forwarder = address(0);

    USDc public usdc;

    uint256 johnInitRightsBalance;
    uint256 janeInitRightsBalance;
    uint256 jakeInitRightsBalance;
    uint256 jillInitRightsBalance;

    uint256 johnInitUSDcBalance;
    uint256 janeInitUSDcBalance;
    uint256 jakeInitUSDcBalance;
    uint256 jillInitUSDcBalance;

    function setUp() public {
        usdc = new USDc();
        tMarket = new TMarket(address(usdc));

        cmtatTPFactory = new CMTAT_TP_FACTORY(
            address(new CMTAT_PROXY(forwarder)),
            factoryAdmin
        );


        johnInitRightsBalance = 300000;
        janeInitRightsBalance = 300000;
        jakeInitRightsBalance = 400000;
        jillInitRightsBalance = 200000;

        johnInitUSDcBalance = 1000000000;
        janeInitUSDcBalance = 1000000000;
        jakeInitUSDcBalance = 1000000000;
        jillInitUSDcBalance = 1000000000;
    }

    function testCreateRightsTokenAndMintAndTrade() public {
        //
        // lets create some accounts and give them some fake usdc
        //
        address john = vm.addr(3);
        vm.label(john, "john");
        vm.deal(john, 4410000);
        usdc.mint(john, johnInitUSDcBalance);

        address jane = vm.addr(4);
        vm.label(jane, "jane");
        vm.deal(jane, 4410000);
        usdc.mint(jane, janeInitUSDcBalance);

        address jake = vm.addr(5);
        vm.label(jake, "jake");
        vm.deal(jake, 4410000);
        usdc.mint(jake, jakeInitUSDcBalance);

        address jill = vm.addr(6);
        vm.label(jill, "jill");
        vm.deal(jill, 4410000);
        usdc.mint(jill, jillInitUSDcBalance);
        assertEq(johnInitUSDcBalance, usdc.balanceOf(john));

        //
        // Create The Rights Token
        //
        vm.prank(factoryAdmin);
        cmtatTPFactory.deployCMTAT(
            proxyAdminOwner,
            tokenAdmin,
            IAuthorizationEngine(address(0)),
            "Rights",
            "Rights",
            0,
            "Rights_Token_id",
            "url-to-terms",
            IRuleEngine(address(0)),
            "info",
            5 // whats that for?
        );

        CMTAT_PROXY rightsToken = CMTAT_PROXY(cmtatTPFactory.getAddress(0));
        address[] memory accounts = new address[](4);
        accounts[0] = john;
        accounts[1] = jane;
        accounts[2] = jake;
        accounts[3] = jill;
        // initialize values with 1000,000 Rights tokens
        uint256[] memory values = new uint256[](4);
        values[0] = johnInitRightsBalance;
        values[1] = janeInitRightsBalance;
        values[2] = jakeInitRightsBalance;
        values[3] = jillInitRightsBalance;

        vm.prank(tokenAdmin);
        rightsToken.mintBatch(accounts, values);

        // now lets shareholder be able to trade their in an OTC market
        // john wants to sell 100,000 rights tokens for $1 for each right totally $100,000
        // john fills rights disposal form
        vm.prank(john);
        rightsToken.approve(address(tMarket), 100000);
        assertEq(rightsToken.balanceOf(john), johnInitRightsBalance);

        uint256 rightsToSell = 10000;
        uint256 tradeValuePerUnit = 241;
        vm.prank(john);
        tMarket.createOrder(
            address(rightsToken),
            rightsToSell, //units
            tradeValuePerUnit, // trade value per unit
            block.timestamp + 100 days // expiration date
        );

        // assert we only have one rights disposal form
        assertEq(tMarket.orderCount(), 1);
        // john rights disposal form is listed
        TMarket.RightsDisposalOrder memory myOrder = tMarket.getOrder(0);
        assertEq(john, myOrder.seller);

        // jane wants to take johns offer, she clicks on the form

        // jane purchases the right
        vm.startPrank(jane);
        uint256 totalinUsdc = myOrder.tradeValuePerUnit * myOrder.units;
        usdc.approve(address(tMarket), totalinUsdc);
        tMarket.buyOrder(0);
        vm.stopPrank();

        // assert the rights token is transferred
        assertEq(rightsToken.balanceOf(jane), janeInitRightsBalance + rightsToSell);
        assertEq(rightsToken.balanceOf(john), johnInitRightsBalance - rightsToSell);

        // assert the usdc is transferred
        assertEq(usdc.balanceOf(jane), janeInitUSDcBalance - totalinUsdc);
        assertEq(usdc.balanceOf(john), johnInitUSDcBalance + totalinUsdc);

        // todo to do finish this test, assert the fight usdc and rights token are transferred
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {Vm} from "forge-std/Vm.sol";
import {DSTest} from "ds-test/test.sol";
import {ZoraNFTBase} from "../ZoraNFTBase.sol";
import {ZoraDAOFeeManager} from "../ZoraDAOFeeManager.sol";
import {DummyMetadataRenderer} from "./utils/DummyMetadataRenderer.sol";
import {MockUser} from "./utils/MockUser.sol";

contract ZoraNFTBaseTest is DSTest {
    ZoraNFTBase zoraNFTBase;
    MockUser mockUser;
    Vm public constant vm = Vm(HEVM_ADDRESS);
    DummyMetadataRenderer public dummyRenderer = new DummyMetadataRenderer();
    ZoraDAOFeeManager public feeManager;
    address public constant DEFAULT_OWNER_ADDRESS = address(0x23499);
    address payable public constant DEFAULT_FUNDS_RECIPIENT_ADDRESS =
        payable(address(0x21303));
    address payable public constant DEFAULT_ZORA_DAO_ADDRESS =
        payable(address(0x999));
    address public constant mediaContract = address(0x123456);

    modifier setupZoraNFTBase() {
        zoraNFTBase.initialize({
            _name: "Test NFT",
            _symbol: "TNFT",
            _owner: DEFAULT_OWNER_ADDRESS,
            _fundsRecipient: payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
            _editionSize: 10,
            _royaltyBPS: 800,
            _metadataRenderer: dummyRenderer
        });
        _;
    }

    function setUp() public {
        vm.prank(DEFAULT_ZORA_DAO_ADDRESS);
        feeManager = new ZoraDAOFeeManager(250);
        vm.prank(DEFAULT_ZORA_DAO_ADDRESS);
        zoraNFTBase = new ZoraNFTBase(feeManager, address(1234));
    }

    function test_Init() public setupZoraNFTBase {
        // require(
        //     zoraNFTBase.owner() == DEFAULT_OWNER_ADDRESS,
        //     "Default owner set wrong"
        // );
        vm.expectRevert("Initializable: contract is already initialized");
        zoraNFTBase.initialize({
            _name: "Test NFT",
            _symbol: "TNFT",
            _owner: DEFAULT_OWNER_ADDRESS,
            _fundsRecipient: payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
            _editionSize: 10,
            _royaltyBPS: 800,
            _metadataRenderer: dummyRenderer
        });
    }

    function test_UpdateContractURI() public setupZoraNFTBase {
        require(
            bytes(zoraNFTBase.contractURI()).length == 0,
            "Contract URI set by default"
        );
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.updateContractURI(
            "https://data.zora.co/beautiful-contract/data.json"
        );
        assertEq(
            zoraNFTBase.contractURI(),
            "https://data.zora.co/beautiful-contract/data.json",
            "Contract URI set by default"
        );
        vm.prank(address(39));
        vm.expectRevert("Only admin allowed");
        zoraNFTBase.updateContractURI(
            "https://data.zora.co/beautiful-contract/data.json"
        );
    }

    function test_Mint() public setupZoraNFTBase {
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSalePrice(0.1 ether);
        vm.deal(address(456), 1 ether);
        vm.prank(address(456));
        zoraNFTBase.purchase{value: 0.1 ether}(1);
        assertEq(zoraNFTBase.saleDetails().maxSupply, 10);
        assertEq(zoraNFTBase.saleDetails().totalMinted, 1);
        require(
            zoraNFTBase.ownerOf(1) == address(456),
            "owner is wrong for new minted token"
        );
    }

    function test_MintWrongValue() public setupZoraNFTBase {
        vm.deal(address(456), 1 ether);
        vm.prank(address(456));
        vm.expectRevert("Not for sale");
        zoraNFTBase.purchase{value: 0.12 ether}(1);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSalePrice(0.1 ether);
        vm.prank(address(456));
        vm.expectRevert("Wrong price");
        zoraNFTBase.purchase{value: 0.12 ether}(1);
    }

    function test_Withdraw() public setupZoraNFTBase {
        vm.deal(address(zoraNFTBase), 1 ether);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.withdraw();
        (, uint256 feeBps) = feeManager.getZORAWithdrawFeesBPS(
            address(zoraNFTBase)
        );
        assertEq(feeBps, 250);
        assertEq(DEFAULT_ZORA_DAO_ADDRESS.balance, 0.025 ether);
        assertEq(DEFAULT_FUNDS_RECIPIENT_ADDRESS.balance, 0.975 ether);
    }

    function test_WithdrawNotAllowed() public setupZoraNFTBase {
        vm.expectRevert("Does not have proper role or admin");
        zoraNFTBase.withdraw();
    }

    function test_AdminMint() public setupZoraNFTBase() {
      address minter = address(0x32402);
      vm.startPrank(DEFAULT_OWNER_ADDRESS);
      zoraNFTBase.mintEdition(DEFAULT_OWNER_ADDRESS);
      require(zoraNFTBase.balanceOf(DEFAULT_OWNER_ADDRESS) == 1, "Wrong balance");
      zoraNFTBase.grantRole(zoraNFTBase.MINTER_ROLE(), minter);
      vm.stopPrank();
      vm.prank(minter);
      zoraNFTBase.mintEdition(minter);
      require(zoraNFTBase.balanceOf(minter) == 1, "Wrong balance");
      assertEq(zoraNFTBase.saleDetails().totalMinted, 2);
    }

    function test_Burn() public setupZoraNFTBase() {
      address minter = address(0x32402);
      vm.prank(DEFAULT_OWNER_ADDRESS);
      zoraNFTBase.grantRole(zoraNFTBase.MINTER_ROLE(), minter);
      vm.startPrank(minter);
      zoraNFTBase.mintEdition(minter);
      
      vm.stopPrank();
    }
}

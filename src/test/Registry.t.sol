// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "../interfaces/IProposer.sol";
import "../libraries/Status.sol";
import "../Attest.sol";
import "../Proposer.sol";
import "../Registry.sol";
import "../Runtime.sol";
import "./mocks/Target.sol";
import "./mocks/Vm.sol";

contract RegistryTest is DSTest, Vm {
    Target public target = new Target();

    Runtime public runtime;
    Attest public erc20;
    Registry public registry;
    Proposer public proposer;

    function setUp() public {
        runtime = new Runtime();
        erc20 = new Attest("Token", "TOKEN", 18);
        registry = new Registry(address(runtime));
        proposer = new Proposer(address(runtime), address(erc20));

        runtime.allow(address(registry));
        proposer.allow(address(registry));
    }

    function setUpEmptyHeader() public pure returns (Header.Data memory) {
        Transaction.Data[] memory data = new Transaction.Data[](1);
        Header.Data memory header = Header.Data({
            data: data,
            title: "",
            description: ""
        });

        return header;
    }

    function setUpTargetHeader() public view returns (Header.Data memory) {
        Transaction.Data[] memory transactions = new Transaction.Data[](1);
        Header.Data memory header = Header.Data({
            data: transactions,
            title: "Update the target value",
            description: "This proposal updates the target value."
        });

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory datas = new bytes[](1);
        targets[0] = address(target);
        values[0] = 0;
        signatures[0] = "update(uint256)";
        datas[0] = abi.encode(uint256(1337));
        transactions[0] = Transaction.Data({
            targets: targets,
            values: values,
            signatures: signatures,
            datas: datas,
            message: "tweak: update target value 1337"
        });

        return header;
    }

    /**
     * `create`
     */

    function testCreate() public {
        address nft;
        uint96 id;

        registry.create(address(proposer), address(this), setUpEmptyHeader());
        (nft, id) = registry.registry(0);
        assertEq(nft, address(proposer));
        assertEq(id, 0);

        registry.create(address(proposer), address(this), setUpEmptyHeader());
        (nft, id) = registry.registry(1);
        assertEq(nft, address(proposer));
        assertEq(id, 1);
    }

    /**
     * `merge`
     */

    function testMerge() public {
        erc20.mint(address(this), 1e18);
        erc20.delegate(address(this));

        (uint256 tokenId, uint256 registryId) = registry.create(
            address(proposer),
            address(this),
            setUpEmptyHeader()
        );
        proposer.commit(tokenId, setUpTargetHeader());
        proposer.open(tokenId);
        mine(proposer.delay());
        assertEq(uint(proposer.status(tokenId)), uint(Status.Open));
        proposer.attest(tokenId, 0, 1e18, "");
        mine(proposer.get(tokenId).finality);
        assertEq(uint(proposer.status(tokenId)), uint(Status.Approved));
        registry.merge(registryId);
        assertEq(uint(proposer.status(tokenId)), uint(Status.Merged));
    }

    /**
     * `run`
     */

    function testRun() public {
        erc20.mint(address(this), 1e18);
        erc20.delegate(address(this));

        Header.Data memory header = setUpTargetHeader();
        (uint256 tokenId, uint256 registryId) = registry.create(
            address(proposer),
            address(this),
            header
        );
        proposer.open(tokenId);
        mine(proposer.delay());
        proposer.attest(tokenId, 0, 1e18, "");
        mine(proposer.get(tokenId).finality);
        registry.merge(registryId);

        registry.run(header.data[0], bytes32(0));
        assertEq(target.value(), 1337);
    }
}

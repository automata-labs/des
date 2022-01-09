// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "../interfaces/IProposer.sol";
import "../libraries/Status.sol";
import "../Attest.sol";
import "../Proposer.sol";
import "../Runtime.sol";
import "./mocks/Target.sol";
import "./mocks/Vm.sol";

contract User {}

contract ProposerTest is DSTest, Vm {
    using Header for Header.Data;

    event Commit(
        address indexed sender,
        uint256 indexed tokenId,
        bytes32[] hash,
        Header.Data header
    );

    User public user0;
    User public user1;

    Runtime public runtime;
    Attest public erc20;
    Proposer public proposer;

    function setUp() public {
        mine(100);

        user0 = new User();
        user1 = new User();

        runtime = new Runtime();
        erc20 = new Attest("Token", "TOKEN", 18);
        proposer = new Proposer(address(runtime), address(erc20));
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

    function setUpEmptyProposal(address to) public returns (uint256) {
        Transaction.Data[] memory data = new Transaction.Data[](1);
        Header.Data memory header = Header.Data({
            data: data,
            title: "",
            description: ""
        });
        return proposer.mint(to, header);
    }

    /**
     * `mint`
     */

    function testMint() public {
        Header.Data memory header = setUpEmptyHeader();

        uint256 tokenIdExpected;
        uint256 tokenId;

        tokenIdExpected = proposer.next();
        tokenId = proposer.mint(address(this), header);
        assertEq(tokenId, tokenIdExpected);
        assertEq(tokenId, 0);

        tokenIdExpected = proposer.next();
        tokenId = proposer.mint(address(this), header);
        assertEq(tokenId, tokenIdExpected);
        assertEq(tokenId, 1);
    }

    /**
     * `stage`
     */

    function testStage() public {
        uint256 tokenId = setUpEmptyProposal(address(this));

        assertEq(uint(proposer.status(tokenId)), uint(Status.Draft));
        proposer.stage(tokenId);
        assertEq(uint(proposer.status(tokenId)), uint(Status.Staged));
    }

    function testStageUnauthorizedRevert() public {
        uint256 tokenId = setUpEmptyProposal(address(this));

        startPrank(address(user0));
        assertEq(uint(proposer.status(tokenId)), uint(Status.Draft));
        expectRevert("Unauthorized");
        proposer.stage(tokenId);
    }

    function testStageNotDraftRevert() public {
        uint256 tokenId = setUpEmptyProposal(address(this));

        proposer.close(tokenId);
        assertEq(uint(proposer.status(tokenId)), uint(Status.Closed));
        expectRevert("NotDraft");
        proposer.stage(tokenId);
    }

    /**
     * `unstage`
     */

    function testUnstage() public {
        uint256 tokenId = setUpEmptyProposal(address(this));

        proposer.stage(tokenId);
        assertEq(uint(proposer.status(tokenId)), uint(Status.Staged));
        proposer.unstage(tokenId);
        assertEq(uint(proposer.status(tokenId)), uint(Status.Draft));

        proposer.stage(tokenId);
        assertEq(uint(proposer.status(tokenId)), uint(Status.Staged));
        proposer.unstage(tokenId);
        assertEq(uint(proposer.status(tokenId)), uint(Status.Draft));
    }

    function testUnstageUnauthorizedRevert() public {
        uint256 tokenId = setUpEmptyProposal(address(this));

        proposer.stage(tokenId);
        assertEq(uint(proposer.status(tokenId)), uint(Status.Staged));

        startPrank(address(user0));
        expectRevert("Unauthorized");
        proposer.unstage(tokenId);
    }

    function testUnstageNotStagedRevert() public {
        uint256 tokenId = setUpEmptyProposal(address(this));

        expectRevert("NotStaged");
        proposer.unstage(tokenId);
    }

    /**
     * `open`
     */

    function testOpen() public {
        uint256 tokenId = setUpEmptyProposal(address(this));

        proposer.open(tokenId);
        assertEq(uint(proposer.status(tokenId)), uint(Status.Pending));
        mine(proposer.delay());
        assertEq(uint(proposer.status(tokenId)), uint(Status.Open));
    }

    function testOpenWithThreshold() public {
        uint256 tokenId = setUpEmptyProposal(address(this));
        proposer.set(IProposer.threshold.selector, abi.encode(1e18));
        erc20.mint(address(this), 1e18);
        erc20.delegate(address(this));

        proposer.open(tokenId);
        assertEq(uint(proposer.status(tokenId)), uint(Status.Pending));
        mine(proposer.delay());
        assertEq(uint(proposer.status(tokenId)), uint(Status.Open));
    }

    function testOpenStaged() public {
        uint256 tokenId = setUpEmptyProposal(address(this));
        proposer.set(IProposer.threshold.selector, abi.encode(1e18));
        proposer.stage(tokenId);
        erc20.mint(address(user0), 1e18);

        startPrank(address(user0));
        erc20.delegate(address(user0));
        assertEq(uint(proposer.status(tokenId)), uint(Status.Staged));
        proposer.open(tokenId);
        assertEq(uint(proposer.status(tokenId)), uint(Status.Pending));
        mine(proposer.delay());
        assertEq(uint(proposer.status(tokenId)), uint(Status.Open));
    }

    function testOpenNotStagedRevert() public {
        uint256 tokenId = setUpEmptyProposal(address(this));

        startPrank(address(user0));
        expectRevert("NotStaged");
        proposer.open(tokenId);
    }

    function testOpenInsufficientTokensRevert() public {
        uint256 tokenId = setUpEmptyProposal(address(this));
        proposer.set(IProposer.threshold.selector, abi.encode(1e18));
        proposer.stage(tokenId);
        erc20.mint(address(user0), 1e18 - 1);

        startPrank(address(user0));
        erc20.delegate(address(user0));
        expectRevert("Insufficient");
        proposer.open(tokenId);
    }
    
    /**
     * `attest`
     */

    function testAttest() public {
        uint256 tokenId = setUpEmptyProposal(address(this));
        erc20.mint(address(this), 1e18);
        erc20.mint(address(user0), 3e18);
        erc20.mint(address(user1), 3e18);
        proposer.open(tokenId);
        erc20.delegate(address(this));
        prank(address(user0));
        erc20.delegate(address(user0));
        prank(address(user1));
        erc20.delegate(address(this));
        mine(proposer.delay());

        proposer.attest(tokenId, 0, 5e17, "");
        assertEq(proposer.get(tokenId).ack, 5e17);
        assertEq(proposer.get(tokenId).nack, 0);
        assertEq(proposer.attests(tokenId, address(this)), 5e17);

        proposer.attest(tokenId, 0, 3e18 + 5e17, "");
        assertEq(proposer.get(tokenId).ack, 4e18);
        assertEq(proposer.get(tokenId).nack, 0);
        assertEq(proposer.attests(tokenId, address(this)), 4e18);

        prank(address(user0));
        proposer.attest(tokenId, 0, 3e18, "");
        assertEq(proposer.get(tokenId).ack, 7e18);
        assertEq(proposer.get(tokenId).nack, 0);
        assertEq(proposer.attests(tokenId, address(user0)), 3e18);
    }

    function testAttestWithContestation() public {
        uint256 tokenId = setUpEmptyProposal(address(this));
        erc20.mint(address(this), 2e18);
        erc20.mint(address(user0), 5e18);
        erc20.mint(address(user1), 3e18);
        proposer.open(tokenId);
        erc20.delegate(address(this));
        prank(address(user0));
        erc20.delegate(address(user0));
        prank(address(user1));
        erc20.delegate(address(this));
        roll(proposer.get(tokenId).start);

        // `attest` with 2e18 for ack
        proposer.attest(tokenId, 0, 1e18, "");
        prank(address(user0));
        proposer.attest(tokenId, 0, 1e18, "");

        // roll to end and `contest`
        roll(proposer.get(tokenId).end);
        assertEq(uint(proposer.status(tokenId)), uint(Status.Validation));
        proposer.contest(tokenId);
        assertEq(uint(proposer.status(tokenId)), uint(Status.Contesting));

        // error on ack attest
        expectRevert(abi.encodeWithSignature("InvalidChoice(uint8)", uint8(0)));
        proposer.attest(tokenId, 0, 0, "");
        // should pass on nack attest
        proposer.attest(tokenId, 1, 1e18, "");

        roll(proposer.get(tokenId).trial);
        // should revert because the contestation failed (2e18 ack vs 1e18 nack)
        expectRevert(abi.encodeWithSignature("ContestationFailed()"));
        proposer.contest(tokenId);
    }

    function testAttestWithContiuousContestation() public {
        uint256 tokenId = setUpEmptyProposal(address(this));
        erc20.mint(address(this), 2e18);
        erc20.mint(address(user0), 5e18);
        erc20.mint(address(user1), 3e18);
        proposer.open(tokenId);
        erc20.delegate(address(this));
        prank(address(user0));
        erc20.delegate(address(user0));
        prank(address(user1));
        erc20.delegate(address(user1));
        roll(proposer.get(tokenId).start);

        // `attest` with 2e18 for ack
        proposer.attest(tokenId, 0, 1e18, "");
        prank(address(user0));
        proposer.attest(tokenId, 0, 1e18, "");

        // roll to end and `contest`
        roll(proposer.get(tokenId).end);
        proposer.contest(tokenId);

        // attest for nack, so that nack > ack
        proposer.attest(tokenId, 1, 1e18, "");
        prank(address(user0));
        proposer.attest(tokenId, 1, 2e18, "");

        // should be 2e18 ack and 3e18 nack, and we can contest again
        assertEq(proposer.get(tokenId).ack, 2e18);
        assertEq(proposer.get(tokenId).nack, 3e18);
        assert(proposer.get(tokenId).side == true);
        roll(proposer.get(tokenId).trial);
        proposer.contest(tokenId);
        assert(proposer.get(tokenId).side == false);

        // fail when trying to vote for nack during ack-time
        expectRevert(abi.encodeWithSignature("InvalidChoice(uint8)", uint8(1)));
        proposer.attest(tokenId, 1, 0, "");

        prank(address(user0));
        proposer.attest(tokenId, 0, 1e18, "");
        prank(address(user1));
        proposer.attest(tokenId, 0, 1e18, "");
        assertEq(proposer.get(tokenId).ack, 4e18);
        assertEq(proposer.get(tokenId).nack, 3e18);

        // roll to finality and revert when contesting
        roll(proposer.get(tokenId).finality);
        assertEq(uint(proposer.status(tokenId)), uint(Status.Queued));
        expectRevert(abi.encodeWithSignature("StatusError(uint8)", uint8(Status.Queued)));
        proposer.contest(tokenId);

        // roll to maturity and revert when contesting
        roll(proposer.maturity(tokenId));
        assertEq(uint(proposer.status(tokenId)), uint(Status.Approved));
        expectRevert(abi.encodeWithSignature("StatusError(uint8)", uint8(Status.Approved)));
        proposer.contest(tokenId);
    }

    function testAttestStatusErrorRevert() public {
        uint256 tokenId = setUpEmptyProposal(address(this));

        // can't attest on draft
        expectRevert(abi.encodeWithSignature("StatusError(uint8)", uint8(Status.Draft)));
        proposer.attest(tokenId, 0, 0, "");

        // can't attest on pending
        proposer.open(tokenId);
        expectRevert(abi.encodeWithSignature("StatusError(uint8)", uint8(Status.Pending)));
        proposer.attest(tokenId, 0, 0, "");

        // still pending
        mine(proposer.delay() - 1);
        expectRevert(abi.encodeWithSignature("StatusError(uint8)", uint8(Status.Pending)));
        proposer.attest(tokenId, 0, 0, "");

        // should pass, now open
        roll(proposer.get(tokenId).start);
        proposer.attest(tokenId, 0, 0, "");
    }

    function testAttestNonExistentTokenRevert() public {
        expectRevert(abi.encodeWithSignature("UndefinedId(uint256)", 0));
        proposer.attest(0, 0, 0, "");

        expectRevert(abi.encodeWithSignature("UndefinedId(uint256)", 3));
        proposer.attest(3, 0, 0, "");
    }

    function testAttestOnClosedRevert() public {
        uint256 tokenId = setUpEmptyProposal(address(this));
        proposer.open(tokenId);
        mine(proposer.delay());

        // close and attest should revert
        proposer.close(tokenId);
        expectRevert(abi.encodeWithSignature("StatusError(uint8)", uint8(Status.Closed)));
        proposer.attest(tokenId, 0, 0, "");
    }

    function testAttestOverflowRevert() public {
        uint256 tokenId = setUpEmptyProposal(address(this));
        proposer.open(tokenId);
        mine(proposer.delay());

        expectRevert(abi.encodeWithSignature("AttestOverflow()"));
        proposer.attest(tokenId, 0, 1, "");
    }

    /**
     * `commit`
     */

    function testCommit() public {
        Target target = new Target();
        uint256 tokenId = setUpEmptyProposal(address(this));

        Transaction.Data[] memory transactions = new Transaction.Data[](2);
        Header.Data memory header = Header.Data({
            data: transactions,
            title: "Update the target value",
            description: "This proposal updates the target value."
        });

        address[] memory targets_ = new address[](1);
        uint256[] memory values_ = new uint256[](1);
        string[] memory signatures_ = new string[](1);
        bytes[] memory datas_ = new bytes[](1);
        targets_[0] = address(target);
        values_[0] = 0;
        signatures_[0] = "update(uint256)";
        datas_[0] = abi.encode(1337);
        transactions[0] = Transaction.Data({
            targets: targets_,
            values: values_,
            signatures: signatures_,
            datas: datas_,
            message: "tweak: update target value 1337"
        });

        address[] memory targets__ = new address[](1);
        uint256[] memory values__ = new uint256[](1);
        string[] memory signatures__ = new string[](1);
        bytes[] memory datas__ = new bytes[](1);
        targets__[0] = address(target);
        values__[0] = 0;
        signatures__[0] = "update(uint256)";
        datas__[0] = abi.encode(42);
        transactions[1] = Transaction.Data({
            targets: targets__,
            values: values__,
            signatures: signatures__,
            datas: datas__,
            message: "tweak: update target value to 42"
        });

        expectEmit(true, true, true, true);
        emit Commit(address(this), tokenId, header.hash(), header);
        proposer.commit(tokenId, header);
    }
}

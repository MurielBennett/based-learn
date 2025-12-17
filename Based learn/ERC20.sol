// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

// ПИНУЕМ OpenZeppelin v4.9.3 (совместим с 0.8.17)
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC20/extensions/ERC20Snapshot.sol";

contract WeightedVoting is ERC20Snapshot {
    error TokensClaimed();
    error AllTokensClaimed();
    error NoTokensHeld();
    error QuorumTooHigh();
    error QuorumZero();
    error AlreadyVoted();
    error VotingClosed();
    error InvalidIssue(uint256 issueId);

    enum Vote { AGAINST, FOR, ABSTAIN }

    struct Issue {
        uint256 snapshotId;
        string issueDesc;
        uint256 quorum;
        uint256 totalVotes;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 votesAbstain;
        bool passed;
        bool closed;
    }

    struct SerializedIssue {
        address[] voters;
        string issueDesc;
        uint256 quorum;
        uint256 totalVotes;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 votesAbstain;
        bool passed;
        bool closed;
    }

    Issue[] internal issues; // issues[0] dummy
    mapping(address => bool) public tokensClaimed;

    mapping(uint256 => mapping(address => bool)) private hasVoted;
    mapping(uint256 => address[]) private votersList;

    uint256 public constant maxSupply = 1_000_000;
    uint256 public constant claimAmount = 100;

    event Claimed(address indexed account, uint256 amount);
    event IssueCreated(uint256 indexed issueId, address indexed creator, uint256 quorum, uint256 snapshotId, string desc);
    event Voted(uint256 indexed issueId, address indexed voter, Vote vote, uint256 weight);

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        issues.push();
    }

    function decimals() public pure override returns (uint8) { return 0; }

    function claim() external {
        if (tokensClaimed[msg.sender]) revert TokensClaimed();
        if (totalSupply() + claimAmount > maxSupply) revert AllTokensClaimed();

        tokensClaimed[msg.sender] = true;
        _mint(msg.sender, claimAmount);

        emit Claimed(msg.sender, claimAmount);
    }

    function createIssue(string calldata _issueDesc, uint256 _quorum) external returns (uint256) {
        if (balanceOf(msg.sender) == 0) revert NoTokensHeld();
        if (_quorum == 0) revert QuorumZero();

        uint256 snapId = _snapshot();

        if (_quorum > totalSupplyAt(snapId)) revert QuorumTooHigh();

        Issue storage _issue = issues.push();
        _issue.snapshotId = snapId;
        _issue.issueDesc = _issueDesc;
        _issue.quorum = _quorum;

        uint256 issueId = issues.length - 1;
        emit IssueCreated(issueId, msg.sender, _quorum, snapId, _issueDesc);
        return issueId;
    }

    function getIssue(uint256 _issueId) external view returns (SerializedIssue memory) {
        if (_issueId == 0 || _issueId >= issues.length) revert InvalidIssue(_issueId);

        Issue storage _issue = issues[_issueId];
        return SerializedIssue({
            voters: votersList[_issueId],
            issueDesc: _issue.issueDesc,
            quorum: _issue.quorum,
            totalVotes: _issue.totalVotes,
            votesFor: _issue.votesFor,
            votesAgainst: _issue.votesAgainst,
            votesAbstain: _issue.votesAbstain,
            passed: _issue.passed,
            closed: _issue.closed
        });
    }

    function vote(uint256 _issueId, Vote _vote) external {
        if (_issueId == 0 || _issueId >= issues.length) revert InvalidIssue(_issueId);

        Issue storage _issue = issues[_issueId];
        if (_issue.closed) revert VotingClosed();
        if (hasVoted[_issueId][msg.sender]) revert AlreadyVoted();

        uint256 weight = balanceOfAt(msg.sender, _issue.snapshotId);
        if (weight == 0) revert NoTokensHeld();

        hasVoted[_issueId][msg.sender] = true;
        votersList[_issueId].push(msg.sender);

        if (_vote == Vote.AGAINST) _issue.votesAgainst += weight;
        else if (_vote == Vote.FOR) _issue.votesFor += weight;
        else _issue.votesAbstain += weight;

        _issue.totalVotes += weight;

        if (_issue.totalVotes >= _issue.quorum) {
            _issue.closed = true;
            if (_issue.votesFor > _issue.votesAgainst) _issue.passed = true;
        }

        emit Voted(_issueId, msg.sender, _vote, weight);
    }
}
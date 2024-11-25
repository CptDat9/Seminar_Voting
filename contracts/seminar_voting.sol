/**
 *Submitted for verification at testnet.bscscan.com on 2024-09-28
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SeminarVoting {
    // Owner của contract
    address public owner;

    // Cấu trúc lưu trữ thông tin của một seminar
    struct Seminar {
        string title;        // Tên của seminar
        string[] speakers;   // Danh sách tên các diễn giả
        string slideLink;    // Đường link slide của seminar
    }

    // Cấu trúc lưu trữ thông tin của một vòng bầu chọn (round)
    struct Round {
        uint256 id;                // ID của round
        Seminar[] seminars;        // Danh sách các seminar
        uint256 votingStart;       // Thời gian bắt đầu
        uint256 votingDeadline;    // Thời gian kết thúc
        bool votingEnded;          // Đánh dấu vòng bầu chọn đã kết thúc hay chưa
        mapping(string => uint256) seminarVoteCount; // Số lượng phiếu cho mỗi seminar
        mapping(string => uint256) speakerVoteCount; // Số lượng phiếu cho mỗi diễn giả
        mapping(address => uint256) seminarVotes; // Số lượng vote cho seminar của mỗi địa chỉ
        mapping(address => uint256) speakerVotes; // Số lượng vote cho diễn giả của mỗi địa chỉ
        mapping(address => bool) hasVotedForSeminars; // Đánh dấu địa chỉ đã vote cho seminar hay chưa
        mapping(address => bool) hasVotedForSpeakers; // Đánh dấu địa chỉ đã vote cho diễn giả hay chưa
        mapping(address => string[]) votedSpeakers;   // Danh sách diễn giả đã được user vote
        mapping(address => string) voterNames;         // Mapping giữa address và tên người vote
        address[] voters;          // Danh sách địa chỉ đã vote
        address[] speakerVoters;   // Danh sách địa chỉ đã vote cho diễn giả
        uint256 maxVotes;         // Số lượng tối đa vote cho seminar và speaker
    }

    // Danh sách các vòng bầu chọn
    Round[] public rounds;
    uint256 public currentRoundId;

    // Sự kiện
    event RoundCreated(uint256 roundId, uint256 votingStart, uint256 votingDeadline, uint256 maxVotes);
    event SeminarAdded(uint256 roundId, string title, string[] speakers, string slideLink);
    event VoteSubmitted(uint256 roundId, address voter, uint256 seminarId);
    event SpeakerVoteSubmitted(uint256 roundId, address voter, string[] speakers);
    event InvalidVoteRemoved(uint256 roundId, address voter);
    event InvalidSpeakerVoteRemoved(uint256 roundId, address voter);
    event VotingStartChanged(uint256 roundId, uint256 newVotingStart);
    event VotingDeadlineChanged(uint256 roundId, uint256 newVotingDeadline);
    event VoterNameUpdated(address voter, string newName);
    event MaxVotesUpdated(uint256 roundId, uint256 newMaxVotes);

    // Constructor để khởi tạo owner
    constructor() {
        owner = msg.sender;
    }

    // Modifier chỉ cho phép owner gọi hàm
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    // Modifier để kiểm tra xem vòng bầu chọn có tồn tại hay không
    modifier roundExists(uint256 _roundId) {
        require(_roundId < rounds.length, "Round does not exist");
        _;
    }

    // Modifier chỉ cho phép thực hiện khi thời gian vote còn hiệu lực
    modifier voteActive() {
        Round storage round = rounds[currentRoundId];
        require(block.timestamp >= round.votingStart && block.timestamp < round.votingDeadline, "Voting is not active");
        _;
    }

    // Hàm để tạo một vòng bầu chọn mới
    function createRound(uint256 _votingStart, uint256 _votingDuration, uint256 _maxVotes) public onlyOwner {
        uint256 roundId = rounds.length;
        rounds.push();
        Round storage newRound = rounds[roundId];
        newRound.id = roundId;
        newRound.votingStart = _votingStart;
        newRound.votingDeadline = _votingStart + _votingDuration;
        newRound.votingEnded = false;
        newRound.maxVotes = _maxVotes;  // Thiết lập số lượng vote tối đa
        currentRoundId = roundId;
        emit RoundCreated(roundId, _votingStart, newRound.votingDeadline, _maxVotes);
    }

    // Hàm để thêm seminar mới vào vòng bầu chọn hiện tại
    function addSeminar(string memory _title, string[] memory _speakers, string memory _slideLink) 
        public 
        onlyOwner 
    {
        Round storage round = rounds[currentRoundId];
        round.seminars.push(Seminar(_title, _speakers, _slideLink));
        emit SeminarAdded(currentRoundId, _title, _speakers, _slideLink);
    }

    // Hàm để thiết lập tên cho người vote
    function setVoterName(string memory _name) public {
        Round storage round = rounds[currentRoundId];
        require(!round.hasVotedForSeminars[msg.sender], "You have already voted for seminars in this round");
        require(!round.hasVotedForSpeakers[msg.sender], "You have already voted for speakers in this round");
        
        round.voterNames[msg.sender] = _name;
    }

    // Hàm để sửa tên của người vote
    function updateVoterName(string memory _newName) public {
        Round storage round = rounds[currentRoundId];
        require(bytes(round.voterNames[msg.sender]).length != 0, "Voter name is not set");
        round.voterNames[msg.sender] = _newName;

        emit VoterNameUpdated(msg.sender, _newName);
    }

    // Hàm để lấy danh sách các tên người đã vote cho seminar
    function getVoterNames() public view returns (string[] memory) {
        Round storage round = rounds[currentRoundId];
        string[] memory names = new string[](round.voters.length);

        for (uint256 i = 0; i < round.voters.length; i++) {
            names[i] = round.voterNames[round.voters[i]];
        }

        return names;
    }

    // Hàm để lấy danh sách các người chưa vote
    function getVoterNamesNotVoted() public view returns (string[] memory) {
        Round storage round = rounds[currentRoundId];
        uint256 totalVoters = 0;

        // Đếm số lượng người chưa vote
        for (uint256 i = 0; i < round.voters.length; i++) {
            if (!round.hasVotedForSeminars[round.voters[i]] && !round.hasVotedForSpeakers[round.voters[i]]) {
                totalVoters++;
            }
        }

        // Tạo mảng chứa tên người chưa vote
        string[] memory notVotedNames = new string[](totalVoters);
        uint256 index = 0;

        for (uint256 i = 0; i < round.voters.length; i++) {
            if (!round.hasVotedForSeminars[round.voters[i]] && !round.hasVotedForSpeakers[round.voters[i]]) {
                notVotedNames[index] = round.voterNames[round.voters[i]];
                index++;
            }
        }

        return notVotedNames;
    }

    // Hàm để vote cho seminar bằng ID trong vòng bầu chọn hiện tại
    function voteForSeminar(uint256[] calldata _seminarIds) 
        public 
        voteActive 
    {
        Round storage round = rounds[currentRoundId];
        require(!round.hasVotedForSeminars[msg.sender], "You have already voted for seminars in this round");
        require(_seminarIds.length <= round.maxVotes, "You can only vote for a maximum of 3 seminars");
        
        // Kiểm tra số lượng vote hiện tại
        uint256 currentVotes = round.seminarVotes[msg.sender];
        require(currentVotes + _seminarIds.length <= round.maxVotes, "You have reached the maximum number of votes for seminars");

        // Đánh dấu là đã vote
        round.hasVotedForSeminars[msg.sender] = true;
        round.voters.push(msg.sender);

        for (uint256 i = 0; i < _seminarIds.length; i++) {
            uint256 seminarId = _seminarIds[i];
            require(seminarId < round.seminars.length, "Invalid seminar ID");

            // Cộng số lượng vote cho seminar được chỉ định
            round.seminarVoteCount[round.seminars[seminarId].title] += 1;
            round.hasVotedForSeminars[msg.sender] = true; // Đánh dấu là đã vote
        }
    }
    
    // Hàm để vote cho diễn giả bằng ID trong vòng bầu chọn hiện tại
    function voteForSpeakers(string[] memory _speakers) 
        public 
        voteActive 
    {
        Round storage round = rounds[currentRoundId];
        uint256 currentVotes = round.speakerVotes[msg.sender];
        
        // Kiểm tra tổng số vote đã thực hiện trong vòng hiện tại
        require(currentVotes + _speakers.length <= round.maxVotes, "You have reached the maximum number of votes for speakers in this round");

        // Tăng số lượng vote của người dùng lên theo số lượng speakers được vote trong lần gọi này
        round.speakerVotes[msg.sender] += _speakers.length;

        round.hasVotedForSpeakers[msg.sender] = true; // Đánh dấu là đã vote cho speaker
        round.speakerVoters.push(msg.sender); // Thêm người dùng vào danh sách đã vote

        for (uint256 i = 0; i < _speakers.length; i++) {
            round.speakerVoteCount[_speakers[i]] += 1; // Cộng số lượng vote cho mỗi diễn giả
            round.votedSpeakers[msg.sender].push(_speakers[i]); // Lưu lại diễn giả đã được vote
        }


        emit SpeakerVoteSubmitted(currentRoundId, msg.sender, _speakers);
    }

    // Hàm để xem số vote cho mỗi seminar sau khi kết thúc vote
    function getSeminarVotes() public view returns (uint256[] memory) {
        Round storage round = rounds[currentRoundId];
        require(round.votingEnded, "Voting has not ended yet");

        uint256[] memory votes = new uint256[](round.seminars.length);
        for (uint256 i = 0; i < round.seminars.length; i++) {
            votes[i] = round.seminarVoteCount[round.seminars[i].title];
        }
        return votes;
    }

    // Hàm để xem số vote cho mỗi diễn giả sau khi kết thúc vote
    function getSpeakerVotes() public view returns (uint256[] memory) {
        Round storage round = rounds[currentRoundId];
        require(round.votingEnded, "Voting has not ended yet");

        uint256[] memory votes = new uint256[](round.seminars.length);
        for (uint256 i = 0; i < round.seminars.length; i++) {
            votes[i] = round.speakerVoteCount[round.seminars[i].speakers[i]];
        }
        return votes;
    }

    // Hàm để xem danh sách diễn giả trong vòng bầu chọn hiện tại
    function getSpeakers() public view returns (string[][] memory) {
        Round storage round = rounds[currentRoundId];
        // Assuming you have the number of seminars in round.seminars.length
        string[][] memory speakers = new string[][](round.seminars.length);


        for (uint256 i = 0; i < round.seminars.length; i++) {
            speakers[i] = round.seminars[i].speakers;
        }
        return speakers;
    }

    // Hàm để xem danh sách diễn giả cho một round cụ thể
    function getSpeakersByRound(uint256 _roundId) public view returns (string[][] memory) {
        require(_roundId < rounds.length, "Round does not exist"); // Kiểm tra roundId có hợp lệ không
        Round storage round = rounds[_roundId];
        
        string[][] memory speakers = new string[][](round.seminars.length); // Khởi tạo mảng diễn giả

        for (uint256 i = 0; i < round.seminars.length; i++) {
            speakers[i] = round.seminars[i].speakers; // Gán danh sách diễn giả cho từng seminar
        }
        return speakers; // Trả về danh sách diễn giả
    }

    // Hàm để xem danh sách seminar cho một round cụ thể
    function getSeminarsByRound(uint256 _roundId) public view returns (string[] memory titles, string[][] memory speakers) {
        require(_roundId < rounds.length, "Round does not exist"); // Kiểm tra roundId có hợp lệ không
        Round storage round = rounds[_roundId];

        titles = new string[](round.seminars.length); // Khởi tạo mảng tiêu đề seminar
        speakers = new string[][](round.seminars.length); // Khởi tạo mảng diễn giả

        for (uint256 i = 0; i < round.seminars.length; i++) {
            titles[i] = round.seminars[i].title; // Gán tiêu đề seminar
            speakers[i] = round.seminars[i].speakers; // Gán danh sách diễn giả cho từng seminar
        }
    }


    // Hàm để thay đổi thời gian bắt đầu vote cho một vòng bầu chọn
    function changeVotingStart(uint256 _newVotingStart) 
        public 
        onlyOwner 
        roundExists(currentRoundId) 
    {
        Round storage round = rounds[currentRoundId];
        require(_newVotingStart < round.votingDeadline, "Start time must be before the deadline");
        round.votingStart = _newVotingStart;
        emit VotingStartChanged(currentRoundId, _newVotingStart);
    }

    // Hàm để thay đổi thời gian kết thúc vote cho một vòng bầu chọn
    function changeVotingDeadline(uint256 _newVotingDeadline) 
        public 
        onlyOwner 
        roundExists(currentRoundId) 
    {
        Round storage round = rounds[currentRoundId];
        require(_newVotingDeadline > round.votingStart, "Deadline must be after the start time");
        round.votingDeadline = _newVotingDeadline;
        emit VotingDeadlineChanged(currentRoundId, _newVotingDeadline);
    }

    // Hàm để thay đổi số lượng tối đa vote cho một vòng bầu chọn
    function setMaxVotes(uint256 _maxVotes) public onlyOwner roundExists(currentRoundId) {
        Round storage round = rounds[currentRoundId];
        round.maxVotes = _maxVotes;
        emit MaxVotesUpdated(currentRoundId, _maxVotes);
    }

    // Hàm để xem danh sách những người đã vote trong một vòng bầu chọn
    function getVoters() public view returns (address[] memory) {
        return rounds[currentRoundId].voters;
    }

    // Hàm để xem danh sách những người đã vote cho diễn giả trong một vòng bầu chọn
    function getSpeakerVoters() public view returns (address[] memory) {
        return rounds[currentRoundId].speakerVoters;
    }

    // Hàm để xóa vote không hợp lệ của người dùng trong một vòng bầu chọn
    function removeInvalidVote(address _voter) 
        public 
        onlyOwner 
    {
        Round storage round = rounds[currentRoundId];
        require(round.hasVotedForSeminars[_voter], "Voter has not voted");

        round.hasVotedForSeminars[_voter] = false;

        // Giảm số lượng vote cho mỗi seminar mà người dùng đã vote
        for (uint256 i = 0; i < round.seminars.length; i++) {
            round.seminarVoteCount[round.seminars[i].title] -= 1;
        }

        emit InvalidVoteRemoved(currentRoundId, _voter);
    }

    // Hàm để xóa vote không hợp lệ của người dùng cho diễn giả trong một vòng bầu chọn
    function removeInvalidSpeakerVote(address _voter) 
        public 
        onlyOwner 
    {
        Round storage round = rounds[currentRoundId];
        require(round.hasVotedForSpeakers[_voter], "Voter has not voted for speakers");

        round.hasVotedForSpeakers[_voter] = false;

        // Giảm số lượng vote cho mỗi diễn giả mà người dùng đã vote
        string[] memory votedSpeakers = round.votedSpeakers[_voter];
        for (uint256 i = 0; i < votedSpeakers.length; i++) {
            round.speakerVoteCount[votedSpeakers[i]] -= 1;
        }

        emit InvalidSpeakerVoteRemoved(currentRoundId, _voter);
    }
}

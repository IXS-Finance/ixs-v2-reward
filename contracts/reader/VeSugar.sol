// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IVoter} from "../interfaces/IVoter.sol";
import {IVotingEscrow} from "../interfaces/IVotingEscrow.sol";

contract VeSugar {
    uint256 constant MAX_RESULTS = 1000;
    uint256 constant MAX_PAIRS = 30;

    struct LpVote {
        address lp;
        uint256 weight;
    }

    struct VeNFT {
        uint256 id;
        address account;
        uint8 decimals;
        uint128 amount;
        uint256 votingAmount;
        uint256 expiresAt;
        uint256 votedAt;
        LpVote[] votes;
        address token;
        bool permanent;
        uint256 delegateId;
        uint256 managedId;
    }

    IVoter public voter;
    IVotingEscrow public ve;
    address public token;

    constructor(address _voter) {
        voter = IVoter(_voter);
        ve = IVotingEscrow(voter.ve());
        token = ve.token();
    }

    function all(uint256 limit, uint256 offset) external view returns (VeNFT[] memory) {
        VeNFT[] memory result = new VeNFT[](limit);
        uint256 count;

        for (uint256 i = offset; i < offset + MAX_RESULTS && count < limit; i++) {
            address owner = ve.ownerOf(i);
            if (owner == address(0)) continue;

            result[count] = _getById(i);
            count++;
        }

        VeNFT[] memory trimmed = new VeNFT[](count);
        for (uint256 j = 0; j < count; j++) {
            trimmed[j] = result[j];
        }

        return trimmed;
    }

    function byAccount(address account) external view returns (VeNFT[] memory) {
        VeNFT[] memory result = new VeNFT[](MAX_RESULTS);
        uint256 count;

        if (account == address(0)) return result;

        for (uint256 i = 0; i < MAX_RESULTS; i++) {
            uint256 tokenId = ve.ownerToNFTokenIdList(account, i);
            if (tokenId == 0) break;

            result[count] = _getById(tokenId);
            count++;
        }

        VeNFT[] memory trimmed = new VeNFT[](count);
        for (uint256 j = 0; j < count; j++) {
            trimmed[j] = result[j];
        }

        return trimmed;
    }

    function byId(uint256 id) external view returns (VeNFT memory) {
        return _getById(id);
    }

    // Helper function to build the votes array
    function _getVotes(uint256 id) internal view returns (LpVote[] memory) {
        uint256 usedWeight = voter.usedWeights(id);
        uint256 remainingWeight = usedWeight;
        LpVote[] memory votes = new LpVote[](MAX_PAIRS);
        uint256 voteCount = 0;
        for (uint256 i = 0; i < MAX_PAIRS && remainingWeight > 0; i++) {
            address pool = voter.poolVote(id, i);
            if (pool == address(0)) break;
            uint256 weight = voter.votes(id, pool);
            votes[voteCount] = LpVote(pool, weight);
            voteCount++;
            if (weight > remainingWeight) break;
            remainingWeight -= weight;
        }
        LpVote[] memory trimmedVotes = new LpVote[](voteCount);
        for (uint256 j = 0; j < voteCount; j++) {
            trimmedVotes[j] = votes[j];
        }
        return trimmedVotes;
    }

    function _getById(uint256 id) internal view returns (VeNFT memory) {
        address owner = ve.ownerOf(id);
        if (owner == address(0)) {
            LpVote[] memory emptyVotes = new LpVote[](0);
            return
                VeNFT({
                    id: id,
                    account: address(0),
                    decimals: 0,
                    amount: 0,
                    votingAmount: 0,
                    expiresAt: 0,
                    votedAt: 0,
                    votes: emptyVotes,
                    token: token,
                    permanent: false,
                    delegateId: 0,
                    managedId: 0
                });
        }

        (uint128 amount, uint256 expiresAt, bool permanent) = ve.locked(id);
        uint256 votingAmount = ve.balanceOfNFT(id);
        uint8 decimals = ve.decimals();

        uint256 delegateId = ve.delegates(id);
        uint256 managedId = ve.idToManaged(id);
        uint256 votedAt = 0;
        if (managedId != 0 || ve.voted(id)) {
            votedAt = voter.lastVoted(id);
        }

        LpVote[] memory trimmedVotes = _getVotes(id);

        return
            VeNFT({
                id: id,
                account: owner,
                decimals: decimals,
                amount: amount,
                votingAmount: votingAmount,
                expiresAt: expiresAt,
                votedAt: votedAt,
                votes: trimmedVotes,
                token: token,
                permanent: permanent,
                delegateId: delegateId,
                managedId: managedId
            });
    }
}

# CAST
## A fully on-chain voting system
### Resources
A summary of the resources that will be defined by the contract. Important methods are only showcased on resource interfaces, resources are only showing fields for convenience.
#### Community
The core resource of the CAST contract. Stores proposals, keeps track of its users and exposes mechanisms for manage itself, share its info and to become a part (a member) of it.
```cadence
    pub resource interface CommunityAdmin {
        pub fun setupCommunity (votingCap: Capability<&{BallotBox}>, proposingCap: Capability<&{ProposalCreator}>)
        pub fun acceptProposal (proposalID: UInt64)
    }
    pub resource interface CommunityPublic {
        pub fun getCommunityInfo ()
        pub fun getProposals (): {UInt64: &Proposal}
        pub fun getProposalInfo (proposalID: UInt64)

    }
    pub resource interface MembershipRequestManager {
        pub fun requestMembership (user: Address): String
    }
    pub resource interface ProposalCreator {
        pub fun createProposal(proposal: @Proposal)
    }
    pub resource interface BallotBox {
        pub fun castVoteOnProposal(proposalID: UInt64, vote: @Vote)
    }
    pub resource Community: CommunityAdmin, CommunityPublic, MembershipRequestManager, ProposalCreator, BallotBox {
        pub let communityAdminAuthAccountCapability: Capability<&AuthAccount>
        pub var membershipManagerCapability: Capability<&{MembershipRequestManager}>?
        pub var votingCapability: Capability<&{BallotBox}>?
        pub var proposingCapability: Capability<&{ProposalCreator}>?
        pub let info: CommunityInfo
        pub let members: {Address: Bool?}
    }
```
#### Membership issuer
This is an auxiliary resource for handling the `Membership` resource to any account that has call the `requestMembership (user: Address): String` method on a community. One instance of it will be created per each user that has request a `Membership`, having to delete once it has been claimed by the member.
```cadence
    // 
    pub resource interface MembershipGranter {
        pub fun getMembership (): @Membership
    }

    pub resource MembershipIssuer: MembershipGranter {
        pub var membership: @Membership?
    }
```
#### Membership
The resource that will prove that an account belongs to a certain community, holding capabilities to that communities that will allow the owner to create proposals and cast votes on them.
```cadence
    pub resource Membership {
        pub let user: Address
        pub let votingCapability: Capability<&{BallotBox}>
        pub let proposingCapability: Capability<&   {ProposalCreator}>
    }
```
#### Proposal
This will hold the actual proposal info and any important metadata related to it, along with the votes casted on it.
```cadence
    pub resource Proposal {
        access(self) let endingTime: UFix64
        access(self) var state: ProposalState
        access(self) let votes: @{Address: Vote}
        access(self) let results: {VotingResult: UFix64}
        access(self) var approved: VotingResult?
        access(self) var strategy: Strategies
    }
```
#### Vote
The resource that will be created when a member cast a vote on a proposal.
```cadence
    pub resource Vote {
        access(self) let option: Bool
        access(self) let castingTime: UFix64
        access(self) let issuer: Address
    }
```

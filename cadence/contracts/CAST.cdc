/// tl;dr: CAST will allow anyone to create a `@Community`, then any account could 
/// request a single `@Membership` of that community that will be delivered to it via  
/// a capability that will be `inbox.publish()` to that account. `@Membership` will  
/// be able to create `@Proposal`(s) and to cast `@Vote`(s)
pub contract CAST {
    
    ///
    /// Paths
    ///

    ///
    /// Fields
    /// 

    ///
    /// Events
    ///

    ///
    /// Structs
    ///
    pub struct CommunityInfo {
        pub let name: String

        init (name: String) {
            self.name = name
        }
    }

    pub enum Strategies: UInt {
        pub case oneVote
        pub case tokenWeighted
        pub case stakedFlowWeighted
    }

    pub enum VotingResult: UInt {
        pub case favor
        pub case against
        pub case tie
    }

    ///
    /// Resource interfaces
    ///
    pub resource interface CommunityAdmin {
        pub fun setupCommunity (votingCap: Capability<&{BallotBox}>, proposingCap: Capability<&{ProposalCreator}>)
        pub fun acceptProposal (proposalID: UInt64)
    }

    // Community will need to conform to this in order to support public script info
    pub resource interface CommunityPublic {
        // probably we need to define a struct defining community info
        // that struct should be filled on community creation and returned by this fun
        pub fun getCommunityInfo () /*: CommunityInfo */
        pub fun getProposals (): {UInt64: &Proposal}
        pub fun getProposalInfo (proposalID: UInt64)

    }
    
    // public interface anyone can call it
    pub resource interface MembershipRequestManager {
        pub fun requestMembership (user: Address): String
    }

    // Membership roles will have capabilities of this types depending on which role they hold
    pub resource interface ProposalCreator {
        pub fun createProposal(proposal: @Proposal)
    }
    
    // Pretty straight forward
    pub resource interface BallotBox {
        pub fun castVoteOnProposal(proposalID: UInt64, vote: @Vote)
    }

    // 
    pub resource interface MembershipGranter {
        pub fun getMembership (): @Membership
    }

    ///
    /// Resources
    ///

    pub resource Community: CommunityAdmin, MembershipRequestManager, ProposalCreator, BallotBox {
        // Community admin account will be linked to the Community resource for
        // for allowing it to control who belongs to it publishing capabilities
        pub let communityAdminAuthAccountCapability: Capability<&AuthAccount>

        pub var membershipManagerCapability: Capability<&{MembershipRequestManager}>?

        // After creating the community, a voting and proposing capabilities pointing
        // to itself should be created and stored into it so they can be included in
        // the community `@Membership`s
        pub var votingCapability: Capability<&{BallotBox}>?
        pub var proposingCapability: Capability<&{ProposalCreator}>?

        pub let info: CommunityInfo

        // maybe we can open the option to ban users by setting this to false
        // so far nil means is not a user, true is that is already a user
        pub let members: {Address: Bool?}

        // Not sure how to separate accepted proposals from those which haven't been
        // reviewed
        pub let inStudyProposals: @{UInt64: Proposal?}
        pub let acceptedProposals: @{UInt64: Proposal?}

        pub fun requestMembership (user: Address): String {
            pre {
                self.members[user] == nil: "User is already a member"
            }
            // Borrow a reference to community admin auth account
            let adminAccountRef = self.communityAdminAuthAccountCapability.borrow()
                ?? panic ("Can't borrow community admin account reference")
            // Create a membership resource for requesting user
            let membership <- create Membership(user: user, votingCap: self.votingCapability!, proposingCap: self.proposingCapability!)
            // Create a membership issuer resource that will hold the Membership resource for distribution
            let issuer <- create MembershipIssuer(membership: <- membership)
            // Create a base string that will identify paths for membership creation
            // of user inside this community
            let userCommunityBaseString = self.info.name.concat(user.toString())
            // Create issuer custom storage path
            let issuerStoragePath = StoragePath(identifier: userCommunityBaseString
                .concat("MembershipIssuer"))
                    ?? panic("Fail to create membership issuer storage path")
            // Store it into admin account
            adminAccountRef.save(<- issuer, to: issuerStoragePath)
            // Create a private path por linking a capability to the issuer
            let granterPrivatePath = PrivatePath(identifier: userCommunityBaseString
                .concat("MembershipGranter"))
                    ?? panic("Fail to create membership issuer private path")
            // And link it to publish capability to user account
            let granterCap = adminAccountRef
                .link<&{MembershipGranter}>(granterPrivatePath, target: issuerStoragePath)
                    ?? panic("Error while linking membership issuer")
            // Publish capability using base string as name
            adminAccountRef.inbox.publish(granterCap, name: userCommunityBaseString, recipient: user)
            // Register the address as a member
            self.members[user] = true
            // Return base string so user can claim issuer capability
            return userCommunityBaseString
        }

        // this would store a new proposal, how to manage accepted or not?
        pub fun createProposal(proposal: @Proposal) {
            self.inStudyProposals[proposal.uuid] <-! proposal
        }

        pub fun castVoteOnProposal(proposalID: UInt64, vote: @Vote) {
            pre {
                self.acceptedProposals[proposalID] != nil : "Proposal does not match any accepted proposal"
            }
            // you need an auxiliary dummy vote that needs to be destroyed latter or
            // methods for properly dealing with the votes dictionary
            //self.acceptedProposals[proposalID]!!.registerVote(vote: <-vote)
        }

        pub fun setupCommunity (votingCap: Capability<&{BallotBox}>, proposingCap: Capability<&{ProposalCreator}>) {
            self.votingCapability = votingCap
            self.proposingCapability = proposingCap
        }

        pub fun acceptProposal (proposalID: UInt64) {
            // this has to be coded in a proper safer way
            self.acceptedProposals[proposalID] <-> self.inStudyProposals[proposalID]
        }

        init (name: String, authAccountCapability: Capability<&AuthAccount>) {
            self.info = CommunityInfo(name: name)
            self.communityAdminAuthAccountCapability = authAccountCapability
            self.membershipManagerCapability = nil
            self.votingCapability = nil
            self.proposingCapability = nil
            self.members = {}
            self.inStudyProposals <- {}
            self.acceptedProposals <- {}
        }

        destroy () {
            destroy self.inStudyProposals
            destroy self.acceptedProposals
        }

    }

    // For each user willing to join a community, the admin will need to create one
    // of this resources and publish to the user account the MembershipGranter
    // capability pointing to it. This MembershipIssuer resources should be deleted
    // after being used
    pub resource MembershipIssuer: MembershipGranter {

        pub var membership: @Membership?
  
        pub fun getMembership (): @Membership {
            var auxMembership: @Membership? <- nil
            self.membership <-> auxMembership
            return <- auxMembership!
        }

        pub fun hasBeenIssued(): Bool{
            if (self.membership == nil){
                return true
            } else {
                return false
            }
        }

        init (membership: @Membership) {
            self.membership <- membership
        }

        destroy () {
            destroy self.membership
        }
    }

    ///
    pub resource Membership {
        
        pub let user: Address
        pub let votingCapability: Capability<&{BallotBox}>
        pub let proposingCapability: Capability<&{ProposalCreator}>

        //
        // pub fun propose (proposal: @Proposal)
        // pub fun vote (proposalID: UInt64)
        //

        init (user: Address, votingCap: Capability<&{BallotBox}>, proposingCap: Capability<&{ProposalCreator}>) {
            self.user = user
            self.votingCapability = votingCap
            self.proposingCapability = proposingCap
        }
    }

    ///
    pub resource Proposal {
        
        access(self) let endingTime: UFix64
        access(self) let votes: @{Address: Vote}
        access(self) let results: {VotingResult: UFix64}
        access(self) var approved: VotingResult?
        access(self) var strategy: Strategies


        pub fun registerVote(vote: @Vote) {
            pre {
                self.endingTime > vote.getCastingTime() : "Voting has ended"
                self.votes[vote.getIssuer()] == nil : "Member has already vote"
            }
            self.votes[vote.getIssuer()] <-! vote
        }

        pub fun borrowVote(voter: Address): &Vote? {
            return &self.votes[voter] as &Vote?
        }

        pub fun resolveVoting (): VotingResult {
            
            pre {
                getCurrentBlock().timestamp > self.endingTime: "Voting has not finished yet"
                self.approved == nil : "Voting has already been resolved"
            }

            var favor: UFix64 = 0.0
            var against: UFix64 = 0.0

            // Iterate over the votes dictionary retrieving each address option,
            // then apply the appropriate factor to each vote and compose the 
            // result dictionary.
            switch self.strategy {
                case Strategies.oneVote:
                    
                case Strategies.tokenWeighted:
                 
                case Strategies.stakedFlowWeighted:
            }

            // This method should mutate the approved result field of the proposal
            // Would be worth to get rid of the votes dictionary for saving storage
            // or would it be better to keep it for accountability purposes
            return VotingResult.tie

        }

        access(self) fun computeVotes (votes: &{Address: Vote})  {
            for voter in votes.keys {
                 
            }
        }

        init (endingTime: UFix64, strategy: UInt) {
            self.endingTime = endingTime
            self.votes <- {}
            self.results = {}
            self.approved = nil
            self.strategy = Strategies(rawValue: strategy)
                ?? panic ("Invalid strategy")
        }

        destroy () {
            destroy self.votes
        }
    }

    ///
    pub resource Vote {

        access(self) let option: Bool
        access(self) let castingTime: UFix64
        access(self) let issuer: Address

        pub fun getIssuer(): Address {
            return self.issuer
        }

        pub fun getCastingTime(): UFix64 {
            return self.castingTime
        }

        pub fun getOption (): Bool {
            return self.option
        }

        init (option: Bool, issuer: Address) {
            self.option = option
            self.castingTime = getCurrentBlock().timestamp
            self.issuer = issuer
        }

    }


    ///
    /// Functions
    ///
    pub fun createCommunity (name: String, authAccountCapability: Capability<&AuthAccount>): @Community {
        return <- create Community(name: name, authAccountCapability: authAccountCapability)
    }

    init() {

    }

}
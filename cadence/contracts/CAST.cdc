// (read this after going through the rest of the contract) 
// Crazy idea, what if CAST is really a contract interface and each community is an
// implementation of that contract, allowing communities to define their own roles
// while providing default implementations for the 3 most basic roles (creating proposals,
// voting proposals and moderate community)
// This would be incredibly flexible but also will require more work to launch a new 
// community, needing to deploy a new contract for each of them, maybe that could be done through
// a no-code tool. For FLIPs it would just mean we would need to split the contract in two
// files, pub contract interface CAST and pub contract FLIPS: CAST
// There a couple of questions about the future scope of CAST beyond voting FLIPs that we may want
// to try to ask before tying ourselves to a certain architecture

/// tl;dr: CAST will allow anyone to create a @Community, and then to mint @Membership(s) 
/// to other accounts. At least the owner of the community will be able to create @Proposal(s)
/// and then members will be able to cast a @Vote about the proposal 
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

    ///
    /// Resources
    ///

    // Every different role inside a community will be represented by a resource interface
    // exposing only the functions that allow to execute that action.
    // Membership roles will have capabilities of this types depending on which role they hold
    pub resource interface ProposalCreator {

        pub fun createProposal(proposal: @Proposal)

    }

    // Pretty straight forward
    pub resource interface BallotBox {

        pub fun castVoteOnProposal()

    }

    // private capability published into account that allows you to get membership
    pub resource interface MembershipGranter {
        pub fun grantMembership (votingCap: Capability<&{BallotBox}>, proposingCap: Capability<&{ProposalCreator}>): @Membership
    }

    // public interface anyone can call it
    pub resource interface MembershipRequestManager {
        pub fun requestMembership (user: Address): String
    }

    pub resource interface CommunityAdmin {
        pub fun setupCommunity (votingCap: Capability<&{BallotBox}>, membershipCap: Capability<&{MembershipGranter}>)
        pub fun acceptProposal (proposalID: UInt64)
    }

    pub resource Community: CommunityAdmin, MembershipRequestManager, MembershipGranter, ProposalCreator, BallotBox {

        pub let communityAdminAuthAccountCapability: Capability<&AuthAccount>
        pub var grantMembershipCapability: Capability<&{MembershipGranter}>?
        pub var votingCapability: Capability<&{BallotBox}>?

        // this might be a dictionary?
        pub let members: [Address]

        // How to store proposals? maybe just an array? something that they need to be 
        // indexed by so we really need a dictionary?
        pub let inStudyProposals: @{UInt64: Proposal}

        pub let acceptedProposals: @{UInt64: Proposal}

        pub fun requestMembership (user: Address): String {
            pre {
                // check that no membership has been granted previously for that address
            }
            let adminAccountRef = self.communityAdminAuthAccountCapability.borrow()
                ?? panic ("Can't borrow community admin account reference")
            adminAccountRef.inbox.publish(self.grantMembershipCapability!, name: "cap name", recipient: user)
            return "cap name"
        }

        // createMembership function could ask for some FungibleTokens as a parameter
        // in order to make it not free for anyone to join a Community
        // 
        pub fun grantMembership (votingCap: Capability<&{BallotBox}>, proposingCap: Capability<&{ProposalCreator}>): @Membership {
            return <- create Membership(votingCap: votingCap, proposingCap: proposingCap)
        }

        // this would store a new proposal, how to manage accepted or not?
        pub fun createProposal(proposal: @Proposal) {
            self.inStudyProposals[proposal.uuid] <-! proposal
        }

        pub fun castVoteOnProposal() {

        }

        pub fun setupCommunity (votingCap: Capability<&{BallotBox}>, membershipCap: Capability<&{MembershipGranter}>) {
            self.votingCapability = votingCap
            self.grantMembershipCapability = membershipCap
        }

        pub fun acceptProposal (proposalID: UInt64) {
            // this has to be coded in a proper safer way
            self.acceptedProposals[proposalID] <-> self.inStudyProposals[proposalID]
        }

        init (authAccountCapability: Capability<&AuthAccount>) {
            self.communityAdminAuthAccountCapability = authAccountCapability
            // this two would need to be setup on a tx after saving the resource into storage
            self.grantMembershipCapability = nil
            self.votingCapability = nil
            self.members = []
            self.inStudyProposals <- {}
            self.acceptedProposals <- {}
        }

        destroy () {
            destroy self.inStudyProposals
            destroy self.acceptedProposals
        }

    }

    // This resource will represent the belonging of any user to a Community
    // we may want to do this an NFT, if not we should consider if we want a collection-like
    // resource to store all account membership or if we need to directly store memberships
    // on the account storage 
    pub resource Membership {
        // most likely this should also store user address
        pub let votingCapability: Capability<&{BallotBox}>
        pub let proposingCapability: Capability<&{ProposalCreator}>

        // This resource should hold capabilities to community stored objects and
        // expose functions that use those capabilities to allow Membership holders
        // certain actions.
        // Most basic action will be voting, we could then think about more complicated
        // role related actions, such as granting other users different roles or creating
        // proposals
        init (votingCap: Capability<&{BallotBox}>, proposingCap: Capability<&{ProposalCreator}>) {
            self.votingCapability = votingCap
            self.proposingCapability = proposingCap
        }
    }

    // This will keep the proposal content (thinking about flips, a link to the PR?
    // a bunch of text with the whole proposal?) and the votes
    pub resource Proposal {


    }

    // This is the part I'm most confused about. Should this be a FT? a NFT? not a 
    // token at all? this should be just yes / no? each proposal could define its own
    // vote options? for FLIPs its just yes/no, so we can keep it that way
    pub resource Vote {

    }


    ///
    /// Functions
    ///
    pub fun createCommunity (authAccountCapability: Capability<&AuthAccount>): @Community {
        return <- create Community(authAccountCapability: authAccountCapability)
    }

    init() {

    }

}
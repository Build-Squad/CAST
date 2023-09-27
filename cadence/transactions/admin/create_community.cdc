// This transaction will create and store a new community resource
import CAST from "./../../contracts/CAST.cdc"

transaction (name: String) {
    let communityAdminRef: &{CAST.CommunityAdmin}
    let votingCap: Capability<&{CAST.BallotBox}>
    let proposingCap: Capability<&{CAST.ProposalCreator}>

    prepare (communityAdmin: AuthAccount) {
        let adminAuthAccountCap = communityAdmin.linkAccount(/private/somepath)
            ?? panic("Cant get link to admin account")

        let newCommunity <- CAST.createCommunity(name: name, authAccountCapability: adminAuthAccountCap)
        let communityStoragePath = StoragePath(identifier: name)
            ?? panic("Error while creating community storage path")
        communityAdmin.save(<- newCommunity, to: communityStoragePath)
        let communityAdminPrivatePath = PrivatePath(identifier: name.concat("CommunityAdmin"))
            ?? panic("Error while creating community admin private path")
        communityAdmin.link<&{CAST.CommunityAdmin}>(communityAdminPrivatePath, target: communityStoragePath)
        let communityMembershipManagerPublicPath = PublicPath(identifier: name)
            ?? panic("Error while creating community membership manager public path")       
        communityAdmin.link<&{CAST.MembershipRequestManager}>(communityMembershipManagerPublicPath, target: communityStoragePath)
        self.communityAdminRef = communityAdmin.getCapability(communityAdminPrivatePath).borrow<&{CAST.CommunityAdmin}>()
            ?? panic ("cant borrow community admin")
        let communityVotingPrivatePath = PrivatePath(identifier: name.concat("Voting"))
            ?? panic("Error while creating community voting private path")        
        self.votingCap = communityAdmin.link<&{CAST.BallotBox}>(communityVotingPrivatePath, target: communityStoragePath)
            ?? panic("Cant link voting cap")
        let communityProposingPrivatePath = PrivatePath(identifier: name.concat("Proposing"))
            ?? panic("Error while creating community proposal creator private path")   
        self.proposingCap = communityAdmin.link<&{CAST.ProposalCreator}>(communityProposingPrivatePath, target: communityStoragePath)
            ?? panic("Cant link proposing cap")
    }

    execute {
        self.communityAdminRef.setupCommunity(votingCap: self.votingCap, proposingCap: self.proposingCap)
    }

}
// This transaction will create and store a new community resource
import CAST from "./../../contracts/CAST.cdc"

transaction () {

    prepare (communityAdmin: AuthAccount) {
        let adminAuthAccountCap = communityAdmin.linkAccount(/private/somepath)
            ?? panic("Cant get link to admin account")
        let newCommunity <- CAST.createCommunity(authAccountCapability: adminAuthAccountCap)
        communityAdmin.save(<- newCommunity, to: /storage/flips)
        communityAdmin.link<&{CAST.CommunityAdmin}>(/private/comadmin, target: /storage/flips)
        communityAdmin.link<&{CAST.MembershipRequestManager}>(/public/requestmembership, target: /storage/flips)
        let communityAdminRef = communityAdmin.getCapability(/private/comadmin).borrow<&{CAST.CommunityAdmin}>()
            ?? panic ("cant borrow community admin")
        let votingCap = communityAdmin.link<&{CAST.BallotBox}>(/private/voting, target: /storage/flips)
            ?? panic("Cant link voting cap")
        let membershipCap = communityAdmin.link<&{CAST.MembershipGranter}>(/private/voting, target: /storage/flips)
            ?? panic("Cant link voting cap")
        // this should be done in the tx body
        communityAdminRef.setupCommunity(votingCap: votingCap, membershipCap: membershipCap)
    }
}
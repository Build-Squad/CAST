// This transaction will mint and store the identification resource for a new user to
// became part of a community

import CAST from "./../../contracts/CAST.cdc"

transaction (community: Address) {
    let membershipRequestRef: &{CAST.MembershipRequestManager}
    
    prepare (user: AuthAccount) {

        // We actually need a programmatic way of accessing Communities metadata, 
        // maybe a CommunityMetadata standard?
        let flipsMembershipRequestPublicPath = PublicPath(identifier: "flipsmembership")!

        // Borrow a membership requester reference from the community public account
        self.membershipRequestRef = getAccount(community)
            .getCapability<&{CAST.MembershipRequestManager}>(flipsMembershipRequestPublicPath)
            .borrow()
            ?? panic("Cant borrow membership request manager")
        
        // Request to join the community
        let capName = self.membershipRequestRef.requestMembership(user: user.address)

        // Claim the capability that has been publish to be able to retrieve the membership resource
        let membershipGranterCap = user.inbox
            .claim<&{CAST.MembershipGranter}>(capName, provider: community)
            ?? panic("Cant get membership granter cap")
        
        let membership <- membershipGranterCap.borrow()!.getMembership()
        
        // Same issue with Community metadata
        let flipMembershipStoragePath = StoragePath(identifier: "flipmembership")!
        user.save( <- membership, to: flipMembershipStoragePath)

    }

}        
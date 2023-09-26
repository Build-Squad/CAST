// This transaction will mint and store the identification resource for a new user to
// became part of a community

import CAST from "./../../contracts/CAST.cdc"

transaction (community: Address) {
    let membershipRequestRef: &{CAST.MembershipRequestManager}
    
    prepare (user: AuthAccount) {
        self.membershipRequestRef = getAccount(community)
            .getCapability(/public/requestmembershipblic)
            .borrow<&{CAST.MembershipRequestManager}>()
            ?? panic("Cant borrow membership request manager")
        let capName = self.membershipRequestRef.requestMembership(user: user.address)
        let membershipGranter = user.inbox.claim<&{CAST.MembershipGranter}>(capName, provider: community)
            ?? panic("Cant get membership granter cap")
        membershipGranter.borrow()
    }

    execute {
        
    }

}        
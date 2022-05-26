package models

import (
	"fmt"

	"github.com/bjartek/overflow/overflow"
	s "github.com/brudfyi/flow-voting-tool/main/shared"
	"github.com/georgysavva/scany/pgxscan"
	"github.com/jackc/pgx/v4"
	"github.com/rs/zerolog/log"
)

type CommunityUser struct {
	Community_id int    `json:"communityId" validate:"required"`
	Addr         string `json:"addr" validate:"required"`
	User_type    string `json:"userType" validate:"required"`
}

type UserTypes []string

var USER_TYPES = UserTypes{"member", "author", "admin"}

type UserCommunity struct {
	Community
	Membership_type string `json:"membershipType,omitempty"`
}

type CommunityUserPayload struct {
	CommunityUser
	Signing_addr         string                  `json:"signingAddr" validate:"required"`
	Timestamp            string                  `json:"timestamp" validate:"required"`
	Composite_signatures *[]s.CompositeSignature `json:"compositeSignatures" validate:"required"`
}

func GetUsersForCommunity(db *s.Database, communityId, start, count int) ([]CommunityUser, int, error) {
	var users = []CommunityUser{}
	err := pgxscan.Select(db.Context, db.Conn, &users,
		`
		SELECT * FROM community_users WHERE community_id = $1
		LIMIT $2 OFFSET $3
		`, communityId, count, start)

	// If we get pgx.ErrNoRows, just return an empty array
	// and obfuscate error
	if err != nil && err.Error() != pgx.ErrNoRows.Error() {
		return nil, 0, err
	} else if err != nil && err.Error() == pgx.ErrNoRows.Error() {
		return []CommunityUser{}, 0, nil
	}

	// Get total number of users
	var totalRecords int
	countSql := `SELECT COUNT(*) FROM community_users WHERE community_id = $1`
	_ = db.Conn.QueryRow(db.Context, countSql, communityId).Scan(&totalRecords)

	return users, totalRecords, nil
}

func GetUsersForCommunityByType(db *s.Database, communityId, start, count int, user_type string) ([]CommunityUser, int, error) {
	var users = []CommunityUser{}
	err := pgxscan.Select(db.Context, db.Conn, &users,
		`
		SELECT * FROM community_users WHERE community_id = $1 AND user_type = $2
		LIMIT $3 OFFSET $4
		`, communityId, user_type, count, start)

	// If we get pgx.ErrNoRows, just return an empty array
	// and obfuscate error
	if err != nil && err.Error() != pgx.ErrNoRows.Error() {
		return nil, 0, err
	} else if err != nil && err.Error() == pgx.ErrNoRows.Error() {
		return []CommunityUser{}, 0, nil
	}

	// Get total number of users by type
	var totalRecords int
	countSql := `SELECT COUNT(*) FROM community_users WHERE community_id = $1 AND user_type = $2`
	_ = db.Conn.QueryRow(db.Context, countSql, communityId, user_type).Scan(&totalRecords)

	return users, totalRecords, nil
}

func GetCommunitiesForUser(db *s.Database, addr string, start, count int) ([]UserCommunity, int, error) {
	var communities = []UserCommunity{}
	err := pgxscan.Select(db.Context, db.Conn, &communities,
		`
		SELECT
			communities.*,
			community_users.user_type as membership_type
		FROM communities
		LEFT JOIN community_users ON community_users.community_id = communities.id
		WHERE community_users.addr = $1
		LIMIT $2 OFFSET $3
		`, addr, count, start)

	// If we get pgx.ErrNoRows, just return an empty array
	// and obfuscate error
	if err != nil && err.Error() != pgx.ErrNoRows.Error() {
		return nil, 0, err
	} else if err != nil && err.Error() == pgx.ErrNoRows.Error() {
		return []UserCommunity{}, 0, nil
	}

	// Get total number of communities by user
	var totalRecords int
	countSql := `
	SELECT
		COUNT(communities.id)
	FROM communities
	LEFT JOIN community_users ON community_users.community_id = communities.id
	WHERE community_users.addr = $1
	`
	_ = db.Conn.QueryRow(db.Context, countSql, addr).Scan(&totalRecords)

	return communities, totalRecords, nil
}

func (u *CommunityUser) GetCommunityUser(db *s.Database) error {
	sql := `
	SELECT * from community_users as u
	WHERE u.community_id = $1 AND u.addr = $2 AND u.user_type = $3
	`
	return pgxscan.Get(db.Context, db.Conn, u, sql, u.Community_id, u.Addr, u.User_type)
}

func GetAllRolesForUserInCommunity(db *s.Database, addr string, communityId int) ([]CommunityUser, error) {
	var users = []CommunityUser{}
	err := pgxscan.Select(db.Context, db.Conn, &users,
		`
		SELECT * FROM community_users WHERE community_id = $1 AND addr = $2
		`, communityId, addr)

	// If we get pgx.ErrNoRows, just return an empty array
	// and obfuscate error
	if err != nil && err.Error() != pgx.ErrNoRows.Error() {
		return nil, err
	} else if err != nil && err.Error() == pgx.ErrNoRows.Error() {
		return []CommunityUser{}, nil
	}
	return users, err
}

func (u *CommunityUser) Remove(db *s.Database) error {
	_, err := db.Conn.Exec(db.Context,
		`
		DELETE FROM community_users
		WHERE community_id = $1 AND addr = $2 AND user_type = $3
	`, u.Community_id, u.Addr, u.User_type)

	return err // will be nil unless something went wrong
}

// Create any of the 3 roles for the user that they dont have already
func GrantAdminRolesToAddress(db *s.Database, communityId int, addr string) error {
	userTypes := UserTypes{"admin", "author", "member"}
	for _, role := range userTypes {
		userRole := CommunityUser{Addr: addr, Community_id: communityId, User_type: role}
		// Check if role exists.  If we throw a ErrNoRows err, create the role
		if err := userRole.GetCommunityUser(db); err != nil {
			if err := userRole.CreateCommunityUser(db); err != nil {
				log.Error().Err(err).Msgf("db error creating role %s for addr %s for communityId %d", role, addr, communityId)
				return err
			}
		}
	}
	return nil
}

// Create either author or member role for the user that they dont have already
func GrantAuthorRolesToAddress(db *s.Database, communityId int, addr string) error {
	userTypes := UserTypes{"author", "member"}
	for _, role := range userTypes {
		userRole := CommunityUser{Addr: addr, Community_id: communityId, User_type: role}
		// Check if role exists.  If we throw a ErrNoRows err, create the role
		if err := userRole.GetCommunityUser(db); err != nil {
			if err := userRole.CreateCommunityUser(db); err != nil {
				log.Error().Err(err).Msgf("db error creating role %s for addr %s for communityId %d", role, addr, communityId)
				return err
			}
		}
	}
	return nil
}

func (u *CommunityUser) CreateCommunityUser(db *s.Database) error {
	err := db.Conn.QueryRow(db.Context,
		`
		INSERT INTO community_users(community_id, addr, user_type)
		VALUES($1, $2, $3)
		RETURNING community_id, addr, user_type
	`, u.Community_id, u.Addr, u.User_type).Scan(&u.Community_id, &u.Addr, &u.User_type)

	return err // will be nil unless something went wrong
}

// when a user creates a community, they are automatically assigned
// all roles
func GrantRolesToCommunityCreator(db *s.Database, addr string, communityId int) error {

	for _, userType := range USER_TYPES {
		communityUser := CommunityUser{Addr: addr, Community_id: communityId, User_type: userType}
		if err := communityUser.CreateCommunityUser(db); err != nil {
			return err
		}
		log.Debug().Msgf("granted addr %s role %s for community %d", addr, userType, communityId)
	}
	return nil
}

// Validate account's role
func EnsureRoleForCommunity(db *s.Database, addr string, communityId int, userType string) error {
	user := CommunityUser{Addr: addr, Community_id: communityId, User_type: userType}
	return user.GetCommunityUser(db)
}

func EnforceTokenThreshold(db *s.Database, addr string, communityId int) error {

	c := Community{ID: communityId}
	if err := c.GetCommunity(db); err != nil {
		switch err.Error() {
		case pgx.ErrNoRows.Error():
			ERROR := fmt.Errorf("community %d does not exist", communityId)
			return ERROR
		default:
			ERROR := fmt.Errorf("db error getting community %d: %s", communityId, err.Error())
			return ERROR
		}
	}

	g := overflow.NewOverflow().Start()
	result := g.ScriptFromFile("./scripts/get_balance.cdc")
	fmt.Println(result)

	return nil
}

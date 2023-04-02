use admin;
db.createUser(
    {
        user: "appuser",
        pwd: "test",
        roles: [
            {role: "dbAdminAnyDatabase"}
        ]
    }
);
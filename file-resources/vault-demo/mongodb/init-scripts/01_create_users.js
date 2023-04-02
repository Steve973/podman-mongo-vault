use admin;
db.createUser(
    {
        user: "@mongo.app-user.name@",
        pwd: "test",
        roles: [
            {role: "dbAdminAnyDatabase"}
        ]
    }
);
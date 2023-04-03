use admin;
db.createUser(
    {
        user: "@mongo.app-user.name@",
        pwd: `${MONGO_APPUSER_PASSWORD}`,
        roles: [
            {role: "dbAdminAnyDatabase"}
        ]
    }
);
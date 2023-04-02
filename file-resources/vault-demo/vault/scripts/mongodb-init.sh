#!/bin/bash

# Enable the database secrets engine
vault secrets enable -path=mongodb database

# Configure MongoDB secrets engine
vault write mongodb/config/mongo-test \
      plugin_name=mongodb-database-plugin \
      allowed_roles="tester" \
      connection_url="mongodb://{{username}}:{{password}}@mongodb-pod:${mongo.port.container}/admin?tls=false" \
      username="@mongo.root-user.name@" \
      password="test"

# Create a role
vault write mongodb/roles/tester \
    db_name=mongo-test \
    creation_statements='{ "db": "admin", "roles": [{ "role": "readWrite" }, {"role": "read", "db": "foo"}] }' \
    default_ttl="1h" \
    max_ttl="24h"
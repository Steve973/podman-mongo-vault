#!/bin/bash

echo "Setting up MongoDB replica set"
mongod "$@"

echo "Waiting for initialization"
RESTARTED="MongoServerError: command replSetGetStatus requires authentication"
STATUS="STARTING"
while ! [[ "${STATUS}" =~ ${RESTARTED} ]]
do
  STATUS=$(mongosh --quiet --eval 'rs.status()' 2>&1)
  sleep 2
done

echo "Running replica set initiation"
mongosh --quiet \
  --username @mongo.root-user.name@ \
  --password test \
  --authenticationDatabase admin \
  --eval "rs.initiate( { _id: '@mongo.replica-set.name@', version: 1, members: [ { _id: 0, host : 'mongodb-pod:@mongo.port.container@' } ] } )"

echo "Waiting for replica set initiation to complete"
PRIMARY=false
while [ "${PRIMARY}" = false ]; do
  PRIMARY=$(mongosh --quiet --eval "db.isMaster().ismaster" 2>&1)
  sleep 1
done

echo "Stopping MongoDB init container with 120 second timeout"
mongosh --quiet \
  --username @mongo.root-user.name@ \
  --password test \
  --authenticationDatabase admin \
  --eval 'db.getSiblingDB("admin").shutdownServer({ "timeoutSecs": 120 })'

echo "Replica set initiation complete"

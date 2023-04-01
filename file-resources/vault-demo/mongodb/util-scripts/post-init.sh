#!/bin/bash

echo "Running replica set initiation"
mongosh --quiet \
--username superuser \
--password test \
--authenticationDatabase admin \
--eval "rs.initiate( { _id: 'demo-rs', version: 1, members: [ { _id: 0, host : 'mongodb-pod-mongodb:27017' } ] } )"

echo "Waiting for replica set initiation to complete"
PRIMARY=false
while [ "${PRIMARY}" = false ]; do
  PRIMARY=$(mongosh --quiet --eval "db.isMaster().ismaster")
  sleep 1
done
echo "Replica set initiation complete"

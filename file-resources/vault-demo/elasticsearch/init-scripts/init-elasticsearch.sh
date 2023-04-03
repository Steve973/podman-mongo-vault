#!/bin/bash

echo "Waiting for Elasticsearch availability"
until curl -s http://localhost:@elastic.port.container@ | grep -q "missing authentication credentials"
do
  sleep 2
done

echo "Setting kibana_system password"
until curl -s -X POST -u "@elastic.admin-user.name@:${ELASTIC_ADMIN_PASSWORD}" -H "Content-Type: application/json" \
"http://localhost:@elastic.port.container@/_security/user/@kibana.system-user.name@/_password" \
-d "{\"password\":\"${KIBANA_SYSTEM_PASSWORD}\"}" | grep -q "^{}"
do
  sleep 2
done

echo "Elasticsearch initialization complete"

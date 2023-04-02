#!/bin/bash

echo "Creating replica set key"
openssl rand -base64 756 > /data/db/rs-keys/rs-key
chmod 400 /data/db/rs-keys/rs-key

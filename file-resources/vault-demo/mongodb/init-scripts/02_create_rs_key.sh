#!/bin/bash

openssl rand -base64 756 > /rs-keys/rs-key
chmod 400 /rs-keys/rs-key

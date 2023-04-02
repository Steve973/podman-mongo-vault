#!/bin/bash

echo "Importing data"
mongorestore --archive=/data/db/archive/sampledata.archive

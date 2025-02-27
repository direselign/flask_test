#!/bin/bash

# Load environment variables
source .env

# Test PostgreSQL connection
PGPASSWORD=$DB_PASSWORD psql \
    -h $DB_HOST \
    -U $DB_USERNAME \
    -d $DB_NAME \
    -p $DB_PORT \
    -c "\dt"

echo "If you see tables listed above, the connection was successful!" 
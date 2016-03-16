#!/usr/bin/env bash

if [ -f 'functions.sh' ]; then
  . functions.sh
else
  echo "Required file 'functions.sh' not found"
  exit 1
fi

docker-compose up -d canvas-postgres

green "Sleeping for 10 seconds to give postgres time to initialize"
sleep 10 

docker-compose run --rm canvas-web /usr/src/app/setup-db.sh

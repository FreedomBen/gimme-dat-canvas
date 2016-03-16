#!/usr/bin/env bash

if [ -f 'functions.sh' ]; then
  . functions.sh
else
  echo "Required file 'functions.sh' not found"
  exit 1
fi

docker-compose up postgres

green "Sleeping while postgres initializes"

docker run --rm gimme-dat-canvas /usr/src/app/setup-db.sh

#!/usr/bin/env bash

export CANVAS_LMS_ACCOUNT_NAME=Chiefs
export CANVAS_LMS_ADMIN_EMAIL=andy.reid@example.com
export CANVAS_LMS_ADMIN_PASSWORD="password"
export CANVAS_LMS_STATS_COLLECTION="opt_out"

bundle exec rake db:create \
  && bundle exec rake db:initial_setup

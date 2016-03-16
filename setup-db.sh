#!/usr/bin/env bash

export CANVAS_LMS_ADMIN_EMAIL=andy.reid@example.com
export CANVAS_LMS_ADMIN_PASSWORD="password opt_out"

bundle exec rake db:create
bundle exec rake db:initial_setup

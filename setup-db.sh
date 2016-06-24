#!/usr/bin/env bash

if [ -z ${CANVAS_LMS_ACCOUNT_NAME+x} ]; then export CANVAS_LMS_ACCOUNT_NAME=Chiefs; fi
if [ -z ${CANVAS_LMS_ADMIN_EMAIL+x} ]; then export CANVAS_LMS_ADMIN_EMAIL=andy.reid@example.com; fi
if [ -z ${CANVAS_LMS_ADMIN_PASSWORD+x} ]; then export CANVAS_LMS_ADMIN_PASSWORD="password"; fi
if [ -z ${CANVAS_LMS_STATS_COLLECTION+x} ]; then export CANVAS_LMS_STATS_COLLECTION="opt_out"; fi

bundle exec rake db:create \
  && bundle exec rake db:initial_setup

#!/usr/bin/env bash

LOG_FILE="canvas-lms-master-build-log-$(date +'%Y%m%d_%H%M%S').log"
LOG_FILE_NC="canvas-lms-master-build-log-$(date +'%Y%m%d_%H%M%S')-nc.log"

cd /home/bporter/gitclone/gimme-dat-canvas

if [ -f "functions.sh" ]; then
  . functions.sh
else
  echo 'Death by lack of function.sh!'
fi

./build-dat-image-from-master.sh >$LOG_FILE 2>&1

if [ "$?" != '0' ]; then
  # upload the log as a snippet
  cat $LOG_FILE | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" >$LOG_FILE_NC
  curl -F file=@$LOG_FILE_NC -F channels=$CHANNEL -F token="$SLACK_TOKEN" -F username=$USERNAME -F icon_emoji=$ICON_EMOJI https://slack.com/api/files.upload
fi

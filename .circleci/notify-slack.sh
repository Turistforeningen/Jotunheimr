#!/bin/bash

if [ -z $1 ] || [ -z $2 ] || [ -z $3 ]; then
  echo "Missing input parameters to send slack notifications. Aborting!"
  exit 1
fi

app=$1 # app name as defined in Github
pipeline=$2 # pipeline name
success=$3 # true or false

if [ "$success" = true ] ; then
    color="#36a64f"
    button_style="primary"
    status="succeeded"
else
   color="#FF0000"
   button_style="danger"
   status="failed"
fi

echo "sending slack notification ..."
curl -X POST -H 'Content-type: application/json' \
--data '{"attachments": [{"fallback": "'${app}' Build result","color": "'${color}'" ,"pretext": "'${app}' '${pipeline}' pipeline:","title": "Job: ['${CIRCLE_JOB}'] for ('${app}') '${status}'. Check circleci for details.","actions": [{"type": "button","name": "check_workflow","text": "Check Workflow","url": "https://circleci.com/workflow-run/'${CIRCLE_WORKFLOW_ID}'","style": "'${button_style}'"},{"type": "button","name": "check_job","text": "Check Job","url": "https://circleci.com/gh/Turistforeningen/'${app}'/'${CIRCLE_BUILD_NUM}'","style": "'${button_style}'"}]}] }' ${SLACK_WEBHOOK_CIRCLECI}

if [ $? != 0 ]; then
  echo "Failed to send a slack notification!"
  exit 1
fi

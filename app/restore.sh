#!/bin/bash

test -z $DEBUG || set -x

started=$(date +%s)
startedAt=$(date -u -d @$started +"%Y-%m-%dT%H:%M:%SZ")

most_recent_path=$(aws s3 ls $S3_PATH --recursive | sort | tail -n 1 | awk '{print $4}') # get most recent object in bucket
VERSION=$(echo $most_recent_path | cut -d'/' -f2-)                                       # remove bucket name from most_recent_pathj
echo "found ${most_recent_path} as most recent object with name ${most_recent_obj_name}"

s3obj=$VERSION # s3obj="$VERSION.tgz.aes"
tarfile="restore.tgz"

if [[ ! -z "${WIPE_TARGET}" && "${DATA_PATH}" != "/" ]]; then
  find $DATA_PATH/ -mindepth 1 -delete
fi

output=$(aws s3 cp $PARAMS "${S3_PATH}/${s3obj}" "$DATA_PATH" 2>&1)
code=$?
if [ $code ]; then
  cd $DATA_PATH
  cp $s3obj $tarfile # openssl enc -aes-256-cbc -md sha512 -pbkdf2 -iter 100100 -pass "pass:${AES_PASSPHRASE}" -in $s3obj -out $tarfile -d
  ssl_code=$?
  tar xzf $tarfile
  tar_code=$?

  if [[ $ssl_code && $tar_code ]]; then
    result="success"
  else
    result="error:unable to decrypt or untar"
  fi
else
  result="error:$code"
fi

rm -f $s3obj
rm -f $tarfile

printf "{\"restore\":{\"state\":\"restored\" } }\n"

if [[ ! -z "$POST_RESTORE_COMMAND" && "$result" == "success" ]]; then
  restore_cmd_out=$($POST_RESTORE_COMMAND)
  printf "{\"restore\":{\"state\":\"post-command-run\", \"output\":\"%s\", \"exitCode\":\"%s\"}}\n" "$restore_cmd_out" "$?"
fi

finished=$(date +%s)
duration=$((finished - started))
printf "{\"restore\":{ \"state\":\"%s\", \"startedAt\":\"%s\",\"duration\":\"%i seconds\",\"from\":\"%s/%s\",\"output\":\"%s\"}}\n" "$result" "$startedAt" "$duration" "$S3_PATH" "$s3obj" "$output"

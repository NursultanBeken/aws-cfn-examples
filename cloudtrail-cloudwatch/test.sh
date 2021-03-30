#!/usr/bin/env bash
BUCKET_NAME=$1

# create test dummy file
echo "hello from bucket" > test.txt
# put file into s3 bucket
aws s3api put-object --bucket $BUCKET_NAME --key test.txt --body test.txt
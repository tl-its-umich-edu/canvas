#!/bin/bash -x 

if [ -z "${AWS_S3_BUCKET}" ]; then
    AWS_S3_BUCKET="umich-tl-sis"
    echo "aws_s3_bucket set to default value of umich-tl-sis"
fi
echo "AWS_S3_BUCKET set to ${AWS_S3_BUCKET}"

RCLONE_OPTS="--config /app/config/secrets/rclone.conf --cache-dir /tmp/.cache/rclone/"

# rclone --config ./rclone.conf config show
rclone ${RCLONE_OPTS} lsd ~/

rclone -vv ${RCLONE_OPTS} ls sftp:/OUTBOUND

# SIS upload
## 1.copy SIS zip file from the SFTP server
rclone -vv ${RCLONE_OPTS} --exclude '.*' copy sftp:/OUTBOUND/ /usr/src/app/data


## 2. start with the sis_upload.rb
ruby /usr/src/app/sis_upload.rb

if [ $? -eq 0 ] 
then
    ##3. archive the SIS zip file to AWS
    rclone copy ${RCLONE_OPTS} --no-traverse --exclude '.*' /usr/src/app/data aws:${AWS_S3_BUCKET}/archive

    ## 4. remove the SIS zip file from SFTP server
    rclone -vv ${RCLONE_OPTS} delete sftp:/OUTBOUND/

else
    echo "ERROR: There was a problem in SIS upload process. Please check the details in log file. "
fi


## SIS set url script
ruby /usr/src/app/sis_set_url.rb

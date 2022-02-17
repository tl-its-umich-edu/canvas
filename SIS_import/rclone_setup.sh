#!/bin/bash 

# rclone --config ./rclone.conf config show
rclone --config ./rclone.conf lsd ~/

rclone -vv --config ./rclone.conf ls sftp:/OUTBOUND

# SIS upload
## 1.copy SIS zip file from the SFTP server
rclone -vv --config ./rclone.conf --exclude '.*' copy sftp:/OUTBOUND/ /usr/src/app/data

## 2. start with the sis_upload.rb
ruby /usr/src/app/sis_upload.rb

## 3. archive the SIS zip file to AWS
rclone copy --config ./rclone.conf --no-traverse --exclude '.*' /usr/src/app/data aws:umich-tl-sis/archive

## 4. remove the SIS zip file from SFTP server
rclone -vv --config ./rclone.conf delete sftp:/OUTBOUND/

## SIS set url script
ruby /usr/src/app/sis_set_url.rb

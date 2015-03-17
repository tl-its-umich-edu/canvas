#!/bin/sh --

#Helper script for use on build server.
#
# Intended to be run after the Maven build is successful.
#

# Debugging: -x to enable, +x to disable
set +x

timestamp=$(date +%Y%m%d%H%M%S)

# configuration-files.txt contains list of files to archive.
# Use "-C <dir>" to change to <dir> before processing remaining files.
#tar --exclude .svn -cf target/configuration-files.${timestamp}.tar \
# $(cat configuration-files.txt)

cd target

warFilename=$(ls *.war | head -1)
targetFilename=$(basename ${warFilename} .war)

mv ${targetFilename}.war ${targetFilename}.${timestamp}.war

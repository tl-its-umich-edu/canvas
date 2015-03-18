#!/bin/sh --

#Helper script for use on build server.
#
# Intended to be run after the Maven build is successful.
#

# Debugging: -x to enable, +x to disable
set -x

timestamp=$(date +%Y%m%d%H%M%S)
cd sectionsUtilityTool
cd target
warFilename=$(ls *.war | head -1)
targetFilename=$(basename ${warFilename} .war)
mv ${targetFilename}.war ${targetFilename}.${timestamp}.${GIT_BRANCH}.war


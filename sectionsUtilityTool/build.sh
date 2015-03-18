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
#origin/TLUNIZIN-424, origin/master
branch=${GIT_BRANCH}
btemp=${branch:7}
mv ${targetFilename}.war ${targetFilename}.${timestamp}.${btemp}.war


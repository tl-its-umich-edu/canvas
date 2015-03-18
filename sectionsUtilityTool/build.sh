#!/bin/sh --

#Helper script for use on build server.
# Intended to be run after the Maven build is successful.

# Debugging: -x to enable, +x to disable
set +x

timestamp=$(date +%Y%m%d%H%M%S)
cd sectionsUtilityTool
cd target
warFilename=$(ls *.war | head -1)
targetFilename=$(basename ${warFilename} .war)
#GIT_BRANCH =origin/TLUNIZIN-424 or origin/master jenkins environmental variable to get git branch
branch=${GIT_BRANCH}
# substring'ing  ignores string before /
btemp=${branch:7}
mv ${targetFilename}.war ${targetFilename}.${timestamp}.${btemp}.war


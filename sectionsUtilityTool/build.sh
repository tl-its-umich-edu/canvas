#!/bin/sh --

#Helper script for use on build server.
# Intended to be run after the Maven build is successful.

# Debugging: -x to enable, +x to disable
set -x

timestamp=$(date +%Y%m%d%H%M%S)
cd sectionsUtilityTool
cd target
warFilename=$(ls *.war | head -1)
targetFilename=$(basename ${warFilename} .war)
#GIT_BRANCH =origin/TLUNIZIN-424 or origin/master jenkins environmental variable to get git branch
branch=${GIT_BRANCH}
if [ -n "$branch" ]; then
btemp=$(basename ${branch} /)
else
btemp="local"
fi
mv ${targetFilename}.war ${targetFilename}.${btemp}.${timestamp}.war


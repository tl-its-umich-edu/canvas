#!/bin/sh --

## find the next Jenkins build number from environment setting: BUILD_NUMBER
## if missing, set the number to be 1
echo "shell env variable BUILD_NUMBER is ${BUILD_NUMBER}"
build_number=${BUILD_NUMBER:=1}

## check the artifact folder, whether it exists or not
if [ ! -d "artifact" ]; then
    ## no artifact folder
    ## create such folder first
    echo "create artifact folder"
    mkdir artifact
    chmod -R 755 artifact
fi
echo "will generate zip file for build number: ${build_number}"
find . -maxdepth 1 -name "*.rb" -exec tar -rf ./artifact/SIS_import_$build_number.tar {} \;


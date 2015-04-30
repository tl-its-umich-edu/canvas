#!/bin/bash

#build.sh

# Build script to assemble PracticeCourseGenerator.
# Creates a tar containing version.txt and practiceCourseGenerator.py

set -x

# return a sortable timestamp as a string without a newline on the end.
function niceTimestamp {
    echo $(date +"%F-%H-%M")
}

function atStep {
    local msg=$1
    echo "+++ $1"
}

# make a clean directory to hold any build ARTIFACTS
function makeARTIFACTSDir {

    if [ -e ./ARTIFACTS ]; then
        rm -rf ./ARTIFACTS;
    fi

    mkdir ./ARTIFACTS
}

# make a clean directory to hold any build ARTIFACTS
function makeCompressionDir {

    if [ -e ./practiceCourseGenerator ]; then
        rm -rf ./practiceCourseGenerator;
    fi

    mkdir ./practiceCourseGenerator
}

# copy py file
function copyTarFile {
    atStep "copy py file"
    mv practiceCourseGenerator.tar.gz ./ARTIFACTS
}

# copy file to directory that will be compressed
function copyFileToCompressDir {
    atStep "copy py file to Compress Dir"
    cp practiceCourseGenerator.py ./practiceCourseGenerator
    cp version.txt ./practiceCourseGenerator
}

# compress directory
function tarDirectory {
	atStep "tar directory"
	tar czf practiceCourseGenerator.tar.gz practiceCourseGenerator
}

# create file 'version.txt' with some version information to make it available 
# in the build.
function makeVersion {
    atStep "makeVersion"
    FILE="./version.txt"
    echo  "build: PracticeCourseGenerator" >| $FILE
    echo  "time: $ts " >> $FILE

    last_commit=$(git rev-parse HEAD);
    echo "last_commit: $last_commit" >> $FILE
    echo -n "tag: " >> $FILE
    echo $(git describe --tags) >> $FILE
    
    echo >> $FILE
}

ts=$(niceTimestamp)

# create directory that will be compressed into tar file
makeCompressionDir

# Create version information file.
# can be included in the tar file.
makeVersion

# copy files that will be used (python script and version) to a directory 
# that will later be compressed into a tar
copyFileToCompressDir

# compress directory using tar command
tarDirectory

# setup build environment
makeARTIFACTSDir

# Copy TAR file to ARTIFACTS directory
copyTarFile

# Let anyone on the server read the artifacts.  All secure information is
# handled by back channels.
chmod a+r ./ARTIFACTS/*

# Display the ARTIFACTS created for confirmation.
atStep "display artifacts"
ls -l ./ARTIFACTS

#echo "++++++++++++ NOTE: The unresolved specs error message seems to be harmless."
#end
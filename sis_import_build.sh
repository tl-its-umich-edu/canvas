#!/bin/sh --

## find the next Jenkins build number
## in a file named nextBuildNumber two parent directory up
parentdir="$(dirname "$(pwd)")"
parentdir="$(dirname $parentdir)"
echo $parentdir
FILE="$parentdir/nextBuildNumber"

if [ -f $FILE ]; then
        ## found file named nextBuilNumber
        echo "File $FILE exists"
        ## get the build number stored in the file
        build_number=`cat $FILE`
        echo $build_numbe

        ## move to the folder with SIS scripts
        cd SIS_import
        ## check the artifact folder, whether it exists or not
        if [ ! -d "artifact" ]; then
                ## no artifact folder
                ## create such folder first
                echo "create artifact folder"
                mkdir artifact
                chmod -R 755 artifact
        else
                ## exist artifact
                echo "artifact Folder exist"
        fi
        find . -maxdepth 1 -name "*.rb" -exec tar -rf ./artifact/SIS_import_$build_number.tar {} \;
else
        # no file named nextBuildNumber
        echo "File $FILE does not exists"
fi

#!/usr/bin/env ruby

require "json"
require "fileutils"


def upload_to_canvas(fileName, token, server, outputDirectory)
  # upload start time
  p "upload start time : " + Time.new.inspect

  # get file names
  currentFileBaseName = File.basename(fileName)
  currentFileBaseNameWithoutExtension = File.basename(fileName, ".zip")

  #open the output file
  begin
    outputFile = File.open(outputDirectory + currentFileBaseNameWithoutExtension + ".txt", "w")

    # Web Service call
    p fileName
    p server

    json_data=`curl -H "Content-Type: application/zip" --data-binary @#{fileName} -H "Authorization: Bearer #{token}" #{server}/api/v1/accounts/1/sis_imports.json?import_type=instructure_csv`

    outputFile.write("#{json_data}\n")
    parsed = JSON.parse(json_data)

    job_id=parsed["id"]

    outputFile.write("the job id is: #{job_id}\n")
    outputFile.write("here is the job #{job_id} status: \n")

    #set the error flag, default to be false
    upload_error = false

    begin
      #sleep every 10 sec, before checking the status again
      sleep(10);

      json_result=`curl '#{server}/api/v1/accounts/1/sis_imports/#{job_id}' -H "Authorization: Bearer #{token}"`

      #print out the whole json result
      outputFile.write("#{json_result}\n")

      #parse the status percentage
      parsed_result=JSON.parse(json_result)
      if (parsed_result["errors"])
        ## break and print error
        error_array=parsed_result["errors"]
        outputFile.write(error_array[0])
        outputFile.write("\n")

        ##set the error flag to be true
        upload_error = true;

        break;
      else
        job_progress=parsed_result["progress"]
        outputFile.write("processed #{job_progress}\n")
      end
    end until job_progress == 100

    if (!upload_error)
      # print out the process warning, if any
      if (parsed_result["processing_errors"])
        outputFile.write("upload process errors: #{parsed_result["processing_errors"]}\n")
      elsif (parsed_result["processing_warnings"])
        outputFile.write("upload process warning: #{parsed_result["processing_warnings"]}\n")
      else
        outputFile.write("upload process finished successfully\n")
      end
    end
  # close output file
  ensure
    outputFile.close unless outputFile == nil
  end

  # upload stop time
  p "upload stop time : " + Time.new.inspect

end ## end of method definition

# there should be two command line argument when invoking this Ruby script
# like ruby ./SIS_upload.rb <the_token_file_path> <the_server_name> <the_workspace_path>

# the access token
token = ""
# the Canvas server name
server = ""
# the current working directory
currentDirectory=""

# the command line argument count
count=1
# iterate through the inline arguments
ARGV.each do|arg|
  if (count==1)
    File.open(arg, 'r') do |tokenFile|
      while line = tokenFile.gets
        # only read the first line, which is the token value
        token=line.strip
        break
      end
    end
  elsif (count==2)
    # the second argument should be the server name
    server=arg
  elsif (count==3)
    # the third path should be the workspace path
    currentDirectory=arg
  else
   # break
  end

  #increase count
  count=count+1
end

# get the current working directory and the archive folder inside
archiveDirectory=currentDirectory + "archive/"
outputDirectory=currentDirectory + "logs/"

p "server=" + server
p "current directory: " + currentDirectory
p "archive directory: " + archiveDirectory
p "output directory: " + outputDirectory

# search for the canvas import zip file
fileNameSearch=currentDirectory+ "Canvas_Extract_*.zip"
fileNames = Dir[fileNameSearch];
if (fileNames.length == 1)
  ## get the name of file to process
  fileName=fileNames[0]
  currentFileBaseName = File.basename(fileName)

  # upload the file to canvas server
  upload_to_canvas(fileName, token, server, outputDirectory)

  # move file to archive directory after processing
  FileUtils.mv(fileName, archiveDirectory+currentFileBaseName)
  abort("SIS upload finished with " + fileName)
else
  abort("Cannot find file")
end


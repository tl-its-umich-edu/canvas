#!/usr/bin/env ruby

require "json"
require "fileutils"
require "rubygems"
require "nokogiri"


def upload_to_canvas(fileName, token, server, outputDirectory)

	# get file names
	currentFileBaseName = File.basename(fileName)
	currentFileBaseNameWithoutExtension = File.basename(fileName, ".zip")


	#set the error flag, default to be false
	upload_error = false

	#open the output file
	begin
		outputFile = File.open(outputDirectory + currentFileBaseNameWithoutExtension + ".txt", "w")

		# Web Service call
		p fileName
		p server

		json_data=`curl -H "Content-Type: application/zip" --data-binary @#{fileName} -H "Authorization: Bearer #{token}" #{server}/api/v1/accounts/1/sis_imports.json?import_type=instructure_csv`

		outputFile.write("#{json_data}\n")
		parsed = parseJson(json_data)

		if (parsed["errors"])
			## break and print error
			error_array=parsed["errors"]
			## hashmap ["message"=>"error_message"
			uploadError = error_array[0]["message"]
			outputFile.write("upload error: " + uploadError)
			outputFile.write("\n")

			return uploadError
		end

		job_id=parsed["id"]

		begin
			#open a separate file to log the job id
			outputIdFile = File.open(outputDirectory + currentFileBaseNameWithoutExtension + "_id.txt", "w")
			# write the job id into the id file
			outputIdFile.write(job_id);
		ensure
			outputIdFile.close unless outputIdFile == nil
		end

		outputFile.write("the job id is: #{job_id}\n")
		outputFile.write("here is the job #{job_id} status: \n")

		begin
			#sleep every 10 sec, before checking the status again
			sleep(10);

			json_result=`curl '#{server}/api/v1/accounts/1/sis_imports/#{job_id}' -H "Authorization: Bearer #{token}"`

			#print out the whole json result
			outputFile.write("#{json_result}\n")

			#parse the status percentage
			parsed_result=parseJson(json_result)

		if (parsed_result["errors"])
				## break and print error
				uploadError=parsed_result["errors"]
				## hashmap ["message"=>"error_message"
				outputFile.write("upload error: " + uploadError)
				outputFile.write("\n")

				break
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
  
	return upload_error

end ## end of method definition

def parseJson(data)
	begin
		parsedJson = JSON.parse(data)
	rescue JSON::ParserError => e
		# sometimes a html document is returned, containing the following secion
		#<div class="text">
		#<p>
		#<img src="https://s3.amazonaws.com/canvas-maintenance/logo.png" /> &nbsp; Instructure Canvas is currently down for maintenance.
		#	</p>
		#</div>
		# try html parser, and print out the error message
		page = Nokogiri::HTML(data)
		error_text = page.xpath('//body/div[@class="text"]/p').text
		error_text = error_text.gsub(/^\s+/,'')
		error_text = error_text.gsub(/\n/,'')
		parsedJson={"errors"=>[{"message"=>error_text}]}
	end

	# return JSON
	return parsedJson
end

# there should be two command line argument when invoking this Ruby script
# like ruby ./SIS_upload.rb <the_token_file_path> <the_server_name> <the_workspace_path>

# token file name
tokenFile = ""
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
		tokenFile = arg
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

if (Dir[tokenFile].length != 1)
	## token file
        uploadError = "Cannot find token file #{tokenFile}."
else
        File.open(tokenFile, 'r') do |tFile|
	        while line = tFile.gets
	          # only read the first line, which is the token value
	                token=line.strip
	                break
	        end
        end
	if (token=="")
		uploadError="Empty token for Canvas upload."
	end
end

if (uploadError)
elsif (Dir[currentDirectory].length != 1)
	## working directory
	uploadError = "Cannot find current working directory " + currentDirectory
elsif (Dir[archiveDirectory].length != 1)
	## archive directory
	uploadError = "Cannot find archive directory " + archiveDirectory
elsif (Dir[outputDirectory].length != 1)
	## logs directory
	uploadError = "Cannot find logs directory " + outputDirectory
else
	# the canvas import zip file
	fileNames = Dir[currentDirectory+ "Canvas_Extract_*.zip"];
	if (fileNames.length == 0)
		## cannot find zip file to upload
		uploadError = "Cannot find SIS zip file"
	elsif (fileNames.length > 1)
		## there are more than one zip file
		uploadError = "There are more than one SIS zip files to be uploaded."
	elsif
		## get the name of file to process
		fileName=fileNames[0]
		currentFileBaseName = File.basename(fileName)

		# upload start time
		p "upload start time : " + Time.new.inspect

		# upload the file to canvas server
		uploadError = upload_to_canvas(fileName, token, server, outputDirectory)


		# upload stop time
		p "upload stop time : " + Time.new.inspect
	end
end

if (!uploadError)
	## if there is no upload error
	# move file to archive directory after processing
	FileUtils.mv(fileName, archiveDirectory+currentFileBaseName)
	p "SIS upload finished with " + fileName
	exit
else
	## check first about the environment variable setting for MAILTO '
	p " use the environment variable for sending out error messages #{ENV['MAILTO']}"
	## send email to support team with the error message
	`echo #{uploadError} | mail -s "#{server} Upload Error" #{ENV['MAILTO']}`
	abort(uploadError)
end


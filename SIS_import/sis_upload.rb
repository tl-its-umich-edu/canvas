#!/usr/bin/env ruby

require "json"
require "fileutils"
require "rubygems"
require "nokogiri"
require "digest"
require "rest-client"

require_relative "utils.rb"

## make Canvas API GET call
def Canvas_API_GET(url)
	response = RestClient.get url, {:Authorization => "Bearer #{$token}",
                                :accept => "application/json",
                                :verify_ssl => true}
	return json_parse_safe(url, response, nil)
end

## make Canvas API POST call
def Canvas_API_POST(url, fileName)
	response = RestClient.post url, {:multipart => true,
																 :attachment => File.new(fileName, 'rb')
																},
																{:Authorization => "Bearer #{$token}",
                                :accept => "application/json",
                                :import_type => "instructure_csv",
                                :content_type => "application/zip",
                                :verify_ssl => true}
	return json_parse_safe(url, response, nil)
end

def upload_to_canvas(fileName, outputFile, output_file_base_name)


	# set the error flag, default to be false
	upload_error = false

	# prior to upload current zip file, make an attempt to check the prior upload, whether it is finished successfully
	if (prior_upload_error)
		## check first about the environment variable setting for MAILTO '
		return "Previous upload job has not finished yet."
	end

	# upload start time
	outputFile.write("upload start time : " + Time.new.inspect)

	# continue the current upload process
	parsed = Canvas_API_POST("#{$server_api_url}accounts/1/sis_imports.json", fileName)

	if (parsed["errors"])
		## break and print error
		error_array=parsed["errors"]
		## hashmap ["message"=>"error_message"
		upload_error = error_array[0]["message"]
		outputFile.write("upload error: " + upload_error)
		outputFile.write("\n")

		return upload_error
	end

	job_id=parsed["id"]

	begin
		#open a separate file to log the job id
		outputIdFile = File.open($outputDirectory + output_file_base_name + "_id.txt", "w")
		# write the job id into the id file
		outputIdFile.write(job_id);
	ensure
		outputIdFile.close unless outputIdFile == nil
	end

	outputFile.write("the job id is: #{job_id}\n")
	outputFile.write("here is the job #{job_id} status: \n")

	begin
		#sleep every 10 sec, before checking the status again
		sleep($sleep);

		parsed_result = Canvas_API_GET("#{$server_api_url}accounts/1/sis_imports/#{job_id}")

		#print out the whole json result
		outputFile.write("#{parsed_result}\n")

		if (parsed_result["errors"])
			## break and print error
			if (parsed_result["errors"].is_a? Array and parsed_result["errors"][0]["message"])
				# example error message
				# {"errors":[{"message":"An error occurred.","error_code":"internal_server_error"}],"error_report_id":237849}
				upload_error = parsed_result["errors"][0]["message"]
			else
				upload_error = parsed_result["errors"]
			end
			## hashmap ["message"=>"error_message"
			outputFile.write("upload error: " + upload_error)
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

	# upload stop time
	outputFile.write("upload stop time : " + Time.new.inspect)

	return upload_error

end ## end of method definition

# get the prior upload process id and make Canvas API calls to see the current process status
# return true if the process is 100% finished; false otherwise
def prior_upload_error
	# find all the process id files, and sort in descending order based on last modified time
	id_log_file_path = "#{$currentDirectory}logs/*_id.txt"
	p "id log file path is #{id_log_file_path}"
	files = Dir.glob(id_log_file_path)
	files = files.sort_by { |file| File.mtime(file) }.reverse
	if (files.size == 0)
		p "no id file found in path #{id_log_file_path}"
		## first run, no prior cases
		return false
	else
		## get the first and most recent id file
		id_file = files[0]
		p "found recent id file #{id_file}"
		process_id = ''
		File.open(id_file, 'r') do |idFile|
			while line = idFile.gets
				# only read the first line, which is the token value
				process_id=line.strip
				break
			end
		end

		process_result = Canvas_API_GET("#{$server_api_url}accounts/1/sis_imports/#{process_id}")
		if (process_result["errors"] && (process_result["errors"].is_a? Array))
			p "#{process_result["errors"][0]["message"]} for process id number #{process_id}. Continue with current upload."
			# if the prior process lookup result in error, there is no need to block future uploads
			return false
		end
		#parse the status percentage
		progress_status = process_result["progress"]
		if (progress_status != 100)
			# the prior job has not been processed 100%
			p "Prior upload process percent is #{process_id} has not finished yet. That progress status is #{progress_status}"
			return true
		else
			# prior job finished, ready for new upload
			return false
		end

		return true
	end
end

def verify_checksum(base_file_path)
	# default value
	upload_error = false

	# checksum verification
	checksum_file_names = Dir["#{base_file_path}MD5.txt"];
	if (checksum_file_names.length == 0)
		## there is no *MD5.txt file
		upload_error = "Cannot find checksum file #{base_file_path}MD5.txt."
	elsif (checksum_file_names.length > 1)
		## there are more than one checksum file
		upload_error = "There are more than one checksum file. "
	else
		## verify checksum value
		# 1.read checksum value from the *MD5.txt file
		checksum = ""
		File.open("#{base_file_path}MD5.txt", 'r') do |checksum_file|
			while line = checksum_file.gets
				# only read the first line, which is the checksum value
				checksum=line.strip
				break
			end
		end

		# 2. generate the checksum from current file
		new_checksum = Digest::MD5.hexdigest(File.read("#{base_file_path}.zip"))

		# 3. compare two checksum values
		if (!checksum.eql? new_checksum)
			upload_error = "Checksum value mismatch for #{base_file_path}.zip."
		end
	end

	# return error if any
	return upload_error
end

def get_settings(securityFile, propertiesFile)
	# 1. read from security file
	if (Dir[securityFile].length != 1)
		## security file
		return "Cannot find security file #{securityFile}."
	else
		File.open(securityFile, 'r') do |sFile|
			while line = sFile.gets
				# only read the first line
				# format: token=TOKEN,server=SERVER,directory=DIRECTORY
				env_array = line.strip.split(',')
				if (env_array.size != 2)
					return "security file should have the settings in format of: token=TOKEN,server=SERVER"
				end
				token_array=env_array[0].split('=')
				$token=token_array[1]
				server_array=env_array[1].split('=')
				$server=server_array[1]
				$server_api_url= "#{$server}/api/v1/"
				break
			end
		end
		if ($token=="")
			return "Empty token for Canvas upload."
		end
	end

	#2. read from properties file
	if (Dir[propertiesFile].length != 1)
		## properties file
		return "Cannot find properties file #{propertiesFile}."
	else
		File.open(propertiesFile, 'r') do |pFile|
			while line = pFile.gets
				# only read the first line
				# format: sleep=SLEEP
				env_array = line.strip.split(',')
				if (env_array.size != 2)
					return "properties file should have the settings in format of: directory=DIRECTORY,sleep=SLEEP"
				end
				directory_array=env_array[0].split('=')
				$currentDirectory=directory_array[1]
				sleep_array=env_array[1].split('=')
				$sleep=sleep_array[1].to_i
				break
			end
		end
		if (Dir[$currentDirectory].length != 1)
			## working directory
			return "Cannot find current working directory " + $currentDirectory + "."
		else
			# get the current working directory and the archive folder inside
			$archiveDirectory=$currentDirectory + "archive/"
			$outputDirectory=$currentDirectory + "logs/"

			p "server=" + $server
			p "current directory: " + $currentDirectory
			p "archive directory: " + $archiveDirectory
			p "output directory: " + $outputDirectory

			if (Dir[$archiveDirectory].length != 1)
				## archive directory
				return "Cannot find archive directory " + $archiveDirectory + "."
			end
			if (Dir[$outputDirectory].length != 1)
				## logs directory
				return "Cannot find output directory " + $outputDirectory + "."
			end
		end
	end

	# all is fine
	return false
end

# there should be two command line argument when invoking this Ruby script
# like ruby ./SIS_upload.rb <the_token_file_path> <the_server_name> <the_workspace_path>

# the security file name
securityFile = ""
# the properties file name
propertiesFile = ""

# the access token
$token = ""
# the Canvas server name
$server = ""
# the Canvas server api url
$server_api_url = ""
# the current working directory, archive directory and output directory
$currentDirectory=""
$archiveDirectory=""
$outputDirectory=""

# the interval in seconds between API calls to check upload process status
$sleep = 10

# the command line argument count
count=1
# iterate through the inline arguments
ARGV.each do|arg|
	if (count==1)
		#security file
		securityFile = arg
	elsif (count==2)
		# the second argument should be the server name
		propertiesFile=arg
	else
		# break
	end

	#increase count
	count=count+1
end

# read the settings from properties files
upload_error = get_settings(securityFile, propertiesFile)

outputFile = false
if (!upload_error)
	#open the output file
	begin
		# get output file name
		output_file_base_name = "Canvas_upload_" + Time.new.strftime("%Y%m%d%H%M%S")
		outputFile = File.open($outputDirectory + output_file_base_name + ".txt", "w")

		# the canvas import zip file
		fileNames = Dir[$currentDirectory+ "Canvas_Extract_*.zip"];
		if (fileNames.length == 0)
			## cannot find zip file to upload
			upload_error = "Cannot find SIS zip file."
		elsif (fileNames.length > 1)
			## there are more than one zip file
			upload_error = "There are more than one SIS zip files to be uploaded."
		elsif
			## get the name of file to process
			fileName=fileNames[0]
			currentFileBaseName = File.basename(fileName, ".zip")

			## checksum verification step
			upload_error = verify_checksum($currentDirectory + currentFileBaseName)

			if (!upload_error)
				# upload the file to canvas server
				upload_error = upload_to_canvas(fileName, outputFile, output_file_base_name)
			end
		end
	end
end

if (upload_error)
	## check first about the environment variable setting for MAILTO '
	p "Use the environment variable 'MAILTO' for sending out error messages to #{ENV['MAILTO']}"
	p upload_error
	## send email to support team with the error message
	`echo #{upload_error} | mail -s "#{$server} Upload Error" #{ENV['MAILTO']}`
else
	# write the success message
	## if there is no upload error
	# move file to archive directory after processing
	FileUtils.mv(Dir.glob("#{$currentDirectory}*.zip"), $archiveDirectory)
	FileUtils.mv(Dir.glob("#{$currentDirectory}*MD5.txt"), $archiveDirectory)

	upload_success_msg = "SIS upload finished with " + fileName
	outputFile.write(upload_success_msg)
	p upload_success_msg
end

# close output file
outputFile.close unless outputFile == false

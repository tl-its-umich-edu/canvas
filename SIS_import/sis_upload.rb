#!/usr/bin/env ruby

require "json"
require "fileutils"
require "rubygems"
require "nokogiri"


def upload_to_canvas(fileName, token, server, outputDirectory, outputFile, output_file_base_name)


	# set the error flag, default to be false
	upload_error = false

	# prior to upload current zip file, make an attempt to check the prior upload, whether it is finished successfully
	if (prior_upload_error(server, token))
		## check first about the environment variable setting for MAILTO '
		return "Previous upload job has not finished yet."
	end

	# upload start time
	outputFile.write("upload start time : " + Time.new.inspect)

	# continue the current upload process

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
		upload_error = error_array[0]["message"]
		outputFile.write("upload error: " + upload_error)
		outputFile.write("\n")

		return upload_error
	end

	job_id=parsed["id"]

	begin
		#open a separate file to log the job id
		outputIdFile = File.open(outputDirectory + output_file_base_name + "_id.txt", "w")
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
			upload_error=parsed_result["errors"]
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
def prior_upload_error(server, token)
	# find all the process id files, and sort in descending order based on last modified time
	id_log_file_path = "#{Dir.pwd}/logs/*_id.txt"
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
		process_result=`curl '#{server}/api/v1/accounts/1/sis_imports/#{process_id}' -H "Authorization: Bearer #{token}"`

		#parse the status percentage
		progress_status = parseJson(process_result)["progress"]
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

if (Dir[outputDirectory].length != 1)
	## logs directory
	upload_error = "Cannot find logs directory " + outputDirectory

	## check first about the environment variable setting for MAILTO '
	p " use the environment variable 'MAILTO' for sending out error messages to #{ENV['MAILTO']}"
	## send email to support team with the error message
	`echo #{upload_error} | mail -s "#{server} Upload Error" #{ENV['MAILTO']}`
	abort(upload_error)
else
	#open the output file
	begin
		# get output file name
		output_file_base_name = "Canvas_upload_" + Time.new.strftime("%Y%m%d%H%M%S")
		outputFile = File.open(outputDirectory + output_file_base_name + ".txt", "w")

		if (Dir[currentDirectory].length != 1)
			## working directory
			upload_error = "Cannot find current working directory " + currentDirectory
		elsif (Dir[archiveDirectory].length != 1)
			## archive directory
			upload_error = "Cannot find archive directory " + archiveDirectory
		elsif (Dir[tokenFile].length != 1)
			## token file
			upload_error = "Cannot find token file #{tokenFile}."
		else
			File.open(tokenFile, 'r') do |tFile|
				while line = tFile.gets
					# only read the first line, which is the token value
					token=line.strip
					break
				end
			end
			if (token=="")
				upload_error="Empty token for Canvas upload."
			end
		end

		if (!upload_error)
			# the canvas import zip file
			fileNames = Dir[currentDirectory+ "Canvas_Extract_*.zip"];
			if (fileNames.length == 0)
				## cannot find zip file to upload
				upload_error = "Cannot find SIS zip file"
			elsif (fileNames.length > 1)
				## there are more than one zip file
				upload_error = "There are more than one SIS zip files to be uploaded."
			elsif
				## get the name of file to process
				fileName=fileNames[0]
				currentFileBaseName = File.basename(fileName)

				# upload the file to canvas server
				upload_error = upload_to_canvas(fileName, token, server, outputDirectory, outputFile, output_file_base_name)
			end
		end

		if (upload_error)
			# write upload error string into file
			outputFile.write(upload_error)

			## check first about the environment variable setting for MAILTO '
			p " use the environment variable 'MAILTO' for sending out error messages to #{ENV['MAILTO']}"
			## send email to support team with the error message
			`echo #{upload_error} | mail -s "#{server} Upload Error" #{ENV['MAILTO']}`
			abort(upload_error)
		else
			# write the success message
			## if there is no upload error
			# move file to archive directory after processing
			FileUtils.mv(fileName, archiveDirectory+currentFileBaseName)
			upload_success_msg = "SIS upload finished with " + fileName
			outputFile.write(upload_success_msg)
			p upload_success_msg
		end

	# close output file
	ensure
		outputFile.close unless outputFile == nil
	end
end


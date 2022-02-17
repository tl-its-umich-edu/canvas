#!/usr/bin/env ruby

require "json"
require "fileutils"
require "rubygems"
require "nokogiri"
require "digest"
require "rest-client"
require "zip/zip"
require "uri"
require "addressable/uri"
require "set"
require_relative "utils.rb"
require "logger"
require "dotenv"

require_relative "sis_instructor_practice_course"

# Create a Logger that outputs to the standard output stream, with a level of info
# set the Logger's
$logger = Logger.new(STDOUT)
$logger.level = Logger::INFO

# there should be two command line argument when invoking this Ruby script
# like ruby ./SIS_upload.rb <the_token_file_path> <the_properties_file_path>

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
# the current working directory, archive directory
$currentDirectory=""
$archiveDirectory=""

# the warning message from upload process
$upload_warnings = ""

# the interval in seconds between API calls to check upload process status
$sleep = 10

# the alert email address is read from the configuration file
# and defaults to "canvas-sis-data-alerts@umich.edu", if not set otherwise
$alert_email_address = "canvas-sis-data-alerts@umich.edu"

# Canvas account number
ACCOUNT_NUMBER = 1

# the Canvas subaccount ID for instructor practice course sites
# defaults to be the main account id=1
$practice_course_subaccount = 1

# the path of Canvas API call
API_PATH="/api/v1/"


# variables for Canvas API call throttling
$call_hash = {
	"call_count" => 0,
	"start_time" => Time.now,
	"time_interval_in_seconds" => 3600,
	"end_time" => Time.now + 3600, # one hour apart
	"allowed_call_number_during_interval" => 3000
}

# make sure the Canvas call is within API usage quota
def Canvas_API_CALL_check
	$call_hash = sleep_according_to_timer_and_api_call_limit($call_hash, $logger)
end

# Ruby URI.escape has been deprecated.
# Addressable::URI.escape seems to be a viable solution, which offers url encoding, form encoding and normalizes URLs.
# http://stackoverflow.com/questions/2824126/whats-the-difference-between-uri-escape-and-cgi-escape

## make Canvas API GET call
def Canvas_API_GET(url)
	# make sure the Canvas call is within API usage quota
	Canvas_API_CALL_check()
	$logger.info "Canvas API GET #{url}"
	begin
		response = RestClient.get Addressable::URI.escape(url), {:Authorization => "Bearer #{$token}",
		                                                         :accept => "application/json",
		                                                         :verify_ssl => true}
		# increase the call count by one
		$call_hash["call_count"] = $call_hash["call_count"] + 1

		return json_parse_safe(url, response, $logger)
	rescue => e
		return json_parse_safe(url, e.response, $logger)
	end
end

## make Canvas API POST call
def Canvas_API_POST(url, params, fileName)
	# make sure the Canvas call is within API usage quota
	Canvas_API_CALL_check()
	$logger.info "Canvas API POST #{url}"
	begin
		if (fileName != nil)
			# upload the SIS zip file
			response = RestClient.post Addressable::URI.escape(url),
			                           {:multipart => true,
			                            :attachment => File.new(fileName, 'rb')
			                           },
			                           {:Authorization => "Bearer #{$token}",
			                            :accept => "application/json",
			                            :import_type => "instructure_csv",
			                            :content_type => "multipart/form-data;",
			                            :verify_ssl => true}
		else
			response = RestClient.post Addressable::URI.escape(url),
			                           params,
			                           {:Authorization => "Bearer #{$token}",
			                            :accept => "application/json",
			                            :content_type => "application/x-www-form-urlencoded",
			                            :verify_ssl => true}
		end

		# increase the call count by one
		$call_hash["call_count"] = $call_hash["call_count"] + 1

		return json_parse_safe(url, response, $logger)
	rescue => e
		return json_parse_safe(url, e.response, $logger)
	end
end

## make Canvas API PUT call
def Canvas_API_PUT(url, params)
	# make sure the Canvas call is within API usage quota
	Canvas_API_CALL_check()
	$logger.info "Canvas API PUT #{url}"
	begin
		response = RestClient.put Addressable::URI.escape(url), params,
		                          {:Authorization => "Bearer #{$token}",
		                           :accept => "application/json",
		                           :content_type => "application/json",
		                           :verify_ssl => true}
		# increase the call count by one
		$call_hash["call_count"] = $call_hash["call_count"] + 1

		return json_parse_safe(url, response, $logger)
	rescue => e
		return json_parse_safe(url, e.response, $logger)
	end
end

def upload_to_canvas(fileName)

	# set the error flag, default to be false
	upload_error = false

	# continue the current upload process
	parsed = Canvas_API_POST("#{$server_api_url}accounts/#{ACCOUNT_NUMBER}/sis_imports.json",
	                         nil,
	                         fileName)
	if (parsed.nil?)
		return "upload post returned null JSON value. Stop further actions."
	end

	if (parsed["errors"])
		## break and print error
		error_array=parsed["errors"]
		## hashmap ["message"=>"error_message"
		upload_error = error_array[0]["message"]
		logger.warn "upload error: #{upload_error}"
		return upload_error
	end

	job_id=parsed["id"]

	$logger.info "the Canvas upload job id is: #{job_id} with status:"

	begin
		#sleep every 10 sec, before checking the status again
		sleep($sleep);

		parsed_result = Canvas_API_GET("#{$server_api_url}accounts/#{ACCOUNT_NUMBER}/sis_imports/#{job_id}")

		## break if the returned json value is null
		## wait till the next check status call
		if (parsed_result.nil?)
			break;
		end
		# log progress and workflow_state values
		job_progress=parsed_result["progress"]
		workflow_state = parsed_result["workflow_state"]
		$logger.info "Canvas upload job id = #{job_id} processed #{job_progress} with workflow_state = #{workflow_state}"

		if (parsed_result["errors"])
			## break and print error
			if (parsed_result["errors"].is_a? Array and parsed_result["errors"][0]["message"])
				# example error message
				# {"errors":[{"message":"An error occurred.","error_code":"internal_server_error"}],"error_report_id":237849}
				upload_error = parsed_result["errors"][0]["message"]
			else
				upload_error = parsed_result["errors"]
			end
		elsif (workflow_state.eql? ("failed_with_messages"))
			upload_error = parsed_result["processing_errors"]
			$upload_warnings = parsed_result["processing_warnings"]
		elsif (workflow_state.eql?("failed"))
			# if status was "failed", it might not have "errors" returned, mark the upload_error with failed status
			upload_error = "Canvas upload job id = #{job_id} failed"
		end

		if (upload_error)
			# log upload_error, if any
			# and break
			$logger.error "upload error: #{upload_error}"
			break
		end
	end until (!workflow_state.eql?("created") && !workflow_state.eql?("importing"))
	# stop when workflow_state is neither "created" nor "importing";
	#
	# "workflow_state" is a better indicator of the upload progress, instead of the "progress" field
	# we have seen example of "progress=100" while "workflow_statue=importing"
	# Possible value for "workflow_state":
	# - 'created': The SIS import has been created.
	# - 'importing': The SIS import is currently processing.
	# - 'imported': The SIS import has completed successfully.
	# - 'imported_with_messages': The SIS import completed with errors or warnings.
	# - 'failed_with_messages': The SIS import failed with errors, while the import completed partially (or mostly)
	# - 'failed': The SIS import failed and the upload process did not complete at all
	# either 'failed_with_messages' or 'failed' would be caused usually by a corrupt SIS file or typos in the SIS.

	if (!upload_error)
		# print out the process warning, if any
		if (parsed_result["processing_errors"])
			upload_error = parsed_result["processing_errors"]
			$logger.warn "upload process errors: #{parsed_result["processing_errors"]}"
		elsif (parsed_result["processing_warnings"])
			#parsed_result = {"created_at" =>"2015-04-27T19:00:04Z",
			#                 "started_at"=>"2015-04-27T19:00:04Z",
			#                 "ended_at" =>"2015-04-27T19:06:29Z",
			#                 "updated_at"=>"2015-04-27T19:06:29Z",
			#                 "progress"=>100,
			#                 "id"=>429,
			#                 "workflow_state"=>"imported_with_messages",
			#                 "data"=>{"import_type"=>"instructure_csv",
			#                          "supplied_batches"=>["course","section","user","enrollment"],
			#                          "counts"=>{"accounts"=>0,
			#                                     "terms"=>0,
			#                                     "abstract_courses"=>0,
			#                                     "courses"=>488,
			#                                     "sections"=>488,
			#                                     "xlists"=>0,
			#                                     "users"=>606,
			#                                     "enrollments"=>1178,
			#                                     "groups"=>0,
			#                                     "group_memberships"=>0,
			#                                    "grade_publishing_results"=>0}},
			#                 "batch_mode"=>null,
			#                 "batch_mode_term_id"=>null,
			#                 "override_sis_stickiness"=>null,
			#                 "add_sis_stickiness"=>null,
			#                 "clear_sis_stickiness"=>null,
			#                 "diffing_data_set_identifier"=>null,
			#                 "diffed_against_import_id"=>null,
			#                 "processing_warnings"=>[["users.csv","No login_id given for user 67102976"],
			#                                         ["enrollments.csv","User 67102976 didn't exist for user enrollment"],
			#                                         ["enrollments.csv","User 67102976 didn't exist for user enrollment"],
			#                                         ["enrollments.csv","User 67102976 didn't exist for user enrollment"]]}

			# write the warning message into log file
			$logger.info "upload process warning: #{parsed_result["processing_warnings"]}"
			# assign the warning message to upload_warnings param
			$upload_warnings = parsed_result["processing_warnings"]
		else
			$logger.info "upload process finished successfully"
		end
	end

	# upload stop time
	$logger.info "upload stop time : " + Time.new.inspect

	return upload_error

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

def get_settings()
	Dotenv.load
	$currentDirectory=ENV['current_directory']
	$token=ENV['canvas_token']
	$server=ENV['canvas_url']
	$server_api_url= "#{$server}#{API_PATH}"
	$sleep=ENV['sleep'].to_i
	$call_hash["time_interval_in_seconds"]=ENV['canvas_time_interval'].to_i
	$call_hash["allowed_call_number_during_interval"]=ENV['canvas_allowed_call_number'].to_i
	$alert_email_address=ENV['alert_email_address']
	$practice_course_subaccount=ENV['practice_course_subaccount']
	
	$archiveDirectory="TODO"

	$logger.info "server=" + $server
	$logger.info "current directory: " + $currentDirectory
	$logger.info "archive directory: " + $archiveDirectory
	$logger.info "alert email address: " + $alert_email_address
	$logger.info "practice course subaccount: " + $practice_course_subaccount
end

# get env settings
get_settings()

#open the output file
begin
	# the canvas import zip file
	$currentDataDirectory = $currentDirectory + "data/"
	$logger.info($currentDataDirectory)
	fileNames = Dir[$currentDataDirectory+ "Canvas_Extract_*.zip"];
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
		$logger.info "Process file #{currentFileBaseName}.zip"

		## checksum verification step
		upload_error = verify_checksum($currentDataDirectory + currentFileBaseName)

		if (!upload_error)
			# upload the file to canvas server
			upload_to_canvas(fileName)

			## if there is no upload error
			## create sandbox sites for instructors newly uploaded
			## if they do not have such a site now
			create_all_instructor_sandbox_site($currentDataDirectory + currentFileBaseName + ".zip", $logger, $server_api_url, ACCOUNT_NUMBER, $practice_course_subaccount)
		end
	end
end

if (upload_error)
	$logger.warn "SIS upload error #{upload_error}"

	# close logger
	$logger.close
	
	# pass the "failure" code
	exit(upload_error)
else
	# write the success message
	$logger.info "SIS upload finished."

	# close logger
	$logger.close

	# pass the "success" code
	exit('success')
end

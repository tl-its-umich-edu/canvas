#!/usr/bin/env ruby

require "json"
require "fileutils"
require "nokogiri"

require "uglifier"
require "base64"
require "net/http"
require "rest-client"
require "uri"
require "time"

require_relative "utils.rb"

require "logger"

# Create a Logger
# defaults to output to the standard output stream, until reset to output to configured output file
# with a level of info
@logger = Logger.new(STDOUT)
@logger.level = Logger::INFO

# the current working directory
@currentDirectory=""
# the Canvas parameters
@canvasUrl = ""
# the Canvas access token
@canvasToken=""
# ESB parameters
@esbKey=""
@esbSecret=""
@esbUrl=""
@esbTokenUrl=""
# those two cert files are needed for ESB calls
@caRootFilePath=""
@inCommonFilePath=""
# the page size used for ESB API calls
@page_size=100

# variables for ESB API call throttling
@esb_call_hash = {
	"call_count" => 0,
	"start_time" => Time.now,
	"time_interval_in_seconds" => 60,
	"end_time" => Time.now + 60, # one minute apart
	"allowed_call_number_during_interval" => 60
}

# variables for Canva API call throttling
@canvas_call_hash = {
	"call_count" => 0,
	"start_time" => Time.now,
	"time_interval_in_seconds" => 3600,
	"end_time" => Time.now + 3600, # one hour apart
	"allowed_call_number_during_interval" => 3000
}

# the alert email address is read from the configuration file
# and defaults to "canvas-sis-data-alerts@umich.edu", if not set otherwise
@alert_email_address = "canvas-sis-data-alerts@umich.edu"

## refresh token for ESB API call
def refreshESBToken
	encoded_string = Base64.strict_encode64(@esbKey + ":" + @esbSecret)
	param_hash={"grant_type" => "client_credentials", "scope" => "PRODUCTION"}
	json = ESB_APICall(@esbTokenUrl + "/token?grant_type=client_credentials&scope=PRODUCTION",
	                   "Basic " + encoded_string,
	                   "application/x-www-form-urlencoded",
	                   "POST",
	                   param_hash)
	if (!json.nil?)
		return json["access_token"]
	end

	return nil
end

## make Canvas API call
def Canvas_API_call(url, params, json_attribute)
	# make sure the call is within API usage quota
	call_hash = sleep_according_to_timer_and_api_call_limit(@canvas_call_hash, @logger)
	@Canvas_start_time = call_hash["start_time"]
	@Canvas_end_time = call_hash["end_time"]
	@Canvas_call_count = call_hash["call_count"]

	url = url<<"?"<<URI.encode_www_form(params)

	response = actual_Canvas_API_call(url)

	json = parse_canvas_API_response_json(url, response, json_attribute)
	if (json.nil?)
		# return if error
		return nil
	end

	# array of page urls if any
	page_urls = get_all_canvas_page_urls(response.headers)
	if (!page_urls.nil?)
		# there is paging involved
		# need to make further API calls
		# will concat the result json arrays
		page_urls.each do |page_url|
			response = actual_Canvas_API_call(page_url)

			p response
			json_paging_data = parse_canvas_API_response_json(url, response, json_attribute)

			if (!json_paging_data.nil?)
				# merge in all element in the paging data array
				json_paging_data.each do |json_paging_data_element|
					json.push json_paging_data_element
				end
			end
		end
	end

	return json
end

## the get call to Canvas
def actual_Canvas_API_call(url)
	@Canvas_call_count = @Canvas_call_count + 1
	@logger.info "Canvas call #{@Canvas_call_count} #{Time.new.strftime("%Y%m%d%H%M%S")} #{url}"
	response = RestClient.get url, {:Authorization => "Bearer #{@canvasToken}",
	                                :accept => "application/json",
	                                :verify_ssl => true}

	return response
end

## parse the response object into json object
def parse_canvas_API_response_json(url, response, json_attribute)
	json = json_parse_safe(url, response, @logger)

	if !json_attribute.nil?
		if json.has_key? json_attribute
			json = json[json_attribute]
		else
			@logger.info " returned json result does not have attribute " + json_attribute
		end
	end
	return json
end


def get_all_canvas_page_urls(response_headers)
	# https://canvas.instructure.com/doc/api/file.pagination.html
	# Pagination information is provided in the Link header, e.g.
	# :link =>"
	# <https://umich.test.instructure.com/api/v1/accounts/1/courses?..page=1&per_page=100>; rel=\"current\",
	# <https://umich.test.instructure.com/api/v1/accounts/1/courses?..page=2&per_page=100>; rel=\"next\",
	# <https://umich.test.instructure.com/api/v1/accounts/1/courses?..page=1&per_page=100>; rel=\"first\",
	# <https://umich.test.instructure.com/api/v1/accounts/1/courses?..page=2&per_page=100>; rel=\"last\"",
	if (!response_headers.has_key? :link)
		#return if there is no paging information
		return nil;
	end

	# default last page number to be 1
	last_page_number = 1
	# page url part one
	page_url_part_one = nil
	# page url part two
	page_url_part_two = nil

	link_header = response_headers[:link]
	link_page_urls = link_header.split(',')
	link_page_urls.detect { |page_link|
		if page_link.include? "rel=\"last\""
			# this is the last link, get the page id]
			# get the param from url string
			last_page_url_array= page_link.split(';')
			last_page_url = last_page_url_array[0]
			last_page_url = last_page_url.gsub("<", "")
			last_page_url = last_page_url.gsub(">", "")
			## the url string before the page= param
			page_url_part_one = last_page_url[0, last_page_url.index("page=")];
			## the url after page= param, should start with the page number
			page_url_part_two = last_page_url.gsub(page_url_part_one.concat("page="), "");
			## get the last page number
			last_page_number = page_url_part_two[0, page_url_part_two.index('&')].to_i
			page_url_part_two = page_url_part_two[page_url_part_two.index('&'), page_url_part_two.length - page_url_part_two.index('&')]
		end
	}

	@logger.info " Found #{last_page_number} of pages from Canvas API call results"

	# now that we have the last page number, we will construct a list of all url for each page
	if (last_page_number > 1)
		page_url_ary = Array.new
		# start from the second page, since we already have result of the first page
		for page_num in 2 .. last_page_number
			# copy the last page url params, but replace it with
			page_url = page_url_part_one.concat(page_num.to_s).concat(page_url_part_two)
			page_url_ary.push(page_url)
		end
	end
	return page_url_ary
end

## make ESB API call
def ESB_APICall(url, authorization_string, content_type, request_type, param_hash)
	# make sure the call is within API usage quota
	call_hash = sleep_according_to_timer_and_api_call_limit(@esb_call_hash, @logger)
	@esb_start_time = call_hash["start_time"]
	@esb_end_time = call_hash["end_time"]
	@esb_call_count = call_hash["call_count"]

	@esb_call_count = @esb_call_count+1
	@logger.info "ESB call #{@esb_call_count} #{Time.new.strftime("%Y%m%d%H%M%S")} #{url}"

	url = URI.parse(url)

	response = ""
	case request_type
		when "POST"
			request = Net::HTTP::Post.new(url.path)
		when "GET"
			request = Net::HTTP::Get.new(url.path)
		when "PUT"
			request = Net::HTTP::Put.new(url.path)
		else
			puts "wrong request type" + request_type
	end
	request.add_field("Authorization", authorization_string)
	request.add_field("Content-Type", content_type)
	request.add_field("Accept", "*/*")


	if (!param_hash.nil?)
		if (request_type == "PUT")
			payload = param_hash.to_json
			request.body="#{payload}"
		else
			# if parameter hash is not null, attach them to form
			request.set_form_data(param_hash)
		end
	end

	sock = Net::HTTP.new(url.host, url.port)
	sock.use_ssl=true
	store = OpenSSL::X509::Store.new
	store.add_cert(OpenSSL::X509::Certificate.new(File.read(@caRootFilePath)))
	store.add_cert(OpenSSL::X509::Certificate.new(File.read(@inCommonFilePath)))
	sock.cert_store = store

	#sock.set_debug_output $stdout #useful to see the raw messages going over the wire
	sock.read_timeout = 60
	sock.open_timeout = 60
	sock.start do |http|
		response = http.request(request)
	end

	# return json
	return json_parse_safe(url, response.body, @logger)
end

## the ESB PUT call to set class URL in MPathway
def setMPathwayUrl(esbToken, termId, sectionId, courseId)

	lmsUrl = @canvasUrl + "/courses/" + courseId.to_s
	#get course information
	call_url = @esbUrl + "/CurriculumAdmin/v1/Terms/#{termId}/Classes/#{sectionId}/LMSURL";
	return ESB_APICall(call_url, "Bearer " + esbToken, "application/json", "PUT", {"lmsURL" => lmsUrl})
end

## get the current term info from MPathway
def getMPathwayTerms(esbToken)
	rv = Set.new()
	#get term information
	call_url = @esbUrl + "/Curriculum/SOC/v1/Terms";
	result= ESB_APICall(call_url, "Bearer " + esbToken, "application/json", "GET", nil)
	if (!result.nil?)
		# ideally the Term element should always be an Array
		# a ServiceLink request has been created
		# but for now, we need to
		if (result["getSOCTermsResponse"]["Term"].is_a? Array)
			result["getSOCTermsResponse"]["Term"].each do |term|
				termId = term["TermCode"]
				rv.add(termId.to_s)
			end
		else
			# deal with the special case when only one item is returned - it is not returned as in an Array
			term = result["getSOCTermsResponse"]["Term"]
			termId = term["TermCode"]
			rv.add(termId.to_s)
		end
	end

	return rv
end

## 1. get the terms from Canvas
## 2. compare the term list with MPathway term list, take the terms which are in both sets
## 3. iterate through all courses in each term,
## 4. if the course is open/available, find sections/classes in each course, set the class url in MPathway
def processTermCourses(mPathwayTermSet, esbToken)
	## error message for email alert
	error_message = ""

	term_data = Canvas_API_call("#{@canvasUrl}/api/v1/accounts/1/terms",
	                            {:per_page => @page_size},
	                            "enrollment_terms")
	term_data.each { |term|
		if (mPathwayTermSet.include?(term["sis_term_id"]))
			#SIS term ID
			sisTermId = term["sis_term_id"]

			# this is the term we are interested in
			termId = term["id"]

			@logger.info "for term SIS_ID=#{term["sis_term_id"]} and Canvas term id=#{termId}"

			# Web Service call
			json_data = Canvas_API_call("#{@canvasUrl}/api/v1/accounts/1/courses",
			                            {:enrollment_term_id => termId,
			                             :published => true,
			                             :with_enrollments => true,
			                             ##:include[] => "sections",
			                             :per_page => @page_size
			                            },
			                            nil)
			term_course_count = 0
			json_data.each { |course|
				term_course_count = term_course_count + 1
				@logger.info "for term id=#{termId} term_course_count=#{term_course_count}"
				if (course.has_key?("workflow_state") && course["workflow_state"] == "available")
					# only set url for those published sections
					# course is a hash
					course.each do |key, value|
						if (key=="id")
							courseId = value
							sections_data = Canvas_API_call("#{@canvasUrl}/api/v1/courses/#{courseId}/sections",
							                                {:per_page => @page_size},
							                                nil)
							sections_data.each { |section|
								# section is a hash, we will get the sis_section_id value
								# initialize sectionParsedSISID
								sectionParsedSISID = nil
								section.each do |sectionKey, sectionValue|
									if (sectionKey=="sis_section_id")
										## get the sis_section_id value
										sectionParsedSISID=sectionValue
										break
									end
								end
								if (sectionParsedSISID != nil)
									## sis_section_id is 9-digit: <4-digit term id><5-digit section id>
									# we will use just the last 5-digit of the section id
									sectionParsedSISID = sectionParsedSISID[4, 8]
									result_json = setMPathwayUrl(esbToken, sisTermId, sectionParsedSISID, courseId)
									if (!result_json.nil? && (result_json.has_key? "setLMSURLResponse"))
										message = Time.new.inspect + " set url result for section id=#{sectionParsedSISID} with Canvas courseId=#{courseId}: result status=#{result_json["setLMSURLResponse"]["Resultcode"]} and result message=#{result_json["setLMSURLResponse"]["ResultMessage"]}"
										# generate error message when there is a Failure status returned
										if ("Failure".eql? result_json["setLMSURLResponse"]["Resultcode"])
											# generate error if the
											error_message = error_message.concat("\n#{message}")
										end
									else
										message = Time.new.inspect + " set url result for section id=#{sectionParsedSISID} with Canvas courseId=#{courseId}: result #{result_json.to_s}"
										error_message = error_message.concat("\n#{message}")
									end
									# write into output file
									@logger.info message
								end
							}
						end
					end
				else
					@logger.info ("Course #{course["course_code"]} with SIS Course ID #{course["sis_course_id"]} is of status #{course["workflow_state"]}, will not set url for its classes. \n")
				end
			}
		end
	}
	return error_message
end

def update_MPathway_with_Canvas_url(esbToken, outputDirectory)
	upload_error = false

	# get the MPathway term set
	mPathwayTermSet = getMPathwayTerms(esbToken)

	# set URL start time
	@logger.info "set URL start time : #{Time.new.inspect}"

	#call Canvas API to get course url
	upload_error = processTermCourses(mPathwayTermSet, esbToken)

	# set URL stop time
	@logger.info "set URL stop time : #{Time.new.inspect}"

	return upload_error

end

## end of method definition

## read the command line arguments
def read_argv

	# return errors
	return_hash = Hash.new

	# the command line argument count
	count=1
	# iterate through the inline arguments
	ARGV.each do |arg|
		if (count==1)
			if (Dir[arg].length != 1)
				## token file
				return_hash["error"] = "Cannot find security file " + arg
				return return_hash
			end
			File.open(arg, 'r') do |securityFile|
				while line = securityFile.gets
					# only have one line, and in this format:
					# Canvas_token=<Canvas token>,Canvas_server=<Canvas server url>,ESB_key=<ESB key>,ESB_secret=<ESB secret>,ESB_URL=<ESB URL>,
					# ESB_TOKEN_URL=<ESB token server URL>,CA_root_cert_path=<CA root FILE PATH>,InCommon_cert_path=<InCommon cert path>
					env_array = line.strip.split(',')
					if (env_array.size != 8)
						return_hash["error"] = "security file should have the settings in format of: Canvas_token=<Canvas token>,Canvas_server=<Canvas server url>,ESB_key=<ESB key>,ESB_secret=<ESB secret>,ESB_URL=<ESB URL>,ESB_TOKEN_URL=<ESB token server URL>,CA_root_cert_path=<CA root FILE PATH>,InCommon_cert_path=<InCommon cert path>"
						return return_hash
					end
					token_array=env_array[0].split('=')
					@canvasToken=token_array[1]
					url_array=env_array[1].split('=')
					@canvasUrl=url_array[1]
					key_array=env_array[2].split('=')
					@esbKey=key_array[1]
					secret_array=env_array[3].split('=')
					@esbSecret=secret_array[1]
					url_array=env_array[4].split('=')
					@esbUrl=url_array[1]
					token_url_array=env_array[5].split('=')
					@esbTokenUrl=token_url_array[1]
					caRootFilePath_array=env_array[6].split('=')
					@caRootFilePath=caRootFilePath_array[1]
					inCommonFilePath_array=env_array[7].split('=')
					@inCommonFilePath=inCommonFilePath_array[1]
					break
				end
			end
		elsif (count==2)
			if (Dir[arg].length != 1)
				## token file
				return_hash["error"] = "Cannot find properties file " + arg
				return return_hash
			end
			File.open(arg, 'r') do |propertiesFile|
				while line = propertiesFile.gets
					# only have one line, and in this format:
					# directory=<current working directory>,page_size=<ESB API call page size>,esb_time_interval=<ESB API call time interval in seconds>,esb_allowed_call_number=<maximum ESB API call number during the interval>,canvas_time_interval=<Canvas API call time interval in secs>,canvas_allowed_call_number=<maximum Canvas API call during the interval>,alert_email_address=ALERT_EMAIL_ADDRESS
					env_array = line.strip.split(',')
					if (env_array.size != 7)
						return_hash["error"] = "Properties file should have the settings in format of: directory=<current working directory>,page_size=<ESB API call page size>,esb_time_interval=<ESB API call time interval in seconds>,esb_allowed_call_number=<maximum ESB API call number during the interval>,canvas_time_interval=<Canvas API call time interval in secs>,canvas_allowed_call_number=<maximum Canvas API call during the interval>,alert_email_address=<alert email address>"
						return return_hash
					end
					diretory_array=env_array[0].split('=')
					@currentDirectory=diretory_array[1]
					page_size_array=env_array[1].split('=')
					@page_size=page_size_array[1]
					esb_interval_array=env_array[2].split('=')
					@esb_call_hash["time_interval_in_seconds"]=esb_interval_array[1].to_i
					esb_call_array=env_array[3].split('=')
					@esb_call_hash["allowed_call_number_during_interval"]=esb_call_array[1].to_i
					canvas_interval_array=env_array[4].split('=')
					@canvas_call_hash["time_interval_in_seconds"]=canvas_interval_array[1].to_i
					canvas_call_array=env_array[5].split('=')
					@canvas_call_hash["allowed_call_number_during_interval"]=canvas_call_array[1].to_i
					alert_email_address_array=env_array[6].split('=')
					@alert_email_address=alert_email_address_array[1]
					break
				end
			end
		else
			# break
		end

		#increase count
		count=count+1
	end
	return return_hash
end


####################### main ########################
# to invoke this script, use the following format
# ruby ./SIS_update_url.rb <the_security_file_path> <the_properties_file_path>
####################################################

# process error, will notify user through email
process_error = nil

# init from command line arguments
return_hash = read_argv
if return_hash.has_key? "error"
	process_error = return_hash["error"]
else
	# get then log output directory
	outputDirectory=@currentDirectory + "logs/"

	@logger.info "canvasUrl=" + @canvasUrl
	@logger.info "current directory: " + @currentDirectory
	@logger.info "output directory: " + outputDirectory

	if (Dir[@currentDirectory].length != 1)
		## working directory
		process_error = "Cannot find current working directory " + @currentDirectory
	elsif (Dir[outputDirectory].length != 1)
		## logs directory
		process_error = "Cannot find logs directory " + outputDirectory
	else
		begin
			outputFileName = outputDirectory + "Canvas_set_url_#{Time.new.strftime("%Y%m%d%H%M%S")}.txt"
			outputFile = File.open(outputFileName, "w")
			@logger.info "log file is at #{outputFileName}"

			# reset the logger output to output file
			@logger = Logger.new(outputFile)
			@logger.level = Logger::INFO

			esbToken=refreshESBToken()

			# update MPathway with Canvas urls
			updateError = update_MPathway_with_Canvas_url(esbToken, outputDirectory)

			if (!updateError || updateError.nil? || updateError.empty?)
				## if there is no upload error
				@logger.info "Sites set URLs finished."
			else
				process_error = updateError
			end
		end
	end
end

if (process_error && !process_error.empty?)
	# mail the upload warning message
	## check first about the environment variable setting for alert_email_address
	@logger.info "Sending out SIS upload warning messages to #{@alert_email_address}"
	## send email to support team with the error message
	`echo "#{process_error}" | mail -s "#{@canvasUrl} SIS Set URL Error" #{@alert_email_address}`
	@logger.warn "set url error: #{process_error}"
end

# close logger
@logger.close



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

require "logger"
require "openssl"
require_relative "utils.rb"

# Create a Logger
# defaults to output to the standard output stream, until reset to output to configured output file
# with a level of info
@logger = Logger.new(STDOUT)
@logger.level = Logger::INFO

# the requested term id
# script will only retrieve syllabus data for this term
@requestedTermId = ""

# the current working directory
@currentDirectory=""
# the Canvas parameters
@canvasUrl = ""
# the Canvas access token
@canvasToken=""

# the page size used for ESB API calls
@page_size=100

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
@alert_email_address = "zqian@umich.edu"

# global variable for published course count within term
@term_published_course_count = 0
# global variable for published course count with syllabus info within term
@term_published_course_with_syllabus_count = 0


## make Canvas API call
def Canvas_API_call(url, params, json_attribute, paging)
	@logger.info "paging setting #{paging} #{url}"

	# make sure the call is within API usage quota
	#@canvas_call_hash = sleep_according_to_timer_and_api_call_limit(@canvas_call_hash, @logger)

	if (!params.nil?)
		url = url<<"?"<<URI.encode_www_form(params)
	end

	response = actual_Canvas_API_call(url)

	# increase the call count number by 1
	@canvas_call_hash["call_count"] = @canvas_call_hash["call_count"] + 1

	json = parse_canvas_API_response_json(url, response, json_attribute)
	if (json.nil?)
		# return if error
		@logger.error "Null response JSON value for Canvas API call " + url
		return nil
	end


	@logger.info "paging setting 2 #{paging}"
	# if not doing paging, return now
	if (!paging)
		return json
	end
	# array of page urls if any
	page_urls = get_all_canvas_page_urls(response.headers)
	if (!page_urls.nil?)
		# there is paging involved
		# need to make further API calls
		# will concat the result json arrays
		page_urls.each do |page_url|
			response = actual_Canvas_API_call(page_url)

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
	@logger.info "real call #{url}"
	@logger.info "Canvas call #{@canvas_call_hash["call_count"]} #{Time.new.strftime("%Y%m%d%H%M%S")} #{url}"
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
			page_url = page_url_part_one + page_num.to_s + page_url_part_two
			page_url_ary.push(page_url)
		end
	end
	return page_url_ary
end

## get the current term info from MPathway
def getMPathwayTerms()
	rv = Set.new()
	#get term information
	call_url = @esbUrl + "/Curriculum/SOC/Terms";
	response= ESB_APICall(call_url, "Bearer " + getESBToken(@CurriculumScope,false), true,"application/json", "GET", nil)
	result = parse_ESB_API_CALL_RESPONSE(response, call_url, "application/json", "GET", nil,@CurriculumScope)
	if (!result.nil?)
		# ideally the Term element should always be an Array
		# a ServiceLink request has been created
		# but for now, we need to
		term_array = Array.new
		if (result["getSOCTermsResponse"]["Term"].is_a? Array)
			# if the return json element is of array, just assign this array over
			term_array = result["getSOCTermsResponse"]["Term"]
		else
			# otherwise, if the return json element is a single object,
			# then, add it to the array
			term_array << result["getSOCTermsResponse"]["Term"]
		end
		# now this is an array type for sure
		term_array.each do |term|
			termId = term["TermCode"]
			rv.add(termId.to_s)
		end
	end

	return rv
end

## end of method definition

## read the command line arguments
def read_argv

	# return errors
	return_hash = Hash.new

	# the command line argument count
	count=1
	ARGV.each do |arg|
		if (count==1)
			if (Dir[arg].length != 1)
				## token file
				return_hash["error"] = "Cannot find security file " + arg
				return return_hash
			end
			File.open(arg, 'r') do |securityFile|
				while line = securityFile.gets

					@logger.info(line)
					# only have one line, and in this format:
					# Canvas_token=<Canvas token>,Canvas_server=<Canvas server url>,ESB_key=<ESB key>,ESB_secret=<ESB secret>,ESB_URL=<ESB URL>,
					# ESB_TOKEN_URL=<ESB token server URL>,CA_root_cert_path=<CA root FILE PATH>,InCommon_cert_path=<InCommon cert path>
					env_array = line.strip.split(',')
					if (env_array.size != 2)
						return_hash["error"] = "security file should have the settings in format of: Canvas_token=<Canvas token>,Canvas_server=<Canvas server url>,ESB_key=<ESB key>,ESB_secret=<ESB secret>,ESB_URL=<ESB URL>,ESB_TOKEN_URL=<ESB token server URL>,CA_root_cert_path=<CA root FILE PATH>,InCommon_cert_path=<InCommon cert path>"
						return return_hash
					end
					token_array=env_array[0].split('=')
					@canvasToken=token_array[1]
					url_array=env_array[1].split('=')
					@canvasUrl=url_array[1]
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
					if (env_array.size != 2)
						return_hash["error"] = "Properties file should have the settings in format of: directory=<current working directory>,page_size=<ESB API call page size>,esb_time_interval=<ESB API call time interval in seconds>,esb_allowed_call_number=<maximum ESB API call number during the interval>,canvas_time_interval=<Canvas API call time interval in secs>,canvas_allowed_call_number=<maximum Canvas API call during the interval>,alert_email_address=<alert email address>"
						return return_hash
					end
					@logger.info(arg)
					diretory_array=env_array[0].split('=')
					@currentDirectory=diretory_array[1]
					page_size_array=env_array[1].split('=')
					@page_size=page_size_array[1]
					break
				end
			end
		elsif (count==3)
			@requestedTermId = arg
		else
			# break
		end

		#increase count
		count=count+1
	end
	return return_hash
end

# for single Canvas course, find sections within the course, and set URL for those sections
def processCourseData(course, error_message, termId, term_course_count, outputTermSyllabusDirectoryName)
	term_course_count = term_course_count + 1
	@logger.info "for term id=#{termId} term_course_count=#{term_course_count}"
	if (course.has_key?("workflow_state") && course["workflow_state"] == "available")

		#published course, increase count
		@term_published_course_count = @term_published_course_count + 1

		# only set url for those published sections
		# course is a hash
		course.each do |key, value|
			if (key=="id")
				courseId = value
				syllabus_data = Canvas_API_call("#{@canvasUrl}/api/v1/courses/#{courseId}?include[]=syllabus_body",
				                                nil,
				                                nil,
																				false)
				## get the course name as the file name
				if (!syllabus_data.nil? && !syllabus_data["syllabus_body"].nil?)
					syllabus_body = syllabus_data["syllabus_body"].to_s
					if (syllabus_body.length > 0)
						# contains syllabus data, update count
						@term_published_course_with_syllabus_count = @term_published_course_with_syllabus_count + 1

						outputSyllabusFileName = outputTermSyllabusDirectoryName + courseId.to_s + "_" + escapeFolderFileName(syllabus_data["name"]) + ".html"
							open(outputSyllabusFileName, 'w') { |f|
								f.puts "#{syllabus_data['syllabus_body']}"
							}
					end
				end
			end
		end
	else
		@logger.info "Course #{course["course_code"]} with SIS Course ID #{course["sis_course_id"]} is of status #{course["workflow_state"]} \n"
	end
	error_message
end

## escape characters as necessary for creating files and folders
def escapeFolderFileName(name)
	# NOTE: File.basename doesn't work right with Windows paths on Unix
	# get only the filename, not the whole path
	name = name.gsub('/', ' ')

	return name
end
####################### main ########################
# to invoke this script, use the following format
# ruby ./SIS_update_url.rb <the_security_file_path> <the_properties_file_path>
####################################################

# process error, will notify user through email
process_error = nil

# init from command line arguments
return_hash = read_argv
@logger.info return_hash
if return_hash.has_key? "error"
	process_error = return_hash["error"]
else

	@logger.info "no errors"
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
			logFileName = outputDirectory + "Canvas_syllabus_log_#{Time.new.strftime("%Y%m%d%H%M%S")}.txt"
			logFile = File.open(logFileName, "a")
			@logger.info "log file is at #{logFileName}"

			# reset the logger output to output file
			@logger = Logger.new(logFile)
			@logger.level = Logger::INFO

			subaccountData = Canvas_API_call("#{@canvasUrl}/api/v1/accounts/1/sub_accounts",
			                            nil,
			                            nil,
			                            true)
			subaccountData.each { |subaccount|
				subaccountId = subaccount["id"]
				subaccountName = subaccount["name"]

				# skip the "test" and "pilot" subaccounts
				if (subaccountId == 2 || subaccountId == 36)
					next
				end
				@logger.info "subaccount #{subaccountName}"

				outputDirectoryName = outputDirectory + subaccountId.to_s + "_" + escapeFolderFileName(subaccountName) + "/"
				FileUtils.mkdir_p(outputDirectoryName)


				term_data = Canvas_API_call("#{@canvasUrl}/api/v1/accounts/1/terms",
				                            {:per_page => @page_size},
				                            "enrollment_terms",
																		true)
				term_data.each { |term|
				  termId = term["id"]
				  if (termId.to_i != @requestedTermId.to_i)
						next
				  end

				  #this is the term we are interested in
				  termName = term["name"]
					@term_published_course_count = 0
					@term_published_course_with_syllabus_count = 0

					# skip "no term" and "default term"
					#if (termId == 1 || termId == 53)
					#	next
					#end

					#outputTermDirectoryName = outputDirectoryName + termId.to_s + "_" + escapeFolderFileName(termName) + "/"
					#FileUtils.mkdir_p(outputTermDirectoryName)

					@logger.info "for term SIS_ID=#{term["sis_term_id"]} and Canvas term id=#{termId}"
					json_data = Canvas_API_call("#{@canvasUrl}/api/v1/accounts/#{subaccountId}/courses",
					                            {:enrollment_term_id => termId,
					                             :published => true,
					                             :with_enrollments => true,
					                             ##:include[] => "sections",
					                             :per_page => @page_size
					                            },
					                            nil,
																			true)
					if (!json_data.nil?)
						term_course_count = 1
						json_data.each { |course|
							# iterate through course
							error_message = processCourseData(course, error_message, termId, term_course_count, outputDirectoryName)
							term_course_count = term_course_count + 1
						}

						countCSVFileName = outputDirectory + "subaccount_term_syllabus_count.csv"
						countCSVFile = File.open(countCSVFileName, "a")

						# output the term course count file
						open(countCSVFileName, 'a') { |f|
							f.puts "#{subaccountName}\t#{termName}\t#{@term_published_course_count}\t#{@term_published_course_with_syllabus_count}\n"
						}

					else
						@logger.info "term #{term["id"]} does not have any course";
					end
				}
			}
		end
	end
end

# close logger
@logger.close



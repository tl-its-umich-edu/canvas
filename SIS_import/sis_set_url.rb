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
require "openssl"

require "dotenv"

# Create a Logger
# defaults to output to the standard output stream, until reset to output to configured output file
# with a level of info
@logger = Logger.new(STDOUT)
@logger.level = Logger::INFO

# the Canvas parameters
@canvasUrl = ""
# the Canvas access token
@canvasToken=""
# ESB parameters
@esbKey=""
@esbSecret=""
@esbUrl=""
@esbTokenUrl=""

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
# Terms and get/put/delete Sections in a Course ESB calls have separate tokens scoped to below strings
@CurriculumAdminScope="curriculumadmin"
@CurriculumScope="umscheduleofclasses"

@esb_api_scope_to_token_hash={
    @CurriculumAdminScope => nil,
    @CurriculumScope =>nil
}

# the alert email address is read from the configuration file
# and defaults to "canvas-sis-data-alerts@umich.edu", if not set otherwise
@alert_email_address = "canvas-sis-data-alerts@umich.edu"


## refresh token for ESB API call
def getESBToken(scope,token_renewal_needed)
  @esb_api_scope_to_token_hash.each do |key, value|
    @logger.debug "#{key}: #{value}"
  end
  if !token_renewal_needed
    # Token is still good and can be reused for the particular scope api call
    @esb_api_scope_to_token_hash.each do |esb_token_key, esb_token_for_scope|
      if esb_token_key === scope
        if !esb_token_for_scope.nil?
          @logger.info "ESB token taken from esb_api_scope_to_token_hash ending with  " + esb_token_for_scope[-5,5] + "... for scope "+esb_token_key
          return esb_token_for_scope
        end
      end
    end
  end
  # getting the token for the very first time or when token expires after 1 hour.
  @esbToken=refreshESBToken(scope);
  if !@esbToken.nil?
    @esb_api_scope_to_token_hash[scope]=@esbToken
    @logger.info "new esb Token ending with #{@esbToken[-5,5]}...created for the scope #{scope}"
  end

  if (@esbToken.nil?)
    # return empty string instead of nil
    return "";
  else
    return @esbToken
  end
end


# get a new esbToken
# with the ESB new IBM Api Manager each or a family of API call is scoped to a string and will have separate token for that API set.
# sis script has 2 different scopes for the ESB calls it is using, so getting different token for each is essential and determined by the scope.
# for simple use case how token,scope is tied up please refer to the examples in /test directory
def refreshESBToken(scope)
  	@esbToken=nil
	encoded_string = Base64.strict_encode64(@esbKey + ":" + @esbSecret)
	param_hash={"grant_type" => "client_credentials", "scope" => scope}
	response = ESB_APICall(@esbTokenUrl + "/token","Basic " + encoded_string, false,
	                   "application/x-www-form-urlencoded",
	                   "POST",
	                   param_hash)
	json = json_parse_safe(@esbTokenUrl, response.body, @logger)
	if (!json.nil?)
		@esbToken = json["access_token"]
		@logger.info "ESB token refreshed at " + Time.now.to_s + " with new token " + @esbToken[0..4] + "..."
	else
		@logger.error "Null JSON value for ESB refresh token call."
	end
	return @esbToken
end

## make Canvas API call
def Canvas_API_call(url, params, json_attribute)
	# make sure the call is within API usage quota
	@canvas_call_hash = sleep_according_to_timer_and_api_call_limit(@canvas_call_hash, @logger)

	url = url<<"?"<<URI.encode_www_form(params)

	response = actual_Canvas_API_call(url)

	# increase the call count number by 1
	@canvas_call_hash["call_count"] = @canvas_call_hash["call_count"] + 1

	json = parse_canvas_API_response_json(url, response, json_attribute)
	if (json.nil?)
		# return if error
		@logger.warn "Null response JSON value for Canvas API call " + url
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

## make ESB API call
def ESB_APICall(url, authorization_string, ibm_client_id, content_type, request_type, param_hash)
	# make sure the call is within API usage quota
	@esb_call_hash = sleep_according_to_timer_and_api_call_limit(@esb_call_hash, @logger)

	url = URI.parse(url)

	response = ""
	case request_type
		when "POST"
			request = Net::HTTP::Post.new(url.path)
		when "GET"
			request = Net::HTTP::Get.new(url.path)
		when "PUT"
			request = Net::HTTP::Put.new(url.path)
		when "DELETE"
			request = Net::HTTP::Delete.new(url.path)
		else
			@logger.error "wrong request type #{request_type} for #{url}"
	end

	http = Net::HTTP.new(url.host, url.port)
	http.use_ssl = true
	http.verify_mode = OpenSSL::SSL::VERIFY_PEER

	request.add_field("Authorization", authorization_string)
	request.add_field("Content-Type", content_type)
	request.add_field("Accept", "application/json")

	if(ibm_client_id)
		request.add_field("x-ibm-client-id", @esbKey)
	end

	if (!param_hash.nil?)
		if (request_type == "PUT")
			payload = param_hash.to_json
			request.body="#{payload}"
		else
			# if parameter hash is not null, attach them to form
			request.set_form_data(param_hash)
		end
  	end
	
	response = http.request(request)

	@logger.info "ESB call #{@esb_call_hash['call_count']} #{Time.new.strftime("%Y%m%d%H%M%S")} #{url}"

	# increase the call count by one
	@esb_call_hash['call_count'] += 1

	@logger.info "ESB call status " + response.code
	return response
end

## checks the result of ESB API call
## renew ESB token if necessary, and retry the failed call due to expired token
## return parsed JSON. for simple use case how token,scope is tied up please refer to the examples in /test directory
def parse_ESB_API_CALL_RESPONSE(response, url, content_type, request_type, param_hash,scope)
	if (response.code == "401")
		## failed request
		@logger.info "token expired see below:"
		@logger.info response.body
		#renew token
		refreshESBToken(scope);
		## retry the failed call due to expired token
		response = ESB_APICall(url, "Bearer " + getESBToken(scope,true), true, content_type, request_type, param_hash)
	end
	if (response.code == "401")
		## still failed with bad token
		@logger.error "ESB call " + url + " failed again after token renewal "
		return nil
	else
		return json_parse_safe(url, response.body, @logger)
	end
end

## the ESB PUT call to set class URL in MPathway
def setMPathwayUrl(termId, sectionId, courseId)

	lmsUrl = @canvasUrl + "/courses/" + courseId.to_s
	#get course information
	call_url = @esbUrl + "/aa/CurriculumAdmin/Terms/#{termId}/Classes/#{sectionId}/LMSURL";
	response = ESB_APICall(call_url, "Bearer " + getESBToken(@CurriculumAdminScope,false), true,"application/json", "PUT", {"lmsURL" => lmsUrl})
	return parse_ESB_API_CALL_RESPONSE(response, call_url, "application/json", "PUT", {"lmsURL" => lmsUrl},@CurriculumAdminScope)
end

## the ESB PUT call to set class URL in MPathway
def deleteUrlForUnpublishedSections(termId, setSectionPublished)
	#get all sections with LMSURL
	call_url = @esbUrl + "/aa/CurriculumAdmin/Terms/#{termId}/ClassesWithLMSURL";
	response = ESB_APICall(call_url, "Bearer " + getESBToken(@CurriculumAdminScope,false), true,"application/json", "GET", {})
	result = parse_ESB_API_CALL_RESPONSE(response, call_url, "application/json", "GET", nil,@CurriculumAdminScope)
	if (result.nil?)
		@logger.error "There are no MPathway sections with LMSURL set"
		return
	end
	@logger.info(response.body)
	sectionString = result['ClassNumberData']

	# check whether sectionString attribute is null
	if (sectionString.nil?)
		@logger.warn "There is no sectionString value with result value " + response.body
		return
	end

	# splite the comma separated SIS IDs, into set
	sectionArray = sectionString.split(",")
	sectionWithUrlSet = sectionArray.to_set
	@logger.info "1. There are #{sectionWithUrlSet.size} sections with LMSURL in MPathway for the term #{termId}"
	@logger.info sectionWithUrlSet

	# log the total published sections in Canvas
	@logger.info "2. There are #{setSectionPublished.size} sections with published courses in Canvas for the term #{termId}"
	@logger.info setSectionPublished

	# find out the diff, and LMSURL needs to be removed from those sections
	sectionWithUrlSet = sectionWithUrlSet.subtract(setSectionPublished)
	@logger.info "3. There are #{sectionWithUrlSet.size} UNPUBLISHED sections with LMSURL for the term #{termId}, where LMSURL needs to be removed:"
	@logger.info sectionWithUrlSet

	# iterate through the set and delete the url
	sectionWithUrlSet.each do |sectionId|
		call_url = @esbUrl + "/aa/CurriculumAdmin/Terms/#{termId}/Classes/#{sectionId}/LMSURL"
		@logger.info call_url
		response = ESB_APICall(call_url, "Bearer " + getESBToken(@CurriculumAdminScope,false), true,"application/json", "DELETE", {})
		@logger.info(response.body)
	end
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

# for each sections, call the set LMSURL
def processSectionData(courseId, error_message, section, setSectionPublished, sisTermId)
	sectionParsedSISID = nil
	section.each do |sectionKey, sectionValue|
		if (sectionKey=="sis_section_id")
			## get the sis_section_id value
			sectionParsedSISID=sectionValue
			break
		end
	end
	if (sectionParsedSISID != nil)
		if (!sectionParsedSISID.match(/^\d+$/) || sectionParsedSISID.length != 9)
			# if the section id is not in 9-digit format
			# log the error and skip the following set URL call for this section
			@logger.warn "#{sectionParsedSISID} is not of 9-digit format for SIS section id"
			return error_message
		end
		@logger.info "section id #{sectionParsedSISID}"
		## sis_section_id is 9-digit: <4-digit term id><5-digit section id>
		# we will use just the last 5-digit of the section id
		sectionParsedSISID = sectionParsedSISID[4, 8]

		# add the section sis id into the set
		setSectionPublished.add(sectionParsedSISID);

		result_json = setMPathwayUrl(sisTermId, sectionParsedSISID, courseId)
		if (!result_json.nil? && (result_json.has_key? "setLMSURLResponse") && result_json["setLMSURLResponse"] != nil)
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
	error_message
end

# for single Canvas course, find sections within the course, and set URL for those sections
def processCourseData(course, error_message, setSectionPublished, sisTermId, termId, term_course_count)
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
					error_message = processSectionData(courseId, error_message, section, setSectionPublished, sisTermId)
				}
			end
		end
	else
		@logger.info "Course #{course["course_code"]} with SIS Course ID #{course["sis_course_id"]} is of status #{course["workflow_state"]}, will not set url for its classes. \n"
	end
	error_message
end

## 1. get the terms from Canvas
## 2. compare the term list with MPathway term list, take the terms which are in both sets
## 3. iterate through all courses in each term,
## 4. if the course is open/available, find sections/classes in each course, set the class url in MPathway
def processTermCourses(mPathwayTermSet)
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
            if (json_data.nil?)
                @logger.info "There is no published course for term id = #{termId}"
                next
            end

			term_course_count = 0

			## new set of MPathway section ids associated with published Canvas courses in given term
			setSectionPublished = Set.new

			json_data.each { |course|
				# iterate through course
				error_message = processCourseData(course, error_message, setSectionPublished, sisTermId, termId, term_course_count)
			}

			# now compare the published section ids set (SetA) with existing MPathways sections with urls (SetB)
			# for any SetB item not in SetA, it means the section is no longer published in Canvas, and hence need to remove it Canvas url
			deleteUrlForUnpublishedSections(sisTermId, setSectionPublished);

		end # term loop
	}
	return error_message
end

def update_MPathway_with_Canvas_url()
	upload_error = false

	# get the MPathway term set
	mPathwayTermSet = getMPathwayTerms()

	# set URL start time
	@logger.info "set URL start time : #{Time.new.inspect}"

	#call Canvas API to get course url
	upload_error = processTermCourses(mPathwayTermSet)

	# set URL stop time
	@logger.info "set URL stop time : #{Time.new.inspect}"

	return upload_error

end

## end of method definition

## read the command line arguments
def read_argv
	Dotenv.load
	@logger.info(ENV)

	@canvasToken=ENV['canvas_token']
	@canvasUrl=ENV['canvas_url']
	@esbKey=ENV['esb_key']
	@esbSecret=ENV['esb_secret']
	@esbUrl=ENV['esb_url']
	@esbTokenUrl=ENV['esb_token_url']
	@page_size=ENV['page_size']
	@esb_call_hash["time_interval_in_seconds"]=ENV['esb_time_interval'].to_i
	@esb_call_hash["allowed_call_number_during_interval"]=ENV['esb_allowed_call_number'].to_i
	@canvas_call_hash["time_interval_in_seconds"]=ENV['canvas_time_interval'].to_i
	@canvas_call_hash["allowed_call_number_during_interval"]=ENV['canvas_allowed_call_number'].to_i
	@alert_email_address=ENV['alert_email_address']
end


####################### main ########################
# to invoke this script, use the following format
# ruby ./SIS_update_url.rb <the_security_file_path> <the_properties_file_path>
####################################################

# process error, will notify user through email
process_error = nil

# init from command line arguments
read_argv

@logger.info "canvasUrl=" + @canvasUrl

begin

	# update MPathway with Canvas urls
	updateError = update_MPathway_with_Canvas_url()

	if (updateError && updateError.nil? && updateError.empty?)
		## if there is upload error
		@logger.warn(updateError)
	end
	@logger.info "Sites set URLs finished."
end



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
require "rubygems" ## needed for ruby 1.8.7 

## refresh token for ESB API call
def refreshESBToken()
	encoded_string = Base64.strict_encode64 ($esbKey + ":" + $esbSecret)
	param_hash={"grant_type"=>"client_credentials","scope"=> "PRODUCTION"}
	json = ESB_APICall($esbTokenUrl + "/token?grant_type=client_credentials&scope=PRODUCTION",
	                  "Basic " + encoded_string,
	                  "application/x-www-form-urlencoded",
	                  "POST",
	                  param_hash)
	return json["access_token"]
end

## make Canvas API call
def Canvas_APICall(url, authorization_string, content_type, request_type, param_hash)
	response = RestClient.get url, {:Authorization => "Bearer #{authorization_string}",
	                                :accept => content_type,
	                                :verify_ssl => true}
return JSON.parse(response)
end

## make ESB API call
def ESB_APICall(url, authorization_string, content_type, request_type, param_hash)
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
	#if (request != "PUT")

	request.add_field("Content-Type", content_type)
	request.add_field("Accept", "*/*")
	#end
	#request.add_field("Accept", "application/json")
	#request.add_field("Accept", "plain/text")


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
	store.add_cert(OpenSSL::X509::Certificate.new(File.read($caRootFilePath)))
	store.add_cert(OpenSSL::X509::Certificate.new(File.read($inCommonFilePath)))
	sock.cert_store = store

	#sock.set_debug_output $stdout #useful to see the raw messages going over the wire
	sock.read_timeout = 30
	sock.open_timeout = 30
	sock.start do |http|
		response = http.request(request)
	end
	return JSON.parse(response.body)
end

## the ESB PUT call to set class URL in MPathway
def setMPathwayUrl(canvasUrl, esbUrl, esbToken, termId, sectionId, courseId)

	lmsUrl = canvasUrl + "/courses/" + courseId.to_s
	lmsUrl=URI.escape(lmsUrl)
	#get course information
	call_url = esbUrl + "/CurriculumAdmin/v1/Terms/#{termId}/Classes/#{sectionId}/LMSURL";
	result= ESB_APICall(call_url, "Bearer " + esbToken, "application/json", "PUT", {"lmsURL" =>lmsUrl})
	# result hash format
	# {"setLMSURLResponse"=>{"Resultcode"=>"Success", "ResultMessage"=>""}}
	return JSON.parse(result.to_json)
end

## get the current term info from MPathway
def getMPathwayTerms(esbToken)
	rv = Set.new()
	#get term information
	call_url = $esbUrl + "/Curriculum/SOC/v1/Terms";
	result= ESB_APICall(call_url, "Bearer " + esbToken, "application/json", "GET", nil)
	# TODO: we are expecting an array here eventually. But for single item return, it is not in array form now
	termId=result["getSOCTermsResponse"]["Term"]["TermCode"]
	rv.add(termId)
	return rv
end

## 1. get the terms from Canvas
## 2. compare the term list with MPathway term list, take the terms which are in both sets
## 3. iterate through all courses in each term,
## 4. if the course is open/available, find sections/classes in each course, set the class url in MPathway
def processTermCourses(mPathwayTermSet,esbToken, outputFile)

	term_data = Canvas_APICall("#{$canvasUrl}/api/v1/accounts/1/terms",
	                           "Bearer #{$canvasToken}",
	                           "application/json",
	                           "GET",
	                           nil)
	term_data["enrollment_terms"].each {|term|
		if(mPathwayTermSet.include?(term["sis_term_id"]))
			#SIS term ID
			sisTermId = term["sis_term_id"]

			# this is the term we are interested in
			termId = term["id"]

			outputFile.write("for term SIS_ID=#{term["sis_term_id"]} and Canvas term id=#{termId}\n")

			# Web Service call
			json_data = Canvas_APICall("#{$canvasUrl}/api/v1/accounts/1/courses?per_page=100&enrollment_term_id=#{termId}&published=true&with_enrollments=true",
			                  "Bearer #{$canvasToken}",
			                  "application/json",
			                  "GET",
			                  nil)
			#outputFile.write("#{json_data}\n")
			count = 1
			json_data.each { |course|
				if (course.has_key?("workflow_state") && course["workflow_state"] == "available" )
					# only set url for those published sections
					# course is a hash
					course.each do |key, value|
						if (key=="id")
							courseId = value
							sections_data = Canvas_APICall("#{$canvasUrl}/api/v1/courses/#{courseId}/sections",
							                           "Bearer #{$canvasToken}",
							                           "application/json",
							                           "GET",
							                           nil)
							#outputFile.write("#{sections_data}\n")
							sections_data.each { |section|
								# section is a hash
								section.each do |sectionKey, sectionValue|
									if (sectionKey=="id")
										section_data = Canvas_APICall("#{$canvasUrl}/api/v1/sections/#{sectionValue}",
										                               "Bearer #{$canvasToken}",
										                               "application/json",
										                               "GET",
										                               nil)
										if (section_data.has_key?("sis_section_id"))
											sectionParsedSISID=section_data["sis_section_id"]
											if (sectionParsedSISID != nil)
												## for now we will use just the last 5-digit of the section id
												sectionParsedSISID = sectionParsedSISID[4,8]

												result_json = setMPathwayUrl($canvasUrl, $esbUrl, esbToken, sisTermId, sectionParsedSISID, courseId)
												message = "set url result for course id=#{sectionParsedSISID} with Canvas courseId=#{courseId}: result status=#{result_json["setLMSURLResponse"]["Resultcode"]} and result message=#{result_json["setLMSURLResponse"]["ResultMessage"]}\n\n"
												p message
												# write into output file
												outputFile.write(message)
											end
										end
									end
								end
							}
						end
					end
				else
					outputFile.write("Course #{course["course_code"]} with SIS Course ID #{course["sis_course_id"]} is of status #{course["workflow_state"]}, will not set url for its classes. \n")
			end
			p count
			}
		end
	}
end

## the main function
def update_MPathway_with_Canvas_url(esbToken, outputDirectory)

	upload_error = false
	parsed_result = false

	#set the error flag, default to be false
	update_error = false

	#open the output file
	begin
		time = Time.now
		time_formatted = time.strftime("%Y_%m_%d_%H%M%S")
		outputFile = File.open(outputDirectory + "url_update_#{time_formatted}.txt", "w")

		# get the MPathway term set
		mPathwayTermSet = getMPathwayTerms(esbToken)

		#call Canvas API to get course url
		processTermCourses(mPathwayTermSet, esbToken, outputFile)
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

# to invoke this script, use the following format
# ruby ./SIS_update_url.rb <the_token_file_path> <the_server_name> <the_workspace_path> <the_esb_file_path>

# the current working directory
currentDirectory=""

# the Canvas parameters
$canvasUrl = ""
# the Canvas access token
$canvasToken=""

# ESB parameters
esbTokenFile=""
$esbKey=""
$esbSecret=""
$esbUrl=""
$esbTokenUrl=""
# those two cert files are needed for ESB calls
$caRootFilePath=""
$inCommonFilePath=""

# the command line argument count
count=1
# iterate through the inline arguments
ARGV.each do|arg|
	if (count==1)
		if (Dir[arg].length != 1)
			## token file
			abort("Cannot find token file " + arg)
		end
		File.open(arg, 'r') do |tokenFile|
			while line = tokenFile.gets
				# only read the first line, which is the token value
				$canvasToken=line.strip
				break
			end
		end
	elsif (count==2)
		# the second argument should be the server name
		$canvasUrl=arg
	elsif (count==3)
		# the third path should be the workspace path
		currentDirectory=arg
	elsif (count==4)
		esbTokenFile=arg

		# the fourth param should be the ESB config file
		File.open(esbTokenFile, 'r') do |file|
			while line = file.gets
				# only read the first line
				# format: key=KEY,secret=secret
				env_array = line.strip.split(',')
				key_array=env_array[0].split('=')
				$esbKey=key_array[1]
				secret_array=env_array[1].split('=')
				$esbSecret=secret_array[1]
				url_array=env_array[2].split('=')
				$esbUrl=url_array[1]
				token_url_array=env_array[3].split('=')
				$esbTokenUrl=token_url_array[1]
				caRootFilePath_array=env_array[4].split('=')
				$caRootFilePath=caRootFilePath_array[1]
				inCommonFilePath_array=env_array[5].split('=')
				$inCommonFilePath=inCommonFilePath_array[1]
				break
			end
		end
	else
		# break
	end

	#increase count
	count=count+1
end

# get then log output directory
outputDirectory=currentDirectory + "logs/"

p "canvasUrl=" + $canvasUrl
p "current directory: " + currentDirectory
p "output directory: " + outputDirectory

if (Dir[currentDirectory].length != 1)
	## working directory
	abort("Cannot find current working directory " + currentDirectory)
elsif (Dir[outputDirectory].length != 1)
	## logs directory
	abort("Cannot find logs directory " + outputDirectory)
else
	# URL update start time
	p "URL update start time : " + Time.new.inspect

	esbToken=refreshESBToken()

	# update MPathway with Canvas urls
	updateError = update_MPathway_with_Canvas_url(esbToken, outputDirectory)


	# upload stop time
	p "upload stop time : " + Time.new.inspect

	if (!updateError)
		## if there is no upload error
		p "Sites update URLs finished"
		exit
	else
		abort(updateError)
	end
end


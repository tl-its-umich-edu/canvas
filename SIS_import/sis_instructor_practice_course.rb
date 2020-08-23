# placeholder for user sandbox site title
USERNAME="USERNAME"
PREVIOUS_USER_SANDBOX_NAME = "A Canvas training course for #{USERNAME}"
TARGET_USER_SANDBOX_NAME = "#{USERNAME}'s Practice Course"

# for sandbox site creation purpose: looking for users with teacher role, with active enrollment status, both defined in the enrollment file
TEACHER_ROLE_ARRAY = ["teacher", "ta"]
ACTIVE_STATUS = 'active'
ENROLLMENTS_FILE_NAME = 'enrollments.csv'

#
# read instructor information from zip file
# return a set consists SIS id of all instructors
#
def get_teacher_sis_ids_set(zip_file_name, logger)
	# create a hash for all unique teachers SIS ids
	set_teacher_sis_ids = Set.new
	Zip::ZipFile.open(zip_file_name) do |zipfile|
		zipfile.each do |entry|
			if entry.name == ENROLLMENTS_FILE_NAME
				# read the enrollment file name
				user_line_content = entry.get_input_stream.read
				user_line_array = user_line_content.split("\n")
				user_line_array.each {
					|user|
					# format of ',user_mpathway_id,role,section_id,status'
					user_attrs = user.split(",")
					user_mpathway_id = user_attrs[1]
					user_role = user_attrs[2]
					user_status = user_attrs[4]
					if (TEACHER_ROLE_ARRAY.include? user_role and user_status == ACTIVE_STATUS)
						# find user with teacher role and is active
						if (!set_teacher_sis_ids.include? user_mpathway_id)
							set_teacher_sis_ids.add user_mpathway_id
							logger.info "add user id = #{user_mpathway_id} into teacher set"
						end
					end
				}
			end
		end
	end

	return set_teacher_sis_ids
end


def create_instructor_new_sandbox_site(user_canvas_id, user_name, user_sis_login_id, logger, practice_course_subaccount, server_api_url)
	# the new sandbox site name
	user_sandbox_site_name = TARGET_USER_SANDBOX_NAME.gsub(USERNAME, user_name)
	user_sandbox_site_course_code = TARGET_USER_SANDBOX_NAME.gsub(USERNAME, user_sis_login_id)

	# check again for the current naming format of user sandbox site
	user_sandbox_site = Canvas_API_GET("#{server_api_url}accounts/#{practice_course_subaccount}/courses?search_term=#{user_sandbox_site_name}")
	if (user_sandbox_site.nil? || user_sandbox_site.length == 0 || user_sandbox_site.empty?)
		# create user sandbox site
		# if there is no such sandbox site, creat one
		result = Canvas_API_POST("#{server_api_url}accounts/#{practice_course_subaccount}/courses",
		                         {
			                         "course[name]" => user_sandbox_site_name,
			                         "course[course_code]" => user_sandbox_site_course_code
		                         },
		                         nil)
		logger.info "Created a sandbox site - #{user_sandbox_site_name} for User #{user_sis_login_id} \n #{result}"

		# get the newly created course id
		# add the instructor to the course as instructor
		if (result.has_key?("id"))
			sandbox_course_id = result.fetch("id")
			instructor_result = Canvas_API_POST("#{server_api_url}courses/#{sandbox_course_id}/enrollments",
			                                    {
			                                      "enrollment[user_id]" => user_canvas_id,
			                                      "enrollment[type]" => "TeacherEnrollment",
			                                      "enrollment[enrollment_state]" => "active"
			                                    },
			                                    nil)
			if (!instructor_result.nil?)
				logger.info "Enrolled User #{user_sis_login_id} to sandbox course site - #{user_sandbox_site_name} (#{sandbox_course_id}) \n #{instructor_result} \n"
			else
				logger.error "Null JSON value returned for adding enrollment call #{server_api_url}courses/#{sandbox_course_id}/enrollments of user_id #{user_canvas_id}"
			end
		else
			# no id field, log as warning
			logger.warn "There is no id field in the sandbox course json \n #{result}"
		end
	else
		# there is already such site
		logger.info "Sandbox course site #{user_sandbox_site_name} already exists. "
	end
end

def rename_site(course_id, user_sis_login_id, user_sandbox_site_name, logger)
	# if there is no such sandbox site, creat one
	result = Canvas_API_PUT("#{$server_api_url}courses/#{course_id}",
	                        {
		                        "course[name]" => user_sandbox_site_name,
		                        "course[course_code]" => user_sandbox_site_name
	                        })
	if (result.nil?)
		logger.error "Null JSON value returned for Canvas PUT call #{$server_api_url}courses/#{course_id} of course=#{user_sandbox_site_name}"
	else
		logger.info "User #{user_sis_login_id} has a old sandbox site #{user_sandbox_site_name}, and it is renamed to new title #{user_sandbox_site_name} " + result
	end
end

#
# The function to read zip file input and create sandbox sites for all defined instructors
#
def create_all_instructor_sandbox_site(zip_file_name, logger, server_api_url, account_number, practice_course_subaccount)
	# create a hash for all unique teachers SIS ids
	set_teacher_sis_ids = get_teacher_sis_ids_set(zip_file_name, logger)
	logger.info "found total #{set_teacher_sis_ids.size} users with teaching role"

	# now that we have a set of allteacher sis ids, we will create sandbox site for those users
	# counter
	count_teachers = 0
	set_teacher_sis_ids.each {
		|user_mpathway_id|
		count_teachers = count_teachers+1
		logger.info "#{count_teachers}/#{set_teacher_sis_ids.size} found user #{user_mpathway_id}"
		# find user canvas id
		user_details_json = Canvas_API_GET("#{server_api_url}accounts/#{account_number}/users?search_term=#{user_mpathway_id}")
		if (!user_details_json.nil? && user_details_json.size == 1)
			# found user in Canvas
			user_canvas_id = user_details_json[0]["id"]
			user_sis_login_id = user_details_json[0]["login_id"]
			user_name = user_details_json[0]["name"]

			# 1. see whether there is an sandbox site for this user
			previous_user_sandbox_site = Canvas_API_GET("#{server_api_url}accounts/#{practice_course_subaccount}/courses?search_term=#{PREVIOUS_USER_SANDBOX_NAME.gsub(USERNAME, user_name)}")
			if (previous_user_sandbox_site.nil? || previous_user_sandbox_site.length == 0)
				# 2. create new sandbox site with new name format
				create_instructor_new_sandbox_site(user_canvas_id, user_name, user_sis_login_id, logger, practice_course_subaccount, server_api_url)
			else
				# 3. need to rename the previous course with new course title format
				course_id=previous_user_sandbox_site[0]["id"]
				rename_course_site(course_id, user_name, user_sandbox_site_name, user_sis_login_id, logger)
			end
		else
			logger.warn "Cannot find user with id #{user_mpathway_id}"
		end
	}
end

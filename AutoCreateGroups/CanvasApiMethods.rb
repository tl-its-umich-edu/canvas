# Web Service call to get information for a particular course api/v1/courses/:course_id
def get_course_data(auth_token, course_id)
	json_course_data=`curl -s -H "Authorization: Bearer #{auth_token}" https://umich.test.instructure.com/api/v1/courses/#{course_id}`

	course = JSON.parse(json_course_data)

	puts "---------------------------------------"
	puts "COURSE CODE: #{course["course_code"]}"
	puts "COURSE NAME: #{course["name"]}"
	puts "COURSE ID: #{course["id"]}"
	puts "---------------------------------------"

	return JSON.parse(json_course_data)
end

# Web Service call to get course sections -- GET /api/v1/courses/:course_id/sections
def get_course_section_data(auth_token, course_id)
	json_course_section_data=`curl -s -H "Authorization: Bearer #{auth_token}" https://umich.test.instructure.com/api/v1/courses/#{course_id}/sections `
	return JSON.parse(json_course_section_data)
end

# Web Service call to get group categories for course  api/v1/courses/:course_id/group_categories 
def get_group_category_data(auth_token, course_id)
	json_group_category_data=`curl -s -H "Authorization: Bearer #{auth_token}" https://umich.test.instructure.com/api/v1/courses/#{course_id}/group_categories`
	return JSON.parse(json_group_category_data)
end
# Web Service call to add a group to a course. POST /api/v1/group_categories/:group_category_id/groups
def add_group(auth_token, group_category_id, group_name)
	new_group=`curl -H "Authorization: Bearer #{auth_token}" https://umich.test.instructure.com/api/v1/group_categories/#{group_category_id}/groups -F "is_public=false" -F "join_level=invitation_only"  -F "name=#{group_name}" -F "description=#{group_name}"`
	return JSON.parse(new_group)
end

# Web Service call to get enrollments for a particular section.  -- GET /api/v1/sections/:section_id/enrollments
def get_section_enrollment_data(auth_token, section_id)
	json_section_enrollment_data=`curl -s -H "Authorization: Bearer #{auth_token}" https://umich.test.instructure.com/api/v1/sections/#{section_id}/enrollments?per_page=150 `
	return JSON.parse(json_section_enrollment_data)
end

# Web Service call to get user information -- /api/v1/users/:user_id/profile
def get_user_data(auth_token, user_id)
	json_user_data=`curl -s -H "Authorization: Bearer #{auth_token}" https://umich.test.instructure.com/api/v1/users/#{user_id}/profile`
	return JSON.parse(json_user_data)
end

# Web Service call to add user to group -- /api/v1/groups/:group_id/invite -F "invitees[]=#{user_email}"
def add_user_to_group(auth_token, group_id, user_email)
	`curl -H "Authorization: Bearer #{auth_token}" https://umich.test.instructure.com/api/v1/groups/#{group_id}/invite -F "invitees[]=#{user_email}" `
end

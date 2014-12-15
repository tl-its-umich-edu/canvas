#!/usr/bin/env ruby

require "json"
require "./CanvasApiMethods.rb"

APP_ROOT = File.dirname(__FILE__)
require File.join(APP_ROOT, 'lib', 'SectionGroup')

# Constants. TODO: make these web page entry fields to be passed into this script.
#######################################################
# Course Id of course for which we will add groups
SOURCE_COURSE = "166"
# This is only used for testing. I am copying the sections from STATS 250 (course_id: 166) and creating groups in my own testcourse (course_id: 571)
DEST_COURSE = "571"
# Auth Token to invoke Canvas API's
CANVAS_AUTH_TOKEN = "****** PLACE YOUR AUTH TOKEN HERE ******"
# Currently using lecture size as an indicator if section is a lecture section or lab section. Need to 
# change to use ESB call to differentiate between lecture and lab sessions. 
LECTURE_SECTION_SIZE = 100


# Add student enrollment to groups
STUDENT_ENROLLMENT_TYPE = "StudentEnrollment"
# Exclude student view enrollment from groups.
STUDENT_VIEW_ENROLLMENT_TYPE = "StudentViewEnrollment"


## !!!!! HARD-CODED FOR NOW TO STATS 250 (course_id: 166). Should be input from web page in the future.
# Get information for course we are interested in.
course = get_course_data(CANVAS_AUTH_TOKEN, SOURCE_COURSE)

# Get sections for a particular course.
parsed_section_data = get_course_section_data(CANVAS_AUTH_TOKEN, course["id"])

puts "Number of Sections for this course: #{parsed_section_data.length}"

# This is the main data structure that keeps track of the sections and groups for the target course
section_hash = Hash.new()

parsed_section_data.each {
	|section| 

	section_group = SectionGroup.new

	section_group.section_id = section["id"]
	section_group.section_name = section["name"]

	#Build a hash with Section Id and Section Name to be used to create the groups.
	section_hash[section["id"]] = section_group

}

puts "Size of section_hash: #{section_hash.length}"
## Done building hash with all sections in course.

##### !!!!! HARD-CODING GROUP ID (DEST_COURSE) FOR MY CANVAS TEST COURSE.
parsed_group_category_data = get_group_category_data(CANVAS_AUTH_TOKEN, DEST_COURSE)

# There should be only one course category for a course. Ask Victoria ???
parsed_group_category_data.each {
	|groupCategory| puts "Group Category Id: #{groupCategory["id"]} Group Category Name: #{groupCategory["name"]}"

	puts "------------"
		# Iterate through list of Sections and create a Group for each section.
		section_hash.each{

			|section| 
			
			# Extract section name from course section name.
			section_name_index = section[1].section_name.downcase.index /section/

			if section_name_index != nil
				group_name = section[1].section_name[section_name_index..section[1].section_name.length-1]
			else
				group_name = section[1].section_name
			end
			# Capitalize Section name.
			group_name = group_name.capitalize

			# Ideally we don't want to create a group for lecture sections but not sure how to exclue them right now.
			parsed_new_group_data = add_group(CANVAS_AUTH_TOKEN, groupCategory["id"], group_name)

			puts "CREATED Group: #{parsed_new_group_data["name"]} with Group Id: #{parsed_new_group_data["id"]}" 

			# Store the group id and name so we have a relation between section id's and group id's so we can later add students
			## to the groups.
			section[1].group_id = parsed_new_group_data["id"]
			section[1].group_name = parsed_new_group_data["name"]
			puts "Added group id to object #{section}"

		} # We are done creating groups.
		  ##############################
}

	## Now we add students to the groups.
	#####################################
	puts "---STARTING TO ADD STUDENTS TO GROUPS---"
	# Iterate through section hash. Retrieve enrollments for each section and add them to respective group
	section_hash.each{
		|section| 
		puts "GOING TO PROCESS SECTION #{section[0]}"

		parsed_enrollments= get_section_enrollment_data(CANVAS_AUTH_TOKEN, section[0])

		puts "NUMBER OF ENROLLMENTS FOR SECTION #{section[0]} #{section[1].section_name} --> #{parsed_enrollments.length}"

		# For each enrollment, get the section from the section_hash, get the group id from the SectionGroup object and insert
		# student into group.

		puts "STARTING TO PROCESS ENROLLMENTS FOR SECTION #{section[0]}"
		if parsed_enrollments.length < LECTURE_SECTION_SIZE
			parsed_enrollments.each {
				|enrollment| 

				puts "Enrollment Id: #{enrollment["id"]} Enrollment Section Id: #{enrollment["course_section_id"]} Enrollment Type: #{enrollment["type"]} Student Id: #{enrollment["user_id"]} Course Id: #{enrollment["course_id"]} "
				
				parsed_user_data = get_user_data(CANVAS_AUTH_TOKEN, enrollment["user_id"])

				puts "Student for this enrollment-> #{parsed_user_data["name"]}  #{enrollment["type"]} LOGIN ID #{parsed_user_data["login_id"]} User id: #{parsed_user_data["id"]}"
				puts

				# Only add student enrollment type to groups.
				if enrollment["type"] == STUDENT_ENROLLMENT_TYPE 
					# Retrieve the section_group object from the section_hash so we can determine the group associated with this section.
					section_group = section[1]
				
					if section_group != nil
						group_id = section_group.group_id
						user_email = parsed_user_data["login_id"] + '@umich.edu'
						add_user_to_group(CANVAS_AUTH_TOKEN, group_id, user_email)
						puts "ADDED User #{user_email} to group #{group_id} Group Name: #{section_group.group_name}"				
					end
				else
					puts "FOUND ENROLLMENT OTHER THAN STUDENT. DO NOT ADD TO GROUP --> #{enrollment["type"]} Enrollment Name: #{parsed_user_data["name"]} "
				end
			}
		end
	}
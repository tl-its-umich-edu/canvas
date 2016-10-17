# Stack descriptions along the top row of the document
# Then stack answers per user along subsequent rows.
from datetime import datetime
import csv

# We need to find all student enrollments for a given section.
# So, we cannot exit the matching loop on the first try,
# unlike the user file.
def parse_enrollments(sectionId):

	with open("./enrollments.csv", 'r') as enrollments:
		enrollmentReader = csv.reader(enrollments)
		next(enrollmentReader, None) # skip headers
		for row in enrollmentReader:		
			emplid = row[3]
			role = row[4]
			enrollSectionId = row[7]
		
			if sectionId == enrollSectionId:
				if role == "student":
					#useful for debugging if this point was reached.
					#print "Calling parse users. \n"
		
					try:
						names_file.write(emplid + "\n")
					except:
						print "encountered an error, here is the relevant data:"
						print sectionId
						print enrollSectionId
						print emplid



def parse_sections(courseId):

	with open("sections.csv", 'r') as sections:
		sectionReader = csv.reader(sections)
		next(sectionReader, None) # skip headers
		for row in sectionReader:
			sectionId = row[1]
			sectionCourseId = row[3]
		
			if courseId == sectionCourseId:
				#useful for debugging if this point was reached.			
				#print "Passing the section id to the enrollments function."
				parse_enrollments(sectionId)


def parse_courses():

	courseCounter = 1

	with open('courses.csv', 'r') as courses:
		courseReader = csv.reader(courses)
		next(courseReader, None) # skip the headers
		for row in courseReader:
			courseId = row[1]
			courseStatus = row[8]

			if courseStatus == "active":
				#useful for debugging if this point was reached.
				#print "I am sending the id to the parse_sections function."
				parse_sections(courseId)
		
			courseCounter += 1
		
			if courseCounter % 100 == 0:
				print "I have processed " + str(courseCounter) + " courses."


def dedupe_list():
	seq = names_file.readlines()
	seen = set()
	seen_add = seen.add
	return [x for x in seq if not (x in seen or seen_add(x))]


# This script takes a list of courses and
# generates a list of emplids for enrolled students.
print "started at: " + str(datetime.now()) + "\n"

# name of temporary output file is temp_emplids.csv.
# we will de-dupe this a few lines down for our final output file.
names_file = open("./temp_emplids.csv", 'w')
parse_courses()
names_file.close
print "ended at: " + str(datetime.now()) + "\n"
names_file = open("./temp_emplids.csv", 'r')

# the name of our final output file is student_emplids.csv.
uniqnames_file = open("./student_emplids.csv", 'w')
uniqnames_file.writelines(dedupe_list())

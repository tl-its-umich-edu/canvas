# Stack descriptions along the top row of the document
# Then stack answers per user along subsequent rows.
from datetime import datetime
import csv

'''
def parse_users(emplid):

	with open("./enrollments.csv", 'r') as users
		userReader = csv.reader(users)
		next(userReader, None) # skip headers
		for row in userReader:
			userEmplid = row[1]
			userUniqname = row[2]
			userFirstname = row[3]
			userLastname = row[4]
			userEmail = row[9]

			if emplid == userEmplid:
				print userEmplid + " \n"
				print userUniqname + " \n"
				print userFirstname + " \n"
				print userLastname + " \n"
				print userEmail + " \n"
				return userEmplid, userUniqname, userFirstname, userLastname, userEmail
'''

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
			#print emplid + "\n"
		
			if sectionId == enrollSectionId:
				if role == "student":
					#print "Calling parse users. \n"
					#umid, uniqname, firstname, lastname, email = parse_users(emplid)
		
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
			#print sectionCourseId + "\n"
		
			if courseId == sectionCourseId:
				#print "Passing the section id to the enrollments function."
				parse_enrollments(sectionId)


def parse_courses():

	courseCounter = 1
#	activeCourses = 0

	with open('courses.csv', 'r') as courses:
		courseReader = csv.reader(courses)
		next(courseReader, None) # skip the headers
		for row in courseReader:
			courseId = row[1]
			courseStatus = row[8]

			if courseStatus == "active":
#				print "I am sending the id to the parse_sections function."
#				activeCourses += 1
				parse_sections(courseId)
		
			courseCounter += 1
		
			if courseCounter % 100 == 0:
				print "I have processed " + str(courseCounter) + " courses."

#	print "Active courses: " + str(activeCourses)

def dedupe_list():
	seq = names_file.readlines()
	seen = set()
	seen_add = seen.add
#	print seq
	return [x for x in seq if not (x in seen or seen_add(x))]


# This script takes a list of courses and
# generates a list of students that are enrolled 
# with their name and uniqname.
print "started at: " + str(datetime.now()) + "\n"
names_file = open("./student_names.csv", 'w')
parse_courses()
names_file.close
print "ended at: " + str(datetime.now()) + "\n"
names_file = open("./student_names.csv", 'r')
uniqnames_file = open("./uniqnames.csv", 'w')
uniqnames_file.writelines(dedupe_list())

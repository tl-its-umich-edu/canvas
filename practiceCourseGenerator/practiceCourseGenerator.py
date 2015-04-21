'''

@author: Kyle Dove

Purpose: Download user list from Google Drive spreadsheet. Use list to call 
Canvas and generate a zip directory that can be used to create Canvas practice 
courses. 

'''

import logging
import time
import csv
import time
import requests
import json
import os
import zipfile

def download_file(service, drive_file):
    """Download a file's content.

    Args:
            service: Drive API service instance.
            drive_file: Drive File instance.

    Returns:
            File's content if successful, None otherwise.
    """
    download_url = drive_file['exportLinks']['text/csv']
    print 'DownloadUrl: ' + download_url
    if download_url:
            resp, content = service._http.request(download_url)
            if resp.status == 200:
                    print 'Status: %s' % resp
                    title = drive_file.get('title')
                    path = './data/'+title+'.csv'
                    file = open(path, 'wb')
                    file.write(content)
            else:
                    print 'An error occurred: %s' % resp
                    return None
    else:
            # The file doesn't have any content stored on Drive.
            return None

def zipdir(path, zip):
    for root, dirs, files in os.walk(path):
        for file in files:
            zip.write(os.path.join(root, file))

#setup log

#create logger 'canvas_scraper'
logger = logging.getLogger('canvasFileGenerator')
logger.setLevel(logging.INFO)
logdate = time.strftime("%Y%m%d%H%M")

#create file handler
fh = logging.FileHandler('canvasFileGeneratorLog_' + logdate + '.log')
fh.setLevel(logging.INFO)

#create console handler
ch = logging.StreamHandler()
ch.setLevel(logging.INFO)

#create formatter and add it to the handlers
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
fh.setFormatter(formatter)
ch.setFormatter(formatter)

#add the handlers to the logger
logger.addHandler(fh)
logger.addHandler(ch)

logger.info('Script Initiated')

#def getInputFile():
lines = []
userSets = []
users = []
finalUsers = []
userStrings = []
dataSets = []
directoryCounter = 0
outputDirectory = './canvas_files'
userHeader = 'user_id,login_id,password,first_name,last_name,email,status'
courseHeader = 'course_id,short_name,long_name,account_id,term_id,status,start_date,end_date'
enrollmentHeader = 'course_id,user_id,role,section_id,status,associated_user_id'
userDictionaries = []

#Production Environment
#urlPrefix = 'https://umich.instructure.com/api/v1/users/sis_login_id:'

#Beta Environment
urlPrefix = 'https://umich.beta.instructure.com/api/v1/users/sis_login_id:'

#Testing Environment
#urlPrefix = 'https://umich.test.instructure.com/api/v1/users/sis_login_id:'

urlPost = '/profile?access_token='

#Get Token
with open('token.txt') as f:
    for line in f:
    	token = line.rstrip('\n')

#Get Input File
with open('input.csv') as f:
	for line in f:
		line = line.rstrip('\n')
		lines.append(line)

for line in lines:
	#skips header row
	if line == lines[0]:
			continue
	logger.info('Line: ' + line)
	parsedLine = line.split('"')
	userString = parsedLine[1]
	logger.info('User String: ' + userString)
	userSets.append(userString)

logger.info('Folder Exists: ' + str(os.path.isdir(outputDirectory)))

if os.path.isdir(outputDirectory):
	#rename folder
	logger.info('Need to rename directory')
	os.rename(outputDirectory,outputDirectory+'_'+logdate)
	os.mkdir(outputDirectory)
else:
	#create folder
	logger.info('Need to create the directory')
	os.mkdir(outputDirectory)

urlPost = urlPost + token

for userSet in userSets:
	logger.info('User Set:')
	users = (userSet.split(','))
	for user in users:
		if user not in finalUsers:
			finalUsers.append(user)

#Generate users.csv file
with open(outputDirectory + '/users.csv', 'wb') as csvfile:
	csvfile.write(userHeader + '\n')
	for user in finalUsers:
		logger.info('User: ' + user)
		url = urlPrefix + user + urlPost
		logger.info('URL: ' + url)
		data = json.loads(requests.get(url).text)
		logger.info('Data: ' + str(data))
		fullName = data['sortable_name'].split(',')
		data['firstName'] = fullName[1].strip()
		data['lastName'] = fullName[0].strip()
		logger.info('First Name: ' + data['firstName'])
		logger.info('Last Name: ' + data['lastName'])
		userDictionaries.append(data)
		userString = str(data['sis_user_id']) + ',' + data['login_id'] + ',' + ',' + data['firstName'] + ',' + data['lastName'] + ',' + data['primary_email'] + ',' + 'active'
		logger.info('User Record: ' + userString)
		csvfile.write(userString + '\n')

#Generate courses.csv file
with open(outputDirectory + '/courses.csv', 'wb') as csvfile:
	csvfile.write(courseHeader + '\n')
	for user in userDictionaries:
		courseId = str(user['login_id'] + '_practice_course')
		shortName = 'Practice Course for ' + user['firstName'] + ' ' + user['lastName']
		longName = shortName
		accountId = '1055'
		termId = ''
		status = 'active'
		startDate = ''
		endDate = ''
		courseString = str(courseId + ',' + shortName + ',' + longName + ',' + accountId + ',' + termId + ',' + status + ',' + startDate + ',' + endDate)
		logger.info('Course Record: ' + courseString)
		csvfile.write(courseString + '\n')

#Generate enrollments.csv file
with open(outputDirectory + '/enrollments.csv', 'wb') as csvfile:
	csvfile.write(enrollmentHeader + '\n')
	for user in userDictionaries:
		courseId = str(user['login_id'] + '_practice_course')
		userId = str(user['sis_user_id'])
		role = 'teacher'
		status = 'active'
		enrollmentString = str(courseId + ',' + userId + ',' + role + ',' + ',' + status + ',')
		logger.info('Enrollment Record: ' + enrollmentString)
		csvfile.write(enrollmentString + '\n')

#zip it!
zipFileName = 'Canvas_Practice_courses_' + logdate + '.zip'
zipf = zipfile.ZipFile(zipFileName, 'w')
zipdir(outputDirectory, zipf)
zipf.close()

logger.info('Script Completed - Done')

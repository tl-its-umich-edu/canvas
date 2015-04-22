'''

@author: Kyle Dove

Purpose: Download users list from Google Drive. Generate CSV files in 
directory. Zip directory to be used to create Canvas practice courses.

DATE           Author               Description   
===========    ===============      ============================================
Mar 31 2015    Kyle Dove			TLUNIZIN-470
									Created.

'''

import logging
import time
import csv
import requests
import json
import os
import zipfile
from apiclient.discovery import build
from httplib2 import Http
from oauth2client import file, client, tools
from apiclient import errors
from apiclient import http

def download_file(service, drive_file):
    download_url = drive_file['exportLinks']['text/csv']
    logger.info('DownloadUrl: ' + download_url)
    if download_url:
            resp, content = service._http.request(download_url)
            if resp.status == 200:
                    logger.info('Status: %s' % resp)
                    title = drive_file.get('title')
                    path = './input.csv'
                    file = open(path, 'wb')
                    file.write(content)
            else:
                    logger.info('An error occurred: %s' % resp)
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
errorCount = 0
outputDirectory = './canvas_files'
userHeader = 'user_id,login_id,password,first_name,last_name,email,status'
courseHeader = 'course_id,short_name,long_name,account_id,term_id,status,start_date,end_date'
enrollmentHeader = 'course_id,user_id,role,section_id,status,associated_user_id'
userDictionaries = []

#Read properties file
with open('propertiesProd.json') as data_file:    
    data = json.load(data_file)

logger.debug('urlPrefix: ' + str(data['URL_PREFIX']))
logger.debug('driveFile: ' + str(data['DRIVE_FILE']))

urlPrefix = str(data['URL_PREFIX'])
urlPost = '/profile?access_token='

#Download exceptions file
CLIENT_SECRET = 'tl_client_secret.json'
SCOPES = [
	'https://www.googleapis.com/auth/drive.readonly',
	'https://www.googleapis.com/auth/drive',
	'https://www.googleapis.com/auth/drive.appdata',
	'https://www.googleapis.com/auth/drive.apps.readonly',
	'https://www.googleapis.com/auth/drive.file',
	'https://www.googleapis.com/auth/drive.readonly'
]
store = file.Storage('storage.json')
creds = store.get()
if not creds or creds.invalid:
    flow = client.flow_from_clientsecrets(CLIENT_SECRET, ' '.join(SCOPES))
    creds = tools.run(flow, store)
DRIVE = build('drive', 'v2', http=creds.authorize(Http()))
file_Id = str(data['DRIVE_FILE'])
gFile = DRIVE.files().get(fileId = file_Id).execute()
download_file(DRIVE, gFile)

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
	#rename
	logger.info('Need to rename directory')
	os.rename(outputDirectory,outputDirectory+'_'+logdate)
	os.mkdir(outputDirectory)
else:
	#create 
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
		logger.info("User: '" + user + "'")
		logger.info('Stripping user white space')
		user = user.strip()
		url = urlPrefix + user + urlPost
		logger.info('URL: ' + url)
		data = json.loads(requests.get(url).text)
		logger.info('Data: ' + str(data))
		#If given bad input and a user profile is not returned an error JSON object will be returned instead. Print error message and continue iterating.
		if 'errors' in data:
			errors = data['errors']
			for error in errors:
				#Record error message and the user to whom it pertains
				logger.info('Error: ' + user + ' ' + error['message'])
			errorCount += 1
			logger.debug('Error Count: ' + str(errorCount))
			continue
		#Some users from Dearborn maybe in a course. These users do not have SIS IDs and do not belong in our version of Canvas. We do not have to generate practice courses for them. Continue iterating.
		if 'sis_user_id' not in data:
			logger.info(user + ' is missing SIS_ID')
			continue
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

logger.info('Error Count: ' + str(errorCount))
logger.info('Script Completed - Done')

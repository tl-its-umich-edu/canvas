'''

@author: Kyle Dove

Purpose: Download users list from Google Drive. Generate CSV files in 
directory. Zip directory to be used to create Canvas practice courses.

'''

import logging
import time
import csv
import requests
import json
import os
import zipfile
import hashlib
import sys
import shutil
import apiclient.discovery as gDriveClient
from enum import Enum
from httplib2 import Http
from oauth2client import file, client, tools
from apiclient import errors
from apiclient import http

def downloadFile(service, driveFile):
    downloadUrl = driveFile['exportLinks']['text/csv']
    logger.info('DownloadUrl: ' + downloadUrl)
    if downloadUrl:
    	resp, content = service._http.request(downloadUrl)
    	if resp.status == 200:
    		logger.info('Status: %s' % resp)
    		title = driveFile.get('title')
    		path = title + '.csv'
    		file = open(path, 'wb')
    		file.write(content)
    		return path
        else:
         	logger.info('An error occurred: %s' % resp)
         	return None
    else:
    	# The file doesn't have any content stored on Drive.
    	return None

def downloadUsersFile(clientSecret, storageFile):
	SCOPES = [
		'https://www.googleapis.com/auth/drive.readonly',
		'https://www.googleapis.com/auth/drive',
		'https://www.googleapis.com/auth/drive.appdata',
		'https://www.googleapis.com/auth/drive.apps.readonly',
		'https://www.googleapis.com/auth/drive.file',
		'https://www.googleapis.com/auth/drive.readonly'
	]
	store = file.Storage(storageFile)
	creds = store.get()
	if not creds or creds.invalid:
		flow = client.flow_from_clientsecrets(clientSecret, ' '.join(SCOPES))
		creds = tools.run(flow, store)
	DRIVE = gDriveClient.build('drive', 'v2', http=creds.authorize(Http()))
	fileId = str(data['DRIVE_FILE'])
	gFile = DRIVE.files().get(fileId = fileId).execute()
	path = downloadFile(DRIVE, gFile)
	return path

def writeCsvFile(type, header, outputDirectory, userDictionaries):
	if type is FileType.users:
		with open(outputDirectory + '/users.csv', 'wb') as csvfile:
			csvfile.write(header + '\n')
			for user in userDictionaries:
				logger.info("User: '" + user['login_id'] + "'")
				userString = str(user['sis_user_id']) + ',' + user['login_id'] + ',' + ',' + user['firstName'] + ',' + user['lastName'] + ',' + user['primary_email'] + ',' + 'active'
				logger.info('User Record: ' + userString)
				csvfile.write(userString + '\n')
	if type is FileType.courses:
		with open(outputDirectory + '/courses.csv', 'wb') as csvfile:
			csvfile.write(header + '\n')
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
	if type is FileType.enrollments:
		with open(outputDirectory + '/enrollments.csv', 'wb') as csvfile:
			csvfile.write(header + '\n')
			for user in userDictionaries:
				courseId = str(user['login_id'] + '_practice_course')
				userId = str(user['sis_user_id'])
				role = 'teacher'
				status = 'active'
				enrollmentString = str(courseId + ',' + userId + ',' + role + ',' + ',' + status + ',')
				logger.info('Enrollment Record: ' + enrollmentString)
				csvfile.write(enrollmentString + '\n')

def zipdir(path, zip):
    for root, dirs, files in os.walk(path):
        for file in files:
            zip.write(os.path.join(root, file))

def populateUserDictionary(userList, urlPrefix, urlPost):
	global errorCount
	for user in userList:
		logger.info("User: '" + user + "'")
		logger.info('Stripping user white space')
		user = user.strip()
		url = urlPrefix + user + urlPost
		logger.info('URL: ' + url)
		data = json.loads(requests.get(url).text)
		logger.info('Data: ' + str(data))
		#If given bad input and a user profile is not returned an error JSON 
		#object will be returned instead. Print error message and continue 
		#iterating.
		if 'errors' in data:
			errors = data['errors']
			for error in errors:
				#Record error message and the user to whom it pertains
				logger.info('Error: ' + user + ' ' + error['message'])
			errorCount += 1
			logger.debug('Error Count: ' + str(errorCount))
			continue
		#Some users from Dearborn maybe in a course. These users do not have 
		#SIS IDs and do not belong in our version of Canvas. We do not have 
		#to generate practice courses for them. Continue iterating.
		if 'sis_user_id' not in data:
			logger.info('Error ' + user + ' is missing SIS_ID')
			errorCount += 1
			continue
		fullName = data['sortable_name'].split(',')
		#Ran into issue where user did not have last name entered in Canvas.
		if len(fullName) is not 2:
			logger.info('Error ' + user + ' only has first or last name entered')
			errorCount += 1
			continue
		data['firstName'] = fullName[1].strip()
		data['lastName'] = fullName[0].strip()
		userDictionaries.append(data)
	return userDictionaries

def generateMd5(fileName, fileNameBase):
	checkSum = hashlib.md5(open(fileName, 'rb').read()).hexdigest()
	logger.info('CheckSum for ' + str(fileName) + ': ' + str(checkSum))
	#Write checkSum to file
	checkSumFile = fileNameBase + 'MD5.txt'
	with open(checkSumFile, 'wb') as writeFile:
		writeFile.write(checkSum)

def setupLogger(logDirectory, logdate):
	#create logger 'canvasFileGenerator'
	logger = logging.getLogger('canvasFileGenerator')
	logger.setLevel(logging.INFO)

	#create file handler
	fh = logging.FileHandler(logDirectory + '/canvasFileGeneratorLog_' + logdate + '.log')
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

	return logger

if len(sys.argv) is not 4:
	print 'ERROR: Expecting format $ python practiceCourseGenerator.py dataDirectory logDirectory propsDirectory'
	sys.exit(2)

logdate = time.strftime("%Y%m%d%H%M")

#Veraiables
lines = []
userSets = []
users = []
finalUsers = []
userStrings = []
dataSets = []
userDictionaries = []

FileType = Enum('FileType', 'users courses enrollments')

directoryCounter = 0
errorCount = 0

dataDirectory = sys.argv[1]
logDirectory = sys.argv[2]
propsDirectory = sys.argv[3]

outputDirectory = dataDirectory + '/canvas_files'
fileNameBase = dataDirectory + '/Canvas_Extract_Practice_courses_' + logdate

propertiesFile = propsDirectory + '/properties.json'
tokenFile = propsDirectory + '/token.txt'
clientSecret = propsDirectory + '/tl_client_secret.json'
storageFile = propsDirectory + '/storage.json'

userHeader = 'user_id,login_id,password,first_name,last_name,email,status'
courseHeader = 'course_id,short_name,long_name,account_id,term_id,status,start_date,end_date'
enrollmentHeader = 'course_id,user_id,role,section_id,status,associated_user_id'

logger = setupLogger(logDirectory, logdate)

logger.info('Script Initiated')

#Read properties file
with open(propertiesFile) as dataFile:    
    data = json.load(dataFile)

logger.debug('urlPrefix: ' + str(data['URL_PREFIX']))
logger.debug('driveFile: ' + str(data['DRIVE_FILE']))

urlPrefix = str(data['URL_PREFIX'])
urlPost = '/profile?access_token='

usersFilePath = downloadUsersFile(clientSecret, storageFile)

#Get Token
with open(tokenFile) as f:
    for line in f:
    	token = line.rstrip('\n')

#Get Input File #canvas_practice_course_requests.csv
with open(usersFilePath) as f:
	for line in f:
		line = line.rstrip('\n')
		lines.append(line)

for line in lines:
	#skips header row
	if line == lines[0]:
			continue
	logger.info('Line: ' + line)
	if '"' in line:
		parsedLine = line.split('"')
	else:
		parsedLine = line.split(',')
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
	users = (userSet.split(','))
	for user in users:
		if user not in finalUsers:
			finalUsers.append(user)

userDictionaries = populateUserDictionary(finalUsers, urlPrefix, urlPost)

for user in userDictionaries:
	logger.info('User Dictionary: ' + str(user))

writeCsvFile(FileType.users, userHeader, outputDirectory, userDictionaries)
writeCsvFile(FileType.courses, courseHeader, outputDirectory, userDictionaries)
writeCsvFile(FileType.enrollments, enrollmentHeader, outputDirectory, userDictionaries)

#zip it!
zipFileName = fileNameBase + '.zip'
zipf = zipfile.ZipFile(zipFileName, 'w')
zipdir(outputDirectory, zipf)
zipf.close()

generateMd5(zipFileName, fileNameBase)

#delete the temporary file used for zipping
shutil.rmtree(outputDirectory)

logger.info('Error Count: ' + str(errorCount))
logger.info('Script Completed - Done')

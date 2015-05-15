'''

@author: Kyle Dove

Purpose: Pull data from Canvas using the Canvas API to create summary report 
on notification preferences. 

'''

import logging
import time
import requests
import json
import numpy
import csv
import re
import time

#setup log

#create logger 'canvas_scraper'
logger = logging.getLogger('notificationPreferencesReportGenerator')
logger.setLevel(logging.INFO)
logdate = time.strftime("%Y%m%d")

#create file handler
fh = logging.FileHandler('notificationPreferencesReportGenerator_' + logdate + '.log')
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

#Variables
CHECKED_NOTIFICATIONS = []
CHECKED_FREQUENCIES = []
users = []
userNotificationChannels = []
userCount = 0
channelCount = 0
errorCount = 0
apiCallCount = 0
propertiesFile = './properties.json'

#Read properties file
with open(propertiesFile) as dataFile:    
    data = json.load(dataFile)

logger.debug('urlPrefix: ' + str(data['URL_PREFIX']))

urlPrefix = str(data['URL_PREFIX'])

#Get Token
with open('token.txt') as f:
    for line in f:
    	token = line.rstrip('\n')

#Get notifications that we are checking
with open('checkedNotifications.txt') as f:
    for line in f:
    	CHECKED_NOTIFICATIONS.append(line.rstrip('\n'))

#Get the frequencies that we are checking
with open('checkedFrequencies.txt') as f:
    for line in f:
    	CHECKED_FREQUENCIES.append(line.rstrip('\n'))

#Get the users that we are checking
with open('users.txt') as f:
    for line in f:
    	users.append(line.rstrip('\n'))

#Create empty matrix to hold counts for notifications and frequencies being checked
matrix = numpy.zeros(shape=(len(CHECKED_NOTIFICATIONS), len(CHECKED_FREQUENCIES)))

logger.debug('CHECKED_NOTIFICATIONS: ' + str(CHECKED_NOTIFICATIONS))
logger.debug('CHECKED_FREQUENCIES: ' + str(CHECKED_FREQUENCIES))
logger.debug('token: ' + token)

urlPostChannels = '/communication_channels?access_token=' + token
urlPostPreferences = '/notification_preferences?access_token=' + token

#For each user, get the user's notification channel(s) 
for user in users:
	#Increment user count
	userCount += 1
	logger.info('Checking User sisID: ' + user)
	url = urlPrefix + user + urlPostChannels
	logger.info('URL: ' + url)
	logger.debug('Retrieiving data from ' + url + ' and converting it into dictionary data structure')
	apiCallCount += 1
	time.sleep(1.2)
	#Grabs data and enters it into python dictionary data structure
	channelData = json.loads(requests.get(url).text)
	logger.debug('Channel Data: ' + str(channelData))

	#For each communication channel in channelData...
	for channel in channelData:
		#If an error is found - add 1 to the error count and skip there account
		if channel == 'errors':
			errors = channelData['errors']
			for error in errors:
				#Record error message and the user to whom it pertains
				logger.info('Error: ' + user + ' ' + error['message'])
			errorCount += 1
			logger.debug('Error Count: ' + str(errorCount))
			break
		else:
			logger.debug('DATA:')
			logger.debug(channel)
			logger.debug('KEYS:')
			logger.debug(channel.keys())
			logger.debug('Checking Channel ID: ' + str(channel['id']))
			logger.debug('Channel Type: ' + channel['type'])

			#Only check type email
			if channel['type'] == 'email':
				channelCount += 1
				url = urlPrefix + user + '/communication_channels/' + str(channel['id']) + urlPostPreferences
				logger.debug('URL: ' + url)
				logger.debug('Retrieiving data from ' + url + ' and converting it into dictionary data structure')
				preferencesData = json.loads(requests.get(url).text)
				apiCallCount += 1
				time.sleep(1.2)
				logger.debug('DATA:')
				logger.debug(preferencesData)
				logger.debug('KEYS:')
				logger.debug(preferencesData['notification_preferences'][0].keys())
				notificationPreferences = preferencesData['notification_preferences']
				#Iterate through the notification preferences
				for notificationPreference in notificationPreferences:
					#If a notification preference is in the list to be checked, check it. Otherwise don't do anything with it.
					if notificationPreference['notification'] in CHECKED_NOTIFICATIONS and notificationPreference['frequency'] in CHECKED_FREQUENCIES:
						logger.debug('Notification: ' + notificationPreference['notification'] + ' ' + notificationPreference['frequency'])
						row = CHECKED_NOTIFICATIONS.index(notificationPreference['notification'])
						column = CHECKED_FREQUENCIES.index(notificationPreference['frequency'])
						logger.debug(str(row) + ',' + str(column))
						matrix[row][column] += 1 

logger.debug('\n' + str(matrix))

#Write Reort file out to CSV
with open('outputReport.csv', 'wb') as csvfile:
	writer = csv.writer(csvfile, delimiter=',', quotechar=' ', quoting=csv.QUOTE_MINIMAL)
	writer.writerow([' '] +  CHECKED_FREQUENCIES)
	for r in range(len(CHECKED_NOTIFICATIONS)):
		writeString = CHECKED_NOTIFICATIONS[r]
		for c in range(len(CHECKED_FREQUENCIES)):
			writeString = writeString + ',' + str(int(matrix[r][c]))
		logger.debug(writeString)
		writer.writerow([writeString])
	writer.writerow(' ')
	errorString = 'Error Count: ' + str(errorCount)
	writer.writerow([errorString])
	userString = 'User Count: ' + str(userCount)
	writer.writerow([userString])
	channelString = 'Channel Count: ' + str(channelCount)
	writer.writerow([channelString])

logger.info('API calls made: ' + str(apiCallCount))
logger.info('Script Completed - Done')
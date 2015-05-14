#Notification Preference Report Generator

Description: The following README file corresponds with the 'canvasNotificationCall.py' file. 
When run, the script will read an admin token from a file. Then the script 
will read the users from a file. The script will then use the token and ID to 
create a URI to query canvas and return a user's notification preferences. The 
script will then summarize these results in a csv file.

NOTE: The following instructions assume that you have Python 2.7 installed. As 
Macs come pre-installed with Python 2.7, if you are running on another platform 
you will need to install Python 2.7 on your local machine.

1.	Install pip with the following command in terminal:
		sudo easy_install pip

2.	Install requests package with the following command in terminal:
		sudo pip requests

3.	Create a file called token.txt in the same directory as the test.py file.

4.	Modify the token.txt file to contain the token of the admin user you plan on using for the script.

5.	Create a file called users.txt in the same directory as the test.py file.

6.	Modify the users.txt file to contain the sisIDs of the users you wish to query in the following format:

	12345678</br>
	23456789</br>
	34567890</br>
	...
	...
	...

7.	Create a file called checkedFrequencies.txt. This file will contain the frequencies that you would like the report to show.

	NOTE: There are only four types of frequencies: immediately, daily, weekly, never

8. Create a file called checkedNotifications.txt. This file will contain the notification types that you would like the report to show.

	NOTE: Some examples of Notification Types are as follows: 

	assignment_due_date_changed</br>
	new_file_added</br>
	new_announcement</br>
	assignment_graded</br>
	collaboration_invitation</br> 

	NOTE: You can find a user's notification channel id by performing the following API call:

	[base_url]/api/v1/users/sis_user_id:[sis_user_id]/communication_channels?access_token=[token]

	EXAMPLE OUTPUT (where '123456' is the communication channel id):

	[
    	{
        	"id": 123456,
        	"position": 1,
        	"user_id": 123123,
        	"workflow_state": "active",
        	"address": "me@college.edu",
        	"type": "email"
    	}
	]

	NOTE: You can view all the notification types by pulling a single users notification preferences. The API call for that is: 

	EXAMPLE OUTPUT:

	[base_url]/api/v1/users/sis_user_id:[sis_user_id]/communication_channels/[communication_channel_id]/notification_preferences?access_token=[token]

	{
    	"notification_preferences": [
        	{
            	"frequency": "immediately",
            	"notification": "new_announcement",
            	"category": "announcement"
        	},
        	{
            	"frequency": "weekly",
            	"notification": "assignment_due_date_changed",
            	"category": "due_date"
        	},
        	{
            	"frequency": "never",
            	"notification": "conversation_created",
            	"category": "conversation_created"
        	}
    	]
	}

9.	Run 'Scraper'

10.	There will be 2 output files: 

	canvasScrapeLog_[date].log</br>
	outputReport.csv

The log will contain any logging that was set to be recorded in the script. The 
CSV file will contain the metrics for your user's notification preferences as 
they correspond with the user list in users.txt, the notifications listed in 
notificationsChecked.txt, and the frequencies listed in checkedFrequencies.txt.

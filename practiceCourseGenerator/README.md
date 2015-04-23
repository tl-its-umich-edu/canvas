# Canvas Practice Course Generator

Description: Python script for generating zip file that can be used to create 
practice courses for students in Canvas.

Installation:

For this script to run the following needs to be installed...

1. Python 2.7
2. google-api-python-client

Installing the google-api-python-client is simple with PIP:

In a command line teminal, type the following:

	pip install --upgrade google-api-python-client

Of course this requires that you have PIP installed.

To install PIP open a terminal, type the following:

	sudo easy_install pip

Mac's come with Python 2.7 which includes easy_install so this should work.


Input: 

1. input.csv - gathered from Google Drive
2. propertiesProd.json -  holds custom properties
3. storage.json - holds information to access google drive
4. tl_client_secret.json - holds information to access google drive
5. token.txt -  holds token to use Canvas API

Output: 

1. Directory - canvas_files_[Date]
2. File - Canvas_Practice_courses_[Data].zip
3. File - canvasFileGeneratorLog_[Date].log

Process:

1. Create log file for record keeping regarding the success or failure of the 
run.

2. Download file from Google Drive - Canvas Practice Course Training List 
(Responses) and rename it to input.csv

3. Use input.csv to gather the list of users that need a practice course 
generated.

4. With this list of users, the URL from the properties file, and the Canvas 
toekn from the properties file - make Canvas API call to gather information 
on specific users.

5. Create a directory to be zipped in a later step.

6. Generate 3 csv files necessary for generating Canvas Practice Courses:

A. courses.csv
B. enrollments.csv
C. users.csv

7. Put the three aforementioned files into the directory made in step 5.

8. Zip the directory into it's own file.

9. Close the log file.
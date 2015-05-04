# Canvas Practice Course Generator

Description: Python script for generating zip file that can be used to create 
practice courses for instructors in Canvas.

## Installation:

1. Install Vagrant <http://www.vagrantup.com/downloads>
2. Start virtual server `vagrant up`
3. Login into vertual server: `vagrant ssh`
4. cd \vagrant
5. Run application: `python practiceCourseGenerator.py . .`

## Running application

Input: 

1. Canvas Practice Course Training List (Responses).csv - gathered from Google Drive
2. propertiesProd.json -  holds custom properties
3. storage.json - holds information to access google drive
4. tl_client_secret.json - holds information to access google drive
5. token.txt -  holds token to use Canvas API

Output: 

1. Directory - canvas_files_[Date]
NOTE: This directory will be zipped and used as an input file for he SIS_import script.
2. File - Canvas_Practice_courses_[Data].zip
3. File - canvasFileGeneratorLog_[Date].log

Process:

1. Create input files as specified above
2. Run application `python practiceCourseGenerator.py . .`
3. Three csv files are generated in zip file:
	* courses.csv
	* enrollments.csv
	* users.csv
4. Upload entire zip file into Canvas (instructions tbd)
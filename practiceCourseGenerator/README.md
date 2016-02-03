# Canvas Practice Course Generator

Description: Python script for generating zip file that can be used to create practice courses for instructors in Canvas. The list of instructors is harvested from a google form/file.

## Pre-requisits

While Vagrant isn't required, it's the recommended to use for running this script in a pre-defined virtual image.

1. Install Vagrant <http://www.vagrantup.com/downloads>
2. Install the ubuntu image used for running this script: `vagrant box add hashicorp/precise32`
3. Install VirtualBox or VMWare (if not already installed)

## Installation

1. Create properties files from samples (umich.edu users should download from deluxe.ctools.org)
2. Start virtual server (with default VirtualBox): `vagrant up`
    * or with VMWare `vagrant up --provider=vmware_fusion`
3. Login into vertual server: `vagrant ssh`
4. cd /vagrant

## Running application

The following configuration files are required. Secure copies (prod and qa) can be found on deluxe (/usr/local/ctools/securityFiles/practiceCourseGenerator/).

1. properties.json -  holds custom properties
2. storage.json - holds information to access google drive
3. tl_client_secret.json - holds information to access google drive
4. token.txt -  holds token to use Canvas API

The application take 3 arguments, which identifies the location of the data, logs, and configuration file directories. The list of users is taken from a google file.

2. Run the application: `python practiceCourseGenerator.py . . .`
2. The outputs include:
    * Canvas_Extract_Practice_courses MD5 
    * Canvas_Extract_Practice_courses zip file (courses, enrollments, users)
    * canvasFileGeneratorLog log file
    * Canvas Practice Course Training List (Responses).csv
3. Upload the Canvas_Extract_Practice_courses_[]DATE].zip file into Canvas using Admin -> SIS Import

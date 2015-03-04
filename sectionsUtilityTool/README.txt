[Sections Utility Tool]

1) [Build Directions]
 
 a) sectionsTool$ mvn clean install
 b) copy to tomcat/webapp
 c) Add 2 property files on linux box sectionsToolPropsSecure.properties and sectionsToolPropsLessSecure.properties Then in JAVA_OPTS add  2 -D's 
		 1) -DsectionsToolPropsPathSecure=file:/<file-path>/sectionsToolPropsSecure.properties 
		 2) -DsectionsToolPropsPathLessSecure=file:/<file-path>/sectionsToolPropsLessSecure.properties 
 d) Run this as http://localhost:port/sectionsUtilityTool/?testUser=<uniquename>.
     no need of testUser in Prod as we will enable the cosign for authentication and we will be getting remote user info from that.
 
2) [sectionsToolPropsSecure.properties]
 Add the following 3 properties to this file. 
 # paste admin token here
canvas.admin.token=
# eg.https://umich.test.instructure.com
canvas.url=
# when cosign/local development is not enable set it true. Production should always be set it to false. We are enabling testUser for local develpemt and with this variable testUser will never is enabled. 
use.test.url=false

3)[sectionsToolPropsLesssecure.properties]
Add these following  properties to this file. These values will be same for Prod/dev envi. ldap is used for authorizing the user and he needs to be part of particular Mcommunity group for give authorization.
ldap.server.url=
mcomm.group=
 

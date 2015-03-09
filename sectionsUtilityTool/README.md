[Sections Utility Tool]

1) [Build Directions]
 
 a) sectionsTool$ mvn clean install
 b) copy to tomcat/webapp
 c) Add the property file on linux box sectionsToolPropsSecure.properties  then in JAVA_OPTS add the -D
		 1) -DsectionsToolPropsPathSecure=file:/<file-path>/sectionsToolPropsSecure.properties 
 d) Run this in local http://localhost:port/sectionsUtilityTool/?testUser=<uniquename>.
     testUser parameter is not allowed in Prod and this is controlled by below property with value called use.test.url=false. we will enable the cosign for authentication the user so we will get remote user info through that.
 
2) [sectionsToolPropsSecure.properties]
 Add the following 5 properties to this file. 
 # paste admin token here
canvas.admin.token=
# eg.https://umich.test.instructure.com
canvas.url=

#If "use.test.url" is true, users will be able to execute the tool as if authenticated as the user specified in the URL parameter ?testUser=. In Production this variable is  false. Based on this property 
property testUser is not allowed in Production
use.test.url=false

#ldap is used for authorizing the user and he needs to be part of particular Mcommunity group to be authorized to use the tool.
# umich ldap server name
ldap.server.url=
#Mcommunity group name
mcomm.group=


 

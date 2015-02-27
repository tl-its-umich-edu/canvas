[Sections Utility Tool]

1) [Build Directions]
 
 a) sectionsTool$ mvn clean install
 b) copy to tomcat/webapp
 c) Add the property file on your linux box sectionsToolProps.properties. Then in JAVA_OPTS -DsectionsToolPropsPath=file:/Users/pushyami/sections/sectionsToolProps.properties 
 d) Run this as http://localhost:port/sectionsUtilityTool
 
2) [sectionsToolProps.properties]
 Add the following 2 properties to this file. 
 # paste admin token here
canvas.admin.token=
# eg.https://umich.test.instructure.com
canvas.url=
# when cosign/local development is not enable set it true. Production should always be set it to false. We are enabling testUser for local develpemt and with this variable testUser will never is enabled. 
test.url=false

 
 

# Sections Utility Tool

## Build Directions
 
1. sectionsTool$ <code>mvn clean install</code>
2. Copy to tomcat/webapp
3. Add the property file on linux box <code>sectionsToolPropsSecure.properties</code>,   
then in JAVA_OPTS add the  
<code>-DsectionsToolPropsPathSecure=file:/file-path/sectionsToolPropsSecure.properties</code>
4. Add the following 5 properties to sectionsToolPropsSecure.properties: 

    <code>canvas.admin.token=canvas token  
    canvas.url=target canvas server e.g. https://umich.test.instructure.com  
    use.test.url=true  
    ldap.server.url=ldap server e.g. ldap://ldap.itd.umich.edu:389/dc=umich,dc=edu  
    mcomm.group=group that can use this tool e.g. its-canvas-sections</code>

5. Run this in local  
<code>http://localhost:port/sectionsUtilityTool/?testUser=uniquename</code>
  1. testUser parameter is not allowed in Prod and this is controlled by above property with value called <code>use.test.url=false</code>
  2. We will enable the cosign for authentication the user so we will get remote user info through that.

## Notes

If <code>use.test.url</code> is true, users will be able to execute the tool as if authenticated as the user specified in the URL parameter <code>?testUser=uniqname</code>. In Production this variable is  false. Based on this property property testUser is not allowed in Production.

ldap is used for authorizing the user and he needs to be part of particular Mcommunity group to be authorized to use the tool.


 

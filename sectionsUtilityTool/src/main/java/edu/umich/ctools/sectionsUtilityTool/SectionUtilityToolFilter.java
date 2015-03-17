package edu.umich.ctools.sectionsUtilityTool;

import java.io.IOException;
import java.util.Hashtable;
import java.util.Properties;

import javax.naming.Context;
import javax.naming.NamingEnumeration;
import javax.naming.NamingException;
import javax.naming.directory.Attribute;
import javax.naming.directory.DirContext;
import javax.naming.directory.InitialDirContext;
import javax.naming.directory.SearchControls;
import javax.naming.directory.SearchResult;
import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;

import edu.umich.its.lti.utils.PropertiesUtilities;



public class SectionUtilityToolFilter implements Filter {

	private static Log M_log = LogFactory.getLog(SectionUtilityToolFilter.class);
	
	private static final String OU_GROUPS = "ou=Groups";
	private static final String LDAP_CTX_FACTORY = "com.sun.jndi.ldap.LdapCtxFactory";
	protected static final String SYSTEM_PROPERTY_FILE_PATH_SECURE = "sectionsToolPropsPathSecure";
	protected static final String PROPERTY_CANVAS_ADMIN = "canvas.admin.token";
	protected static final String PROPERTY_CANVAS_URL = "canvas.url";
	protected static final String PROPERTY_USE_TEST_URL = "use.test.url";
	protected static final String PROPERTY_LDAP_SERVER_URL = "ldap.server.url";
	private static final String PROPERTY_AUTH_GROUP = "mcomm.group";
	private static final String TEST_USER = "testUser";
	private String providerURL = null;
	private String mcommunityGroup = null;
	private boolean isTestUrlEnabled=false;
	protected static Properties appExtSecurePropertiesFile=null;
	private static final String FALSE = "false";
	
	@Override
	public void init(FilterConfig filterConfig) throws ServletException {
		M_log.debug("Filter Init(): Called");
		getExternalAppProperties();
		
	}

	@Override
	public void doFilter(ServletRequest request, ServletResponse response,
			FilterChain chain) throws IOException, ServletException {
		M_log.debug("doFilter: Called");
		HttpServletRequest useRequest = (HttpServletRequest) request;
		HttpServletResponse useResponse=(HttpServletResponse)response;
		if(!checkForAuthorization(useRequest)) {
			useResponse.sendError(403);
			return;
		}
		chain.doFilter(useRequest, response);
	}

	@Override
	public void destroy() {
		M_log.debug("destroy: Called");
	}
	
	protected void getExternalAppProperties() {
		M_log.debug("getExternalAppProperties(): called");
		String propertiesFilePathSecure = System.getProperty(SYSTEM_PROPERTY_FILE_PATH_SECURE);
		if (!isEmpty(propertiesFilePathSecure)) {
			appExtSecurePropertiesFile=PropertiesUtilities.getPropertiesObjectFromURL(propertiesFilePathSecure);
			if(appExtSecurePropertiesFile!=null) {
				isTestUrlEnabled = Boolean.parseBoolean(appExtSecurePropertiesFile.getProperty(SectionUtilityToolFilter.PROPERTY_USE_TEST_URL,FALSE));
				providerURL=appExtSecurePropertiesFile.getProperty(PROPERTY_LDAP_SERVER_URL);
				mcommunityGroup=appExtSecurePropertiesFile.getProperty(PROPERTY_AUTH_GROUP);
			}else {
				M_log.error("Failed to load secure application properties from sectionsToolPropsSecure.properties for SectionsTool");
			}
			
		}else {
			M_log.error("File path for (sectionsToolPropsPathSecure.properties) is not provided");
		}
		
	}
	 private boolean isEmpty(String value) {
		return (value == null) || (value.trim().equals(""));
	}
	
	/*
	 * User is authenticated using cosign and authorized using Ldap. For local development we are enabling
	 * "testUser" parameter. "testUser" also go through the Ldap authorization process. 
	 * we have use.test.url configured in the properties file in order to disable usage of "testUser" parameter in PROD.
	 * 
	 */
	 private boolean checkForAuthorization(HttpServletRequest request) {
		 M_log.debug("checkLdapForAuthorization(): called");
		 String remoteUser = request.getRemoteUser();
		 String testUser = request.getParameter(TEST_USER);
		 boolean isAuthorized = false;
		 String user=null;

		 String testUserInSession = (String)request.getSession().getAttribute(TEST_USER);

		 if ( isTestUrlEnabled && testUser != null ) { 
			 user=testUser;
			 request.getSession().setAttribute(TEST_USER, testUser);
		 }
		 else if ( isTestUrlEnabled && testUserInSession != null ){
			 user=testUserInSession;
		 } 
		 if  ( !isAuthorized && remoteUser != null ) {
			 user=remoteUser;
			 M_log.info("The Service Desk Person uniqname issuing the request is: "+remoteUser);
		 }
		 isAuthorized=ldapAuthorizationVerification(user); 
		 return isAuthorized;


	 }
     /*
      * The Mcommunity group we have is a members-only group is one that only the members of the group can send mail to. 
      * The group owner can turn this on or off.
      * More info on Ldap configuration  http://www.itcs.umich.edu/itcsdocs/r1463/attributes-for-ldap.html#group.
      */
	private boolean ldapAuthorizationVerification(String user)  {
		M_log.debug("ldapAuthorizationVerification(): called");
		boolean isAuthorized = false;
		DirContext dirContext=null;
		NamingEnumeration listOfPeopleInAuthGroup=null;
		NamingEnumeration allSearchResultAttributes=null;
		NamingEnumeration simpleListOfPeople=null;
		Hashtable<String,String> env = new Hashtable<String, String>();
		if(!isEmpty(providerURL) && !isEmpty(mcommunityGroup)) {
		env.put(Context.INITIAL_CONTEXT_FACTORY, LDAP_CTX_FACTORY);
		env.put(Context.PROVIDER_URL, providerURL);
		}else {
			M_log.error(" [ldap.server.url] or [mcomm.group] properties are not set, review the sectionsToolPropsLessSecure.properties file");
			return isAuthorized;
		}
		try {
			dirContext = new InitialDirContext(env);
			String[] attrIDs = {"member"};
			SearchControls searchControls = new SearchControls();
			searchControls.setReturningAttributes(attrIDs);
			searchControls.setReturningObjFlag(true);
			searchControls.setSearchScope(SearchControls.SUBTREE_SCOPE);
			String searchBase = OU_GROUPS;
			String filter = "(&(cn=" + mcommunityGroup + ") (objectclass=rfc822MailGroup))";
			listOfPeopleInAuthGroup = dirContext.search(searchBase, filter, searchControls);
			String positiveMatch = "uid=" + user + ",";
			outerloop:
			while (listOfPeopleInAuthGroup.hasMore()) {
				SearchResult searchResults = (SearchResult)listOfPeopleInAuthGroup.next();
				allSearchResultAttributes = (searchResults.getAttributes()).getAll();
				while (allSearchResultAttributes.hasMoreElements()){
					Attribute attr = (Attribute) allSearchResultAttributes.nextElement();
					simpleListOfPeople = attr.getAll();
					while (simpleListOfPeople.hasMoreElements()){
						String val = (String) simpleListOfPeople.nextElement();
						if(val.indexOf(positiveMatch) != -1){
							isAuthorized = true;
							break outerloop;
						}
					}
				}
			}
			return isAuthorized;
		} catch (NamingException e) {
			M_log.error("Problem getting attribute:" + e);
			return isAuthorized;
		}
		finally {
			try {
				if(simpleListOfPeople!=null) {
				simpleListOfPeople.close();
				}
			} catch (NamingException e) {
				M_log.error("Problem occurred while closing the NamingEnumeration list \"simpleListOfPeople\" list ",e);
			}
			try {
				if(allSearchResultAttributes!=null) {
				allSearchResultAttributes.close();
				}
			} catch (NamingException e) {
				M_log.error("Problem occurred while closing the NamingEnumeration \"allSearchResultAttributes\" list ",e);
			}
			try {
				if(listOfPeopleInAuthGroup!=null) {
				listOfPeopleInAuthGroup.close();
				}
			} catch (NamingException e) {
				M_log.error("Problem occurred while closing the NamingEnumeration \"listOfPeopleInAuthGroup\" list ",e);
			}
			try {
				if(dirContext!=null) {
				dirContext.close();
				}
			} catch (NamingException e) {
				M_log.error("Problem occurred while closing the  \"dirContext\"  object",e);
			}
		}
		
	}

}

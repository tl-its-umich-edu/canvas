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
	private static final String OU_GROUPS = "ou=Groups";
	private static final String PROVIDER_URL = "ldap://ldap.itd.umich.edu:389/dc=umich,dc=edu";
	private static final String LDAP_CTX_FACTORY = "com.sun.jndi.ldap.LdapCtxFactory";
	private static final String ASSETS_PATH = "/assets";
	private static Log M_log = LogFactory.getLog(SectionUtilityToolFilter.class);
	protected static final String SYSTEM_PROPERTY_FILE_PATH = "sectionsToolPropsPath";
	protected static final String PROPERTY_CANVAS_ADMIN = "canvas.admin.token";
	protected static final String PROPERTY_CANVAS_URL = "canvas.url";
	protected static final String PROPERTY_TEST_URL = "test.url";
	private static final String AUTH_GROUP = "its-canvas-sections";
	private static final String TEST_USER = "testUser";
	protected static Properties canvasProperties = null;
	private boolean isTestUrlEnabled=false;

	@Override
	public void init(FilterConfig filterConfig) throws ServletException {
		M_log.debug("Filter Init(): Called");
		getCanvasCredentials();
		
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
		M_log.debug("detroy: Called");
	}
	protected void getCanvasCredentials() {
		M_log.debug("getCanvasCredentials(): called");
		String propertiesFilePath = System.getProperty(SYSTEM_PROPERTY_FILE_PATH);
		if (!isEmpty(propertiesFilePath)) {
		canvasProperties=PropertiesUtilities.getPropertiesObjectFromURL(propertiesFilePath);
		}else {
			M_log.error("File path for (sectionsToolProps.properties) is not provided");
		}
		
		
	}
	 private boolean isEmpty(String value) {
		return (value == null) || (value.trim().equals(""));
	}
	
	/*
	 * User is authenicated using cosign  authorized using Ldap. For local development we are enabling
	 * "testUser" parameter. "testUser" also go through the Ldap authorization process. 
	 * we have test.url configured in the properties file in order to disable usage of "testUser" parameter in PROD.
	 * "/assets" folder is where all the js/css resources. I am not making those folder go through authorization process for
	 * 2 reasons 1) If the request of /index.html page fails we return the error page and that needs .css file for doing styling.
	 * 2) if /index.html is 200 ok, the next request that follows are /assets. so it kind of redundant to go through ldap check.
	 */
	private boolean checkForAuthorization(HttpServletRequest request) {
		M_log.debug("checkLdapForAuthorization(): called");
     	String remoteUser = request.getRemoteUser();
		String servletPath = request.getServletPath();
		String testUser = request.getParameter(TEST_USER);
		boolean isAuthorized = false;
		
		if(canvasProperties!=null) {
			isTestUrlEnabled = Boolean.parseBoolean(canvasProperties.getProperty(SectionUtilityToolFilter.PROPERTY_TEST_URL));
		}else {
			M_log.warn("Failed to load system property test.url from sectionsToolProps.properties for SectionsTool");
		}
		
		if(servletPath.startsWith(ASSETS_PATH)) {
			return true;
		}
		String testUserInSession = (String)request.getSession().getAttribute(TEST_USER);
		
	    if ( isTestUrlEnabled && testUser != null ) { 
			isAuthorized=ldapAuthorizationVerification(testUser); 
			request.getSession().setAttribute(TEST_USER, testUser);
		}
		else if ( isTestUrlEnabled && testUserInSession != null )
		{
			isAuthorized=ldapAuthorizationVerification(testUserInSession); 
		} 
		if  ( !isAuthorized && remoteUser != null ) {
			isAuthorized=ldapAuthorizationVerification(remoteUser); 
		}
		return isAuthorized;
		
		
	}

	private boolean ldapAuthorizationVerification(String user) {
		M_log.debug("ldapAuthorizationVerification(): called");
		boolean isMem = false;
		String authGroup = AUTH_GROUP;
		Hashtable<String,String> env = new Hashtable<String, String>();
		env.put(Context.INITIAL_CONTEXT_FACTORY, LDAP_CTX_FACTORY);
		env.put(Context.PROVIDER_URL, PROVIDER_URL);
		try {
			DirContext dirContext = new InitialDirContext(env);
			String[] attrIDs = {"member"};
			SearchControls searchControls = new SearchControls();
			searchControls.setReturningAttributes(attrIDs);
			searchControls.setReturningObjFlag(true);
			searchControls.setSearchScope(SearchControls.SUBTREE_SCOPE);
			String filter = "(&(cn=" + authGroup + ") (objectclass=rfc822MailGroup))";
			String searchBase = OU_GROUPS;
			NamingEnumeration listOfPeopleInAuthGroup = dirContext.search(searchBase, filter, searchControls);
			String positiveMatch = "uid=" + user + ",";
			while (listOfPeopleInAuthGroup.hasMore()) {
				SearchResult searchResults = (SearchResult)listOfPeopleInAuthGroup.next();
				NamingEnumeration allSearchResultAttributes = (searchResults.getAttributes()).getAll();
				while (allSearchResultAttributes.hasMoreElements()){
					Attribute attr = (Attribute) allSearchResultAttributes.nextElement();
					NamingEnumeration simpleListOfPeople = attr.getAll();
					while (simpleListOfPeople.hasMoreElements()){
						String val = (String) simpleListOfPeople.nextElement();
						if(val.indexOf(positiveMatch) != -1){
							isMem = true;
							break;
						}
					}
					simpleListOfPeople.close();
				}
				allSearchResultAttributes.close();
			}
			listOfPeopleInAuthGroup.close();
			dirContext.close();
			return isMem;
		} catch (NamingException e) {
			M_log.error("Problem getting attribute:" + e);
			return isMem;
		}
	}

}

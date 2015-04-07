package edu.umich.ctools.sectionsUtilityTool;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Properties;
import java.util.ResourceBundle;
import java.util.Set;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.http.NameValuePair;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpDelete;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.client.methods.HttpPut;
import org.apache.http.client.methods.HttpUriRequest;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.message.BasicNameValuePair;




public class SectionsUtilityToolServlet extends HttpServlet {

	private static Log M_log = LogFactory.getLog(SectionsUtilityToolServlet.class);
	private static final long serialVersionUID = 7284813350014385613L;
	
	private static final String CANVAS_API_GETCOURSE_BY_UNIQNAME_NO_SECTIONS = "canvas.api.getcourse.by.uniqname.no.sections.regex";
	private static final String CANVAS_API_GETALLSECTIONS_PER_COURSE = "canvas.api.getallsections.per.course.regex";
	private static final String CANVAS_API_GETSECTION_PER_COURSE = "canvas.api.getsection.per.course.regex";
	private static final String CANVAS_API_GETSECTION_INFO = "canvas.api.getsection.info.regex";
	private static final String CANVAS_API_DECROSSLIST = "canvas.api.decrosslist.regex";
	private static final String CANVAS_API_CROSSLIST = "canvas.api.crosslist.regex";
	private static final String CANVAS_API_GETCOURSE_INFO = "canvas.api.getcourse.info.regex";
	private static final String CANVAS_API_RENAME_COURSE = "canvas.api.rename.course.regex";
	private static final String CANVAS_API_GETCOURSE_BY_UNIQNAME = "canvas.api.getcourse.by.uniqname.regex";
	private static final String CANVAS_API_ENROLLMENT = "canvas.api.enrollment.regex";
	private static final String CANVAS_API_TERMS = "canvas.api.terms.regex";
	private static final String RENAME_COURSE_API_SNIPPET = "[course_code]";
	private static final String DELETE = "DELETE";
	private static final String POST = "POST";
	private static final String GET = "GET";
	private static final String PUT = "PUT";
	private String canvasToken;
	private String canvasURL;
	ResourceBundle props = ResourceBundle.getBundle("sectiontool");

	
	public void init() throws ServletException {
		M_log.debug(" Servlet init(): Called");
	}
	
	protected void doGet(HttpServletRequest request,HttpServletResponse response){
		M_log.debug("doGet: Called");
		try {
			canvasRestApiCall(request, response);
		}catch(Exception e) {
			M_log.error("GET request has some exceptions",e);
		}
	}
	
	protected void doPost(HttpServletRequest request,HttpServletResponse response){
		M_log.debug("doPOST: Called");
		try {
			canvasRestApiCall(request, response);
		}catch(Exception e) {
			M_log.error("POST request has some exceptions",e);
		}
		
	}
	protected void doPut(HttpServletRequest request,HttpServletResponse response){
		M_log.debug("doPut: Called");
		try {
			canvasRestApiCall(request, response);
		}catch(Exception e) {
			M_log.error("PUT request has some exceptions",e);
		}
	}
	protected void doDelete(HttpServletRequest request,HttpServletResponse response) {
		M_log.debug("doDelete: Called");
		try {
			canvasRestApiCall(request, response);
		}catch(Exception e) {
			M_log.error("DELETE request has some exceptions",e);
		}
	}
	
   /*
    * This method is handling all the different Api request like PUT, POST etc to canvas.
    * We are using canvas admin token stored in the properties file to handle the request. 
    */
	private void canvasRestApiCall(HttpServletRequest request,
			HttpServletResponse response) throws IOException {
		request.setCharacterEncoding("UTF-8");
		M_log.debug("canvasRestApiCall(): called");
		PrintWriter out = response.getWriter();
		response.setContentType("application/json");
		Properties appExtSecureProperties = SectionUtilityToolFilter.appExtSecurePropertiesFile;
		if(appExtSecureProperties!=null) {
			canvasToken = appExtSecureProperties.getProperty(SectionUtilityToolFilter.PROPERTY_CANVAS_ADMIN);
			canvasURL = appExtSecureProperties.getProperty(SectionUtilityToolFilter.PROPERTY_CANVAS_URL);
		}
		else {
			response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
			out = response.getWriter();
			out.print(props.getString("property.file.load.error"));
			out.flush();
			M_log.error("Failed to load system properties(sectionsToolProps.properties) for SectionsTool");
			return;
		}
		if(isAllowedApiRequest(request)) {
			apiConnectionLogic(request,response);

		}else {
			response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
			out = response.getWriter();
			out.print(props.getString("api.not.allowed.error"));
			out.flush();
		}

	}
	/*
	 * This function has logic that execute client(i.e., browser) request and get results from the canvas  
	 * using Apache Http client library
	 */
	

	private void apiConnectionLogic(HttpServletRequest request, HttpServletResponse response)
			throws IOException {
		String requestMethod = request.getMethod();
		String queryString = request.getQueryString();
		
		String pathInfo = request.getPathInfo();
		PrintWriter out = response.getWriter();
		String url;
		if(queryString!=null) {
			if(queryString.contains(RENAME_COURSE_API_SNIPPET)) {
				requestMethod=PUT;
			}
			url= canvasURL+pathInfo+"?"+queryString;
		}else {
			url=canvasURL+pathInfo;
		}
		String sessionId = request.getSession().getId();
		String loggingApiWithSessionInfo = String.format("Canvas API request with Session Id \"%s\" for URL \"%s\"", sessionId,url);
		M_log.info(loggingApiWithSessionInfo);
		HttpUriRequest clientRequest = null;
		if(requestMethod.equals(GET)) {
			clientRequest = new HttpGet(url);
		}else if (requestMethod.equals(POST)) {
			clientRequest = new HttpPost(url);
		}else if(requestMethod.equals(PUT)) {
			clientRequest=new HttpPut(url);
		}else if(requestMethod.equals(DELETE)) {
			clientRequest=new HttpDelete(url);
		}
		HttpClient client = new DefaultHttpClient();
		final ArrayList<NameValuePair> nameValues = new ArrayList<NameValuePair>();
		nameValues.add(new BasicNameValuePair("Authorization", "Bearer"+ " " +canvasToken));
		nameValues.add(new BasicNameValuePair("content-type", "application/json"));
		for (final NameValuePair h : nameValues)
		{
			clientRequest.addHeader(h.getName(), h.getValue());
		}
		BufferedReader rd = null;
		long startTime = System.currentTimeMillis();
		try {
			rd = new BufferedReader(new InputStreamReader(client.execute(clientRequest).getEntity().getContent()));
		} catch (IOException e) {
			M_log.error("Canvas API call did not complete successfully", e);
		}
		long stopTime = System.currentTimeMillis();
		long elapsedTime = stopTime - startTime;
		M_log.info(String.format("CANVAS Api response took %sms",elapsedTime));
		String line = "";
		StringBuilder sb = new StringBuilder();
		while ((line = rd.readLine()) != null) {
			sb.append(line);
		}
		out.print(sb.toString());
		out.flush();
	}
    /*
     * This method control canvas api request allowed. If a particular request from UI is not in the allowed list then it will not process the request 
     * and sends an error to the UI. Using regex to match the incoming request
     */
	
	private boolean isAllowedApiRequest(HttpServletRequest request) {
		M_log.debug("isAllowedApiRequest(): called");
		String url;
		String queryString = request.getQueryString();
		String pathInfo = request.getPathInfo();
		boolean isAllowedRequest=false;
		if(queryString!=null) {
			url=pathInfo+"?"+queryString;
			isAllowedRequest=isApiFoundIntheList(url);
		}else {
			url=pathInfo;
			isAllowedRequest=isApiFoundIntheList(url);
			
		}
		return isAllowedRequest;
	}
    /*
     * This helper method iterate through the list of api's that sections tool have and if a match is found then logs associated debug message.
     */
	private boolean isApiFoundIntheList(String url) {
		M_log.debug("isApiFoundIntheList(): called");
		String prefixDebugMsg="The canvas api request ";
		HashMap<String,String> apiListRegexWithDebugMsg= new HashMap<String,String>(){{
			put(CANVAS_API_TERMS, "for terms");put(CANVAS_API_CROSSLIST, "for crosslist");put(CANVAS_API_RENAME_COURSE, "for rename a course");put(CANVAS_API_GETCOURSE_BY_UNIQNAME, "for getting courses by uniqname");
			put(CANVAS_API_GETCOURSE_BY_UNIQNAME_NO_SECTIONS, "for getting courses by uniqname not including sections");put(CANVAS_API_ENROLLMENT, "for enrollment");put(CANVAS_API_GETCOURSE_INFO, "for getting course info");put(CANVAS_API_DECROSSLIST,"for decrosslist");
			put(CANVAS_API_GETSECTION_INFO, "for getting section info");put(CANVAS_API_GETSECTION_PER_COURSE, "for getting section info for a given course");put(CANVAS_API_GETALLSECTIONS_PER_COURSE, "for getting all sections info for a given course");
		}};
		boolean isMatch=false;
		Set<String> apiListRegex = apiListRegexWithDebugMsg.keySet();
		for (String api : apiListRegex) {
			if(url.matches(props.getString(api))) {
				M_log.debug(prefixDebugMsg+apiListRegexWithDebugMsg.get(api));
				isMatch= true;
				break;
			}
			
		}
		return isMatch;
	}

	
	
    


}
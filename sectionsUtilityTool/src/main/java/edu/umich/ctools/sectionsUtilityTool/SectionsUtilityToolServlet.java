package edu.umich.ctools.sectionsUtilityTool;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.Properties;
import java.util.ResourceBundle;

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
	
	private static final String CANVAS_API_DECROSSLIST = "canvas.api.decrosslist";
	private static final String CANVAS_API_CROSSLIST = "canvas.api.crosslist";
	private static final String CANVAS_API_GETCOURSE_INFO = "canvas.api.getcourse.info";
	private static final String CANVAS_API_RENAME_COURSE = "canvas.api.rename.course";
	private static final String CANVAS_API_GETCOURSE_BY_UNIQNAME = "canvas.api.getcourse.by.uniqname";
	private static final String CANVAS_API_ENROLLMENT = "canvas.api.enrollment";
	private static final String CANVAS_API_TERMS = "canvas.api.terms";
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
	
	protected void doGet(HttpServletRequest request,HttpServletResponse response) throws IOException {
		M_log.debug("doGet: Called");
		canvasRestApiCall(request, response);
	}
	
	protected void doPost(HttpServletRequest request,HttpServletResponse response) throws IOException {
		M_log.debug("doPOST: Called");
		canvasRestApiCall(request, response);
		
	}
	protected void doPut(HttpServletRequest request,HttpServletResponse response) throws IOException {
		M_log.debug("doPut: Called");
		canvasRestApiCall(request, response);
	}
	protected void doDelete(HttpServletRequest request,HttpServletResponse response) throws IOException {
		M_log.debug("doDelete: Called");
		canvasRestApiCall(request, response);
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
		String queryString = request.getQueryString();
		String pathInfo = request.getPathInfo();
		String url=null;
		if(isAllowedApiRequest(request)) {
			if(queryString!=null) {
				url= canvasURL+pathInfo+"?"+queryString;
			}else {
				url=canvasURL+pathInfo;
			}
			String sessionId = request.getSession().getId();
			StringBuilder loggingApiWithSessionInfo =new StringBuilder();
			loggingApiWithSessionInfo.append("Canvas API request with Session Id:  \"");
			loggingApiWithSessionInfo.append(sessionId);
			loggingApiWithSessionInfo.append("\" for URL:  \"");
			loggingApiWithSessionInfo.append(url);
			loggingApiWithSessionInfo.append("\"");
			M_log.info(loggingApiWithSessionInfo);
			HttpUriRequest clientRequest = null;
			if(request.getMethod().equals(GET)) {
				clientRequest = new HttpGet(url);
			}else if (request.getMethod().equals(POST)) {
				clientRequest = new HttpPost(url);
			}else if(request.getMethod().equals(PUT)) {
				clientRequest=new HttpPut(url);
			}else if(request.getMethod().equals(DELETE)) {
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
			try {
				rd = new BufferedReader(new InputStreamReader(client.execute(clientRequest).getEntity().getContent()));
			} catch (IOException e) {
				M_log.error("Canvas API call did not happen",e);
			}
			String line = "";
			StringBuilder sb = new StringBuilder();
			while ((line = rd.readLine()) != null) {
				sb.append(line);
			}
			
			out.print(sb.toString());
			out.flush();

		}else {
			response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
			out = response.getWriter();
			out.print(props.getString("api.not.allowed.error"));
			out.flush();
		}

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
			if(url.matches(props.getString(CANVAS_API_TERMS))) {
				isAllowedRequest=true;
				M_log.debug("The canvas api request for terms");
			}else if (url.matches(props.getString(CANVAS_API_ENROLLMENT))) {
				isAllowedRequest=true;
				M_log.debug("The canvas api request for enrollment");
			}else if (url.matches(props.getString(CANVAS_API_GETCOURSE_BY_UNIQNAME))) {
				isAllowedRequest=true;
				M_log.debug("The canvas api request for getting courses by uniqname");
			}else if (url.matches(props.getString(CANVAS_API_RENAME_COURSE))) {
				isAllowedRequest=true;
				M_log.debug("The canvas api request for rename a course");
			}else if (url.matches(props.getString(CANVAS_API_GETCOURSE_INFO))) {
				isAllowedRequest=true;
				M_log.debug("The canvas api request for getting course info");
			}
		}else {
			url=pathInfo;
			if(url.matches(props.getString(CANVAS_API_CROSSLIST))) {
				isAllowedRequest=true;
				M_log.debug("The canvas api request for crosslist");
			}else if(url.matches(props.getString(CANVAS_API_DECROSSLIST))) {
				isAllowedRequest=true;
				M_log.debug("The canvas api request for decrosslist");
			}
		}
		return isAllowedRequest;
	}

	
	
    


}
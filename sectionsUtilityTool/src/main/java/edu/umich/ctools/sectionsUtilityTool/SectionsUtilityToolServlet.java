package edu.umich.ctools.sectionsUtilityTool;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.Properties;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.http.NameValuePair;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.message.BasicNameValuePair;

import edu.umich.its.lti.utils.PropertiesUtilities;



public class SectionsUtilityToolServlet extends HttpServlet {

	private static final long serialVersionUID = 7284813350014385613L;
	private static Log M_log = LogFactory.getLog(SectionsUtilityToolServlet.class);
	private static final String SYSTEM_PROPERTY_FILE_PATH = "sectionsToolPropsPath";
	private static final String PROPERTY_CANVAS_ADMIN = "canvas.admin.token";
	private static final String PROPERTY_CANVAS_URL = "canvas.url";
	protected Properties canvasProperties = null;
	private String canvasToken;
	private String canvasURL;
	
	
	public void init() throws ServletException {
		M_log.debug("init(): Called");
		getCanvasCredentials();
		
	}
	
	protected void doGet(HttpServletRequest request,HttpServletResponse response) throws IOException {
		M_log.debug("doGet: Called");
		canvasRESTAPICall(request, response);
	}
	
	protected void doPOST(HttpServletRequest request,HttpServletResponse response) throws IOException {
		M_log.debug("doPOST: Called");
		canvasRESTAPICall(request, response);
		
	}
	
	

	private void canvasRESTAPICall(HttpServletRequest request,
			HttpServletResponse response) throws IOException {
		request.setCharacterEncoding("UTF-8");
		M_log.debug("canvasRESTAPICall(): called");
		if(canvasProperties!=null) {
			canvasToken = canvasProperties.getProperty(PROPERTY_CANVAS_ADMIN);
			canvasURL = canvasProperties.getProperty(PROPERTY_CANVAS_URL);
		}
		else {
			response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
			PrintWriter out = response.getWriter();
			out.print("Problem loading property file");
			out.flush();
			M_log.error("Failed to load system properties(sectionsToolProps.properties) for SectionsTool");
			return;
		}
		HttpClient client = new DefaultHttpClient();
		String queryString = request.getQueryString();
		String pathInfo = request.getPathInfo();
		String url=null;
		if(pathInfo!=null&&(pathInfo.contains("courses")||pathInfo.contains("terms")||pathInfo.contains("crosslist"))) {
		if(queryString!=null) {
		url= canvasURL+pathInfo+"?"+queryString;
		 }else {
			url=canvasURL+pathInfo;
		}
		HttpGet clientRequest = new HttpGet(url);
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
		response.setContentType("application/json");
		PrintWriter out = response.getWriter();
		out.print(sb.toString());
		out.flush();
		
		}
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
    


}
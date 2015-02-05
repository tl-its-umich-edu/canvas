package edu.umich.ctools.sectionsUtilityTool;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.Map;

import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.http.NameValuePair;
import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.message.BasicNameValuePair;


public class SectionsUtilityToolServlet extends HttpServlet {

	private static final long serialVersionUID = 7284813350014385613L;
	private static Log M_log = LogFactory.getLog(SectionsUtilityToolServlet.class);
	
	protected void doGet(HttpServletRequest request,HttpServletResponse response) throws IOException {
		M_log.debug("doGet: Called");
		HttpClient client = new DefaultHttpClient();
		String targetURI= "https://umich.test.instructure.com";
		String queryString = request.getQueryString();
		String servletPath = request.getServletPath();
		String pathInfo = request.getPathInfo();
		String url=null;
		if(pathInfo!=null&&(pathInfo.contains("courses")||pathInfo.contains("terms")||pathInfo.contains("crosslist"))) {
		if(queryString!=null) {
		url= targetURI+pathInfo+"?"+queryString;
		 //url= servletPath+"?"+queryString;
		 }
		else {
			url=targetURI+pathInfo;
			//url=servletPath;
		}
		System.out.println("URL: "+url);
		HttpGet clientRequest = new HttpGet(url);
		final ArrayList<NameValuePair> nameValues = new ArrayList<NameValuePair>();
	    nameValues.add(new BasicNameValuePair("Authorization", "Bearer"+ " " +getCanvasAdminToken()));
	    nameValues.add(new BasicNameValuePair("content-type", "application/json"));
	    for (final NameValuePair h : nameValues)
	    {
	        clientRequest.addHeader(h.getName(), h.getValue());
	    }
		BufferedReader rd = null;
		try {
			 rd = new BufferedReader(new InputStreamReader(client.execute(clientRequest).getEntity().getContent()));
		} catch (ClientProtocolException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		}
		String line = "";
		StringBuilder sb = new StringBuilder();
		while ((line = rd.readLine()) != null) {
			sb.append(line);
			System.out.println(sb.toString());
		}
		request.setCharacterEncoding("UTF-8");
		response.setContentType("application/json");
		PrintWriter out = response.getWriter();
		out.print(sb.toString());
		out.flush();
		
		}
		 //TODO Delete
		String contextPath = request.getContextPath();
		String requestURI = request.getRequestURI();
		Enumeration headerNames = request.getHeaderNames();
		Map<String,String> parameterMap = request.getParameterMap();
		Enumeration<String> parameterNames = request.getParameterNames();
		String pathTranslated = request.getPathTranslated();
		String remoteAddr = request.getRemoteAddr();
		String localAddr = request.getLocalAddr();
		StringBuffer requestURL = request.getRequestURL();
		String serverName = request.getServerName();
		System.out.println("ServerName: "+serverName);
		System.out.println("ServletPath: "+servletPath);
		System.out.println("RequestURL: "+requestURL.toString());
		System.out.println("Remote Address: "+remoteAddr);
		System.out.println("PathTranslated: "+pathTranslated);
		System.out.println("LocalAddr: "+localAddr);
		System.out.println("PathInfo: "+pathInfo);
		System.out.println("ParameterNames: "+parameterNames);
		System.out.println("ParameterMap: "+parameterMap);
		System.out.println("HeaderNames: "+headerNames);
		System.out.println("RequestURI: "+requestURI);
		System.out.println("QueryString: "+queryString);
		System.out.println("ContextPath: "+contextPath);
	}
	
	private String getCanvasAdminToken() {
		return "REPLACE WITH ACTUAL TOKEN";
	}
    


}
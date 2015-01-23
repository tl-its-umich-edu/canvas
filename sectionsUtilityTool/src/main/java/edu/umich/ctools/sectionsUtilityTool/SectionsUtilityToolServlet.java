package edu.umich.ctools.sectionsUtilityTool;

import java.io.IOException;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.velocity.Template;
import org.apache.velocity.context.Context;
import org.apache.velocity.tools.view.VelocityViewServlet;


public class SectionsUtilityToolServlet extends VelocityViewServlet {

	private static final long serialVersionUID = 7284813350014385613L;
	private static Log M_log = LogFactory.getLog(SectionsUtilityToolServlet.class);
	
	
    private static final String NAME = "Hello World !!!";
    public void init() throws ServletException {
		M_log.debug("init: called");
    }
    
    public void doGet(HttpServletRequest request, HttpServletResponse response)
			throws ServletException, IOException {
    	M_log.debug("doGET: called");
		doRequest(request, response);
	}

	public void doPost(HttpServletRequest request, HttpServletResponse response)
			throws ServletException, IOException {
		M_log.debug("doPOST: called");
		doRequest(request, response);
	}

	public void doPut(HttpServletRequest request, HttpServletResponse response)
			throws ServletException, IOException {
		M_log.debug("doPUT: called");
		doRequest(request, response);
	}
	public void fillContext(Context context, HttpServletRequest request) {
		 M_log.debug("fillContext: called");   
	        context.put("name", NAME);
		
	}
    
    


}

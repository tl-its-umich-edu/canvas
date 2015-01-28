package edu.umich.ctools.sectionsUtilityTool;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

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
    	M_log.debug("##################################################################################################");
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
	        String uniqueName = request.getParameter("uniquename");
	        String termList = request.getParameter("term");
	        String primaryInstructorForm = request.getParameter("form1");
	        context.put("name", NAME);
	        if (primaryInstructorForm!=null) {
	        String[] split = primaryInstructorForm.split(",");
	        HashMap<String, List<String>> coursesOfInstructorForATerm = getCoursesOfInstructorForATerm();
	       // context.put("uniquename", split[1]);
	        //context.put("termList", split[0]);
	        context.put("coursesOfInstructor", coursesOfInstructorForATerm);
	        }
	}

	private HashMap<String,List<String>> getCoursesOfInstructorForATerm() {
		 M_log.debug("getCoursesOfInstructorForATerm(): called");   
		
		HashMap<String, List<String>> course=new HashMap<String, List<String>>();
		List <String> physics101Sections=new ArrayList<String>();
		physics101Sections.add("Physics 101 Sec A");
		physics101Sections.add("Physics 101 Sec B");
		physics101Sections.add("Physics 101 Sec C");
		physics101Sections.add("Physics 101 Sec D");
		physics101Sections.add("Physics 101 Sec E");
		
		List <String> physics102Sections=new ArrayList<String>();
		physics102Sections.add("Physics 102 Sec A");
		physics102Sections.add("Physics 102 Sec B");
		physics102Sections.add("Physics 102 Sec C");
		physics102Sections.add("Physics 102 Sec D");
		physics102Sections.add("Physics 102 Sec E");
		
		List <String> physics103Sections=new ArrayList<String>();
		physics103Sections.add("Physics 103 Sec A");
		physics103Sections.add("Physics 103 Sec B");
		physics103Sections.add("Physics 103 Sec C");
		physics103Sections.add("Physics 103 Sec D");
		physics103Sections.add("Physics 103 Sec E");
		
		List <String> physics104Sections=new ArrayList<String>();
		physics104Sections.add("Physics 104 Sec A");
		physics104Sections.add("Physics 104 Sec B");
		physics104Sections.add("Physics 104 Sec C");
		physics104Sections.add("Physics 104 Sec D");
		physics104Sections.add("Physics 104 Sec E");
		
		List <String> physics105Sections=new ArrayList<String>();
		physics105Sections.add("Physics 105 Sec A");
		physics105Sections.add("Physics 105 Sec B");
		physics105Sections.add("Physics 105 Sec C");
		physics105Sections.add("Physics 105 Sec D");
		physics105Sections.add("Physics 105 Sec E");
		
		List <String> physics106Sections=new ArrayList<String>();
		physics106Sections.add("Physics 106 Sec A");
		physics106Sections.add("Physics 106 Sec B");
		physics106Sections.add("Physics 106 Sec C");
		physics106Sections.add("Physics 106 Sec D");
		physics106Sections.add("Physics 106 Sec E");
		
		course.put("Physics 101", physics101Sections);
		course.put("Physics 102", physics102Sections);
		course.put("Physics 103", physics103Sections);
		course.put("Physics 104", physics104Sections);
		course.put("Physics 105", physics105Sections);
		course.put("Physics 106", physics106Sections);
		return course;
	}

	protected void setContentType(HttpServletRequest request,
			HttpServletResponse response) {
		response.setContentType("text/html; charset=UTF-8");
	}
	/**
	 * TODO: come back to be more descriptive 
	 * This fetches the admin token that can be used for Quering canvasAPI.  
	 * @return
	 */
	
	private String getAdminToken() {
		return "ERJDKKD";
	}
    
    


}

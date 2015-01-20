package edu.umich.ctools.sectionsUtilityTool;

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
    
    protected Template handleRequest(HttpServletRequest request,
            HttpServletResponse response, Context ctx)
    {
         M_log.debug("Start of the application......");   
    	Template template = null;
        try {
        	template = getTemplate("templates/sections.vm");
        	}
        catch (Exception e) {
        	M_log.debug("Some weired error occured");
        	}
        
        ctx.put("name", NAME);
        return template;
    }


}

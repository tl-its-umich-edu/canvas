There are two ways to update class URL field in MPathway:

1. The "canvas_url_update" script will be run nightly, harvesting all courses with all eligible terms ( terms return by ESB '/Curriculum/SOC/v1/Terms' call), and all the sections within those courses. The script will then write the Canvas course URL for each section/class into MPathway system.

2. CTools site URL update is still executed based on "site publish/unpublish" or "realm provider id change" events.

So it is really depends on the timing of those two above steps. MPathway might first associate the CTools site url with the section id when the site is published inside CTools. However, after the nightly cron job run, Canvas course url will override the previous CTools site URL in MPathway. 


command format and properties file format:
========================================
To execute the script, one need to follow the following command format:

ruby <sis_set_url.rb path> <security file path> <properties file path>

Here are the settings inside the security file, separated by comma:
token=<Canvas API token>,server=<Canvas server>,key=<ESB key>,secret=<ESB secret>,url=<ESB server url>,token_url=<ESB token server url>,caRootFilePath=<CA root file path>,inCommonFilePath=<InCommon file path>

Here are the settings inside properties file, separated by comma:
directory=<work directory of the script results>,page_size=<Canvas API request page size>,esb_time_interval=<ESB API call time interval in seconds>,esb_allowed_call_number=<maximum ESB API call number during the interval>,canvas_time_interval=<Canva API call time interval in secs>,canvas_allowed_call_number=<maximum Canvas API call during the interval>
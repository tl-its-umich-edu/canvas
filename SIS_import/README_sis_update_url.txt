There are two ways to update class URL field in MPathway:

1. The "canvas_url_update" script will be run nightly, harvesting all courses with all eligible terms ( terms return by ESB '/Curriculum/SOC/v1/Terms' call), and all the sections within those courses. The script will then write the Canvas course URL for each section/class into MPathway system.

2. CTools site URL update is still executed based on "site publish/unpublish" or "realm provider id change" events.

So it is really depends on the timing of those two above steps. MPathway might first associate the CTools site url with the section id when the site is published inside CTools. However, after the nightly cron job run, Canvas course url will override the previous CTools site URL in MPathway. 

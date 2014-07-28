#!/usr/bin/env ruby

require "json"

token="<token>"

# Web Service call
json_data=`curl -H "Content-Type: application/zip" --data-binary @mpathway.zip -H "Authorization: Bearer #{token}" https://umich.beta.instructure.com/api/v1/accounts/1/sis_imports.json?import_type=instructure_csv`
#json_data=`curl -H "Content-Type: application/zip" --data-binary @mpathway.zip -H "Authorization: Bearer #{token}" https://umich.beta.instructure.com/api/v1/accounts/1/sis_imports.json?import_type=instructure_csv&batch_mode=1`

#print "#{json_data}\n"
parsed = JSON.parse(json_data)

job_id=parsed["id"]

if (parsed["errors"])
	print "ERROR: #{parsed["errors"]}\n"
else
	print "the job id is: #{job_id}\n"

	print "here is the job #{job_id} status: \n"

	begin
		#sleep every 10 sec, before checking the status again
		sleep(10);

		json_result=`curl 'https://umich.beta.instructure.com/api/v1/accounts/1/sis_imports/#{job_id}' -H "Authorization: Bearer #{token}"`

		#print out the whole json result
		print "#{json_result}\n"

		#parse the status percentage
		parsed_result=JSON.parse(json_result)
		job_progress=parsed_result["progress"]

		print "processed #{job_progress}\n"
	end until job_progress == 100

	# print out the process warning, if any
	if (parsed_result["processing_errors"])
		print "upload process errors: #{parsed_result["processing_errors"]}\n"
	elsif (parsed_result["processing_warnings"])
        	print "upload process warning: #{parsed_result["processing_warnings"]}\n"	
	else
		print "upload process finished successfully\n"
	end
end

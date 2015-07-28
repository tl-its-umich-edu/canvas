def json_parse_safe(url, json, outputFile)
	# The top-level structure of a JSON document is an array or object,
	# and the shortest representations of those are [] and {}, respectively.
	# So valid non-empty json should have two octet
	if json && json.length >= 2
		begin
			return JSON.parse(json)
		rescue JSON::ParserError, TypeError => e
			puts "Not a valid JSON String #{json} for url= #{url} #{e}"
			if (!outputFile.nil?)
				# write into output file
				outputFile.write "Not a valid JSON String #{json} for url= #{url}"
			end
			return nil
		end
	else
		return nil
	end
end

# control the API call pace
def sleep_according_to_timer_and_api_call_limit(start_time, end_time, call_count, time_interval_in_seconds, allowed_call_number_during_interval)
	# if meet max allowed call count during the time interval
	# sleep until time expires
	while (Time.now.to_i <= end_time.to_i && call_count >= allowed_call_number_during_interval)
		sleep_sec = (end_time - Time.now).to_i + 2
		p "sleep #{sleep_sec} seconds till next time interval"
		sleep(sleep_sec)
	end

	if (Time.now.to_i > end_time.to_i)
		# set new time frame
		start_time = Time.now
		end_time = start_time + time_interval_in_seconds # one minute apart
		#rest the esb call count
		p "reset call count"
		call_count = 0
	end

	# return changed values
	return {"start_time" => start_time,
	        "end_time" => end_time,
	        "call_count" => call_count
	}
end
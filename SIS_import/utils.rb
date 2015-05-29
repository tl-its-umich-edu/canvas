def json_parse_safe(url, json, outputFile)
	# The top-level structure of a JSON document is an array or object,
	# and the shortest representations of those are [] and {}, respectively.
	# So valid non-empty json should have two octet
	if json && json.length >= 2
		begin
			return JSON.parse(json)
		rescue JSON::ParserError, TypeError => e
			puts "Not a valid JSON String #{json} for url= #{url}"
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
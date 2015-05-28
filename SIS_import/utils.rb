def json_parse_nil(json)
		JSON.parse(json) if json && json.length >= 2
end
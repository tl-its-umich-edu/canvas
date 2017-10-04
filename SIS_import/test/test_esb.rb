#!/usr/bin/env ruby
require 'uri'
require 'openssl'
require 'net/http'
require "json"
require "base64"

def httpClient(url)
  url = URI(url)
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
  return http
end

@esbToken=''
# replace it with new esb key and secret
@esbKey=''
@esbSecret=''

token_url= "https://apigw-tst.it.umich.edu/um/aa/oauth2/token"
token_client=httpClient(token_url)
encoded_string = Base64.strict_encode64(@esbKey + ":" + @esbSecret)
request = Net::HTTP::Post.new(token_url)
request["content-type"] = 'application/x-www-form-urlencoded'
request["accept"] = 'application/json'
# request["Authorization"] = 'Basic '+encoded_string
# request.body = "grant_type=client_credentials&scope=umscheduleofclasses"
request.body = "grant_type=client_credentials&client_id="+@esbKey+"&client_secret="+@esbSecret+"&scope=umscheduleofclasses"

response = token_client.request(request)
json=JSON.parse(response.body)
@esbToken=json["access_token"]


terms_url="https://apigw-tst.it.umich.edu/um/Curriculum/SOC/Terms"

terms_client = httpClient(terms_url)
request = Net::HTTP::Get.new(terms_url)
request["x-ibm-client-id"] = @esbKey
request["authorization"] = 'Bearer '+@esbToken
request["accept"] = 'application/json'

response_terms = terms_client.request(request)
puts response_terms.read_body
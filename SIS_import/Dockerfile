# This file mostly used for local testing and development.
FROM ruby:2.2.2
ENV app /usr/src/app
RUN mkdir $app
WORKDIR $app
ADD . $app
RUN bundle install
# while running the docker file somehow the docker enviroment ask for below gems so place them in the Gemfile
# gem "therubyracer", :platforms => :ruby
# gem "execjs"
# the 2nd and 3rd arguments are the security and property files and these needs to be placed at the same level as the sis_set_url.rd
ENTRYPOINT ["./sis_set_url.rb","sis_set_url.canvastest.security","sis_set_url.canvastest.properties"]
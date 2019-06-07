# This file mostly used for local testing and development.
FROM ruby:2.6
ENV app /usr/src/app
RUN mkdir $app
WORKDIR $app
# Precache Bundle
COPY Gemfile* /tmp
WORKDIR /tmp
RUN bundle install
WORKDIR $app
ADD . $app

# Quick check syntax
RUN find . | grep ".rb$" | xargs ruby -c
# while running the docker file somehow the docker enviroment ask for below gems so place them in the Gemfile
# gem "therubyracer", :platforms => :ruby
# gem "execjs"
# the 2nd and 3rd arguments are the security and property files and these needs to be placed at the same level as the sis_set_url.rd
ENTRYPOINT ["./sis_set_url.rb","sis_set_url.canvastest.security","sis_set_url.canvastest.properties"]
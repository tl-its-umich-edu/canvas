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
# ENTRYPOINT ["./sis_set_url.rb"]
ENTRYPOINT [ "./sis_upload.rb" ]
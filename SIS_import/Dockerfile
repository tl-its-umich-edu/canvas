# This file mostly used for local testing and development.
FROM ruby:2.7
ENV app /usr/src/app
RUN mkdir $app
WORKDIR $app

# Precache Bundle
COPY Gemfile* /tmp/
WORKDIR /tmp
RUN bundle update --bundler
RUN bundle install
WORKDIR $app
ADD . $app

RUN apt-get update && \
    apt-get install rclone -y && \
    apt-get upgrade -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

# Quick check syntax
RUN find . | grep ".rb$" | xargs ruby -c

RUN chown -R root:root /usr/src/app/data
RUN chmod g+rw /usr/src/app/data

ENTRYPOINT [ "./rclone_setup.sh" ]

# This file mostly used for local testing and development.
FROM ruby:2.7-slim
ENV app /usr/src/app
RUN mkdir $app
WORKDIR $app

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential curl

# Rclone in Debian isn't the latest
# Download latest from https://rclone.org/downloads/
ENV RCLONE_VER=v1.57.0

RUN apt install rclone -y

# Precache Bundle
COPY Gemfile* /tmp/
WORKDIR /tmp
RUN bundle update --bundler
RUN bundle install
WORKDIR $app
ADD . $app

RUN apt-get upgrade -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

# Quick check syntax
RUN find . | grep ".rb$" | xargs ruby -c

RUN mkdir /usr/src/app/data
RUN chown -R root:root /usr/src/app/data
RUN chmod g+rw /usr/src/app/data

ENV PROCESS=sis_set_url

ENTRYPOINT [ "./rclone_setup.sh" ]

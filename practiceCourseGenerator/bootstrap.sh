#!/usr/bin/env bash

apt-get update
apt-get install -y vim

wget https://bootstrap.pypa.io/get-pip.py
python get-pip.py
python -m pip install google-api-python-client
python -m pip install requests
python -m pip install enum34

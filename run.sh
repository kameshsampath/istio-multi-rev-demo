#!/usr/bin/env bash

trap '{ echo "" ; exit 1; }' INT

url=$1
if [ -z "$url" ]
then
    # we have setup kind to allow accessing Gloo Edge via localhost
    url="http://localhost:30080/api/hello"
fi

while true
do http -b "$url"
sleep .5
done

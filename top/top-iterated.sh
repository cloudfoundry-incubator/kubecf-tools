#!/bin/bash

## Given the name of a k8s namespace to watch, the path to a file, and
## a sleep delay it polls the resource usage of the pods and
## containers in the specified namespace, saving them to the specified
## file. If the file exists, new data is appended.

space="${1}"	; shift
log="${1}"	; shift
delay="${1}"	; shift

if test -z "${space}" -o -z "${log}" -o -z "${delay}"
then
    echo 1>&2 "Usage: $0 space log delay"
    exit 1
fi

while true
do
    now="$(date +%s)"
    echo SNAP "${space}" @ "$(date)" ".." "${now}"
    ( echo
      kubectl top pod --namespace "${space}" --containers \
	  | grep -v POD \
	  | sed -e "s|^|${now}	|"
    ) >> "${log}"
    sleep "${delay}"
done

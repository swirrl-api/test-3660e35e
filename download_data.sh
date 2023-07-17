#!/bin/bash

function download() {
    url=$1
    dest=$2

    response=$(curl -X GET ${url} -o -)
    format=$(echo ${response} | jq -r .format)
    if [ "${format}" = "base64" ] ; then
        echo ${response} | jq -j .content | base64 -d > $dest
    elif [ "${format}" = "text" ] ; then
        echo ${response} | jq -j .content > $dest
    else
        echo "Format ${format} of file ${dest} not supported"
        echo ${response} | jq -j .content > $dest
    fi
}

notebook_created="no"

function get_notebook() {
    ## Creates a new notebook if needed. Sets flag to delete if
    ## notebook was re-created.
    apiurl=$1
    sessionid=$2
    serviceid=$3
    svcinfo=`curl --silent -X GET "${apiurl}/${serviceid}" -H  "accept: application/json"`
    if [ $(echo ${svcinfo} | jq -j .sessionId) = "${sessionid}" ] ; then
        return ## NOTEBOOK_URL unchanged.
    fi
    
    svcinfo=`curl --silent -X POST "${apiurl}" -H  "accept: application/json" \
                  -H  "Content-Type: application/json" -d "{\"sessionId\":\"${sessionid}\"}"`
    notebook_created="yes"
    
    svcurl=`echo ${svcinfo} | jq -j .serviceURL`
    if [ "${svcurl}" = "null" ] ; then
        echo "Session ${sessionid} no longer exists. Cannot download data."
        exit 1
    fi

    SERVICE_ID=`echo ${svcinfo} | jq -j .id`
    echo "Wait for service ${SERVICE_ID} to be re-created at ${svcurl}."
    while ! curl --silent -IL -X GET ${svcurl} | grep "200 OK" ; do
        sleep 5
    done
    NOTEBOOK_URL=${svcurl}
}

function delete_notebook() {
    apiurl=$1
    if [ "${notebook_created}" = "yes" ] ; then
        curl -X DELETE "${apiurl}/${SERVICE_ID}" -H  "accept: */*"
    fi
}

function download_working_dir_data() {
    if [ ! -e download_filelist.dat ] ; then
        echo "Nothing to download from working dir."
        return
    fi
    apiurl=$1
    for file in `cat download_filelist.dat` ; do
        download ${apiurl}/${file} ${HOME}/${file}
    done
}

conda install -y -c conda-forge curl jq || exit 1


# =======================================================
# Everything below here is generated by the snapshot job:
# =======================================================
NOTEBOOK_URL=http://192.168.49.2/swirrl/jupyter/dd2e1687-3bc2-44ed-961d-e8b73a973068
SERVICE_ID=dd2e1687-3bc2-44ed-961d-e8b73a973068
get_notebook http://swirrl-api/swirrl-api/v1.0/notebook 6e4deef2-8da0-4cd0-9fd2-c33733bcf2cf dd2e1687-3bc2-44ed-961d-e8b73a973068
echo 'Nothing to download from data staging directory.'
download_working_dir_data ${NOTEBOOK_URL}/api/contents
delete_notebook http://swirrl-api/swirrl-api/v1.0/notebook

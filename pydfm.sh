#!/bin/bash

. ./config.ini

get_auth_token () {
    gnome-open $(echo `curl -k -s "https://oauth.yandex.ru/authorize?response_type=token&client_id=${client_id}"` | awk -F"Redirecting to" '{print $2}')
    read NEW_TOKEN
    echo old TOKEN=${TOKEN}
    echo new TOKEN=${NEW_TOKEN}
    sed -i "s/${TOKEN}/${NEW_TOKEN}/g" ./config.ini
}

get_all_file_list () {
    file_list=""
    IFS=$'\n'   
    while read line; do
        file_list+=(${line})
    done< <(curl -k -s -H "Authorization: OAuth "${TOKEN} "https://cloud-api.yandex.net:443/v1/disk/resources/files?limit=${query_limit_records}" | jq '.items[] | .path, .public_url | select (.!=null)' | sed "s/\"//g")
    regex="(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]"
    for (( i=1; i<${#file_list[@]}+1; i++ )); do
        if [[ ${file_list[$i+1]} =~ $regex ]]; then
            echo ${file_list[$i]} ${file_list[$i+1]}
            i=$(($i+1))
        else 
            echo ${file_list[$i]}
        fi    
    done
}

get_private_file_list () {
    file_list=""
    IFS=$'\n'   
    while read line; do
        file_list+=(${line})
    done< <(curl -k -s -H "Authorization: OAuth "${TOKEN} "https://cloud-api.yandex.net:443/v1/disk/resources/files?limit=${query_limit_records}" | jq '.items[] | .path, .public_url | select (.!=null)' | sed "s/\"//g")
    regex="(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]"
    for (( i=1; i<${#file_list[@]}+1; i++ )); do
        if [[ ${file_list[$i+1]} =~ $regex ]]; then
            i=$(($i+1))
        else 
            echo ${file_list[$i]}
        fi    
    done
}

publish_new_files () {
    file_list=""
    new_file_list=""
    IFS=$'\n'   
#get all files list
    while read line; do
	file_list+=(${line}) 
    done< <(curl -k -s -H "Authorization: OAuth "${TOKEN} "https://cloud-api.yandex.net:443/v1/disk/resources/files?limit=${query_limit_records}" | jq '.items[] | .path, .public_url | select (.!=null)' | sed "s/\"//g")

#filter unpublished files into string array   
    regex="(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]"
    while read line; do
        new_file_list+=(${line})
    done< <(
            for (( i=1; i<${#file_list[@]}+1; i++ )); do
                if [[ ${file_list[$i+1]} =~ $regex ]]; then
                    i=$(($i+1))
                else 
                    echo ${file_list[$i]}
                fi    
            done
        )


#publish each file and compose bib-record
#bib example:
#@book{Unknown, author = {{}}, Title = {{23-webcodegeeks-w_sitb52-nwe6KbpyUbZFHtExOxPV9Q.pdf}}, url = {https://yadi.sk/i/eLUWcsg33aWquJ} }    
    for (( i=1; i<${#new_file_list[@]}; i++ )); do
	r=$(curl -k -s -X PUT -H "Authorization: "${TOKEN} "https://cloud-api.yandex.net:443/v1/disk/resources/publish?path=${new_file_list[$i]}")
        curl -k -s -H "Authorization: "${TOKEN} "https://cloud-api.yandex.net:443/v1/disk/resources?path=${new_file_list[$i]}" | jq '.public_url' | sed "s/\"//g"
     done
}

case $1 in

	auth)
	  get_auth_token;
	;;
        ls-all)
          get_all_file_list 
        ;;

        ls-private)
          get_private_file_list 
        ;;

        publish-all)
          publish_new_files
        ;;

        list)
          list
        ;;
esac
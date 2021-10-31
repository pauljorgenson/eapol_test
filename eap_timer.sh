#!/bin/#!/usr/bin/env bash

# This script is meant to be run as a scheduled job every minute to provide
# connection time metrics for a PEAP or EAP-TLS connection with wireless taken out of
# the equation. This gives a minimum possible connection time baseline
# This depends on a compiled and working version of the eapol_test binary from
# the wpa_supplicant package https://w1.fi/wpa_supplicant/
# This version is generalized but can be adapted to various time series database
# and metrics platforms that can gather metrics from a textfile on an endpoint
# a client EAP configuation file with a valid client identity and
# authorized credentials (cert or user/pass) is required

eap_auth_port=$1
eap_shared_secret=$2
eapol_cli="/sbin/eapol_test -c eap-tls_ssid.conf -r 0 -t 10 -p $eap_auth_port -s $eap_shared_secret"
metrics_file_path=/var/lib/metrics_collector
metrics_file_name=eap_tls_metrics.txt

# RADIUS servers
# you can define more servers using server_list[3], server_list[4], etc
server_list[0]=192.168.1.10 # Example server 1
server_list[1]=192.168.2.10 # Example server 2

length=${#server_list[@]}
for (( i=0; 1 < length; i++ )); do
  sleep 0.5
  eap_result="$($eapol_cli -a ${server_list[i]})"
  sleep 0.5
  eap_result_time="$(/usr/bin/time -p $eapol_cli -a ${server_list[i]})"
  rtt_seconds="$(echo $eap_result_time | grep -oP '(?<=real )\S+')"
  if [[ ${eap_result:(-7)} == "SUCCESS" ]]
  then
    eap_response_list[i]=1
    eap_rtt_seconds_list[i]=$rtt_seconds
  else
    eap_response_list[i]=0
    eap_rtt_seconds_list[i]=0
  fi
done

# write the results to file for ingestion by metrics agent
cat << EOF > "$metrics_file_path/$metrics_file_name.$$"
# eap_response_bool - did we get a response?
eap_response_bool ${server_list[0]} ${eap_response_list[0]}
eap_response_bool ${server_list[1]} ${eap_response_list[1]}
# eap_response_rtt_seconds - what was the response time?
eap_response_rtt_seconds ${server_list[0]} ${eap_rtt_seconds_list[0]}
eap_response_rtt_seconds ${server_list[1]} ${eap_rtt_seconds_list[1]}

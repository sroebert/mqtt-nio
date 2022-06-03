#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

IP="roebert.nl"
SUBJECT_CA="/C=NL/ST=Amsterdam/L=Amsterdam/O=roebert/OU=CA/CN=$IP"
SUBJECT_SERVER="/C=NL/ST=Amsterdam/L=Amsterdam/O=roebert/OU=Server/CN=$IP"
SUBJECT_CLIENT="/C=NL/ST=Amsterdam/L=Amsterdam/O=roebert/OU=Client/CN=$IP"

function generate_CA () {
   echo "$SUBJECT_CA"
   openssl req -x509 -nodes -sha256 -newkey rsa:2048 -subj "$SUBJECT_CA"  -days 365 -keyout "$SCRIPT_DIR/ca.key" -out "$SCRIPT_DIR/ca.crt"
   openssl x509 -in "$SCRIPT_DIR/ca.crt" -out "$SCRIPT_DIR/ca.der" -outform DER
}

function generate_server () {
   echo "$SUBJECT_SERVER"
   openssl req -nodes -sha256 -new -subj "$SUBJECT_SERVER" -keyout "$SCRIPT_DIR/server.key" -out "$SCRIPT_DIR/server.csr"
   openssl x509 -req -sha256 -in "$SCRIPT_DIR/server.csr" -CA "$SCRIPT_DIR/ca.crt" -CAkey "$SCRIPT_DIR/ca.key" -CAcreateserial -out "$SCRIPT_DIR/server.crt" -days 365
}

generate_CA
generate_server

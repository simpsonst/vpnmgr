#!/bin/bash
# -*- c-basic-offset: 4; indent-tabs-mode: nil -*-

## Copyright 2018-2020, Lancaster University
## All rights reserved.
## 
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions are
## met:
## 
##  * Redistributions of source code must retain the above copyright
##    notice, this list of conditions and the following disclaimer.
## 
##  * Redistributions in binary form must reproduce the above copyright
##    notice, this list of conditions and the following disclaimer in the
##    documentation and/or other materials provided with the
##    distribution.
## 
##  * Neither the name of the copyright holder nor the names of
##    its contributors may be used to endorse or promote products derived
##    from this software without specific prior written permission.
## 
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
## "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
## LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
## A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
## OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
## SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
## LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
## DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
## THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
## (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
## OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
##
##
## Author: Steven Simpson <https://github.com/simpsonst>

## Call this before parsing command-line arguments.
function prepare_settings () {
    declare -Ag IFACE VLIFACE BRIFACE DHFILE SERVERNAME \
            CACERT SERVERKEY SERVERCERT VLANS INTERNALNAME
    SOURCE_CONFIG=/etc/vpnmgr.sh
    VPNUSER="${SUDO_USER:-"${LOGNAME}"}"

    ## The directory that OpenVPN finds subservice configurations in
    CONFDIR=/etc/openvpn

    ## The directory that OpenVPN will be instructed to find
    ## certificates and CRLs, etc, in
    RTSTATDIR=/etc/openvpn/server/vpnmgr

    ## The UDP ports that OpenVPN clients will connect to for the
    ## default bank - This must be specified, or the bank does not exist.
    #PORTRANGES[default]=12000-12100

    ## The range of VLANs available for the default bank
    VLANS[default]=1-4095

    ## The name --remote setting in OpenVPN client configurations for
    ## this bank, and the hostname that OpenVPN servers will bind
    ## their UDP port to
    SERVERNAME[default]="$HOSTNAME"

    ## The interface on which VLANs in the default bank appear
    IFACE[default]=eth1

    ## The --dh file used to run servers in the default bank
    DHFILE[default]=/etc/openvpn/dh1024.pem

    ## The certificate given to clients to verify OpenVPN servers in
    ## the default bank
    CACERT[default]=/etc/openvpn/ca.crt

    ## The private key used by OpenVPN servers in the default bank
    SERVERKEY[default]=/etc/openvpn/server.key

    ## The certificate identifying OpenVPN servers in the default bank
    SERVERCERT[default]=/etc/openvpn/server.crt

    ## The prefixes for bridges and interfaces created to implement
    ## VLAN gateways in the default bank
    BRIFACE[default]=vlanbr
    VLIFACE[default]=vlan
    TAPIFACE[default]=vlantap
}

## Call this after parsing command-line arguments.
function complete_settings () {
    if [ -r "$SOURCE_CONFIG" ] ; then
        source "$SOURCE_CONFIG"
    else
        printf >&2 '%s: Warning: no config: %s\n' "${0##*/}" "$SOURCE_CONFIG"
    fi

    if [ -z "$STATDIR" ] ; then
        if VPNHOME="$(getent passwd "$VPNUSER" 2> /dev/null | cut -d: -f6)"
        then
            STATDIR="$VPNHOME"/.config/vpnmgr
            SSHAUTHDIR="${STATDIR%/}/ssh"
        else
            printf >&2 '%s: Who are you, [%s]?\n' "${0##*/}" "$VPNUSER"
            exit 1
        fi
    fi

    RUNDIR="${RUNDIR:-"/tmp/$VPNUSER-vpnmgr"}"

    if [ -z "$SERVERTITLE" ] ; then
        SERVERTITLE="$(hostname)"
    fi
}

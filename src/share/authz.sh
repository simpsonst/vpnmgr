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

## forbid - The user can do nothing with the target.

## read - The user can read settings from the target.

## manage - The user can modify the target's settings, but not
## permissions of any user with respect to it.

## admin - The user can modify the target's settings, and permissions
## of any user with respect to it.

declare -A LEVELS=()
INVLEVELS=(forbid read manage admin)
declare -A LEVEL_DOWNGRADES=()
LEVEL_DOWNGRADES[admin]=manage
for lvl in "${INVLEVELS[@]}" ; do
    LEVELS["$lvl"]="${#LEVELS[@]}"
done

function rebuild_auth () {
    "$VPNMGRHOME/share/vpnmgr/rebuild-auth" \
        -f "$SOURCE_CONFIG" -u "$VPNUSER" "$@"
}

function read_authz () {
    local hash="$1" ; shift
    declare -Ag AUTHZ_BANKS=() AUTHZ_VLANS=()
    declare -g AUTHZ_ROOT
    unset AUTHZ_ROOT
    local fn
    while read -r fn ; do
        local lvl="$(cat "$SSHAUTHDIR/$fn")"
        fn="${fn#auth.}"
        fn="${fn%".$hash"}"
        case "$fn" in
            (vlan.*)
                AUTHZ_VLANS["${fn#vlan.}"]="$lvl"
                ;;
            (bank.*)
                AUTHZ_BANKS["${fn#bank.}"]="$lvl"
                ;;
            (root)
                AUTHZ_ROOT="$lvl"
                ;;
        esac
    done < <(find "$SSHAUTHDIR" -maxdepth 1 -mindepth 1 \
                  -name "auth.*.$hash" -printf '%P\n')
}

## Check authorization of whichever user whose permissions are
## currently stored in AUTHZ_{ROOT,BANKS,VLANS}.  The first argument
## is the required level of authorization (read, manage, admin).  To
## check root authorization, provide no further arguments.  To check
## bank authorization, provide the bank name as the next argument.  To
## check VLAN authorization, provide the bank name and VLAN id as the
## next two arguments.  Multiple VLANs may be specified, and the user
## must have the required permission in all of them.
##
## Admin authorization for a VLAN is implicit if the user has at least
## 'manage' authorization for the containing bank.  Similarly, Admin
## authorization for a bank is implicit if the user has at least
## 'manage' authorization for the root.
function check_authz () {
    local reqlvltxt="$1" ; shift
    local reqlvl="${LEVELS["$reqlvltxt"]:-${#LEVELS[@]}}"
    local cur="${INVLEVELS["$reqlvl"]}"
    local dgr="${LEVEL_DOWNGRADES["$cur"]:-"$cur"}"
    local gotlvl

    if [ $# -ge 2 ] ; then
        ## Access is requested to a VLAN in a bank.
        local bank="$1" ; shift
        local vlan
        while [ $# -gt 0 ] ; do
            vlan="$1" ; shift
            gotlvl="${LEVELS["${AUTHZ_VLANS["$bank.$vlan"]:-0}"]:-0}"
            if (( gotlvl < reqlvl )) ; then
                check_authz "$dgr" "$bank"
                return $?
            fi
        done
        return 0
    fi

    if [ $# -ge 1 ] ; then
        ## Access is requested to a bank.
        local bank="$1" ; shift
        local gotlvl="${LEVELS["${AUTHZ_BANKS["$bank"]:-0}"]:-0}"
        if (( gotlvl >= reqlvl )) ; then return 0 ; fi
        check_authz "$dgr"
        return $?
    fi

    local gotlvl="${LEVELS["${AUTHZ_ROOT:-0}"]:-0}"
    (( gotlvl >= reqlvl ))
}

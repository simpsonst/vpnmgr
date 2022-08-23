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

function copymap () {
    declare -n to="$1"
    declare -n from="$2"
    local key
    for key in "${!from[@]}" ; do
        to["$key"]="${from["$key"]}"
    done
}

function extendset () {
    declare -n to="$1"
    shift
    for key in "$@" ; do
        to["$key"]=yes
    done
}

function removekeys () {
    declare -n to="$1"
    shift
    local key
    for key in "$@" ; do
        unset to["$key"]
    done
}

function retainkeys () {
    local varname="$1" ; shift
    declare -n to="$varname"
    declare -A tokeep=()
    extendset tokeep "$@"
    local key
    for key in "${!to[@]}" ; do
        if [ -n "${tokeep["$key"]}" ] ; then continue ; fi
        unset to["$key"]
    done
}

function invertmap () {
    declare -n to="$1"
    declare -n from="$2"

    declare -A tmp=()
    local key val
    for key in "${!from[@]}" ; do
        val="${from["$key"]}"
        tmp["$val"]="$key"
    done
    to=()
    for key in "${!tmp[@]}" ; do
        val="${tmp["$key"]}"
        to["$key"]="$val"
    done
}

function ranges2set () {
    local min=0
    local max=9223372036854775807
    local arg
    while [ $# -gt 0 ] ; do
        arg="$1"
        shift
        case "$arg" in
            (--min=*)
                min="${arg#--*=}"
                ;;
            (--max=*)
                max="${arg#--*=}"
                ;;
            (*)
                declare -n res="$arg"
                break
                ;;
        esac
    done
    local arg
    for arg in "$@" ; do
        while [ "${arg}" ] ; do
            local cur="${arg%%,*}"
            arg="${arg#$cur}"
            arg="${arg#,}"

            if [[ "$cur" =~ ^[[:space:]]*([0-9]+)(-[0-9]+)?(:[0-9]+)?[[:space:]]*$ ]] ; then
                local from="${BASH_REMATCH[1]}"
                local to="${BASH_REMATCH[2]:1}"
                to="${to:-$from}"
                local out="${BASH_REMATCH[3]:1}"
                out="${out:-$from}"
                local offset=$((out - from))
                if [ $to -lt $from ] ; then
                    local tmp=$from
                    from=$to
                    to=$tmp
                fi
                local num
                for num in $(seq $from $to) ; do
                    if [ $num -ge "$min" -a $num -le "$max" ] ; then
                        res[$num]=$((num + offset))
                    fi
                done
            fi
        done
    done
}

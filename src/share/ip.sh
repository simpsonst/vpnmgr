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

function ip2int () {
    local text="$1" ; shift
    local res=0
    local i
    for (( i = 0 ; i < 4 ; i++ )) ; do
        res=$((res << 8))
        local pfx="${text%%.*}"
        text="${text#$pfx}"
        text="${text#.}"
        res=$((res + pfx))
    done
    printf '0x%08x\n' "$res"
}

function subnet2ints () {
    local text="$1" ; shift
    local ip="${text%%/*}"
    local len="${text#$ip}"
    len="${len#/}"
    len="${len-32}"
    local mask=$(((0xffffffff << (32 - len)) & 0xffffffff))
    local ival="$(ip2int "$ip")"
    printf '0x%08x 0x%08x 0x%08x %d\n' "$ival" "$((ival & mask))" "$mask" "$len"
}

function int2ip () {
    local val="$(($1))" ; shift
    printf '%d.%d.%d.%d\n' \
           $((0xff & (val >> 24))) \
           $((0xff & (val >> 16))) \
           $((0xff & (val >> 8))) \
           $((0xff & val))
}

function mask2spec () {
    local mask="$1" ; shift
    local arg="$(printf '%08x\n' "$mask")" ; shift
    case "$arg" in
        (ffffffff)
            echo 32
            ;;
        (fffffffe)
            echo 31
            ;;
        (fffffffc)
            echo 30
            ;;
        (fffffff8)
            echo 29
            ;;
        (fffffff0)
            echo 28
            ;;
        (ffffffe0)
            echo 27
            ;;
        (ffffffc0)
            echo 26
            ;;
        (ffffff80)
            echo 25
            ;;
        (ffffff00)
            echo 24
            ;;
        (fffffe00)
            echo 23
            ;;
        (fffffc00)
            echo 22
            ;;
        (fffff800)
            echo 21
            ;;
        (fffff000)
            echo 20
            ;;
        (ffffe000)
            echo 19
            ;;
        (ffffc000)
            echo 18
            ;;
        (ffff8000)
            echo 17
            ;;
        (ffff0000)
            echo 16
            ;;
        (fffe0000)
            echo 15
            ;;
        (fffc0000)
            echo 14
            ;;
        (fff80000)
            echo 13
            ;;
        (fff00000)
            echo 12
            ;;
        (ffe00000)
            echo 11
            ;;
        (ffc00000)
            echo 10
            ;;
        (ff800000)
            echo 9
            ;;
        (ff000000)
            echo 8
            ;;
        (fe000000)
            echo 7
            ;;
        (fc000000)
            echo 6
            ;;
        (f8000000)
            echo 5
            ;;
        (f0000000)
            echo 4
            ;;
        (e0000000)
            echo 3
            ;;
        (c0000000)
            echo 2
            ;;
        (80000000)
            echo 1
            ;;
        (0)
            echo 0
            ;;
        (*)
            printf >&2 'Non-prefix mask: %s\n' "$mask"
            return 1
            ;;
    esac
    return 0
}

function ints2subnet () {
    local net="$1" ; shift
    local mask="$1" ; shift

    local spec
    if ! spec="$(mask2spec "$mask")" ; then
        return 1
    fi

    
    net="$((net & mask))"
    local text="$(int2ip "$net")"
    local alt
    while alt="${text%.0}" ; [ "$alt" != "$text" ]
    do
        text="$alt"
    done
    printf '%s/%d\n' "$alt" "$spec"
}

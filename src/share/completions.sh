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

function _vpnmgr_compgen_words () {
    local val="$1" ; shift
    while [ $# -gt 0 ] ; do
        local cand="$1" ; shift
        #printf >&2 'Testing [%s] [%s] [%s]\n' "$cand" "$val" "${cand:0:${#val}}"
        if [ "${cand:0:${#val}}" != "$val" ] ; then continue ; fi
        COMPREPLY+=("$cand")
    done
}

function _vpnmgr_compgen_files () {
    local val="$1" ; shift
    local IFS=$'\n'

    local res=()
    case "$COMP_TYPE" in
        (63)
            res+=($(compgen -A directory -S / -- "$val"))
            ;;
        (*)
            res+=($(compgen -A directory -S /x -- "$val"))
            res+=($(compgen -A directory -S /y -- "$val"))
            ;;
    esac
    while [ $# -gt 0 ] ; do
        res+=($(compgen -f -X '!'"*$1" -- "$val"))
        shift
    done

    local opt
    for opt in "${res[@]}" ; do
        COMPREPLY+=("$(printf '%q\n' "$opt")")
    done
}

function _vpnmgr_completions () {
    ## $2 is the word being completed.  $3 is the word before it.

    ## These options are followed by an argument.
    local opts0=()
    opts0+=(-p)
    opts0+=(-m)
    opts0+=(-P)
    opts0+=(-b)
    opts0+=(-s)
    opts0+=(-i)
    opts0+=(-v)
    opts0+=(-n)

    ## These options take no arguments.
    local opts1=()
    opts1+=(--no-ovpn)
    opts1+=(--no-crl)
    opts1+=(--no-ca)
    opts1+=(--no-network)
    opts1+=(--no-bank +b)
    opts1+=(--no-vlan +v)
    opts1+=(--enable)
    opts1+=(--disable)
    opts1+=(--no-metric)
    opts1+=(--no-gateway)
    opts1+=(--no-domain)
    opts1+=(--no-dns)
    opts1+=(--no-authz)

    ## THese options contain an argument.
    local opts2=()
    opts2+=(--port)
    opts2+=(--match)
    opts2+=(--public)
    opts2+=(--bank)
    opts2+=(--server)
    opts2+=(--crl)
    opts2+=(--ca)
    opts2+=(--ovpn)
    opts2+=(--vlan)
    opts2+=(--network)
    opts2+=(--gateway)
    opts2+=(--metric)
    opts2+=(--route)
    opts2+=(--domain)
    opts2+=(--dns)
    opts2+=(--authz)

    ## These are the subcommands.
    local subs=()
    subs+=(test)
    subs+=(forbid)
    subs+=(admin)
    subs+=(manage)
    subs+=(read)
    subs+=(config)
    subs+=(create)
    subs+=(update)
    subs+=(destroy)
    subs+=(status)
    subs+=(list)
    subs+=(clients)

    ## Detect the subcommand.
    if [ "$COMP_CWORD" -eq 1 ] ; then
        _vpnmgr_compgen_words "$2" "${subs[@]}"
        return
    fi

    case "$2" in
        (-*)
            ;;

        (*)
            local prior="$3"
            if [ "$prior" = "=" ] ; then
                prior="${COMP_WORDS[$((COMP_CWORD-2))]}"
            fi
            case "$prior" in
                (--port|-p)
                    COMPREPLY+=($(compgen -W "$(seq 1 65535)" "$2"))
                    return
                    ;;

                (--crl)
                    _vpnmgr_compgen_files "$2" .crl .pem
                    return
                    ;;

                (--key)
                    _vpnmgr_compgen_files "$2" .key .pem
                    return
                    ;;

                (--ca)
                    _vpnmgr_compgen_files "$2" .crt .pem
                    return
                    ;;

                (--ovpn)
                    _vpnmgr_compgen_files "$2" .ovpn
                    return
                    ;;

                (--authz)
                    _vpnmgr_compgen_files "$2" .yaml
                    return
                    ;;
            esac
            return
            ;;
    esac
            
    _vpnmgr_compgen_words "$2" "${opts0[@]}" "${opts1[@]}"
    case "$COMP_TYPE" in
        (63)
            _vpnmgr_compgen_words "$2" "${opts2[@]/%/=}"
            ;;
        (*)
            _vpnmgr_compgen_words "$2" "${opts2[@]/%/=x}"
            _vpnmgr_compgen_words "$2" "${opts2[@]/%/=y}"
            ;;
    esac
}

complete -F _vpnmgr_completions vpnmgr

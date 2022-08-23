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

all::

FIND=find
SED=sed
XARGS=xargs
PRINTF=printf

-include ./config.mk
-include vpnmgr-env.mk

BINODEPS_SCRIPTDIR=src/share
SHAREDIR=$(PREFIX)/share/vpnmgr
LIBEXECDIR=$(PREFIX)/libexec/vpnmgr

admin_scripts += vpnmgr
hidden_scripts += vpnmgr-ssh-agent
hidden_scripts += privact
hidden_scripts += installation
hidden_scripts += rebuild-auth
hidden_scripts += brlink
hidden_scripts += authcheck
datafiles += settings.sh
datafiles += privileged.sh
datafiles += base62.sh
datafiles += ip.sh
datafiles += authz.sh
datafiles += sets.sh
datafiles += chunks.sh
datafiles += header.sh

hidden_binaries.c += encode_chunks
encode_chunks_obj += encode_chunks

hidden_binaries.c += decode_chunks
decode_chunks_obj += decode_chunks

include binodeps.mk

all:: installed-binaries

install:: install-hidden-scripts
install:: install-library-scripts
install:: install-admin-scripts
install:: install-data
install:: install-hidden-binaries

install::
	$(INSTALL) -m 0755 -d "/etc/bash_completion.d"
	$(INSTALL) -m 0644 src/share/completions.sh \
		"/etc/bash_completion.d/vpnmgr"
	$(RM) $(SHAREDIR)/vpnmgr-brlink
	$(RM) $(SHAREDIR)/vpnmgr-rebuild-auth
	$(RM) $(SBINDIR)/vpnmgr-agent
	$(RM) $(SBINDIR)/vpnmgr-install

clean:: tidy

tidy::
	@$(PRINTF) 'Removing detritus\n'
	@$(FIND) . -name "*~" -delete

YEARS=2018-2020

update-licence:
	$(FIND) . -name '.git' -prune -or -type f -print0 | $(XARGS) -0 \
	$(SED) -i 's/Copyright\s\+[-0-9,]\+\sLancaster University/Copyright $(YEARS), Lancaster University/g'

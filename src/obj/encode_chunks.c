// -*- c-basic-offset: 2; indent-tabs-mode: nil -*-

/*
 * Copyright 2018-2020, Lancaster University
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 * 
 *  * Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 
 *  * Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the
 *    distribution.
 * 
 *  * Neither the name of the copyright holder nor the names of
 *    its contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *
 * Author: Steven Simpson <https://github.com/simpsonst>
 */

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <stdbool.h>

#include <unistd.h>
#include <fcntl.h>

#include <sys/select.h>
#include <sys/ioctl.h>

int main(int argc, const char *const *argv)
{
  const int fd_in = fileno(stdin);
  const int fd_out = fileno(stdout);

  do {
    /* Wait until there is some data to read. */
    {
      fd_set ins;
      FD_ZERO(&ins);
      FD_SET(fd_in, &ins);
      int rc = select(fd_in + 1, &ins, NULL, NULL, NULL);
      if (rc < 0) {
        fprintf(stderr, "%s: select: %s\n", argv[0], strerror(errno));
        return EXIT_FAILURE;
      }
    }

    /* Find out how many bytes at least are buffered.  This will be
       our chunk size. */
    size_t got;
    {
      int ig;
      if (ioctl(fd_in, FIONREAD, &ig) < 0) {
        fprintf(stderr, "%s: ioctl(FIONREAD): %s\n", argv[0], strerror(errno));
        return EXIT_FAILURE;
      }
      got = ig;
    }
    if (got == 0)
      break;
    if (got > 0x70000000)
      got = 0x70000000;

    /* Print out the number of bytes we have in hex on a line of its
       own. */
    {
      size_t rem = got;
      unsigned nibs = 0;
      while (rem > 0) {
        nibs++;
        rem >>= 4;
      }
      const unsigned bufsz = nibs + 2;
      unsigned char buf[bufsz];
      unsigned pos = 0;
      while (pos < sizeof buf - 2 && nibs > 0) {
        unsigned val = 0xf & (got >> (4 * --nibs));
        switch (val) {
        case 0: case 1: case 2: case 3: case 4:
        case 5: case 6: case 7: case 8: case 9:
          buf[pos++] = 48 + val;
          break;
        case 10: case 11: case 12:
        case 13: case 14: case 15:
          buf[pos++] = (97 - 10) + val;
          break;
        }
      }
      if (pos > sizeof buf - 2) {
        fprintf(stderr, "%s: length text too long (0x%zx)\n", argv[0], got);
        return EXIT_FAILURE;
      }
      buf[pos++] = 13;
      buf[pos++] = 10;
      unsigned start = 0;
      while (start < pos) {
        ssize_t done = write(fd_out, buf + start, pos - start);
        if (done < 0) {
          fprintf(stderr, "%s: write length: %s\n", argv[0], strerror(errno));
          return EXIT_FAILURE;
        }
        start += done;
      }
    }

    while (got > 0) {
      ssize_t done = splice(fd_in, NULL, fd_out, NULL, got, 0);
      if (done < 0) {
	fprintf(stderr, "%s: splice: %s\n", argv[0], strerror(errno));
	return EXIT_FAILURE;
      }
      got -= done;
    }

    {
      unsigned char buf[] = { 13, 10 };
      const unsigned pos = sizeof buf;
      for (unsigned start = 0; start < pos; ) {
        ssize_t done = write(fd_out, buf + start, pos - start);
        if (done < 0) {
          fprintf(stderr, "%s: write crlf: %s\n", argv[0], strerror(errno));
          return EXIT_FAILURE;
        }
        start += done;
      }
    }
  } while (true);

  /* Write a trailing 0 length to mark the end. */
  {
    unsigned char buf[] = { 48, 13, 10 };
    const unsigned pos = sizeof buf;
    for (unsigned start = 0; start < pos; ) {
      ssize_t done = write(fd_out, buf + start, pos - start);
      if (done < 0) {
        fprintf(stderr, "%s: write crlf: %s\n", argv[0], strerror(errno));
        return EXIT_FAILURE;
      }
      start += done;
    }
  }

  return EXIT_SUCCESS;
}

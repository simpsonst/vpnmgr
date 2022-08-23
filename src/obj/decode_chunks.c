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

#include <fcntl.h>
#include <unistd.h>
#include <assert.h>

#include <sys/sendfile.h>

#define UNREACHABLE false

int main(int argc, const char *const *argv)
{
  const int fd_in = fileno(stdin);
  const int fd_out = fileno(stdout);

  do {
    /* Read the line giving the size of the chunk in hex. */
    size_t expect = 0;
    {
      enum { START, DIGITS, LF, DONE } stat = START;
      while (stat != DONE) {
        //fprintf(stderr, "Expect so far: %zu\n", expect);
        unsigned char c;
        ssize_t rc = read(fd_in, &c, 1);
        if (rc < 0) {
          fprintf(stderr,
                  "%s: expecting size: %s\n", argv[0], strerror(errno));
          return EXIT_FAILURE;
        }
        if (rc == 0) {
          fprintf(stderr,
                  "%s: premature EOF expecting size\n", argv[0]);
          return EXIT_FAILURE;
        }
        //fprintf(stderr, "Read 0x%02x\n", c);

        switch (stat) {
        case DONE:
          assert(UNREACHABLE);

        case LF:
          if (c != 10) {
            fprintf(stderr,
                    "%s: illegal byte 0x%02x expecting LF\n", argv[0], c);
            return EXIT_FAILURE;
          }
          stat = DONE;
          break;

        case START:
        case DIGITS:
          switch (c) {
          default:
            fprintf(stderr,
                    "%s: illegal byte %u expecting xdigit%s\n", argv[0], c,
                    stat == DIGITS ? " or CRLF" : "");
            return EXIT_FAILURE;

          case 48: case 49: case 50: case 51: case 52:
          case 53: case 54: case 55: case 56: case 57:
            expect <<= 4;
            expect |= c - 48;
            stat = DIGITS;
            break;
          case 65: case 66: case 67: case 68: case 69: case 70:
            expect <<= 4;
            expect |= c + (10 - 65);
            stat = DIGITS;
            break;
          case 97: case 98: case 99: case 100: case 101: case 102:
            expect <<= 4;
            expect |= c + (10 - 97);
            stat = DIGITS;
            break;

          case 13:
            if (stat == START) {
              fprintf(stderr, "%s: premature CR expecting size\n", argv[0]);
              return EXIT_FAILURE;
            }
            stat = LF;
            break;
          case 10:
            if (stat == START) {
              fprintf(stderr, "%s: premature LF expecting size\n", argv[0]);
              return EXIT_FAILURE;
            }
            stat = DONE;
            break;
          }
        }
      }
      if (stat != DONE) {
        fprintf(stderr, "%s: premature EOF expecting size\n", argv[0]);
        return EXIT_FAILURE;
      }
    }
    //fprintf(stderr, "expecting 0x%zx...\n", expect);
    if (expect == 0)
      break;

    /* Copy directly from stdin to stdout, without user-space
       buffering. */
    while (expect > 0) {
      //fprintf(stderr, "expecting %zu...\n", expect);
      ssize_t moved = splice(fd_in, NULL, fd_out, NULL, expect, 0);
      if (moved == 0) {
	fprintf(stderr, "%s: premature EOF expecting %zu\n",
                argv[0], expect);
	return EXIT_FAILURE;
      }
      if (moved < 0) {
	fprintf(stderr, "%s: splice: %s\n", argv[0], strerror(errno));
	return EXIT_FAILURE;
      }
      expect -= moved;
    }

    /* Consume the terminating newline. */
    {
      enum { CRLF, LF, DONE } stat = CRLF;
      while (stat != DONE) {
        unsigned char c;
        ssize_t rc = read(fd_in, &c, 1);
        if (rc < 0) {
          fprintf(stderr,
                  "%s: expecting %s: %s\n", argv[0],
                  stat == CRLF ? "CRLF" : "LF", strerror(errno));
          return EXIT_FAILURE;
        }
        if (rc == 0) {
          fprintf(stderr,
                  "%s: premature EOF expecting %s\n", argv[0],
                  stat == CRLF ? "CRLF" : "LF");
          return EXIT_FAILURE;
        }
        //fprintf(stderr, "got 0x%02x\n", c);
        switch (stat) {
        case DONE:
          assert(UNREACHABLE);

        case CRLF:
          switch (c) {
          case 13:
            stat = LF;
            break;
          case 10:
            stat = DONE;
            break;
          default:
            fprintf(stderr,
                    "%s: got 0x%02x expecting CRLF\n", argv[0], c);
            return EXIT_FAILURE;
          }
          break;

        case LF:
          switch (c) {
          case 10:
            stat = DONE;
            break;
          default:
            fprintf(stderr,
                    "%s: got 0x%02x expecting LF\n", argv[0], c);
            return EXIT_FAILURE;
          }
          break;
        }
      }
    }
  } while (true);
  return EXIT_SUCCESS;
}

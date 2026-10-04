// =============================================================================
//  Program : string.c
//  Author  : Chun-Jen Tsai
//  Date    : Dec/09/2019
// -----------------------------------------------------------------------------
//  Description:
//  This is the minimal string library for aquila.
// -----------------------------------------------------------------------------
//  Revision information:
//
//  None.
// -----------------------------------------------------------------------------
//  License information:
//
//  This software is released under the BSD-3-Clause Licence,
//  see https://opensource.org/licenses/BSD-3-Clause for details.
//  In the following license statements, "software" refers to the
//  "source code" of the complete hardware/software system.
//
//  Copyright 2019,
//                    Embedded Intelligent Systems Lab (EISL)
//                    Deparment of Computer Science
//                    National Chiao Tung Uniersity
//                    Hsinchu, Taiwan.
//
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//
//  2. Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//
//  3. Neither the name of the copyright holder nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
// =============================================================================
#include <stdio.h>
#include <string.h>

// ------------------------------------------------------------------------------
//  Functions that needs to be optimized.
//

#include <stdint.h>

typedef uint32_t word_t __attribute__((__may_alias__));

static inline uint32_t rv32_haszero(uint32_t x)
{
    return (x - UINT32_C(0x01010101)) & ~x & UINT32_C(0x80808080);
}

static inline void copy_tail(char *dst, uint32_t x)
{
    char c = (char)x;
    *dst++ = c;
    if (c == '\0') return;

    c = (char)(x >> 8);
    *dst++ = c;
    if (c == '\0') return;

    c = (char)(x >> 16);
    *dst++ = c;
    if (c == '\0') return;

    *dst = (char)(x >> 24);
}

char *strcpy(char *dst, char *src)
{
    char *ret = dst;

    if ((((uintptr_t)dst ^ (uintptr_t)src) & 3u) == 0) {
        while (((uintptr_t)src & 3u) != 0) {
            char c = *src++;
            *dst++ = c;
            if (c == '\0')
                return ret;
        }

        const word_t *s = (const word_t *)src;
        word_t *d = (word_t *)dst;

        for (;;) {
            uint32_t x = s[0];
            if (rv32_haszero(x)) {
                copy_tail((char *)d, x);
                return ret;
            }
            d[0] = x;

            x = s[1];
            if (rv32_haszero(x)) {
                copy_tail((char *)(d + 1), x);
                return ret;
            }
            d[1] = x;

            s += 2;
            d += 2;
        }
    }

    for (;;) {
        char c = *src++;
        *dst++ = c;
        if (c == '\0')
            return ret;
    }
}

static inline int word_diff(uint32_t a, uint32_t b)
{
    unsigned char ca = (unsigned char)a;
    unsigned char cb = (unsigned char)b;
    if (ca != cb || ca == 0) return (int)ca - (int)cb;

    ca = (unsigned char)(a >> 8);
    cb = (unsigned char)(b >> 8);
    if (ca != cb || ca == 0) return (int)ca - (int)cb;

    ca = (unsigned char)(a >> 16);
    cb = (unsigned char)(b >> 16);
    if (ca != cb || ca == 0) return (int)ca - (int)cb;

    ca = (unsigned char)(a >> 24);
    cb = (unsigned char)(b >> 24);
    return (int)ca - (int)cb;
}

int strcmp(char *s1, char *s2)
{
    const unsigned char *p = (const unsigned char *)s1;
    const unsigned char *q = (const unsigned char *)s2;

    if ((((uintptr_t)p ^ (uintptr_t)q) & 3u) == 0) {
        while (((uintptr_t)p & 3u) != 0) {
            unsigned int a = *p++;
            unsigned int b = *q++;

            if (a != b || a == 0)
                return (int)a - (int)b;
        }

        const word_t *w1 = (const word_t *)p;
        const word_t *w2 = (const word_t *)q;

        for (;;) {
            uint32_t a = w1[0];
            uint32_t b = w2[0];

            if (a != b)
                return word_diff(a, b);

            if (rv32_haszero(a))
                return 0;

            a = w1[1];
            b = w2[1];

            if (a != b)
                return word_diff(a, b);

            if (rv32_haszero(a))
                return 0;

            w1 += 2;
            w2 += 2;
        }
    }

    for (;;) {
        unsigned int a = *p++;
        unsigned int b = *q++;

        if (a != b || a == 0)
            return (int)a - (int)b;
    }
}

char *strncpy(char *dst, char *src, size_t n)
{
    char *tmp = dst;

    while (*src && n) *(tmp++) = *(src++), n--;
    while (n--) *(tmp++) = 0;
    return dst;
}

int strncmp(char *s1, char *s2, size_t n)
{
    int value;

    s1--, s2--;
    do
    {
        s1++, s2++;
        if (*s1 == *s2)
        {
            value = 0;
        }
        else if (*s1 < *s2)
        {
            value = -1;
            break;
        }
        else
        {
            value = 1;
            break;
        }
    } while (--n && *s1 != 0 && *s2 != 0);
    return value;
}

void *memcpy(void *d, void *s, size_t n)
{
    unsigned char *dst = (unsigned char *) d;
    unsigned char *src = (unsigned char *) s;

    for (int idx = 0; idx < n; idx++) *(dst++) = *(src++);
    return d;
}

int memcmp(const void *s1, const void *s2, size_t n)
{
    char *c1 = (char *) s1;
    char *c2 = (char *) s2;

    while (--n && *c1 == *c2)
    {
        c1++;
        c2++;
    }
    return (*c1 - *c2);
}

void *memset(void *d, int v, size_t n)
{
    unsigned char *dst = (unsigned char *) d;

    while (n--) *(dst++) = (unsigned char) v;
    return d;
}

//  End of functions extracted from Newlib.
// ------------------------------------------------------------------------------

void *memmove(void *d, void *s, size_t n)
{
    unsigned char *dst = (unsigned char *) d + n - 1;
    unsigned char *src = (unsigned char *) s + n - 1;

    if ((unsigned) d >= (unsigned) s && (unsigned) d <= (unsigned) s + n)
    {
        while (n--) *(dst--) = *(src--);
    }
    else memcpy(d, s, n);

    return d;
}

long strlen(char *s)
{
    long n = 0;

    while (*s++) n++;
    return n;
}

char *strcat(char *dst, char *src)
{
    char *tmp = dst;

    while (*tmp) tmp++;
    while (*src) *(tmp++) = *(src++);
    *tmp = 0;
    return dst;
}

char *strncat(char *dst, char *src, size_t n)
{
    char *tmp = dst;

    while (*tmp) tmp++;
    while (*src && n) *(tmp++) = *(src++), n--;
    *tmp = 0;
    return dst;
}


// =============================================================================
//  Program : stdlib.c
//  Author  : Chun-Jen Tsai
//  Date    : Dec/09/2019
// -----------------------------------------------------------------------------
//  Description:
//  This is the minimal stdlib library for Aquila.
// -----------------------------------------------------------------------------
//  Revision information:
//
//  Apr/01/2021, by Po-Wei Ho:
//     Fixed two bugs in malloc(). The first bug is that the for-loop index 'ptr'
//     was sometimes updated without clearing the used/unused flag.
//     The second bug is that 'curr_top' can somtimes point to itself.
//
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
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

extern uint8_t  __heap_start; /* declared in the linker script */
extern uint32_t __heap_size;  /* declared in the linker script */

static uint32_t heap_top = (uint32_t) &__heap_start;
static uint32_t heap_size = (uint32_t) &__heap_size;
static uint32_t *curr_top = (uint32_t *) 0xFFFFFFF0;
static uint32_t *heap_end = (uint32_t *) 0xFFFFFFF0;

void *malloc(size_t n)
{
    void *return_ptr;
    uint32_t *ptr, temp;
    int r;

    if (curr_top == heap_end) // first time to call malloc()?
    {
        curr_top = (uint32_t *) heap_top;
        heap_end = (uint32_t *) ((heap_top + heap_size) & 0xFFFFFFF0);
        *curr_top = (uint32_t) heap_end;
    }

    // Search for a large-enough free memory block (FMB).
    return_ptr = NULL;
    for (ptr = curr_top; ptr < heap_end; ptr = (uint32_t *) (*ptr & 0xFFFFFFFE))
    {
        if ((*ptr & 1) == 0 && (*ptr - (uint32_t) ptr > n))
        {
            temp = ((uint32_t) ptr) & 0xFFFFFFFE;
            return_ptr = (void *) (temp + sizeof(uint32_t));

            // Update the FMB link list structure.
            r = n % sizeof(uint32_t);
            temp = n + sizeof(uint32_t) + ((r)? 4-r : 0);
            curr_top = ptr + temp/sizeof(uint32_t);
            if (curr_top != (uint32_t *) *ptr)
                *curr_top = *ptr;
            *ptr = (uint32_t) curr_top | 1;
            break;
        }
    }

    if (return_ptr != NULL) return return_ptr;

    // Search again for a FMB from heap_top to curr_top
    for (ptr = (uint32_t *) heap_top; ptr < curr_top; ptr = (uint32_t *) (*ptr & 0xFFFFFFFE))
    {
        if ((*ptr & 1) == 0 && (*ptr - (uint32_t) ptr > n))
        {
            temp = ((uint32_t) ptr) & 0xFFFFFFFE;
            return_ptr = (void *) (temp + sizeof(uint32_t));

            // Update the FMB link list structure.
            r = n % sizeof(uint32_t);
            temp = n + sizeof(uint32_t) + ((r)? 4-r : 0);
            curr_top = ptr + temp/sizeof(uint32_t);
            if (curr_top != (uint32_t *) *ptr)
                *curr_top = *ptr;
            *ptr = (uint32_t) curr_top | 1;
            break;
        }
    }

    return return_ptr;
}

void free(void *mptr)
{
    uint32_t *ptr, *next;

    ptr = ((uint32_t *) mptr) - 1;
    *ptr = *ptr & 0xFFFFFFFE; // Free the FMB.
    next = (uint32_t *) *ptr;
    if ((*next & 1) == 0)
    {
        *ptr = *next; // Merge with the next FMB.
        curr_top = ptr;
    }
}

void *calloc(size_t n, size_t size)
{
    void *mptr;
    mptr = malloc(n*size);
    memset(mptr, 0, n*size);
    return mptr;
}

int atoi(char *s)
{
    int value, sign;

    /* skip leading while characters */
    while (*s == ' ' || *s == '\t') s++;
    if (*s == '-') sign = -1, s++;
    else sign = 1;
    if (*s >= '0' && *s <= '9') value = (*s - '0');
    else return 0;
    s++;
    while (*s != 0)
    {
       if (*s >= '0' && *s <= '9')
       {
           value = value * 10 + (*s - '0');
           s++;
       }
       else return 0;
    }

    return value * sign;
}

int abs(int n)
{
    int j;

    if (n >= 0) j = n; else j = -n;

	return j;
}

#pragma GCC push_options
#pragma GCC optimize ("O0")
void exit(int status)
{
    printf("\n-----------------------------------------------------------------------\n");
    printf("Program exit with a status code %d\n", status);
    printf("Press <reset> on the FPGA board to reboot the cpu ...\n\n");

    // If Aquila is running in a waveform simulator, we can use putchar(03)
    // to inform the simulator to end simulation if exit() has been called.
    // However, you need a UART module that invokes $finish() when a 0x03 code
    // has been sent to the UART device in simulation mode.
    putchar(03);

    while (1);
}
#pragma GCC pop_options

static int rand_seed = 27182;

void srand(unsigned int seed)
{
    rand_seed = (long) seed;
}

int rand(void)
{
    return(((rand_seed = rand_seed * 214013L + 2531011L) >> 16) & 0x7fff);
}

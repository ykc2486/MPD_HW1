// BSD 3-Clause License

// Copyright (c) 2026, ykc2486

#pragma once

#include <stdio.h>

// Profiler base address
#define PROF_BASE 0xCB000000
#define MAX_CHANNELS 5

// Control bits
#define CTRL_ENABLE 0x1
#define CTRL_DISABLE 0x0
#define CTRL_CLEAR  0x2

// Global profiler registers
#define prof_ctrl (*(volatile unsigned int *)(PROF_BASE + 0x00))
#define main_total_cycles (*(volatile unsigned int *)(PROF_BASE + 0x04))

// Registers for one profiler channel
typedef struct {
    volatile unsigned int start;
    volatile unsigned int end;
    volatile unsigned int cycles;
    volatile unsigned int mem_cycles;
} channel_t;

// First channel starts at offset 0x10
#define channels ((volatile channel_t *)(PROF_BASE + 0x10))

// Function information
typedef struct {
    const char *name;
    unsigned int start;
    unsigned int size;
} target_t;

// Set function address ranges
static inline void profiler_init(const target_t *targets, unsigned int count)
{
    if (count > MAX_CHANNELS)
        count = MAX_CHANNELS;

    for (unsigned int i = 0; i < count; i++) {
        channels[i].start = targets[i].start;
        channels[i].end = targets[i].start + targets[i].size;
    }
}

// Clear counters and start profiling
static inline void profiler_start(void)
{
    prof_ctrl = CTRL_CLEAR;
    prof_ctrl = CTRL_ENABLE;
}

// Stop profiling
static inline void profiler_stop(void)
{
    prof_ctrl = CTRL_DISABLE;
}

// Print profiling results
static inline void profiler_print(const target_t *targets, unsigned int count)
{
    if (count > MAX_CHANNELS)
        count = MAX_CHANNELS;

    printf("\n=== HW Profiler ===\n");
    printf("Total cycles: %u\n", main_total_cycles);

    for (unsigned int i = 0; i < count; i++) {
        printf("%s: cycles=%u, mem=%u\n",
               targets[i].name,
               channels[i].cycles,
               channels[i].mem_cycles);
    }

    printf("===================\n");
}
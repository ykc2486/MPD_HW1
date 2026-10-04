# Aquila CoreMark Hardware Profiler

This project is based on EEMBC CoreMark and has been modified for use with the Aquila SoC.

## Modifications

The following functionality was added or modified:

- Added an MMIO-based hardware profiler for the Aquila SoC.
- Added software interfaces to configure, start, stop, and read the profiler.
- Added five configurable profiling channels.
- Modified `core_main.c` to configure and measure selected CoreMark functions.
- Current profiling targets:
  - `crcu8`
  - `core_list_find`
  - `core_list_reverse`
  - `matrix_mul_matrix_bitextract`
  - `core_state_transition`

The profiler monitors the processor PC in hardware and counts execution cycles and memory-related cycles for the configured function address ranges.

## License and Attribution

The original CoreMark source code and other third-party source files remain subject to their original copyright notices, license headers, comments, and applicable `LICENSE` files.

The modifications related to the Aquila hardware profiler were made by **ykc2486** and are identified where applicable.

For files not modified by the author of this project, please refer to the license notices and comments contained in the corresponding source files or license files.

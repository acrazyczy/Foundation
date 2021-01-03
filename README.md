# Foundation
MS108 homework in ACM 2019 class, a toy RISC-V CPU supporting partial of rv32i ISA.

Have passed all testcases on FPGA with 100MHz. The worst negative slack is -2.697ns.

Can run pi with 2.2s.
***
## Feature
 - Tomasulo algorithm with hardware-based speculation
 - 2-bit saturating counter branch prediction with 128 entries
 - 2KiB directed-mapped i-cache with 512 entries
 - reorder buffer with 16 entries, reservation station with 16 entries, load buffer with 16 entries, instruction queue with 8 entries
 - support memory disambiguation, load forwarding and bypassing (but the acceleration is not so significant as I expected)

## Summary
 - I've tried the complete load bypassing described in CAAQA5 with a true load buffer, but it's too hard to implement the memory disambiguation. Then I made a compromise and changed the load buffer to load queue, but still managed to support load forwarding and bypassing for the head of queue.
 - The branch predictor doesn't work well. There may be some bugs but I have no time to fix.

## Reference
1. Computer Architecture: A Quantitative Approach Fifth Edition

2. https://compas.cs.stonybrook.edu/~nhonarmand/courses/sp16/cse502/slides/11-ooo_mem.pdf, a lecture about some methods to handle memory accesses in
out-of-order execution
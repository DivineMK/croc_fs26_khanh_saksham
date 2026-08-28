#import "titlepage.typ": eth-title

#set heading(numbering: "1.")
#set page(numbering: "1")

#show link: set text(blue)
#show math.equation: math.upright // disable italic for math symbols

#show: eth-title.with(
  title: [
    VLSI-II Final Project Report
  ],
  subtitle: [
    _Chip Name_ : Volderoc
  ],
  logo: image("volderoc_bare.svg", width: 80%),
  author: [ Khanh Lo  \  Saksham Kamath],
  date: datetime(year: 2026, month: 6, day: 29),
)

#outline()
#pagebreak()

= Introduction
$"PUE"="Total facility energy"/"Compute energy"$
The goal of this project was to add dedicated hardware accelerator for fixed point CORDIC #footnote[https://en.wikipedia.org/wiki/CORDIC] operations, specifically sin/cos, Cartesian to polar and vector rotation. These operations are widely used in DSP and other signal processing applications. However, software implementations of these operations on the baseline Croc processor exhibit latencies of up to 280 cycles, motivating the need for dedicated hardware acceleration. We chose 2 such workloads for evaluation: QR Decomposition-based Recursive Least Squares (QR-RLS) and software phase-locked loop (PLL).  

Our accelerator speeds up performance by up to 8.8x for these CORDIC operations, 2.7x and 3.3x respectively for QR-RLS and PLL with only 6kGE area overhead.

In addition, it is designed with configurable registers, making it easy to introduce or remove support for operations as needed.

= Design
== Architectural Overview
@updsoc-arch shows the updated SoC architecture. The CORDIC accelerator, along with the user ROM, is integrated into the user domain, requiring only minimal integration effort due to the parameterizable address map of the user domain. 

The CORDIC module exposes a single subordinate interface for processor access, enabling configuration and retrieval of computed results, while the User ROM provides a separate subordinate interface.

@soc-mem-map shows the base address of the integrated CORDIC accelerator in the user domain.
#set figure(
  gap: 1.5em,
)
#figure(
    image("assets/CORDIC-Block Integration.png", width: 90%),
    caption: [Croc SoC block diagram with CORDIC],
) <updsoc-arch>

#v(2em)

#figure(
  align(center,
    table(
      columns: 5,

      table.hline(),
      table.header(
        table.cell(colspan: 3, align: center)[*Region*], [*Start Address*], [*End Address*]
      ),
      table.hline(),

      // System bus spans all entries
      table.cell(rowspan: 11, align: (center + horizon))[*System Bus*],

      // Peripheral bus spans first 7 entries
      table.cell(rowspan: 7, align: (center + horizon))[*Peripheral Bus*],
      [Debug Module], [0x0000_0000], [0x0003_FFFF],
      [SOC Control], [0x0300_0000], [0x0300_0FFF],
      [UART], [0x0300_2000], [0x0300_2FFF],
      [GPIO], [0x0300_5000], [0x0300_5FFF],
      [Timer], [0x0300_A000], [0x0300_AFFF],
      [BOOT ROM], [0x0200_0000], [0x0200_3FFF],
      [CLINT], [0x0204_0000], [0x0207_FFFF],

      // SRAM banks directly on system bus
      table.cell(rowspan: 2)[*SRAMs*],
      [SRAM Bank 0], [0x1000_0000], [0x1000_0FFF],
      [SRAM Bank 1], [0x1000_1000], [0x1000_1FFF],

      // User bus spans last 2 entries
      table.cell(rowspan: 2, align: (center + horizon))[*User Bus*],
      [User ROM], [0x2000_0000], [0x2FFF_FFFF],
      [User CORDIC], [0x3000_0000], [0x3000_0FFF],
    ),
  ),
  caption: [SoC memory map]
) <soc-mem-map>

== CORDIC Module Description
We have implemented CORDIC supporting 3 operation modes -
1. _Sin/Cos Mode_ - Computes sine and cosine by rotating a unit vector through a given angle.
2. _Rotating Mode_ - Rotates an input vector (X,Y) by a specified angle
3. _Vectoring Mode_ - Computes the magnitude and angle of a given vector (X,Y).

This design uses normalized angle inputs #footnote[#link("https://zipcpu.com/dsp/2017/06/15/no-pi-for-you.html")[ZipCPU - No Pi for you]]  in the range [0, 2$pi$) ($pi = 2^31$) is used to simplify hardware logic. In addition, all computations use Q15.16 fixed point representation.

#v(1em)
#figure(
  image("assets/block_diagram.svg", width: 100%),
  caption: [High-level CORDIC internal block diagram],
)

The accelerator consists of 3 main components: the configurable special function registers (`config_sfr`) described in @sec:reg, the lookup table (`tan_lut`) and the main CORDIC engine (`cordic_engine`) described in @sec:cordic. In addition, we added clock gating to save idle power consumption, described in @sec:drcg.

=== Special Function Registers and Address Map <sec:reg>
@tab:cordic-regmap lists the CORDIC register interface relative to the module’s base address, including configuration, control, and status registers, along with their access permissions (read-only or read-write).

#figure(
    table(
      columns: 3,
      stroke: none,
      table.hline(),
      table.header(
        [*Offset (Hex)*], [*Register Description*], [*Access Permissions*]
      ),
      table.hline(),

      // Read-Only group
      [0x00], [CORDIC X result (cosine / rotated X / vector magnitude)], [Read-Only],
      [0x04], [CORDIC Y result (sine / rotated Y)], [Read-Only],
      [0x08], [Final vector phase output], [Read-Only],
      [0x0C], [Status register], [Read-Only],

      table.hline(),

      // Read-Write group
      [0x10], [Input phase angle], [Read-Write],
      [0x14], [Input X value (vectoring / rotation)], [Read-Write],
      [0x18], [Input Y value (vectoring / rotation)], [Read-Write],
      [0x1C], [Accuracy configuration register], [Read-Write],
      [0x20], [Miscellaneous configuration register], [Read-Write],
      [0x24], [Operation type in a mode], [Read-Write],
      [0x28], [CORDIC operation mode], [Read-Write],
      [0x2C], [Regional clock gating configuration register], [Read-Write],

      table.hline(),
      // v(0.2em)
  ),
  caption: [CORDIC register map (relative to base address)]
) <tab:cordic-regmap>

We decided not to use a combined configuration register to avoid the software overhead associated with read–modify–write operations when updating individual fields.

=== CORDIC engine state machine <sec:cordic>

#figure(
  pad(left: 5em,
    image("assets/Cordic_FSM.svg", width: 90%)
  ),
  caption: [CORDIC engine FSM]
) <fsm>

@fsm shows the finite state machine (FSM) that controls the operation of the CORDIC engine. Upon receiving a compute request, the FSM transitions from the `IDLE` state to the `RUN` state, where it performs iterative CORDIC computations. The FSM remains in the `RUN` state until the iteration count reaches the configured precision. It then returns to the `DONE` state and asserts the `compute_done` signal, which asserts the status bit in the Status register (0x0C in @tab:cordic-regmap). The processor checks this status bit to determine when the requested operation has completed.

An important design consideration was whether to use an interrupt-driven mechanism instead of polling the status bit to determine when a computation had completed. Although the design supports an interrupt-based mode to eliminate polling, the associated interrupt context switch overhead is significant (\~60–70 cycles). Consequently, for the relatively short execution latency of the CORDIC operations, polling provides better overall performance. In addition, with the latency known explicitly from the precision, the core can simply offload CORDIC operations to the accelerator and only poll when needed, allow overlapping of accelerator computations with other instructions.

=== Dynamic Regional Clock Gating (DRCG) <sec:drcg>
To prevent idle power consumption, a DRCG module is introduced that uses an integrated clock-gating cell and internal clock-enable logic to disable the clock to the entire module when there are no incoming requests or outstanding transactions. The power implications of the CORDIC module in idle mode will be discussed later in @sec:power.

== CVE2 Core Configuration
Our chosen applications for benchmark as well as other DSP applications often perform a significant number of multiplications for both output processing and CORDIC compensation. Therefore, having a dedicated multiplier within the Croc SoC beneficial for reducing latency.

The RISC-V CVE2 core used in Croc provides an option to enable hardware multiplication #footnote[#link("https://docs.openhwgroup.org/projects/cve2-user-manual/en/latest/02_user/integration.html#parameters")[CVE2 User Manual]] by configuring the `RV32M` parameter of the `cve2_core` module. We enabled the `cve2_pkg::RV32MFast` configuration, which instantiates the `cve2_multdiv_fast` unit in the core. This reduces multiplication latency to approximately 3-4 cycles, compared to the multi-cycle shift-and-add implementation of a pure ALU, which can take several tens of cycles.

To utilize this capability, the software toolchain was updated by modifying the `Makefile` to target the `rv32im_zicsr` ISA.

The primary trade-off of including the multiplier unit is increased area, which will be discussed in @sec:area_eval.

== SRAM
//TODO: Check and change overflow
For minimizing binary size, we first optimized the `Makefile` with garbage collection flags to remove unused function from binary. Then we optimize the software by preventing unnecessary function inlining and leveraging functions mapped directly to hardware accelerators. However, the program still exceeds the available memory by 312 bytes. This shows that increasing the SRAM capacity is necessary for real application usage, given that the default 4 KB cannot fit a test program.

To address this, the total SRAM capacity was doubled to 8 KB by configuring two 4 KB SRAM banks. This was achieved by modifying the `SramBankNumWords` parameter in `croc_pkg` from `512` to `1024`, and updating the software linker script accordingly to reflect the expanded memory size.

== Software interface

In order to determine when to start computation in the accelerator, we detect write to one of the inputs depending on the operation mode. Specifically, for _sin/cos_ mode, the condition to start computation is a write to input angle register, while for _rotate_ and _vector_ it is a write to input Y register.

We provide utility functions for the available CORDIC operations for ease of use, as well as to show the assumptions made in hardware, i.e. order of input for triggering computation, normalized angle values.

#figure(
  rect(
    stroke: 0.5pt,
    inset: 8pt,
  ```c
// Configuration
static inline void cordic_set_precision(uint32_t prec);
static inline void cordic_set_drcg(uint32_t enable);

// Hardware CORDIC wrappers
static inline void hw_sincos(uint32_t angle, int32_t *sin_out, int32_t *cos_out);
static inline void hw_vector(int32_t x, int32_t y, int32_t *mag_out, int32_t *phase_out);
static inline void hw_rotate(int32_t x, int32_t y, uint32_t angle, int32_t *x_out, int32_t *y_out);
  ```
),
caption : [CORDIC utility functions for the three modes of operation: sincos, vector and rotate],
)
== Other modifications
=== User ROM
We integrated a ROM into the User Domain and personalized the chip by embedding the string "`Saksham, Khanh's ASIC`" within its contents. The file `test_rom.c` used for ROM verification and testing is included as part of the submission.

#v(1em)

= Backend Implementation <chp:implementation>
The backend implementation followed a highly iterative development process, encompassing logic synthesis with Yosys, physical design using OpenROAD, Design Rule Checking (DRC) with KLayout supplemented by custom Python scripts and Layout-Versus-Schematic (LVS) verification using Calibre DRV. Throughout the project, we adapted and extended portions of the reference flow scripts to accommodate the specific requirements of our design and implementation methodology.

The technology node used is `IHP-SG13G2` 130nm with standard cell library `EZ130`. All backend results use the `tt` corner (1.2V, 25$degree$C).
// - Floorplanning (SRAM increase)
// - Clock Tree Root Buffer size reduction (X64 is an overkill)
// - Routing script change to iterate over repair_design till setup & hold time violations disappear
// - DRC Violations -done
// - sink_clustering related stuff for skew and its effect on slew
// - bufx32 with cluster 8 gives best results for max slew, max_cap and max_fanout violations


== Optimizing the Clock Tree Buffer List
The reference flow used BUFX64 in the clock buffer list, which proved excessive in terms of area and power for our design. Through experimentation with the clock tree buffer list, we arrived at BUFX8 as the root buffer and lower strength buffers for leaf cells as the optimal choice. In addition to reducing power and area, the use of smaller buffers results in a deeper clock tree with more buffering stages, providing OpenROAD with greater flexibility to balance delays and control clock skew. The tradeoff is a slight degradation in worst case setup slack, however we concluded that the power and area savings outweigh the speedup degradation, as validated by the T×A×P (time period × area × power) product metric which showed approximately 30% reduction in power and a marginal reduction in total cell area. @clktree shows the regions catered to by a parent buffer of the synthesized clock tree realized in our design. The clock tree in this case is distributed into four distinct regions, each driven by a common parent buffer to achieve balanced clock distribution.

#figure(
    image("assets/clk_tree3.png", width: 60%),
    caption: [Visualization of the Clock Distribution Regions],
) <clktree>

== Resolving Maximum Fanout Violations on Clock Tree
//TODO: Change fanout
During the backend implementation, we encountered several fanout-related violations, particularly within the clock tree and on some heavily driven internal signals. To address the clock-tree-related issues, we isolated them from the rest of the design and systematically tuned the clock tree synthesis (CTS) process using the `clustering_unbalance_ratio`, `sink_clustering_size` and `sink_clustering_levels` switches. This iterative optimization significantly reduced the number of clock-related fanout violations.

After CTS tuning, only a single fanout violation remained in the CORDIC module. The violation originated from the DRCG-generated clock signal driven by a `BUFX8` cell, which fans out to the CK input pin of 22 DFFRQX3 cells, exceeding the specified maximum fanout limit of 16 by only six sinks. To assess the severity of the violation, we compared the resulting load against the standard-cell characterization data. The combined output capacitance contributed by the wiring and the CK input pins of the 22 `DFFRQX3` flip-flops was found to be well below the `out_cload` limit specified for the driving `BUFX8` cell in the `ez130_8t` technology library. Since the electrical load remained within the cell's characterized operating range and no adverse timing effects were observed, the violation was deemed non-critical and accepted in the final design.

== Dealing With Slew Violations
A significant portion of the backend effort was devoted to debugging and resolving maximum slew violations. During our initial runs on the baseline Croc design, we encountered several slew violations with only slightly negative slew slack, primarily caused by heavily loaded, high-fanout cells. We hypothesized that increasing the drive strength of the offending cells would resolve the issue and verified this by manually replacing selected instances with functionally equivalent higher-drive-strength cells in the placement script. This successfully eliminated all slew violations in the baseline design except for a few associated with GPIO and pad cells, which the TAs advised us to ignore.

Following the integration of the CORDIC accelerator, similar violations reappeared. However, the previous solution was no longer applicable because the offending cells were already instantiated at the highest drive strengths available in the library. Many of the violations were traced to high-fanout instances of the `NOR4BBX2` cell. As further upsizing was not possible, we adopted a synthesis-level fix by modifying the Yosys `init_tech.tcl` script to exclude the use of any `NOR4BBX*` cell type, and subsequently reran the entire implementation flow starting from synthesis.

== DRC Closure and Sign-off 
The final step in the backend flow involved achieving DRC and LVS clean sign-off. We initially reduced the number of design rule violations from 10 to 2 by increasing the number of `detailed_route` iterations. The remaining violations consisted of two Metal1 spacing issues observed after routing. Since modifying a single cell instance affected multiple occurrences of the same standard cell, a targeted fix was applied instead. We identified the two offending cells and introduced a one-grid padding adjustment on the affected side by modifying the `02_placement.tcl` script. The design flow was then rerun from placement through routing, which successfully resolved all remaining DRC violations.



== Other changes

We corrected the pad rings placement to match the provided reference DEF and adapt the SRAM macro placement and power connection to the new macro used.

In addition, we modified `04_routing.tcl` to make routing repairs using `repair_design` command iteratively for maximum 40 iterations until the violations are either fixed or no longer improves. We adopted a similar iterative approach for setup timing optimization by repeatedly invoking `repair_timing` until the worst negative slack of the setup timing violations were minimized.

= Evaluation results <chp:eval>

The baseline used for performance and power evaluation is baseline Croc *with multiplier enabled* (`RV32MFast`), which we will from now on refers to as baseline Croc, to isolate clearly the benefits of our accelerator.

== Functional verification
// TODO: ask if we should include openroad scripts used
For RTL functional verification, we first modified `tb_croc_soc.sv` as in exercise 10 #footnote[https://vlsi.ethz.ch/wiki/Exercise_-_Power_analysis] to match the module instantiation from OpenROAD. Then we verified the post-layout result functionally with SDF generated from this script:
#figure(
  rect(
    stroke: 0.5pt,
    inset: 8pt,
```
source scripts/init_tech.tcl
set extRules ../technology/rcx/IHP_rcx_patterns.rules
read_def ./out/croc.def
define_process_corner -ext_model_index 0 tt
extract_parasitics -ext_model_file $extRules
write_sdf ./out/croc.sdf -corner tt -include_typ
```
),
caption : [SDF generation script for post-layout verification ],
)

The vsim scripts are also updated to use the SDF as in exercise 2 #footnote[https://vlsi.ethz.ch/wiki/Exercise_-_Simulation_flow].

For verifying correctness, we created C tests on our host (laptop) under `sw_host` to compare the results with the `sinf/cosf` from C standard library `math.h`. It is verified that there are negligible discrepancies due to the difference between floating point version of the standard library and our fixed point implementation. In addition, we then also compare results obtained from hardware versions with software versions in all tests: `test_cordic.c, test_pll.c and test_qr_rls.c`.

#v(1em)

== Performance
// TODO
We successfully closed timing and met the target operating frequency of 100 MHz. The design achieves a maximum operating frequency of 102.04 MHz. This was accomplished by constraining OpenROAD with a clock period more aggressive than the design could initially satisfy, encouraging more aggressive timing optimization during synthesis and place-and-route.

We develop equivalent software implementations of the supported CORDIC operations to evaluate the performance benefits of the accelerator. We then compare the hardware-based (HW) and software-based (SW) implementations of the CORDIC operations by first conducting micro-benchmarks for each operation independently, followed by evaluation using two representative applications: QR-RLS, commonly used in adaptive filtering applications such as noise cancellation, and digital PLL, commonly used in clock synchronization and carrier recovery. All benchmarks are performed at the maximum configurable precision, corresponding to 16 iterations.
The results are presented in @tab:benchmark.

// #figure(
//   table(
//     columns: 4,
//     align: center + horizon,
//     table.header([*Benchmarks*], [*SW* \ (in cycles)], [*HW* \ (in cycles)], [*Speedup*]),
//     [_Sin/Cos_], [281], [32], [8.8x],
//     [_Vector_], [285], [34], [8.4x],
//     [_Rotate_], [265], [36], [7.4x],
//     [_Gain compensation_], [21], [-], [-], 
//     [_QR-RLS_], [162724], [60796], [2.7x],
//     [_PLL_], [43725], [13354], [3.3x]
//   ),
//   caption: [Latency benchmarks of CORDIC operations and the applications]
// ) <tab:benchmark>

#figure(
  table(
    columns: 5,
    align: center + horizon,

    table.header(
      [*Benchmark Type*],
      [*Benchmarks*],
      [*SW* \(in cycles)],
      [*HW* \(in cycles)],
      [*Speedup*]
    ),

    // CORDIC Operations (rowspan = 3)
    table.cell(rowspan: 3, align: center + horizon)[CORDIC Operations],
    [_Sin/Cos_], [281], [32], [8.8x],

     [_Vector_], [285], [34], [8.4x],
    [_Rotate_], [265], [36], [7.4x],

    // Applications (rowspan = 3)
    [-], [_Gain compensation_], [21], [-], [-],
    table.cell(rowspan: 2, align: center + horizon)[Applications],

    [_QR-RLS_], [162724], [60796], [2.7x],
    [_PLL_], [43725], [13354], [3.3x]
  ),
  caption: [Latency benchmarks of CORDIC operations and applications]
) <tab:benchmark>

It is important to note that the micro-benchmarks of the CORDIC operations is only used for knowing the maximum speedup possible with the help of function inlining. In real applications this is not always possible due to the limited number of registers, forcing usage of stack. The function call overhead is \~30 cycles, reducing the speedup of CORDIC operations down to \~4.5x instead.

The results clearly shows the performance improvement that the accelerator brings. In software-based versions, CORDIC operations takes up \~80% execution time for QR-RLS and \~90% for PLL, resulting in overall speedup of 2.7x and 3.3x respectively.

In addition, gain compensation is applied in the 2 evaluated applications for vector and rotate (sin/cos has compensation built in the implementation). Users however can decide to ignore this gain compensation for more performance gain.

== Area <sec:area_eval>

#figure(
  image("assets/01b_plot_area_bar_comparison.png"),
  caption: [Comparison of area usage (in $mu m^2$) between original Croc and our design]
) <area_composition>

@area_composition illustrates the area difference between the baseline CROC design (provided in the reference flow) and our implementation. All gate equivalent (GE) values are rounded for simplicity.

The following observations can be made from the figure:
- Increasing the SRAM size from 2 kB to 4 kB introduces an area overhead of approximately 8 kGE/bank.
- Adding a MultDiv_Fast unit to the CVE2 core increases the area by around 6 kGE.
- The user-defined CORDIC accelerator adds roughly 6 kGE to the overall area, which is comparable to, and in absolute terms slightly lower than, the area of a CVE2 multiplier.
To better visualise the area impact of our modifications, @area_impact_visualisation compares the baseline Croc implementation with the proposed design (@area_impact_visualisation\a and @area_impact_visualisation\b, respectively). The figure presents a module-level view of the chip, with annotations restricted to the modules that were modified or added during the design process.


#figure(
  stack(
    dir: ttb,
    spacing: 0pt,
    
    // Side-by-side layout
    grid(
      columns: (1fr, 1fr),
      gutter: 1.5em,
      
      // Left Column: Image + Custom Label
      stack(
        dir: ttb,
        spacing: 0.65em, // Space between left image and its label
        image("assets/base_croc_annotated.png", width: 100%),
        align(center)[#text(size: 10pt)[a. Module view of baseline Croc with regions selected for modification]]
      ),
      
      // Right Column: Image + Custom Label
      stack(
        dir: ttb,
        spacing: 0.65em, // Space between right image and its label
        image("assets/multidiv_annotated.png", width: 100%),
        align(center)[#text(size: 10pt)[b. Module view of our design with additional design implementations]]
      )
    ),
    
  ),
  caption: [Visualization of area impact due to changes implemented in our design],
) <area_impact_visualisation>
== Power <sec:power>

For power estimation, we used the stimuli-based approach with generated `vcd` from running `vsim` with the chosen QR-RLS and PLL applications. We modify `tb_croc_soc.sv` to only start dumping waveform *after* the core is woken up (by `jtag_write_reg32` to CLINT) to exclude binary loading and startup period from measurement. We also commented out all irrelevant parts in our C tests e.g. `uart_init(), printf()`. We compare the hardware-based (HW) and software-based (SW) implementations of the CORDIC operations for the target applications, with the corresponding power measurements reported in @tab:power_swhw. For the software implementation, the CORDIC algorithm is executed on the baseline Croc processor, whereas the hardware implementation leverages the proposed CORDIC accelerator integrated into our design.

In addition, following the discussion in @sec:drcg, we evaluate the impact of Dynamic Regional Clock Gating (DRCG), with the corresponding power measurements reported in @tab:power_drcg. These results are obtained using our implemented design as the test chip, allowing us to quantify the power savings achieved by enabling DRCG.
#figure(
  table(
    columns: 4,
    align: center + horizon,
    table.header([*Benchmarks*], [*Without DRCG* \ (mW)], [*With DRCG* \ (mW)], [*DRCG savings* \ (mW)]),
    [_QR-RLS sw_], [37.1], [35.9], [1.2],
    [_QR-RLS hw_], [33.6], [33.1], [0.5],
    [_PLL sw_],    [37.7], [36.6], [1.1],
    [_PLL hw_],    [35.6], [34.5], [1.1]
  ),
  caption: [Power estimation comparison for with and without DRCG enabled] 
) <tab:power_drcg>

We observed from @tab:power_drcg that the savings are marginal (approximately 3%), which is reasonable given the low area overhead of our CORDIC accelerator. We inferred from this observation that the accelerator power overhead is negligible compared to the system as we already verified the DRCG functionally by inspecting the waveform.

Therefore, all power measurement results were obtained from our design with DRCG enabled directly, instead of having to perform measurements and backend flow for baseline Croc.

We looked at the savings from HW over SW without DRCG in more detailed in @tab:power_swhw.

//TODO: Check
#figure(
  table(
    columns: 4,
    align: center + horizon,
    table.header(
      [*Applications*], 
      [*SW* \ (mW)], 
      [*HW* \ (mW)], 
      [*HW savings* \ (mW)]
    ),
    [_QR-RLS_], [37.1], [33.6], [3.5],
    [_PLL_],    [37.7], [35.6], [2.1]
  ),
  caption: [Power estimation comparison for software-based and hardware-based CORDIC implementation] 
) <tab:power_swhw>

Even though power savings of HW is not significant (\~10% for QR-RLS and 6% for PLL), the energy savings is substantial with the runtime reduction presented in @tab:benchmark, giving 3x and 3.5x energy consumption reduction for QR-RLS and PLL respectively.

//TODO: Check
// #figure(
//   table(
//     columns: 5,
//     align: center + horizon,
//     table.header(
//       [*Test Chip*], 
//       [*Benchmarks*], 
//       [*Without DRCG* \ (mW)], 
//       [*With DRCG* \ (mW)], 
//       [*DRCG savings* \ (mW)]
//     ),
//     // y-span: 4 merges this cell vertically for all 4 benchmark rows
//     table.cell(rowspan: 4)[_Our \ Design_], [_QR-RLS sw_], [37.1], [35.9], [1.2],
//     [_QR-RLS hw_], [33.6], [33.1], [0.5],
//     [_PLL sw_],    [37.7], [36.6], [1.1],
//     [_PLL hw_],    [35.6], [34.5], [1.1]
//   ),
//   caption: [Power estimation comparison for with and without DRCG enabled] 
// ) <tab:power_drcg>

 
// - Power savings when the application is offloaded to the CORDIC is almost 
//TODO

= Potential improvements

The current design is iteratively decomposed instead of pipelined as this will multiply the CORDIC engine area overhead. However, specifically for QR-RLS, it would be beneficial to have a systolic array of pipelined CORDIC engines, which will allow overlapping data movement and computation further.

Another potential improvement is that with the targeted applications that have blocking CORDIC operations, it is likely better to connect this CORDIC accelerator directly as a core extension through the CV-X-IF interface #footnote[https://docs.openhwgroup.org/projects/openhw-group-core-v-xif/en/latest/intro.html].
// engine 4.7kGE, sfr 1.7kGE

= Conclusion

This project extended Croc with a 6kGE configurable CORDIC accelerator that speeds up chosen DSP application by up to 3.3x, reducing energy consumption by 3.5x. 

The accelerator is integrated into Croc and full RTL-GDS flow is performed, passing all DRC and LVS checks.

The project's full design flow is open-sourced at https://github.com/DivineMK/croc_fs26_khanh_saksham.

#set heading(numbering: "A.1")
#counter(heading).update(0)
= Appendix
`user_domain` directory structure
```
rtl/user_domain
├── cordic.sv: top-level
├── cordic_engine.sv: CORDIC engine module
├── drcg.sv: DRCG module
├── TANtable.sv: lookup table for tangent values 
├── config_sfr.sv: configuration registers interface
├── config_sfr_pkg.sv
└── user_rom.sv
```


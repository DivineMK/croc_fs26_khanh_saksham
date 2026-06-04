# Copyright 2023 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Authors:
# - Tobias Senti      <tsenti@ethz.ch>
# - Jannis Schönleber <janniss@iis.ee.ethz.ch>
# - Philippe Sauter   <phsauter@iis.ee.ethz.ch>

# Initialize the PDK

if {[file exists "../technology"]} {
	utl::report "Init tech from ETHZ DZ cockpit"
	set pdk_dir "../technology"
	set pdk_cells_lib ${pdk_dir}/lib
	set pdk_cells_lef ${pdk_dir}/lef
	set pdk_sram_lib  ${pdk_dir}/lib
	set pdk_sram_lef  ${pdk_dir}/lef
	set pdk_io_lib    ${pdk_dir}/lib
	set pdk_io_lef    ${pdk_dir}/lef
  set pdk_pad_lef   ${pdk_dir}/lef

  # LIB
  define_corners tt ff
  
  puts "Init standard cells"
  read_liberty -corner tt ${pdk_cells_lib}/ez130_8t_tt_1p20v_25c.lib
  read_liberty -corner ff ${pdk_cells_lib}/ez130_8t_ff_1p32v_m40c.lib
  
  puts "Init IO cells"
  read_liberty -corner tt ${pdk_io_lib}/sg13cmos5l_io_typ_1p2V_3p3V_25C.lib
  read_liberty -corner ff ${pdk_io_lib}/sg13cmos5l_io_fast_1p32V_3p6V_m40C.lib
  
  puts "Init SRAM macros"
  foreach file [glob -directory $pdk_sram_lib RM_IHPSG13*_typ_1p20V_25C.lib] {
  	read_liberty -corner tt "$file"
  }
  
  foreach file [glob -directory $pdk_sram_lib RM_IHPSG13*_fast_1p32V_m55C.lib] {
  	read_liberty -corner ff "$file"
  }
  
  puts "Init tech-lef"
  read_lef ${pdk_cells_lef}/ez130_cmos5l_tech.lef
  
  puts "Init cell-lef"
  read_lef ${pdk_cells_lef}/ez130_8t.lef
  read_lef ${pdk_io_lef}/sg13cmos5l_io.lef
  read_lef ${pdk_pad_lef}/bondpad5l_70x70.lef
  
  foreach file [glob -directory $pdk_sram_lef RM_IHPSG13*.lef] {
  	read_lef "$file"
  }

  # Tie cell pins
  set tieHiPin "TIEHI/Y"
  set tieLoPin "TIELO/Y"
  
  # Tap cell insertion
  proc insertTapCells {} {
  	utl::report "Inserting tap cells"
  	tapcell \
      -distance            40 \
      -tapcell_master WELLTAP \
      -endcap_master  WELLTAP \
      -halo_width_x 10 -halo_width_y 10
  }
  
  set ctsBuf [ list BUFX8 BUFX6 BUFX4 BUFX3 BUFX2 BUFX1]
  set ctsBufRoot BUFX8
  
  # disallow OR from inserting these cells
  set dont_use_cells [list sg13cmos5l_IOPad* AOI31X*]
  
  set stdfill [ list FILLER16 FILLER8 FILLER4 FILLER2 FILLER1 ]
  
  
  set iocorner sg13cmos5l_Corner
  set iofill [ list sg13cmos5l_Filler10000 sg13cmos5l_Filler4000 sg13cmos5l_Filler2000 sg13cmos5l_Filler1000 sg13cmos5l_Filler400 sg13cmos5l_Filler200 ]
  
  set bondPadCell bondpad5l_70x70
} else {
	utl::report "Init tech from Github PDK"
	if {![info exists pdk_dir]} {
		set pdk_dir "../ihp13/pdk"
	}
	set pdk_cells_lib ${pdk_dir}/ihp-sg13g2/libs.ref/sg13g2_stdcell/lib
	set pdk_cells_lef ${pdk_dir}/ihp-sg13g2/libs.ref/sg13g2_stdcell/lef
	set pdk_sram_lib  ${pdk_dir}/ihp-sg13g2/libs.ref/sg13g2_sram/lib
	set pdk_sram_lef  ${pdk_dir}/ihp-sg13g2/libs.ref/sg13g2_sram/lef
	set pdk_io_lib    ${pdk_dir}/ihp-sg13g2/libs.ref/sg13g2_io/lib
	set pdk_io_lef    ${pdk_dir}/ihp-sg13g2/libs.ref/sg13g2_io/lef
  set pdk_pad_lef   ../ihp13/bondpad/lef
  # LIB
  define_corners tt ff
  
  puts "Init standard cells"
  read_liberty -corner tt ${pdk_cells_lib}/sg13g2_stdcell_typ_1p20V_25C.lib
  read_liberty -corner ff ${pdk_cells_lib}/sg13g2_stdcell_fast_1p32V_m40C.lib
  
  puts "Init IO cells"
  read_liberty -corner tt ${pdk_io_lib}/sg13g2_io_typ_1p2V_3p3V_25C.lib
  read_liberty -corner ff ${pdk_io_lib}/sg13g2_io_fast_1p32V_3p6V_m40C.lib
  
  puts "Init SRAM macros"
  foreach file [glob -directory $pdk_sram_lib *_typ_1p20V_25C.lib] {
  	read_liberty -corner tt "$file"
  }
  
  foreach file [glob -directory $pdk_sram_lib *_fast_1p32V_m55C.lib] {
  	read_liberty -corner ff "$file"
  }
  
  puts "Init tech-lef"
  read_lef ${pdk_cells_lef}/sg13g2_tech.lef
  
  puts "Init cell-lef"
  read_lef ${pdk_cells_lef}/sg13g2_stdcell.lef
  read_lef ${pdk_io_lef}/sg13g2_io.lef
  read_lef ${pdk_pad_lef}/bondpad_70x70.lef
  
  foreach file [glob -directory $pdk_sram_lef RM_IHPSG13*.lef] {
  	read_lef "$file"
  }
  # Tie cell pins
  set tieHiPin "sg13g2_tiehi/L_HI"
  set tieLoPin "sg13g2_tielo/L_LO"
  
  # Tap cell insertion
  proc insertTapCells {} {
  	# no tap cells in this PDK
  }
  
  set ctsBuf [ list sg13g2_buf_16 sg13g2_buf_8 sg13g2_buf_4 sg13g2_buf_2 ]
  set ctsBufRoot sg13g2_buf_8
  
  # disallow OR from inserting these cells
  set dont_use_cells [list sg13g2_IOPad* ]
  
  set stdfill [ list sg13g2_fill_8 sg13g2_fill_4 sg13g2_fill_2 sg13g2_fill_1 ]
  
  
  set iocorner sg13g2_Corner
  set iofill [ list sg13g2_Filler10000 sg13g2_Filler4000 sg13g2_Filler2000 sg13g2_Filler1000 sg13g2_Filler400 sg13g2_Filler200 ]
  
  set bondPadCell bondpad_70x70
}

# Set layers used for estimate_parasitics
proc setDefaultParasitics {} {
	set_wire_rc -clock -layer Metal3
	set_wire_rc -signal -layer Metal3
}

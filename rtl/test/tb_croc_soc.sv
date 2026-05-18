// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Philippe Sauter <phsauter@iis.ee.ethz.ch>
// - Enrico Zelioli <ezelioli@iis.ee.ethz.ch>

`define TRACE_WAVE

module tb_croc_soc #(
  parameter int unsigned GpioCount = 18
);

  import tb_croc_pkg::*;
  import tb_ip_vga_pkg::*;
  import ip_vga_config_pkg::*;

  // Signals fully controlled by the VIP
  // use VIP functions/tasks to manipulate these signals
  logic rst_n;
  logic sys_clk;
  logic ref_clk;

  logic jtag_tck;
  logic jtag_trst_n;
  logic jtag_tms;
  logic jtag_tdi;
  logic jtag_tdo;

  logic uart_rx;
  logic uart_tx;

  // Signals partially controlled by the VIP
  logic [GpioCount-1:0] gpio_in;
  logic [GpioCount-1:0] gpio_out;
  logic [GpioCount-1:0] gpio_out_en;

  // VGA
  `ifdef TARGET_VGA
  logic hsync, vsync;
  logic [RedWidth-1:0] red;
  logic [GreenWidth-1:0] green;
  logic [BlueWidth-1:0] blue;
  `endif

  // Signals controlled by the testbench

  /////////////////////////////
  //  Command Line Arguments //
  /////////////////////////////

  string binary_path;

  initial begin
    // $value$plusargs defines what to look for (here +binary=...)
    if ($value$plusargs("binary=%s", binary_path)) begin
      $display("Running program: %s", binary_path);
    end else begin
      $display("No binary path provided. Running helloworld.");
      binary_path = "../sw/bin/helloworld.hex";
    end
  end

  ////////////
  //  VIP   //
  ////////////
  // Verification IP
  // - drives clocks and resets
  // - provides helper tasks and functions for JTAG, namely:
  //   - jtag_load_hex: loads a hex file into the DUT's memory
  //   - jtag_write_reg32: write 32-bit value to DUT
  //   - jtag_read_reg32: read 32-bit value from DUT
  //   - jtag_halt / jtag_resume: control core execution
  //   - jtag_wait_for_eoc: wait for end of code execution (core writes non-zero to status register)
  // - prints UART output to console (you can also write via uart_write_byte)
  // - internal GPIO loopback for helloworld test

  croc_vip #(
    .GpioCount ( GpioCount )
  ) i_vip (
    .rst_no        ( rst_n       ),
    .sys_clk_o     ( sys_clk     ),
    .ref_clk_o     ( ref_clk     ),
    .jtag_tck_o    ( jtag_tck    ),
    .jtag_trst_no  ( jtag_trst_n ),
    .jtag_tms_o    ( jtag_tms    ),
    .jtag_tdi_o    ( jtag_tdi    ),
    .jtag_tdo_i    ( jtag_tdo    ),
    .uart_rx_o     ( uart_rx     ),
    .uart_tx_i     ( uart_tx     ),
    .gpio_out_en_i ( gpio_out_en ),
    .gpio_out_i    ( gpio_out    ),
    .gpio_in_o     ( gpio_in     )
  );

  ////////////
  //  DUT   //
  ////////////

`ifdef TARGET_NETLIST_OPENROAD
    wire  [GpioCount-1:0] gpio_io_tb;
    logic [GpioCount-1:0] gpio_en_tb;

    // Set port 0-3 to output mode
    // You may need to adjust it for your own tests
    assign gpio_en_tb = 32'h0000_000F;

    for (genvar i = 0; i < GpioCount; i++) begin
        // drive the io pad based on the gpio mode
        assign gpio_io_tb[i] = gpio_en_tb[i] ? 1'bz : gpio_in[i];
    end

    assign gpio_out = gpio_io_tb;

    croc_chip i_croc_soc (
        .clk_i      (sys_clk),
        .testmode_i (1'b0),
        .gpio0_io(gpio_io_tb[0]),
        .gpio1_io(gpio_io_tb[1]),
        .gpio2_io(gpio_io_tb[2]),
        .gpio3_io(gpio_io_tb[3]),
        .gpio4_io(gpio_io_tb[4]),
        .gpio5_io(gpio_io_tb[5]),
        .gpio6_io(gpio_io_tb[6]),
        .gpio7_io(gpio_io_tb[7]),
        .gpio8_io(gpio_io_tb[8]),
        .gpio9_io(gpio_io_tb[9]),
        .gpio10_io(gpio_io_tb[10]),
        .gpio11_io(gpio_io_tb[11]),
        .gpio12_io(gpio_io_tb[12]),
        .gpio13_io(gpio_io_tb[13]),
        .gpio14_io(gpio_io_tb[14]),
        .gpio15_io(gpio_io_tb[15]),
        .gpio16_io(gpio_io_tb[16]),
        .gpio17_io(gpio_io_tb[17]),
        `ifdef TARGET_VGA
        `ifdef TARGET_NETLIST_OPENROAD
        .red_o_0_      (red[0]),
        .red_o_1_      (red[1]),
        .red_o_2_      (red[2]),
        .red_o_3_      (red[3]),
        .red_o_4_      (red[4]),
        .green_o_0_    (green[0]),
        .green_o_1_    (green[1]),
        .green_o_2_    (green[2]),
        .green_o_3_    (green[3]),
        .green_o_4_    (green[4]),
        .green_o_5_    (green[5]),
        .blue_o_0_     (blue[0]),
        .blue_o_1_     (blue[1]),
        .blue_o_2_     (blue[2]),
        .blue_o_3_     (blue[3]),
        .blue_o_4_     (blue[4]),
        `else
        .red_o         (red),
        .green_o       (green),
        .blue_o        (blue),
        `endif
        .hsync_o       (hsync),
        .vsync_o       (vsync),
        `endif
        .jtag_tck_i (jtag_tck  ),
        .jtag_tdi_i (jtag_tdi  ),
        .jtag_tdo_o (jtag_tdo  ),
        .jtag_tms_i (jtag_tms  ),
        .jtag_trst_ni (jtag_trst_n),
        .ref_clk_i (ref_clk),
        .rst_ni (rst_n),
        .status_o  (         ),
        .uart_rx_i (uart_rx  ),
        .uart_tx_o (uart_tx  )
    );
`else
  `ifdef TARGET_NETLIST_YOSYS
  \croc_soc$croc_chip.i_croc_soc i_croc_soc (
  `else
  croc_soc #(
    .GpioCount ( GpioCount )
  ) i_croc_soc (
  `endif
    .clk_i         ( sys_clk     ),
    .rst_ni        ( rst_n       ),
    .ref_clk_i     ( ref_clk     ),
    .testmode_i    ( 1'b0        ),
    .status_o      (             ),
    .jtag_tck_i    ( jtag_tck    ),
    .jtag_tdi_i    ( jtag_tdi    ),
    .jtag_tdo_o    ( jtag_tdo    ),
    .jtag_tms_i    ( jtag_tms    ),
    .jtag_trst_ni  ( jtag_trst_n ),
    .uart_rx_i     ( uart_rx     ),
    .uart_tx_o     ( uart_tx     ),
    `ifdef TARGET_VGA
    .hsync_o       (hsync),
    .vsync_o       (vsync),
    .red_o         (red),
    .green_o       (green),
    .blue_o        (blue),
    `endif
    .gpio_i        ( gpio_in     ),
    .gpio_o        ( gpio_out    ),
    .gpio_out_en_o ( gpio_out_en )
  );
`endif

  /////////////////
  //  Testbench  //
  /////////////////

  logic [31:0] tb_data;

  initial begin
    $timeformat(-9, 0, "ns", 12); // 1: scale (ns=-9), 2: decimals, 3: suffix, 4: print-field width

    // wait for reset
    #ClkPeriodSys;

    // init jtag
    i_vip.jtag_init();

    // write test value to sram
    i_vip.jtag_write_reg32(SramBaseAddr, 32'h1234_5678, 1'b1);

    // load binary to sram
    i_vip.jtag_load_hex(binary_path);

    // wake core from WFI by writing to CLINT msip
    $display("@%t | [CORE] Waking core via CLINT msip", $time);
    i_vip.jtag_write_reg32(ClintBaseAddr, 32'h1);

    // halt core
    //i_vip.jtag_halt();

    // resume core
    //i_vip.jtag_resume();

`ifndef TARGET_VGA
    // wait for non-zero return value (written into core status register)
    $display("@%t | [CORE] Wait for end of code...", $time);
    i_vip.jtag_wait_for_eoc(tb_data);

    // finish simulation
    repeat(50) @(posedge sys_clk);
    $finish();
`endif
  end

`ifdef TARGET_VGA
  initial begin
    // VGA testbench
    #(ClkPeriodSys);
    `ifdef TARGET_NETLIST_OPENROAD
    @(posedge i_croc_soc.\i_croc_soc/i_user/i_ip_vga/vga_en );
    `else
    @(posedge i_croc_soc.i_user.i_ip_vga.vga_en);  // wait for first vsync
    `endif
    `ifdef TRACE_WAVE
    $dumpvars(0, i_croc_soc);
    $info("Start dump");
    `endif
    //#(1 * ClkPeriodSys * ClkDiv * FullRenderHeight * FullRenderWidth);
    #(1 * ClkPeriodSys * ClkDiv * (FullRenderHeight - VertVisibleSize + FontHeight) * FullRenderWidth);
    #(50 * ClkPeriodSys);
    $info("TIMEOUT");
    $finish();
  end

  pixel_t framebuffer[FrameHeight][FrameWidth];

  task write_frame_to_bmp(string file);
    automatic int fd, fd_debug;
    automatic int i, j;
    automatic bit [7:0] r8, g8, b8;
    automatic int row_pad = (4 - (FrameWidth * 3) % 4) % 4;  // pad row to 4-byte aligned
    automatic int filesize = 54 + (FrameWidth * 3 + row_pad) * FrameHeight;

    fd = $fopen(file, "wb");
    fd_debug = $fopen("bmp_write_dump.txt", "w");

    // bitmap header (14 bytes)
    $fwrite(fd, "%c%c", "B", "M");  // signature (fixed)
    $fwrite(fd, "%u", filesize);  // file size (#bytes)
    $fwrite(fd, "%u", 0);  // reserved
    $fwrite(fd, "%u", 54);  // data offset

    // DIP header (BITMAPINFOHEADER)
    $fwrite(fd, "%u", 40);  // header size
    $fwrite(fd, "%u", FrameWidth);  // img width (#pixels)
    $fwrite(fd, "%u", FrameHeight);  // img height (#pixels)
    $fwrite(fd, "%u", 32'h00_18_00_01);  // #planes (must be 1), #bits per pixel (24)
    $fwrite(fd, "%u", 0);  // compression (no)
    $fwrite(fd, "%u", (FrameWidth * 3 + row_pad) * FrameHeight);  // image size
    $fwrite(fd, "%u", 1000);  // X pixels/meter
    $fwrite(fd, "%u", 1000);  // Y pixels/meter
    $fwrite(fd, "%u", 0);  // colors used
    $fwrite(fd, "%u", 0);  // important colors

    // Pixels (format:BGR, frame bottom-up)
    for (i = FrameHeight - 1; i >= 0; i--) begin
      for (j = 0; j < FrameWidth; j++) begin
        r8 = framebuffer[i][j].r << (8 - RedWidth);
        g8 = framebuffer[i][j].g << (8 - GreenWidth);
        b8 = framebuffer[i][j].b << (8 - BlueWidth);
        $fwrite(fd, "%c%c%c", b8, g8, r8);
        $fwrite(fd_debug, "(row=%0d, col=%0d): R=%0d, G=%0d, B=%0d\n", FrameHeight - 1 - i, j, r8,
                g8, b8);
      end
      for (j = 0; j < row_pad; j++) $fwrite(fd, "%c", 8'h00);
    end

    $fclose(fd_debug);
    $fclose(fd);
  endtask

  initial begin : frame_capture
    automatic int clk_div_counter = 0;
    automatic int hsync_porch = 0, vsync_porch = 0;
    automatic bit hsync_prev = 0, vsync_prev = 0;
    automatic int row = 0, col = 0;
    automatic int frame_num = 0;
    automatic bit capturing = 0;
    automatic string file;

    wait (rst_n === 0);
    @(posedge rst_n);
    `ifdef TARGET_NETLIST_OPENROAD
    @(posedge i_croc_soc.\i_croc_soc/i_user/i_ip_vga/vga_en );
    `else
    @(posedge i_croc_soc.i_user.i_ip_vga.vga_en);  // wait for first vsync
    `endif
    @(edge vsync);  // sync capturing on first vsync
    forever begin
      // before the divided clock, capture the previous values
      if (clk_div_counter == '0) begin
        hsync_prev = hsync;
        vsync_prev = vsync;
      end

      @(posedge sys_clk);
      #(0.8 * ClkPeriodSys);

      // clock divider: skip rest except every N-th clock edge
      clk_div_counter++;
      if (clk_div_counter < ClkDiv) begin
        continue;
      end else begin
        clk_div_counter = 0;
      end

      // start capturing frame after vsync pulse
      if (vsync_prev == ControlVsyncPol && vsync == ~ControlVsyncPol) begin
        vsync_porch = 0;
        hsync_porch = 0;
        row = 0;
        col = 0;
        capturing = 1;
        $info("VSYNC PULSE: Start capturing frame");
        continue;
      end

      // skip vertical back porch
      if (capturing && vsync_porch < VertBackPorchSize) begin
        if (hsync_prev == ControlHsyncPol && hsync == ~ControlHsyncPol) begin
          vsync_porch++;
        end
        continue;
      end


      // capture lines with visible area
      if (capturing && row < FrameHeight) begin
        // start capturing current line after hsync pulse
        if (hsync_prev == ControlHsyncPol && hsync == ~ControlHsyncPol) begin
          hsync_porch = 0;
          col = 0;
          row++;
          $info("Capturing line no #%0d", row);
          continue;
        end

        // skip horizontal back porch
        if (hsync_porch < (HoriBackPorchSize - 1)) begin
          hsync_porch++;
          continue;
        end

        // capture pixel in visible area of this line
        if (col < FrameWidth) begin
          framebuffer[row][col].r = red;
          framebuffer[row][col].g = green;
          framebuffer[row][col].b = blue;
          // if ({red, green, blue} == 16'b0) begin
          //   $info("Error at time %0t in row %0d col %0d", $time, row, col);
          // end
          col++;
        end
      end

      if (capturing && row == FrameHeight) begin
        file = $sformatf("frame_%0d.bmp", frame_num++);
        write_frame_to_bmp(file);
        $info("Frame #%0d captured to %s", frame_num - 1, file);
        capturing = 0;
      end
    end
  end
`endif

  ////////////////
  //  Waveform  //
  ////////////////
  // start waveform dump at time 0, independent of stimuli
  initial begin
    `ifdef TRACE_WAVE
      `ifdef VERILATOR
        $dumpfile("croc.fst");
      `else
        $dumpfile("croc.vcd");
      `endif
    `endif
  end

  // flush waveform dump when simulation ends
  final begin
    `ifdef TRACE_WAVE
      $dumpflush;
    `endif
  end

endmodule

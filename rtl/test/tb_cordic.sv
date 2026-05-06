module tb_cordic #();
  import croc_pkg::*; // Import OBI types
  localparam int unsigned ClkPeriod = 20ns;

  logic clk_i, rst_ni;

  clk_rst_gen #(
      .ClkPeriod   (ClkPeriod),
      .RstClkCycles(5)
  ) i_clk_rst (
      .clk_o (clk_i),
      .rst_no(rst_ni)
  );

  sbr_obi_req_t req;
  sbr_obi_rsp_t rsp;

  cordic #(
      .ObiCfg           (obi_pkg::ObiDefaultConfig),
      .obi_req_t        (sbr_obi_req_t),
      .obi_rsp_t        (sbr_obi_rsp_t),
      .MaxIterationDepth(16)
  ) i_cordic (
      .clk_i,
      .rst_ni,
      .obi_req_i(req),
      .obi_rsp_o(rsp),
      .drcg_en_i(1'b1) // Enable clock gating for testing
  );

  initial begin
    // Setup waveform dumping
    $dumpfile("tb_cordic.fst");
    $dumpvars(0, tb_cordic);
    // Initialize inputs
    req = '0;
    
    // Wait for reset to finish
    @(posedge rst_ni);
    @(posedge clk_i);
    // 1. Write to Precision SFR (Addr: 0x0)
    // Set to maximum iterations (e.g., 16)
    #1;
    req.req = 1'b1;
    req.a.we = 1'b1;
    req.a.addr = 32'h2000_1000 + 32'h0;
    req.a.wdata = 32'h0000_000d; // 16 iterations
    
    // Wait for the grant indicating request accepted
    wait(rsp.gnt);
    @(posedge clk_i);
    #1;
    req.req = 1'b0;
    // 2. Write to Operation SFR (Addr: 0x4)
    // Starts the computation. Let's say we want OpMode=0 (Rotation), OpType=0 (Sine), Angle = 30 degrees (mapped)
    // Angle sits in the upper bits [31:16]
    @(posedge clk_i);
    #1;
    req.req = 1'b1;
    req.a.we = 1'b1;
    req.a.addr = 32'h2000_1000 + 32'h4;
    // req.a.wdata = {20'h10C15, 12'h0000}; // pi/3
    req.a.wdata = {20'h0C910, 12'h0000}; // pi/4
    
    wait(rsp.gnt);
    @(posedge clk_i);
    #1;
    req.req = 1'b0;
    // 3. Wait for computation to finish (rvalid goes high)
    wait(rsp.rvalid);
    $display("Time: %0t | CORDIC Output Result: %h", $time, rsp.r.rdata);
    // Finish simulation
    #170ns;
    $finish;
  end
endmodule

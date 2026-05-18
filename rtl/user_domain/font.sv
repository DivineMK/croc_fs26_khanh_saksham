module font #(
    parameter int unsigned FontSize = 256,
    parameter int unsigned FontAddrWidth = $clog2(FontSize),
    parameter int unsigned FontDataWidth = 64
) (
    input  logic                       clk_i,
    input  logic                       rst_ni,
    // Read port
    input  logic [  FontAddrWidth-1:0] req_addr_i,
    output logic [  FontDataWidth-1:0] rsp_data_o,
    // Write port
    input  logic                       wr_req_i,
    input  logic [  FontAddrWidth-1:0] wr_addr_i,
    input  logic [  FontDataWidth-1:0] wr_data_i,
    input  logic [FontDataWidth/8-1:0] wr_be_i
);

  logic [FontSize-1:0][FontDataWidth-1:0] font_init_data;

  always_comb begin : font_init
    for (int unsigned i = 0; i < FontSize; i += 1) begin
      font_init_data[i] = {
        8'b00000000,  // ........
        8'b00000000,  // ...X....
        8'b00000000,  // ..XXX...
        8'b00000000,  // .XX.XX..
        8'b00000000,  // .XX.XX..
        8'b00000000,  // XXXXXXX.
        8'b00000000,  // XX...XX.
        8'b00000000   // ........
      };
    end
  end

  logic [FontAddrWidth-1:0] init_cnt_q, init_cnt_d;
  logic init_done_q, init_done_d;

  always_ff @(posedge clk_i, negedge rst_ni) begin : init_seq
    if (~rst_ni) begin
      init_cnt_q  <= '0;
      init_done_q <= 1'b0;
    end else begin
      init_cnt_q  <= init_cnt_d;
      init_done_q <= init_done_d;
    end
  end

  always_comb begin : init_ctrl
    init_cnt_d  = init_cnt_q;
    init_done_d = init_done_q;
    if (~init_done_q) begin
      if (init_cnt_q == FontSize - 1) begin
        init_done_d = 1'b1;
      end else begin
        init_cnt_d = init_cnt_q + 1'b1;
      end
    end
  end

  logic                       sram_we;
  logic [  FontAddrWidth-1:0] sram_addr;
  logic [  FontDataWidth-1:0] sram_wdata;
  logic [FontDataWidth/8-1:0] sram_be;
  logic [  FontDataWidth-1:0] sram_rdata;

  assign sram_we    = ~init_done_q | wr_req_i;
  assign sram_addr  = ~init_done_q ? init_cnt_q : wr_req_i ? wr_addr_i : req_addr_i;
  assign sram_wdata = ~init_done_q ? font_init_data[init_cnt_q] : wr_data_i;
  assign sram_be    = ~init_done_q ? '1 : wr_be_i;

  assign rsp_data_o = init_done_q ? sram_rdata : '0;

  tc_sram_impl #(
      .NumWords (FontSize),
      .DataWidth(FontDataWidth),
      .ByteWidth(8),
      .NumPorts (1),
      .Latency  (1),
      .SimInit  ("none")
  ) i_sram (
      .clk_i,
      .rst_ni,
      .req_i  (1'b1),
      .we_i   (sram_we),
      .addr_i (sram_addr),
      .wdata_i(sram_wdata),
      .be_i   (sram_be),
      .rdata_o(sram_rdata),
      .impl_i ('0),
      .impl_o ()
  );

endmodule

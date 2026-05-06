module drcg(
    input  logic         clk_i,
    input  logic         rst_ni,
    input  logic         req_i,
    input  logic         rvalid_i,
    input  logic         drcg_en_i,
    output logic         drcg_clk_o
);

//Internal Signals
logic drcg_q, drcg_d;
logic drcg_clk;
logic drcg_en;

//Internal Signal Assignments
assign drcg_en = (~drcg_en_i) | drcg_q | req_i | rvalid_i; // Gating enable is active when either request is active, response is valid, or the internal state is high (indicating an ongoing transaction)


always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        drcg_q <= 1'b0;
    end else begin
        drcg_q <= drcg_d;
    end
end

always_comb begin
    if(req_i) begin
        drcg_d = 1'b1;
    end else begin
        if(rvalid_i) begin
            drcg_d = 1'b0;
        end
        else begin
            drcg_d = drcg_q;
        end
    end
end

//TODO: Confirm the parameter values for the clock gating cell 
tc_clk_gating #(
  .IS_FUNCTIONAL(1'b1)
) i_clk_gate (
  .clk_i     ( clk_i      ),
  .en_i      ( drcg_en    ),
  .test_en_i ( 1'b0       ),
  .clk_o     ( drcg_clk_o )
);

endmodule
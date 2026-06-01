module cordic #(
    parameter obi_pkg::obi_cfg_t ObiCfg      = obi_pkg::ObiDefaultConfig,
    parameter type               obi_req_t   = logic,
    parameter type               obi_rsp_t   = logic,
    parameter                    drcg_enable = 1'b0
) (
    input clk_i,
    input rst_ni,
    input obi_req_t obi_req_i,
    output obi_rsp_t obi_rsp_o
);
  import config_sfr_pkg::config_cordic_t;
  import config_sfr_pkg::PrecisionWidth;
  import config_sfr_pkg::DataWidth;

  // Internal signal declarations
  config_cordic_t config_cordic;
  logic cordic_compute_done;
  logic signed [DataWidth-1:0] cordic_x, cordic_y;  // TODO: check width
  logic cordic_start;
  logic compute_start;

  logic [PrecisionWidth-1:0] tantable_ptr;
  logic [DataWidth-1:0] tan_value;
  logic drcg_clk;

  // Config SFR can be configured by OBI Master i.e Ibex Core to set the precision of the CORDIC algorithm.
  config_sfr #(
      .obi_req_t(obi_req_t),
      .obi_rsp_t(obi_rsp_t),
      .config_cordic_t(config_cordic_t)
  ) i_config_sfr (
      .clk_i (drcg_clk),
      .rst_ni(rst_ni),
      .obi_req_i,
      .obi_rsp_o,

      .cordic_oup_x_i (cordic_x),
      .cordic_oup_y_i (cordic_y),
      .cordic_done_i  (cordic_compute_done),
      .config_cordic_o(config_cordic),
      .cordic_start_o (cordic_start)
  );

  // Control Unit to manage the iterations and control flow of the CORDIC algorithm
  control_unit #() i_control_unit (
      .clk_i          (drcg_clk),
      .rst_ni         (rst_ni),
      .control_start_i(cordic_start),
      .precision_i    (config_cordic.precision),
      .ptr_o          (tantable_ptr),
      .done_o         (cordic_compute_done)
  );

  cordic_engine #(
      .config_cordic_t(config_cordic_t)
  ) i_cordic_engine (
      .clk_i          (drcg_clk),
      .rst_ni         (rst_ni),
      .start_i        (cordic_start),
      .config_cordic_i(config_cordic),
      .tan_i          (tan_value),
      .ptr_i          (tantable_ptr),
      .cordic_x_o     (cordic_x),
      .cordic_y_o     (cordic_y)
  );

  // TAN table stores the different arctan values 
  TANtable #() i_tantable (
      .ptr_i(tantable_ptr),
      .tan_o(tan_value)
  );

  // TODO: rethink drcg logic
  generate
    if (drcg_enable) begin
      drcg i_drcg (
          .clk_i     (clk_i),
          .rst_ni    (rst_ni),
          .req_i     (obi_req_i.req),
          .rvalid_i  (cordic_compute_done),
          .drcg_en_i (drcg_enable),
          .drcg_clk_o(drcg_clk)
      );
    end else begin
      assign drcg_clk = clk_i;
    end
  endgenerate
endmodule

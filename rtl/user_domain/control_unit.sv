`include "common_cells/registers.svh"

import config_sfr_pkg::PrecisionWidth;

module control_unit #(
) (
    input logic clk_i,
    input logic rst_ni,
    input logic control_start_i,
    input logic [PrecisionWidth-1:0] precision_i,
    // input logic ready_i,
    output logic compute_start_o,
    output logic done_o,
    output logic [PrecisionWidth-1:0] ptr_o
);

  // Typedefs for state machine
  typedef enum logic [1:0] {
    SYSTEM_IDLE,
    COMPUTE_INIT,
    COMPUTE_START,
    COMPUTE_DONE
  } state_t;

  // Internal signal declarations
  state_t state_q, state_d;
  logic [PrecisionWidth-1:0] iteration_q, iteration_d;

  `FF(state_q, state_d, SYSTEM_IDLE, clk_i, rst_ni)
  `FF(iteration_q, iteration_d, 'd0, clk_i, rst_ni)

  always_comb begin
    state_d = state_q;
    iteration_d = iteration_q;

    unique case (state_q)
      SYSTEM_IDLE: begin
        iteration_d = 'd0;
        if (control_start_i) begin
          state_d = COMPUTE_START;
        end
      end

      COMPUTE_START: begin
        iteration_d = iteration_q + 1;
        if (iteration_q == precision_i) begin
          state_d = COMPUTE_DONE;
          iteration_d = iteration_q;
        end
      end

      COMPUTE_DONE: begin
        state_d = SYSTEM_IDLE;
        iteration_d = 'd0;  // Reset iteration pointer for the next computation
      end

      default: begin
        state_d = SYSTEM_IDLE;
        iteration_d = 'd0;
      end

    endcase
  end

  // Output Assignments
  assign ptr_o = iteration_q;
  assign done_o = (state_q == COMPUTE_DONE);
  assign compute_start_o = (state_q == COMPUTE_START);

endmodule

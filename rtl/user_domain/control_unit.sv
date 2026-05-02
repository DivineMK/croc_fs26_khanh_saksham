module control_unit #(
    parameter MaxIterationDepth = 16,
    parameter DataWidth = 32,

    //Derived parameters
    parameter PtrWidth = $clog2(MaxIterationDepth)
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic start_i,
    input  logic [DataWidth-1:0] config_i,
    input  logic ready_i,
    input  logic [ObiCfg.IdWidth-1:0] aid_i,
    output logic [PtrWidth-1:0] ptr_o,
    output logic done_o,
    output logic system_busy_o,
    output logic [ObiCfg.IdWidth-1:0] rid_o
);

// Typedefs for state machine
typedef enum logic [1:0] {
    SYSTEM_IDLE  = 2'b00,
    COMPUTE_START = 2'b01,
    COMPUTE_DONE  = 2'b10
} state_t;

// Internal signal declarations
state_t current_state, next_state;
logic [PtrWidth-1:0] current_iteration_ptr, next_iteration_ptr;
logic [ObiCfg.IdWidth-1:0] aid_q;

// State transition logic
always_ff @(posedge clk_i) begin
    if(!rst_ni) begin
        current_state <= SYSTEM_IDLE;
        current_iteration_ptr <= 'd0;
        aid_q <= 'b0;
    end else begin
        current_state <= next_state;
        current_iteration_ptr <= next_iteration_ptr;
        aid_q <= aid_d;
    end
end


always_comb begin
    unique case(current_state)
        aid_d = aid_q;
        next_state = current_state; // Default to hold state
        next_iteration_ptr = current_iteration_ptr; // Default to hold iteration pointer

        SYSTEM_IDLE: begin
            next_iteration_ptr = 'd0;
            if(start_i) begin
                next_state = COMPUTE_START;
                aid_d = aid_i;
            end else begin
                next_state = SYSTEM_IDLE;
            end
        end

        COMPUTE_START: begin
            if(current_iteration_ptr <= config_i) begin
                next_state = COMPUTE_START;
                next_iteration_ptr = current_iteration_ptr + 1;
            end else begin
                next_state = COMPUTE_DONE;
                next_iteration_ptr = current_iteration_ptr;
            end
        end

        COMPUTE_DONE: begin
            next_state = SYSTEM_IDLE;
            next_iteration_ptr = 'd0; // Reset iteration pointer for the next computation
        end

        default: begin
            next_state = SYSTEM_IDLE;
            next_iteration_ptr = 'd0;
        end

    endcase
end

//Output Assignments
assign ptr_o = current_iteration_ptr;
assign done_o = (current_state == COMPUTE_DONE);
assign system_busy_o = (current_state != SYSTEM_IDLE);
assign rid_o = aid_q;

endmodule
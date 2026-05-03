module config_sfr #(
    parameter SfrAddrWidth = 3,
    parameter SfrDataWidth = 32,
    parameter OpTypeFieldBitWidth = 4,
    parameter OpModeFieldBitWidth = 2,
    parameter OpAngleFieldBitWidth = 16,
    parameter MaxIterationDepth = 16
) (
    input  logic                             clk_i,
    input  logic                             rst_ni,
    input  logic [SfrAddrWidth-1:0]          sfr_addr_i,
    input  logic [SfrDataWidth-1:0]          sfr_data_i,
    input  logic                             sfr_we_i,
    input  logic                             sfr_upd_i, // Signal to indicate when to update the SFR value
    output logic [OpTypeFieldBitWidth-1:0]   optype_o,
    output logic [OpModeFieldBitWidth-1:0]   opmode_o,
    output logic [OpAngleFieldBitWidth-1:0]  opangle_o,
    output logic [SfrDataWidth-1:0]          sfr_data_o
);

//Internal signal declarations
logic [SfrDataWidth-1:0] sfr_rdata_q, sfr_rdata_d;
logic [SfrDataWidth-1:0] sfr_prec_data_q, sfr_prec_data_d;
logic [SfrDataWidth-1:0] sfr_op_data_q, sfr_op_data_d;


//Local parameters and type declarations
localparam AddrOffset = $clog2(SfrDataWidth/8);
localparam MaxIterationDepthBitWidth = $clog2(MaxIterationDepth);




//SFR Addresses
localparam PRECISION_SFR_ADDR = 'd0; // SFR for precision configuration
localparam OPERATION_SFR_ADDR = 'd4; // SFR for deciding which trigonometric function to compute




always_ff @(posedge clk_i) begin
    if(!rst_ni) begin
        sfr_rdata_q <= 'b0;
        sfr_prec_data_q <= 'hf;
        sfr_op_data_q <= 'b0;
    end else begin
        sfr_rdata_q <= sfr_rdata_d;
        sfr_prec_data_q <= sfr_prec_data_d;
        sfr_op_data_q <= sfr_op_data_d;
    end
end




//SFR Address Map

//-------------- PRECISION_SFR_ADDR: --------------------
// Maximum possible precision is determined by the parameter MaxIterationDepth of the CORDIC algorithm. 
// We allocate MaxIterationDepthBitWidth bits in the LSB within the SfrDataWidth bits in the SFR
// [MaxIterationDepthBitWidth-1:0] Prec Field
//Prec Field: 
// 0x0: 1 iteration, 0x1: 2 iterations, 0x2: 3 iterations ... 0xf: 16 iterations (Default)




//-------------- OPERATION_SFR_ADDR: ---------------
// [1:0] OpMode Field
// OpMode Field: We use 2 bits for deciding Rotation Mode or Vectoring Mode.
// 0x0: Rotation Mode (Default), 0x1: Vectoring Mode

// [5:2] OpType Field
// OpType Field: Within the Rotation Mode, we use 4 bits to decide trigonometric function
// 0x0: Sine(Default), 0x1: Cosine, 0x2: Tangent, 0x3: Cotangent, 0x4: Cosecant, 0x5: Secant

// [31:15] Angle Field
// Value of the angle stored

always_comb begin : sfr_read_logic
    sfr_rdata_d = 'b0; // Default read data value

    unique case(sfr_addr_i[AddrOffset:0]) // Address decoding based on the upper bits of the address

        PRECISION_SFR_ADDR: begin
            if(!sfr_we_i) begin
                sfr_rdata_d = sfr_prec_data_q;
            end
        end

        OPERATION_SFR_ADDR: begin
            if(!sfr_we_i) begin
                sfr_rdata_d = sfr_op_data_q;
            end
        end

        default: begin
            sfr_rdata_d = 'b0; // Default case to hold the value
        end
    endcase
    
end


always_comb begin : sfr_write_logic

    // Default to hold the current values
    sfr_prec_data_d = sfr_prec_data_q;
    sfr_op_data_d = sfr_op_data_q;

    unique case(sfr_addr_i[AddrOffset:0]) // Address decoding based on the upper bits of the address

        PRECISION_SFR_ADDR: begin
            if(sfr_we_i & ~sfr_upd_i) begin
                sfr_prec_data_d = {{ (SfrDataWidth - MaxIterationDepthBitWidth){1'b0} }, sfr_data_i[MaxIterationDepthBitWidth-1:0]}; 
            end
        end

        OPERATION_SFR_ADDR: begin
            if(sfr_we_i & ~sfr_upd_i) begin
                sfr_op_data_d = {sfr_data_i[SfrDataWidth - 1:SfrDataWidth - OpAngleFieldBitWidth], { (SfrDataWidth - OpTypeFieldBitWidth - OpModeFieldBitWidth - OpAngleFieldBitWidth){1'b0} }, sfr_data_i[OpTypeFieldBitWidth + OpModeFieldBitWidth - 1:0]};
            end
        end

        default: begin
            sfr_prec_data_d = sfr_prec_data_q;
            sfr_op_data_d = sfr_op_data_q;
        end
    endcase
    
end

//Output Assignments
assign sfr_data_o = sfr_rdata_q;
assign opmode_o = sfr_op_data_q[OpTypeFieldBitWidth + OpModeFieldBitWidth - 1:OpTypeFieldBitWidth];
assign optype_o = sfr_op_data_q[OpTypeFieldBitWidth-1:0];
assign opangle_o = sfr_op_data_q[OpAngleFieldBitWidth-1:0];

endmodule

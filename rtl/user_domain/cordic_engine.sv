module cordic_engine #(
    parameter DataWidth = 32,
    parameter PtrWidth = 4,
    parameter OpAngleFieldBitWidth = 20,
    parameter OpTypeFieldBitWidth = 4,
    parameter OpModeFieldBitWidth = 2
) (
    input  logic                                clk_i,
    input  logic                                rst_ni,
    input  logic                                start_i,
    input  logic [OpTypeFieldBitWidth-1:0]      optype_i,
    input  logic [OpModeFieldBitWidth-1:0]      opmode_i,
    input  logic [OpAngleFieldBitWidth-1:0]     opangle_i,
    input  logic [DataWidth-1:0]                tan_i,
    input  logic [PtrWidth-1:0]                 ptr_i,
    output logic signed [DataWidth-1:0]         cordic_o
);


// Internal signal declarations
logic signed [DataWidth-1:0] X_pre, Y_pre, Z_pre;
logic signed [DataWidth-1:0] X_q, Y_q, Z_q;
logic signed [DataWidth-1:0] X_next, Y_next, Z_next;


//Implementation only done for Rotation Mode sine/cosine.
assign X_pre = (opmode_i == 2'h0) ? 'd39797 :'d0;
assign Y_pre = (opmode_i == 2'h0) ? 'd0 :'d0;
assign Z_pre = (opmode_i == 2'h0) ? $signed({{(DataWidth-OpAngleFieldBitWidth){1'b0}}, opangle_i}) : $signed('d0);

always_comb begin : X_Y_Z_nextvalue_calc
    if(Z_q < $signed('d0)) begin
        X_next = X_q + (Y_q >>> ptr_i);
        Y_next = Y_q - (X_q >>> ptr_i);
        Z_next = Z_q + $signed({1'b0, tan_i[DataWidth-2:0]});
    end
    else begin
        X_next = X_q - (Y_q >>> ptr_i);
        Y_next = Y_q + (X_q >>> ptr_i);
        Z_next = Z_q - $signed({1'b0, tan_i[DataWidth-2:0]});
    end
end

always_ff @( posedge clk_i ) begin : X_Y_Z_registers
    if(!rst_ni) begin
        X_q <= X_pre;
        Y_q <= Y_pre;
        Z_q <= Z_pre;
    end else if (start_i) begin
        X_q <= X_next;
        Y_q <= Y_next;
        Z_q <= Z_next;
    end else begin
        X_q <= X_pre;
        Y_q <= Y_pre;
        Z_q <= Z_pre;
    end
    
end

assign cordic_o = (optype_i == 4'h0) ? X_q : 
                  (optype_i == 4'h1) ? Y_q : $signed('d0); 

endmodule

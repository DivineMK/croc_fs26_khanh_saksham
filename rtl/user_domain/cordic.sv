module cordic #(
      parameter obi_pkg::obi_cfg_t ObiCfg              = obi_pkg::ObiDefaultConfig,
      parameter type               obi_req_t           = logic,                 
      parameter type               obi_rsp_t           = logic,
      parameter int                MaxIterationDepth   = 16,
      parameter                    UserDesignBaseAddress = 32'h2000_1000
) (
    input  clk_i,
    input  rst_ni,
    input  obi_req_t obi_req_i,
    output obi_rsp_t obi_rsp_o
);

//Local parameters and type declarations
localparam integer PtrWidth = $clog2(MaxIterationDepth);
localparam integer OpTypeFieldBitWidth = 4;
localparam integer OpModeFieldBitWidth = 2;
localparam integer OpAngleFieldBitWidth = 20;

// Internal signal declarations
logic [ObiCfg.DataWidth-1:0] config_sfr_data;
logic [PtrWidth-1:0] tantable_ptr;
logic [ObiCfg.DataWidth-1:0] tan_value;
logic [ObiCfg.IdWidth-1:0] rid;
logic [OpAngleFieldBitWidth-1:0] opangle;
logic [OpModeFieldBitWidth-1:0] opmode;
logic [OpTypeFieldBitWidth-1:0] optype;
logic [PtrWidth-1:0] precision;
logic system_busy;
logic compute_done;
logic [ObiCfg.DataWidth-1:0] cordic_result;
logic compute_start;
logic opsfr_access_valid;
logic sfr_access_valid;
logic err;


//Config SFR can be configured by OBI Master i.e Ibex Core to set the precision of the CORDIC algorithm.
config_sfr #(
    .SfrAddrWidth ( ObiCfg.AddrWidth ),
    .SfrDataWidth ( ObiCfg.DataWidth ),
    .OpTypeFieldBitWidth (OpTypeFieldBitWidth),
    .OpModeFieldBitWidth (OpModeFieldBitWidth),
    .OpAngleFieldBitWidth (OpAngleFieldBitWidth),
    .MaxIterationDepth ( MaxIterationDepth ),
    .CordicBaseAddress ( UserDesignBaseAddress )
) i_config_sfr (
    .clk_i                ( clk_i                  ),
    .rst_ni               ( rst_ni                 ),
    .sfr_addr_i           ( obi_req_i.a.addr       ),
    .sfr_data_i           ( obi_req_i.a.wdata      ),
    .sfr_we_i             ( obi_req_i.a.we         ),
    .sfr_upd_i            ( system_busy            ),
    .opmode_o             ( opmode                 ),
    .optype_o             ( optype                 ),
    .opangle_o            ( opangle                ),
    .precision_o          ( precision              ),
    .sfr_data_o           ( config_sfr_data        ),
    .opsfr_access_valid_o ( opsfr_access_valid     ),
    .sfraccess_valid_o    ( sfr_access_valid       )
);


//Control Unit to manage the iterations and control flow of the CORDIC algorithm
control_unit #(
    .MaxIterationDepth ( MaxIterationDepth ),
    .DataWidth ( ObiCfg.DataWidth )
) i_control_unit (
    .clk_i                ( clk_i                  ),
    .rst_ni               ( rst_ni                 ),
    .ready_i              ( '1                     ), // TODO
    .start_i              ( obi_req_i.req          ),
    .opsfr_access_valid_i ( opsfr_access_valid     ),
    .sfr_access_valid_i   ( sfr_access_valid       ),
    .config_i             ( precision              ),
    .aid_i                ( obi_req_i.a.aid        ),
    .ptr_o                ( tantable_ptr           ),
    .done_o               ( compute_done           ),
    .system_busy_o        ( system_busy            ),
    .rid_o                ( rid                    ),
    .err_o                ( err                    )
);


cordic_engine #(
    .DataWidth ( ObiCfg.DataWidth ),
    .PtrWidth  ( PtrWidth ),
    .OpTypeFieldBitWidth (OpTypeFieldBitWidth),
    .OpModeFieldBitWidth (OpModeFieldBitWidth)
) i_cordic_engine (
    .clk_i      ( clk_i                  ),
    .rst_ni     ( rst_ni                 ),
    .start_i    ( system_busy            ),
    .opmode_i   ( opmode                 ),
    .optype_i   ( optype                 ),
    .opangle_i  ( opangle                ),
    .tan_i      ( tan_value              ),
    .ptr_i      ( tantable_ptr           ),
    .cordic_o   ( cordic_result          )
);


// TAN table stores the different arctan values 
TANtable #(
    .MaxIterationDepth ( MaxIterationDepth ),
    .DataWidth ( ObiCfg.DataWidth )
) i_tantable (
    .ptr_i   ( tantable_ptr ),
    .tan_o   ( tan_value    )
);



//A-Channel Signals
assign obi_rsp_o.gnt = obi_req_i.req && !system_busy; // Grant when there is a valid request and the system is not busy

//R-Channel Signals
assign obi_rsp_o.rvalid        = compute_done;
assign obi_rsp_o.r.rdata       = cordic_result; 
assign obi_rsp_o.r.err         = err; // OKAY response
assign obi_rsp_o.r.rid         = rid;
assign obi_rsp_o.r.r_optional  = 'b0; // Not used in this design;

endmodule

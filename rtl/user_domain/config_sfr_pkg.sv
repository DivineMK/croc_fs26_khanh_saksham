package config_sfr_pkg;

  parameter unsigned SfrAddrWidth = 4;
  parameter unsigned SfrDataWidth = 32;
  parameter unsigned OpTypeFieldBitWidth = 4;
  parameter unsigned OpModeFieldBitWidth = 2;
  parameter unsigned MaxIterationDepth = 16;
  // parameter unsigned Precision = MaxIterationDepth;

  parameter unsigned DataWidth = SfrDataWidth;
  // Derived parameters
  parameter unsigned PrecisionWidth = $clog2(MaxIterationDepth);

  typedef struct packed {
    logic [PrecisionWidth-1:0] precision;  // -1 of actual number of iterations
    logic [OpTypeFieldBitWidth-1:0] optype;  // choose between 2 outputs of CORDIC
    logic [OpModeFieldBitWidth-1:0] opmode;  // CORDIC mode: 0=sincos, 1=vector
    logic drcg_en;  // enable drcg
    logic [DataWidth-1:0] cordic_a_inp;  // CORDIC angle input (0-2pi)
    logic signed [DataWidth-1:0] cordic_x_inp;  // X input for vector mode
    logic signed [DataWidth-1:0] cordic_y_inp;  // Y input for vector mode
  } config_cordic_t;

  localparam int unsigned IntAddrWidth = SfrAddrWidth + 2;

  // SFR Address Map
  //-------------- PRECISION_SFR_OFFSET: --------------------
  // Maximum possible precision is determined by the parameter MaxIterationDepth of the CORDIC algorithm. 
  // We allocate MaxIterationDepthBitWidth bits in the LSB within the DataWidth bits in the SFR
  // [MaxIterationDepthBitWidth-1:0] Prec Field
  // [3:0] Prec Field: 
  // 0x0: 1 iteration, 0x1: 2 iterations, 0x2: 3 iterations ... 0xf: 16 iterations (Default)
  //-------------- MISC_SFR_OFFSET: --------------------
  // [0] DRCG Enable Bit: 
  // 1'b0: DRCG Disabled(Default), 1'b1: DRCG Enabled 
  //-------------- OPERATION_SFR_OFFSET: ---------------
  // [1:0] OpMode Field
  // OpMode Field: We use 2 bits for deciding Rotation Mode or Vectoring Mode.
  // 0x0: Rotation Mode (Default), 0x1: Vectoring Mode

  // [5:2] OpType Field
  // OpType Field: Within the Rotation Mode, we use 4 bits to decide trigonometric function
  // 0x0: Sine(Default), 0x1: Cosine

  // [31:15] Angle Field
  // Value of the angle stored

  // TODO: determine order for synthesizing better selection logic
  parameter logic [IntAddrWidth-1:0] OUTPUT_X_OFFSET = 6'h00;  // output read-only
  parameter logic [IntAddrWidth-1:0] OUTPUT_Y_OFFSET = 6'h04;  // output read-only
  parameter logic [IntAddrWidth-1:0] STATUS_OFFSET = 6'h08;  // control status
  parameter logic [IntAddrWidth-1:0] INPUT_OFFSET = 6'h0C;
  parameter logic [IntAddrWidth-1:0] PRECISION_SFR_OFFSET = 6'h10;
  parameter logic [IntAddrWidth-1:0] MISC_SFR_OFFSET = 6'h14;
  parameter logic [IntAddrWidth-1:0] OPTYPE_SFR_OFFSET = 6'h18;
  parameter logic [IntAddrWidth-1:0] OPMODE_SFR_OFFSET = 6'h1C;
  parameter logic [IntAddrWidth-1:0] INPUT_X_OFFSET = 6'h20;
  parameter logic [IntAddrWidth-1:0] INPUT_Y_OFFSET = 6'h24;
  parameter logic [IntAddrWidth-1:0] DRCG_SFR_OFFSET = 6'h28;

endpackage


package ip_vga_config_pkg;
  localparam int unsigned FontSize = 256;
  localparam int unsigned FontWidth = 8;
  localparam int unsigned FontHeight = 8;
  localparam int unsigned FontAddrWidth = $clog2(FontSize);
  localparam int unsigned FontWidthLog = $clog2(FontWidth);
  localparam int unsigned FontHeightLog = $clog2(FontHeight);
  localparam int unsigned FontDataWidth = 64;  // font word size

  localparam int unsigned LineCharWidth = 80;
  localparam int unsigned LineCharHeight = 25;

  // OBI parameters -> use ObiCfg
  // localparam int unsigned ObiDataWidth = 32;  // obi width
  // localparam int unsigned ObiAddrWidth = 32;  // croc is 32 bit
  // localparam int unsigned ObiIdWidth = 1;

  localparam int unsigned TBSize = LineCharWidth * LineCharHeight / 2;  // word size = 2 elements

  localparam int unsigned FrameWidth = FontWidth * LineCharWidth;
  localparam int unsigned FrameHeight = FontHeight * LineCharHeight;

  localparam int unsigned HoriVisibleSize = FrameWidth;
  localparam int unsigned HoriFrontPorchSize = 32'h00000010;
  localparam int unsigned HoriBackPorchSize = 32'h00000060;
  localparam int unsigned HoriSyncSize = 32'h00000060;

  localparam int unsigned VertVisibleSize = FrameHeight;
  localparam int unsigned VertFrontPorchSize = 32'h0000000A;
  localparam int unsigned VertBackPorchSize = 32'h00000021;
  localparam int unsigned VertSyncSize = 32'h00000002;

  localparam int unsigned ClkDiv = 2;
  localparam logic ControlEnable = 1;
  localparam logic ControlHsyncPol = 0;
  localparam logic ControlVsyncPol = 0;
endpackage

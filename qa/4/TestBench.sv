`timescale 100ps / 100ps
//
// RAMIO + BurstRAM
//
`default_nettype none

module TestBench;

  localparam RAM_DEPTH_BITWIDTH = 4; // 2^4 * 8 B

  reg sys_rst_n = 0;
  reg clk = 1;
  localparam clk_tk = 36;
  always #(clk_tk / 2) clk = ~clk;

  wire br_cmd;
  wire br_cmd_en;
  wire [RAM_DEPTH_BITWIDTH-1:0] br_addr;
  wire [63:0] br_wr_data;
  wire [7:0] br_data_mask;
  wire [63:0] br_rd_data;
  wire br_rd_data_valid;
  wire br_init_calib;
  wire br_busy;

  BurstRAM #(
      .DATA_FILE("RAM.mem"),  // initial RAM content
      .DEPTH_BITWIDTH(RAM_DEPTH_BITWIDTH),  // 2 ^ 4 * 8 B entries
      .BURST_COUNT(4),  // 4 * 64 bit data per burst
      .CYCLES_BEFORE_DATA_VALID(6)
  ) burst_ram (
      .clk(clk),
      .rst_n(sys_rst_n),
      .cmd(br_cmd),  // 0: read, 1: write
      .cmd_en(br_cmd_en),  // 1: cmd and addr is valid
      .addr(br_addr),  // 8 bytes word
      .wr_data(br_wr_data),  // data to write
      .data_mask(br_data_mask),  // not implemented (same as 0 in IP component)
      .rd_data(br_rd_data),  // read data
      .rd_data_valid(br_rd_data_valid),  // rd_data is valid
      .init_calib(br_init_calib),
      .busy(br_busy)
  );

  reg enable = 0;
  reg [1:0] write_type = 0;
  reg [2:0] read_type = 0;
  reg [31:0] address = 0;
  wire [31:0] data_out;
  wire data_out_ready;
  reg [31:0] data_in = 0;
  wire busy;
  wire [5:0] leds = 0;
  reg uart_tx;
  wire uart_rx;

  RAMIO #(
      .RAM_DEPTH_BITWIDTH(RAM_DEPTH_BITWIDTH),
      .RAM_ADDRESSING_MODE(3), // 64 bit word RAM
      .CACHE_LINE_IX_BITWIDTH(1),
      .CLK_FREQ(20_250_000),
      .BAUD_RATE(9600)
  ) ramio (
      .rst_n(sys_rst_n && br_init_calib),
      .clk(clk),
      .enable(enable),
      .write_type(write_type),
      .read_type(read_type),
      .address(address),
      .data_in(data_in),
      .data_out(data_out),
      .data_out_ready(data_out_ready),
      .busy(busy),
      .leds(leds),
      .uart_tx(uart_tx),
      .uart_rx(uart_rx),

      // burst RAM wiring; prefix 'br_'
      .br_cmd(br_cmd),  // 0: read, 1: write
      .br_cmd_en(br_cmd_en),  // 1: cmd and addr is valid
      .br_addr(br_addr),  // see 'RAM_ADDRESSING_MODE'
      .br_wr_data(br_wr_data),  // data to write
      .br_data_mask(br_data_mask),  // always 0 meaning write all bytes
      .br_rd_data(br_rd_data),  // data out
      .br_rd_data_valid(br_rd_data_valid)  // rd_data is valid
  );

  initial begin
    $dumpfile("log.vcd");
    $dumpvars(0, TestBench);

    #clk_tk;
    #clk_tk;
    sys_rst_n <= 1;
    #clk_tk;

    // wait for burst RAM to initiate
    while (br_busy) #clk_tk;

    data_in <= 0;

    // read; cache miss
    address <= 16;
    read_type <= 3'b111;  // read full word
    write_type <= 2'b00;  // disable write
    enable <= 1;
    #clk_tk;

    while (!data_out_ready) #clk_tk;

    if (data_out == 32'hD5B8A9C4) $display("Test 1 passed");
    else $display("Test 1 FAILED");

    // read unsigned byte; cache hit
    address <= 17;
    read_type <= 3'b001;
    write_type <= 2'b00;
    enable <= 1;
    #clk_tk;

    while (!data_out_ready) #clk_tk;

    if (data_out == 32'h0000_00A9) $display("Test 2 passed");
    else $display("Test 2 FAILED");

    // read unsigned short; cache hit
    address <= 18;
    read_type <= 3'b010;
    write_type <= 2'b00;
    enable <= 1;
    #clk_tk;

    while (!data_out_ready) #clk_tk;

    if (data_out == 32'h0000_D5B8) $display("Test 3 passed");
    else $display("Test 3 FAILED");

    $finish;

    #clk_tk;
    #clk_tk;
    #clk_tk;
    #clk_tk;

    $finish;
  end

endmodule

`default_nettype wire

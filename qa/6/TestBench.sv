`timescale 100ps / 100ps
//
// RAMIO + BurstRAM
//
`default_nettype none

module TestBench;

  localparam RAM_DEPTH_BITWIDTH = 4;  // 2^4 * 8 B

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
  reg uart_rx = 0;

  RAMIO #(
      .RAM_DEPTH_BITWIDTH(RAM_DEPTH_BITWIDTH),
      .RAM_ADDRESSING_MODE(3),  // 64 bit word RAM
      .CACHE_LINE_IX_BITWIDTH(1),
      .CLK_FREQ(20_250_000),
      .BAUD_RATE(20_250_000)
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
      .leds(leds[5:2]),
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

  Core core (
      .rst_n(sys_rst_n && br_init_calib),
      .clk  (clk),
      .led  (led[1:0]),

      .ramio_enable(ramio_enable),
      .ramio_write_type(ramio_write_type),
      .ramio_read_type(ramio_read_type),
      .ramio_address(ramio_address),
      .ramio_data_in(ramio_data_in),
      .ramio_data_out(ramio_data_out),
      .ramio_data_out_ready(ramio_data_out_ready),
      .ramio_busy(ramio_busy),

      .flash_clk (flash_clk),
      .flash_miso(flash_miso),
      .flash_mosi(flash_mosi),
      .flash_cs  (flash_cs)
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

    if (br_busy == 0) $display("Test 1 passed");
    else $display("Test 1 FAILED");

    $finish;

  end

endmodule

`default_nettype wire

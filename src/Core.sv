`timescale 100ps / 100ps
//
`default_nettype none

module Core (
    input wire clk,
    input wire rst_n,
    output reg [1:0] led,

    // RAMIO
    output reg ramio_enable,

    // b00 not a write; b01: byte, b10: half word, b11: word
    output reg [1:0] ramio_write_type,

    // b000 not a read; bit[2] flags sign extended or not, b01: byte, b10: half word, b11: word
    output reg [2:0] ramio_read_type,

    // address in bytes
    output reg [31:0] ramio_address,

    // sign extended byte, half word, word
    output reg [31:0] ramio_data_in,

    // data at 'address' according to 'read_type'
    input wire [31:0] ramio_data_out,

    input wire ramio_data_out_ready,

    input wire ramio_busy,

    // flash
    output reg  flash_clk,
    input  wire flash_miso,
    output reg  flash_mosi,
    output reg  flash_cs
);

  // ----------------------------------------------------------
  localparam STARTUP_WAIT = 1_000_000;

  // localparam FLASH_TRANSFER_BYTES_NUM = 32'h0020_0000;
  localparam FLASH_TRANSFER_BYTES_NUM = 32'h0010_0000;

  // used while reading flash
  reg [23:0] flash_data_to_send;
  reg [4:0] flash_bits_to_send;
  reg [31:0] flash_counter;
  reg [7:0] flash_current_byte_out;
  reg [7:0] flash_current_byte_num;
  reg [7:0] flash_data_in[4];

  // used while reading flash to increment 'cache_address'
  reg [31:0] ramio_address_next;

  localparam STATE_INIT_POWER = 0;
  localparam STATE_LOAD_CMD_TO_SEND = 1;
  localparam STATE_SEND = 2;
  localparam STATE_LOAD_ADDRESS_TO_SEND = 3;
  localparam STATE_READ_DATA = 4;
  localparam STATE_START_WRITE = 5;
  localparam STATE_WRITE = 6;
  localparam STATE_TEST_1 = 7;
  localparam STATE_TEST_2 = 8;
  localparam STATE_DONE = 9;

  reg [4:0] state = 0;
  reg [4:0] return_state = 0;

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      ramio_enable <= 0;
      ramio_read_type <= 0;
      ramio_write_type <= 0;
      ramio_address <= 0;
      ramio_address_next <= 0;
      ramio_data_in <= 0;

      led[1:0] <= 2'b11;

      flash_counter <= 0;
      flash_clk <= 0;
      flash_mosi <= 0;
      flash_cs <= 1;

      state <= STATE_INIT_POWER;

    end else begin

      case (state)

        STATE_INIT_POWER: begin
          if (flash_counter > STARTUP_WAIT) begin
            flash_counter <= 0;
            state <= STATE_LOAD_CMD_TO_SEND;
          end else begin
            flash_counter <= flash_counter + 1;
          end
        end

        STATE_LOAD_CMD_TO_SEND: begin
          flash_cs <= 0;
          flash_data_to_send[23-:8] <= 3;  // command 3: read
          flash_bits_to_send <= 8;
          state <= STATE_SEND;
          return_state <= STATE_LOAD_ADDRESS_TO_SEND;
        end

        STATE_LOAD_ADDRESS_TO_SEND: begin
          flash_data_to_send <= 0;  // address 0x0
          flash_bits_to_send <= 24;
          flash_current_byte_num <= 0;
          state <= STATE_SEND;
          return_state <= STATE_READ_DATA;
        end

        STATE_SEND: begin
          if (flash_counter == 0) begin
            // at clock to low
            flash_clk <= 0;
            flash_mosi <= flash_data_to_send[23];
            flash_data_to_send <= {flash_data_to_send[22:0], 1'b0};
            flash_bits_to_send <= flash_bits_to_send - 1;
            flash_counter <= 1;
          end else begin
            // at clock to high
            flash_counter <= 0;
            flash_clk <= 1;
            if (flash_bits_to_send == 0) begin
              state <= return_state;
            end
          end
        end

        STATE_READ_DATA: begin
          if (!flash_counter[0]) begin
            flash_clk <= 0;
            flash_counter <= flash_counter + 1;
            if (flash_counter[3:0] == 0 && flash_counter > 0) begin
              // every 16 clock ticks (8 bit * 2)
              flash_data_in[flash_current_byte_num] <= flash_current_byte_out;
              flash_current_byte_num <= flash_current_byte_num + 1;
              if (flash_current_byte_num == 3) begin
                state <= STATE_START_WRITE;
              end
            end
          end else begin
            flash_clk <= 1;
            flash_current_byte_out <= {flash_current_byte_out[6:0], flash_miso};
            flash_counter <= flash_counter + 1;
          end
        end

        STATE_START_WRITE: begin
          if (!ramio_busy) begin
            ramio_enable <= 1;
            ramio_read_type <= 0;
            ramio_write_type <= 2'b11;
            ramio_address <= ramio_address_next;
            ramio_address_next <= ramio_address_next + 4;
            ramio_data_in <= {
              flash_data_in[3], flash_data_in[2], flash_data_in[1], flash_data_in[0]
            };
            state <= STATE_WRITE;
          end
        end

        STATE_WRITE: begin
          if (!ramio_busy) begin
            ramio_enable <= 0;
            flash_current_byte_num <= 0;
            if (ramio_address_next < FLASH_TRANSFER_BYTES_NUM) begin
              state <= STATE_READ_DATA;
            end else begin
              flash_cs <= 1;
              state <= STATE_TEST_1;
            end
          end
        end

        STATE_TEST_1: begin
          if (!ramio_busy) begin
            // read unsigned half-word (16 bits) from address 0x4
            ramio_enable <= 1;
            ramio_read_type <= 3'b010;
            ramio_write_type <= 0;
            ramio_address <= 4;
            state <= STATE_TEST_2;
          end
        end

        STATE_TEST_2: begin
          if (ramio_data_out_ready) begin
            if (ramio_data_out == 32'h00_00_41_20) begin  // addr: 0x4, half-word
              led[1:0] <= 2'b00;
            end else begin
              led[1:0] <= 2'b11;
            end
            state <= STATE_DONE;
          end
        end

        STATE_DONE: begin
        end

      endcase
    end
  end

endmodule

`default_nettype wire

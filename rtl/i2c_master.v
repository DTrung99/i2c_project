`timescale 1ns / 1ps
module i2c_master (
  input  wire       clk,
  input  wire       rst_n,
  input  wire       i_start,
  input  wire       i_write,
  input  wire       i_read,
  input  wire       i_stop,
  input  wire [6:0] i_addr,
  input  wire [7:0] i_wdata,
  input  wire       tick,
  output reg  [7:0] o_rdata,
  output reg        o_busy,
  output reg        o_ack_err,
  output reg        o_done,
  output reg        scl_oen,
  output reg        sda_oen,
  input  wire       sda_i
);

  localparam [3:0]
    IDLE     = 4'b0000,
    START    = 4'b0001,
    TX_ADDR  = 4'b0010,
    ACK_ADDR = 4'b0011,
    TX_DATA  = 4'b0100,
    ACK_DATA = 4'b0101,
    RX_DATA  = 4'b0110,
    ACK_RX   = 4'b0111,
    STOP_A   = 4'b1000,
    STOP_B   = 4'b1001,
    STOP_C   = 4'b1010;

  reg [3:0] state;
  reg       half;
  reg [3:0] bit_cnt;
  reg [6:0] shift_in;
  reg       ack_nack;
  wire [7:0] addr_rw = {i_addr, i_read};

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= IDLE;
      half     <= 1'b0;
      bit_cnt  <= 4'd0;
      shift_in <= 7'd0;
      o_rdata  <= 8'd0;
      o_busy   <= 1'b0;
      o_ack_err<= 1'b0;
      o_done   <= 1'b0;
      ack_nack <= 1'b0;
      scl_oen  <= 1'b1;
      sda_oen  <= 1'b1;
    end else begin
      if (state == TX_ADDR && tick && half)
        $display("M: arw=%b i_a=%b i_r=%b i_w=%b bc=%d sda_oen=%b",
          addr_rw, i_addr, i_read, i_write, bit_cnt, sda_oen);
      if (state == IDLE && i_start)
        $display("M: START i_r=%b i_w=%b i_a=%b", i_read, i_write, i_addr);
      if (tick)
        $display("M: t=%0d st=%d half=%d bc=%d sda_oen=%b scl_oen=%b",
          $time, state, half, bit_cnt, sda_oen, scl_oen);
      o_done    <= 1'b0;
      o_ack_err <= 1'b0;

      case (state)
        IDLE: begin
          scl_oen <= 1'b1;
          sda_oen <= 1'b1;
          o_busy  <= 1'b0;
          if (i_start && (i_write || i_read)) begin
            state   <= START;
            sda_oen <= 1'b0;
            o_busy  <= 1'b1;
          end
        end

        START: begin
          if (tick) begin
            scl_oen <= 1'b0;
            sda_oen <= addr_rw[7];
            bit_cnt <= 4'd7;
            state   <= TX_ADDR;
            half    <= 1'b0;
          end
        end

        TX_ADDR: begin
          if (tick) begin
            half <= ~half;
            if (~half) begin
              scl_oen <= 1'b1;
            end else begin
              scl_oen <= 1'b0;
              if (bit_cnt == 0) begin
                state   <= ACK_ADDR;
                sda_oen <= 1'b1;
              end else begin
                bit_cnt <= bit_cnt - 1;
                sda_oen <= addr_rw[bit_cnt - 1];
              end
            end
          end
        end

        ACK_ADDR: begin
          if (tick) begin
            half <= ~half;
            if (~half) begin
              scl_oen  <= 1'b1;
              ack_nack <= sda_i;
            end else begin
              scl_oen  <= 1'b0;
              if (ack_nack) begin
                state    <= STOP_A;
                o_ack_err<= 1'b1;
                sda_oen  <= 1'b0;
              end else if (i_write) begin
                state   <= TX_DATA;
                bit_cnt <= 4'd7;
                sda_oen <= i_wdata[7];
              end else begin
                state   <= RX_DATA;
                bit_cnt <= 4'd7;
                sda_oen <= 1'b1;
                shift_in<= 7'd0;
              end
            end
          end
        end

        TX_DATA: begin
          if (tick) begin
            half <= ~half;
            if (~half) begin
              scl_oen <= 1'b1;
            end else begin
              scl_oen <= 1'b0;
              if (bit_cnt == 0) begin
                state   <= ACK_DATA;
                sda_oen <= 1'b1;
              end else begin
                bit_cnt <= bit_cnt - 1;
                sda_oen <= i_wdata[bit_cnt - 1];
              end
            end
          end
        end

        ACK_DATA: begin
          if (tick) begin
            half <= ~half;
            if (~half) begin
              scl_oen  <= 1'b1;
              ack_nack <= sda_i;
            end else begin
              scl_oen  <= 1'b0;
              if (ack_nack) begin
                state    <= STOP_A;
                o_ack_err<= 1'b1;
                sda_oen  <= 1'b0;
              end else if (i_stop || !i_write) begin
                state   <= STOP_A;
                sda_oen <= 1'b0;
              end else begin
                state   <= TX_DATA;
                bit_cnt <= 4'd7;
                sda_oen <= i_wdata[7];
              end
            end
          end
        end

        RX_DATA: begin
          if (tick) begin
            half <= ~half;
            if (~half) begin
              scl_oen <= 1'b1;
            end else begin
              scl_oen <= 1'b0;
              shift_in <= {shift_in[5:0], sda_i};
              if (bit_cnt == 0) begin
                o_rdata <= {shift_in[6:0], sda_i};
                state   <= ACK_RX;
                sda_oen <= 1'b0;
              end else begin
                bit_cnt <= bit_cnt - 1;
              end
            end
          end
        end

        ACK_RX: begin
          if (tick) begin
            half <= ~half;
            if (~half) begin
              scl_oen <= 1'b1;
            end else begin
              scl_oen <= 1'b0;
              if (i_stop) begin
                state   <= STOP_A;
                sda_oen <= 1'b0;
              end else begin
                state   <= RX_DATA;
                bit_cnt <= 4'd7;
                sda_oen <= 1'b1;
                shift_in<= 7'd0;
              end
            end
          end
        end

        STOP_A: begin
          if (tick) begin
            scl_oen <= 1'b1;
            sda_oen <= 1'b0;
            state   <= STOP_B;
          end
        end

        STOP_B: begin
          if (tick) begin
            sda_oen <= 1'b1;
            state   <= STOP_C;
          end
        end

        STOP_C: begin
          if (tick) begin
            scl_oen <= 1'b1;
            sda_oen <= 1'b1;
            o_done  <= 1'b1;
            state   <= IDLE;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule

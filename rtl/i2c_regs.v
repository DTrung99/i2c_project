module i2c_regs (
  input  wire       clk,
  input  wire       rst_n,
  input  wire [1:0] addr,
  input  wire       wr_en,
  input  wire [7:0] wdata,
  input  wire       rd_en,
  output reg  [7:0] rdata,
  output reg        start,
  output reg        write,
  output reg        read,
  output reg        stop,
  output reg [6:0]  slave_addr,
  output reg [7:0]  data_wr,
  input  wire [7:0] data_rd,
  input  wire       busy,
  input  wire       ack_err,
  input  wire       done
);

  reg ack_err_sticky;
  reg done_sticky;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start     <= 1'b0;
      write     <= 1'b0;
      read      <= 1'b0;
      stop      <= 1'b0;
      slave_addr<= 7'd0;
      data_wr   <= 8'd0;
      ack_err_sticky <= 1'b0;
      done_sticky <= 1'b0;
      $display("REGS: t=%0t RESET read=0", $time);
    end else begin
      if (wr_en)
        $display("REGS: t=%0t wr_en addr=%b wdata=%b read->%b busy=%b",
          $time, addr, wdata, wdata[4], busy);
      if (busy) start <= 1'b0;

      if (ack_err) ack_err_sticky <= 1'b1;
      if (done)    done_sticky    <= 1'b1;

    if (wr_en && (addr != 2'b00 || !busy)) begin
      case (addr)
        2'b00: begin
          start <= wdata[7];
          stop  <= wdata[6];
          write <= wdata[5];
          read  <= wdata[4];
          ack_err_sticky <= 1'b0;
          done_sticky    <= 1'b0;
        end
        2'b01: slave_addr <= wdata[7:1];
        2'b10: data_wr    <= wdata;
        default: ;
      endcase
    end
    end
  end

  always @(posedge clk) begin
    rdata <= 8'd0;
    if (rd_en) begin
      case (addr)
        2'b00: rdata <= {busy, ack_err_sticky, done_sticky, 5'd0};
        2'b10: rdata <= data_rd;
        default: ;
      endcase
    end
  end

endmodule

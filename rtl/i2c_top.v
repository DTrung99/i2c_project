module i2c_top (
  input  wire       clk,
  input  wire       rst_n,
  input  wire [1:0] addr,
  input  wire       wr_en,
  input  wire [7:0] wdata,
  input  wire       rd_en,
  input  wire       sda_i,
  output wire [7:0] rdata,
  output wire       scl_oen,
  output wire       sda_oen
);

  wire tick;
  wire busy, ack_err, done;
  wire start, write, read, stop;
  wire [6:0] slave_addr;
  wire [7:0] data_wr, data_rd;

  i2c_scl_gen #(.DIVIDER(250)) scl_gen (
    .clk  (clk),
    .rst_n(rst_n),
    .en   (1'b1),
    .tick (tick)
  );

  i2c_master master (
    .clk     (clk),
    .rst_n   (rst_n),
    .i_start (start),
    .i_write (write),
    .i_read  (read),
    .i_stop  (stop),
    .i_addr  (slave_addr),
    .i_wdata (data_wr),
    .tick    (tick),
    .o_rdata (data_rd),
    .o_busy  (busy),
    .o_ack_err(ack_err),
    .o_done  (done),
    .scl_oen (scl_oen),
    .sda_oen (sda_oen),
    .sda_i   (sda_i)
  );

  i2c_regs regs (
    .clk      (clk),
    .rst_n    (rst_n),
    .addr     (addr),
    .wr_en    (wr_en),
    .wdata    (wdata),
    .rd_en    (rd_en),
    .rdata    (rdata),
    .start    (start),
    .write    (write),
    .read     (read),
    .stop     (stop),
    .slave_addr(slave_addr),
    .data_wr  (data_wr),
    .data_rd  (data_rd),
    .busy     (busy),
    .ack_err  (ack_err),
    .done     (done)
  );

endmodule

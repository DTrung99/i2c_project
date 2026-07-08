module i2c_scl_gen (
  input  wire       clk,
  input  wire       rst_n,
  input  wire       en,
  output wire       tick
);

  parameter DIVIDER = 250;

  reg [$clog2(DIVIDER)-1:0] cnt;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt <= 0;
    end else if (!en) begin
      cnt <= 0;
    end else if (cnt == DIVIDER - 1) begin
      cnt <= 0;
    end else begin
      cnt <= cnt + 1;
    end
  end

  assign tick = en && (cnt == DIVIDER - 1);

endmodule

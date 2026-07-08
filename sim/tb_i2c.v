`timescale 1ns/1ps

module tb_i2c();

  reg       clk   = 0;
  reg       rst_n = 0;
  reg [1:0] addr;
  reg       wr_en = 0;
  reg       rd_en = 0;
  reg [7:0] wdata;
  wire[7:0] rdata;
  wire      scl_oen, sda_oen;
  wire      scl, sda;

  always #10 clk = ~clk;

  // TB owns the bus: scl/sda are resolved here based on DUT's oen and slave.
  // The DUT only sees sda_i (an input) for bus monitoring.
  assign scl = (~scl_oen) ? 1'b0 : 1'b1;
  assign sda = (~sda_oen || sla_sda_driven) ? 1'b0 : 1'b1;

  i2c_top u_dut (
    .clk     (clk),
    .rst_n   (rst_n),
    .addr    (addr),
    .wr_en   (wr_en),
    .wdata   (wdata),
    .rd_en   (rd_en),
    .sda_i   (sda),
    .rdata   (rdata),
    .scl_oen (scl_oen),
    .sda_oen (sda_oen)
  );

  // ==========================================================================
  // I2C Slave Model (address 0x50)
  // ==========================================================================
  parameter SLAVE_ADDR = 7'h50;

  reg       sla_sda_driven = 0;

  reg [7:0] slave_shift;
  reg [3:0] slave_bitcnt;
  reg [2:0] slave_state;
  reg       slave_match;
  reg [7:0] slave_rx_byte;
  reg [7:0] slave_tx_data = 8'hA5;

  localparam [2:0]
    S_IDLE  = 3'd0,
    S_ADDR  = 3'd1,
    S_ACK_A = 3'd2,
    S_DATA  = 3'd3,
    S_ACK_D = 3'd4,
    S_RDATA = 3'd5,
    S_ACK_R = 3'd6;

  reg scl_d, sda_d;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      scl_d <= 1'b1;
      sda_d <= 1'b1;
    end else begin
      scl_d <= scl;
      sda_d <= sda;
    end
  end

  wire scl_rise  =  scl && !scl_d;
  wire scl_fall  = !scl &&  scl_d;
  wire start_det = !sda && sda_d && scl;
  wire stop_det  =  sda && !sda_d && scl;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      slave_state   <= S_IDLE;
      sla_sda_driven <= 1'b0;
      slave_shift   <= 8'd0;
      slave_bitcnt  <= 4'd0;
      slave_match   <= 1'b0;
      slave_rx_byte <= 8'd0;
    end else begin
      case (slave_state)
        S_IDLE: begin
          sla_sda_driven <= 1'b0;
          slave_match    <= 1'b0;
          if (start_det) begin
            slave_state  <= S_ADDR;
            slave_bitcnt <= 4'd7;
            slave_shift  <= 8'd0;
          end
        end

        S_ADDR: begin
          if (scl_rise) begin
            slave_shift <= {slave_shift[6:0], sda};
            if (slave_bitcnt == 0) begin
              slave_state  <= S_ACK_A;
              slave_bitcnt <= 4'd7;
              slave_match  <= (slave_shift[6:0] == SLAVE_ADDR);
            end else begin
              slave_bitcnt <= slave_bitcnt - 1;
            end
          end
          if (stop_det) slave_state <= S_IDLE;
        end

        S_ACK_A: begin
          if (scl_fall) sla_sda_driven <= slave_match;
          if (scl_rise) begin
            if (slave_match) begin
              if (slave_shift[0]) begin
                slave_state  <= S_RDATA;
                slave_shift  <= slave_tx_data;
                slave_bitcnt <= 4'd7;
              end else begin
                slave_state  <= S_DATA;
                slave_shift  <= 8'd0;
                slave_bitcnt <= 4'd7;
              end
            end else begin
              slave_state <= S_IDLE;
            end
          end
          if (stop_det) slave_state <= S_IDLE;
        end

        S_DATA: begin
          if (scl_fall) sla_sda_driven <= 1'b0;
          if (scl_rise) begin
            slave_shift <= {slave_shift[6:0], sda};
            $display("SLAVE: t=%0d scl_rise DATA bitcnt=%d sda=%b shift=%b",
              $time, slave_bitcnt, sda, {slave_shift[6:0], sda});
            if (slave_bitcnt == 0) begin
              slave_state  <= S_ACK_D;
              slave_bitcnt <= 4'd7;
            end else begin
              slave_bitcnt <= slave_bitcnt - 1;
            end
          end
          if (stop_det) slave_state <= S_IDLE;
        end

        S_ACK_D: begin
          if (scl_fall) sla_sda_driven <= 1'b1;
          if (scl_rise) begin
            slave_rx_byte  <= slave_shift;
            $display("SLAVE: t=%0d scl_rise ACK_D slave_shift=%b (old)slave_rx_byte=%b",
              $time, slave_shift, slave_rx_byte);
            slave_state    <= S_DATA;
            slave_bitcnt   <= 4'd7;
            slave_shift    <= 8'd0;
          end
          if (stop_det) slave_state <= S_IDLE;
        end

        S_RDATA: begin
          if (scl_fall) sla_sda_driven <= ~slave_shift[slave_bitcnt];
          if (scl_rise) begin
            if (slave_bitcnt == 0) begin
              slave_state  <= S_ACK_R;
              slave_bitcnt <= 4'd7;
            end else begin
              slave_bitcnt <= slave_bitcnt - 1;
            end
          end
          if (stop_det) slave_state <= S_IDLE;
        end

        S_ACK_R: begin
          if (scl_fall) sla_sda_driven <= 1'b0;
          if (scl_rise) slave_state <= S_IDLE;
          if (stop_det) slave_state <= S_IDLE;
        end

        default: slave_state <= S_IDLE;
      endcase
    end
  end

  reg [7:0] sr_val, dr_val;

  // ==========================================================================
  // Register-access helper tasks
  // ==========================================================================
  task reg_write(input [1:0] reg_addr, input [7:0] data);
    begin
      @(posedge clk);
      addr  <= reg_addr;
      wdata <= data;
      wr_en <= 1'b1;
      @(posedge clk);
      wr_en <= 1'b0;
    end
  endtask

  task reg_read(input [1:0] reg_addr);
    begin
      @(posedge clk);
      addr  <= reg_addr;
      rd_en <= 1'b1;
      @(posedge clk);
      #1;
      if (reg_addr == 2'b00) sr_val = rdata;
      else                   dr_val = rdata;
      rd_en <= 1'b0;
    end
  endtask

  // ==========================================================================
  // Test driver
  // ==========================================================================
  initial begin
    integer poll_cnt;

    $dumpfile("sim/tb_i2c.vcd");
    $dumpvars(0, tb_i2c);

    addr  <= 2'd0;
    wdata <= 8'd0;
    wr_en <= 1'b0;
    rd_en <= 1'b0;

    rst_n <= 1'b0;
    #100;
    rst_n <= 1'b1;
    #300;
    $display("--- After reset ---");
    $display("  i_write=%b i_read=%b i_addr=%b addr_rw=%b i_wdata=%b stop=%b",
      u_dut.master.i_write, u_dut.master.i_read, u_dut.master.i_addr,
      u_dut.master.addr_rw, u_dut.master.i_wdata, u_dut.master.i_stop);
    // trace FSM
    fork
      begin
        while (1) begin
          #5000;
          if (u_dut.master.state != 0)
            $display("t=%0d state=%d scl_oen=%b sda_oen=%b scl=%b sda=%b bitcnt=%d half=%b",
              $time, u_dut.master.state,
              scl_oen, sda_oen, scl, sda,
              u_dut.master.bit_cnt, u_dut.master.half);
        end
      end
    join_none

    // ----------------------------------------------------------------
    // Test 1 — Write byte 0x55 to slave 0x50 (with stop)
    // ----------------------------------------------------------------
    $write("T1: Write 0x55 to 0x50 ... ");
    reg_write(2'b01, {SLAVE_ADDR, 1'b0});
    reg_write(2'b10, 8'h55);
    #500; // let things settle
    $display("  (pre-CR: start=%b write=%b read=%b stop=%b)",
      u_dut.regs.start, u_dut.regs.write, u_dut.regs.read, u_dut.regs.stop);
    reg_write(2'b00, 8'b1110_0000);       // start=1, stop=1, write=1
    #200;
    $display("  (post-CR: start=%b write=%b read=%b stop=%b busy=%b master_state=%d done_sticky=%b)",
      u_dut.regs.start, u_dut.regs.write, u_dut.regs.read, u_dut.regs.stop,
      u_dut.busy, u_dut.master.state, u_dut.regs.done_sticky);
    poll_cnt = 0;
    reg_read(2'b00);
    $display("  (poll: init sr=0x%02x)", sr_val);
    while (!sr_val[5] && poll_cnt < 5000) begin
      #1000;
      reg_read(2'b00);
      if (poll_cnt < 5) $display("  (poll: %0d sr=0x%02x)", poll_cnt, sr_val);
      poll_cnt = poll_cnt + 1;
    end
    reg_read(2'b00);
    $display("  (regs: start=%b write=%b read=%b stop=%b busy=%b ack=%b done=%b sr=0x%02x poll=%0d)",
      u_dut.regs.start, u_dut.regs.write, u_dut.regs.read,
      u_dut.regs.stop, u_dut.busy, u_dut.ack_err, u_dut.done, sr_val, poll_cnt);
    if      (poll_cnt >= 5000) $display("TIMEOUT (sr=0x%02x)", sr_val);
    else if (sr_val[6])        $display("FAIL (ack_err)");
    else if (slave_rx_byte !== 8'h55) begin
                               $display("FAIL (data=0x%02x) t=%0d (ns) sr=0x%02x poll_cnt=%0d",
                                 slave_rx_byte, $time, sr_val, poll_cnt);
                               $display("  slave_rx_byte=%b slave_state=%d scl=%b sda=%b done=%b",
                                 slave_rx_byte, slave_state, scl, sda, u_dut.regs.done); end
    else                       $display("PASS");

    // ----------------------------------------------------------------
    // Test 2 — Read byte from slave 0x50
    // ----------------------------------------------------------------
    $write("T2: Read from 0x50 ... ");
    reg_write(2'b01, {SLAVE_ADDR, 1'b0});
    reg_write(2'b00, 8'b1101_0000);       // start=1, stop=1, read=1
    poll_cnt = 0;
    reg_read(2'b00);
    while (!sr_val[5] && poll_cnt < 5000) begin
      #1000;
      reg_read(2'b00);
      poll_cnt = poll_cnt + 1;
    end
    if (poll_cnt >= 5000) begin $display("TIMEOUT"); end else begin
      reg_read(2'b10);
      if (dr_val === 8'hA5) $display("PASS (0x%02x)", dr_val);
      else                  $display("FAIL (got 0x%02x)", dr_val);
    end

    // ----------------------------------------------------------------
    // Test 3 — NACK (wrong slave address)
    // ----------------------------------------------------------------
    $write("T3: NACK addr 0x7E ... ");
    reg_write(2'b01, {7'h7E, 1'b0});
    reg_write(2'b10, 8'h00);
    reg_write(2'b00, 8'b1110_0000);
    poll_cnt = 0;
    reg_read(2'b00);
    while (!sr_val[5] && poll_cnt < 5000) begin
      #1000;
      reg_read(2'b00);
      poll_cnt = poll_cnt + 1;
    end
    reg_read(2'b00);
    if      (poll_cnt >= 5000) $display("TIMEOUT");
    else if (sr_val[6])        $display("PASS");
    else                       $display("FAIL (no ack_err)");

    // ----------------------------------------------------------------
    // Test 4 — Busy flag
    // ----------------------------------------------------------------
    $write("T4: Busy flag ... ");
    reg_write(2'b01, {SLAVE_ADDR, 1'b0});
    reg_write(2'b10, 8'hAA);
    reg_write(2'b00, 8'b1110_0000);
    #10000;
    reg_read(2'b00);
    if (sr_val[7]) $display("PASS");
    else           $display("FAIL");
    poll_cnt = 0;
    reg_read(2'b00);
    while (!sr_val[5] && poll_cnt < 5000) begin
      #1000;
      reg_read(2'b00);
      poll_cnt = poll_cnt + 1;
    end
    if (poll_cnt >= 5000)
      $display("  (T4 poll timeout sr=0x%02x)", sr_val);

    // ----------------------------------------------------------------
    // Test 5 — Write byte 0x5A to slave 0x50
    // ----------------------------------------------------------------
    $write("T5: Write 0x5A to 0x50 ... ");
    reg_write(2'b01, {SLAVE_ADDR, 1'b0});
    reg_write(2'b10, 8'h5A);
    reg_write(2'b00, 8'b1110_0000);
    poll_cnt = 0;
    reg_read(2'b00);
    while (!sr_val[5] && poll_cnt < 5000) begin
      #1000;
      reg_read(2'b00);
      poll_cnt = poll_cnt + 1;
    end
    reg_read(2'b00);
    if      (poll_cnt >= 5000) $display("TIMEOUT (sr=0x%02x)", sr_val);
    else if (sr_val[6])        $display("FAIL (ack_err)");
    else if (slave_rx_byte !== 8'h5A)
                               $display("FAIL (data=0x%02x)", slave_rx_byte);
    else                       $display("PASS");

    // ----------------------------------------------------------------
    // Test 6 — Write byte 0x00 (boundary: all zeros on SDA)
    // ----------------------------------------------------------------
    $write("T6: Write 0x00 to 0x50 ... ");
    reg_write(2'b01, {SLAVE_ADDR, 1'b0});
    reg_write(2'b10, 8'h00);
    reg_write(2'b00, 8'b1110_0000);
    poll_cnt = 0;
    reg_read(2'b00);
    while (!sr_val[5] && poll_cnt < 5000) begin
      #1000;
      reg_read(2'b00);
      poll_cnt = poll_cnt + 1;
    end
    reg_read(2'b00);
    if      (poll_cnt >= 5000) $display("TIMEOUT (sr=0x%02x)", sr_val);
    else if (sr_val[6])        $display("FAIL (ack_err)");
    else if (slave_rx_byte !== 8'h00)
                               $display("FAIL (data=0x%02x)", slave_rx_byte);
    else                       $display("PASS");

    // ----------------------------------------------------------------
    // Test 7 — Write byte 0xFF (boundary: all ones on SDA)
    // ----------------------------------------------------------------
    $write("T7: Write 0xFF to 0x50 ... ");
    reg_write(2'b01, {SLAVE_ADDR, 1'b0});
    reg_write(2'b10, 8'hFF);
    reg_write(2'b00, 8'b1110_0000);
    poll_cnt = 0;
    reg_read(2'b00);
    while (!sr_val[5] && poll_cnt < 5000) begin
      #1000;
      reg_read(2'b00);
      poll_cnt = poll_cnt + 1;
    end
    reg_read(2'b00);
    if      (poll_cnt >= 5000) $display("TIMEOUT (sr=0x%02x)", sr_val);
    else if (sr_val[6])        $display("FAIL (ack_err)");
    else if (slave_rx_byte !== 8'hFF)
                               $display("FAIL (data=0x%02x)", slave_rx_byte);
    else                       $display("PASS");

    // ----------------------------------------------------------------
    // Test 8 — Back-to-back transactions
    // ----------------------------------------------------------------
    $write("T8: Back-to-back transactions ... ");
    reg_write(2'b01, {SLAVE_ADDR, 1'b0});
    reg_write(2'b10, 8'h11);
    reg_write(2'b00, 8'b1110_0000);
    poll_cnt = 0;
    reg_read(2'b00);
    while (!sr_val[5] && poll_cnt < 5000) begin
      #1000;
      reg_read(2'b00);
      poll_cnt = poll_cnt + 1;
    end
    if (poll_cnt >= 5000) begin $display("T8a TIMEOUT"); end else begin
      reg_write(2'b10, 8'h22);
      reg_write(2'b00, 8'b1110_0000);
      poll_cnt = 0;
      reg_read(2'b00);
      while (!sr_val[5] && poll_cnt < 5000) begin
        #1000;
        reg_read(2'b00);
        poll_cnt = poll_cnt + 1;
      end
      reg_read(2'b00);
      if      (poll_cnt >= 5000) $display("T8b TIMEOUT (sr=0x%02x)", sr_val);
      else if (sr_val[6])        $display("FAIL (ack_err)");
      else if (slave_rx_byte !== 8'h22)
                                 $display("FAIL (data=0x%02x)", slave_rx_byte);
      else                       $display("PASS");
    end

    // ----------------------------------------------------------------
    // Test 9 — CR write while busy (busy guard)
    // ----------------------------------------------------------------
    $write("T9: CR write while busy ... ");
    reg_write(2'b01, {SLAVE_ADDR, 1'b0});
    reg_write(2'b10, 8'h77);
    reg_write(2'b00, 8'b1110_0000);
    #6000;
    reg_write(2'b00, 8'b0000_0000);  // bogus CR — should be blocked
    poll_cnt = 0;
    reg_read(2'b00);
    while (!sr_val[5] && poll_cnt < 5000) begin
      #1000;
      reg_read(2'b00);
      poll_cnt = poll_cnt + 1;
    end
    reg_read(2'b00);
    if      (poll_cnt >= 5000) $display("TIMEOUT (sr=0x%02x)", sr_val);
    else if (sr_val[6])        $display("FAIL (ack_err)");
    else if (slave_rx_byte !== 8'h77)
                               $display("FAIL (data=0x%02x)", slave_rx_byte);
    else                       $display("PASS (data=0x%02x)", slave_rx_byte);

    // ----------------------------------------------------------------
    // Test 10 — Read with different slave data (0x3C)
    // ----------------------------------------------------------------
    $write("T10: Read modified slave data ... ");
    slave_tx_data <= 8'h3C;
    #100;
    reg_write(2'b01, {SLAVE_ADDR, 1'b0});
    reg_write(2'b00, 8'b1101_0000);
    poll_cnt = 0;
    reg_read(2'b00);
    while (!sr_val[5] && poll_cnt < 5000) begin
      #1000;
      reg_read(2'b00);
      poll_cnt = poll_cnt + 1;
    end
    if (poll_cnt >= 5000) begin $display("TIMEOUT"); end else begin
      reg_read(2'b10);
      if (dr_val === 8'h3C) $display("PASS (0x%02x)", dr_val);
      else                  $display("FAIL (got 0x%02x)", dr_val);
    end

    // ----------------------------------------------------------------
    $display("=== All tests done ===");
    $finish;
  end

endmodule

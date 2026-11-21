/*UART register_interface test bench (self-checking, directed)
  Bus is driven on the falling edge; read data is sampled 5 ns later,
  i.e. just before the rising edge that will act on it.                 */
`timescale 1ns/1ps
module tb_register_interface;
/*stimulus driven to DUT inputs*/
  reg         en,
              clk,
              rst,
              tx_en,
              u_done,
              wr_rdb,
              drv;                        /*1 = testbench drives the data bus*/
  reg  [7:0]  adds;
  reg  [31:0] data1;

/*DUT outputs*/
  wire [31:0] data,
              dout;
  wire        pen,
              pph;
  wire [1:0]  ben;

/*bookkeeping*/
  reg  [31:0] rd;
  integer     errors,
              checks;

/*data bus: driven by the testbench only during a write*/
  assign data = drv ? data1 : 32'dz;

/*---------------------register interface DUT instantiation-------------------*/
  register_interface rg0 (.clk(clk), .rst(rst), .en(en), .tx_en(tx_en),
                          .wr_rdb(wr_rdb), .u_done(u_done), .adds(adds),
                          .data(data), .dout(dout), .pen(pen), .pph(pph), .ben(ben));

/*clock generation 50mhz*/
  initial clk = 1'b0;
  always #10 clk = ~clk;

/* dump variables into 'vcd' file*/
  initial begin
    $dumpfile("reg_interface.vcd");
    $dumpvars(0, tb_register_interface);
  end

/*--------------------------- tasks ---------------------------*/
  task check;
    input [8*32-1:0] name;
    input [31:0]     got;
    input [31:0]     expected;
    begin
      checks = checks + 1;
      if(got !== expected) begin
        errors = errors + 1;
        $display("%0t ERROR %0s: got=%h expected=%h", $time, name, got, expected);
      end
    end
  endtask

  task bus_idle;
    begin en = 1'b0; drv = 1'b0; wr_rdb = 1'b0; end
  endtask

/*one write cycle (call on a falling edge, returns on the next one)*/
  task bus_write;
    input [7:0]  a;
    input [31:0] d;
    begin
      en = 1'b1; wr_rdb = 1'b1; adds = a; data1 = d; drv = 1'b1;
      @(negedge clk);
      bus_idle;
    end
  endtask

/*one read cycle; result in rd*/
  task bus_read;
    input [7:0] a;
    begin
      en = 1'b1; wr_rdb = 1'b0; adds = a; drv = 1'b0;
      #5 rd = data;
      @(negedge clk);
      bus_idle;
    end
  endtask

/*one-clock u_done pulse*/
  task pulse_done;
    begin
      u_done = 1'b1;
      @(negedge clk);
      u_done = 1'b0;
    end
  endtask

/*-------------------------- test sequence --------------------------*/
  initial begin
    errors = 0; checks = 0;
    rst = 1'b1; tx_en = 1'b1; u_done = 1'b0; adds = 8'd0; data1 = 32'd0;
    bus_idle;
    repeat(2) @(negedge clk);

    /*1. reset values*/
    check("reset dout", dout, 32'd0);
    check("reset pen",  pen,  1'b0);
    check("reset pph",  pph,  1'b0);
    check("reset ben",  ben,  2'd0);
    rst = 1'b0;
    @(negedge clk);
    bus_read(8'd0); check("TDR after reset", rd, 32'd0);
    bus_read(8'd1); check("TCR after reset", rd, 32'd0);

    /*2. TDR write / read back*/
    bus_write(8'd0, 32'hDEADBEEF);
    check("dout after TDR write", dout, 32'hDEADBEEF);
    bus_read(8'd0); check("TDR read back", rd, 32'hDEADBEEF);

    /*3. TCR write: only [3:0] are stored, start bit [4] is set*/
    bus_write(8'd1, 32'hFFFFFFF5);
    check("pen",  pen, 1'b0);
    check("pph",  pph, 1'b1);
    check("ben",  ben, 2'b01);
    check("dout unchanged by TCR write", dout, 32'hDEADBEEF);
    bus_read(8'd1); check("TCR read back (tx_en=1)", rd, 32'h00000015);
    bus_write(8'd1, 32'h0000000F);
    check("pen all ones", pen, 1'b1);
    check("pph all ones", pph, 1'b1);
    check("ben all ones", ben, 2'b11);
    bus_read(8'd1); check("TCR read back 0F", rd, 32'h0000001F);

    /*4. tx_en low clears the start bit*/
    tx_en = 1'b0;
    @(negedge clk);
    bus_read(8'd1); check("start bit cleared", rd, 32'h0000000F);
    tx_en = 1'b1;

    /*5. done flag: set by u_done, cleared by a TCR read*/
    pulse_done;
    bus_read(8'd1); check("done set",      rd, 32'h0000002F);
    bus_read(8'd1); check("done cleared",  rd, 32'h0000000F);

    /*6. reading the TDR must not clear done*/
    pulse_done;
    bus_read(8'd0);
    bus_read(8'd1); check("done kept after TDR read", rd, 32'h0000002F);
    bus_read(8'd1); check("done cleared again",       rd, 32'h0000000F);

    /*7. u_done in the same clock as a TCR read: set wins*/
    en = 1'b1; wr_rdb = 1'b0; adds = 8'd1; u_done = 1'b1;
    @(negedge clk);
    bus_idle; u_done = 1'b0;
    bus_read(8'd1); check("set wins over clear", rd, 32'h0000002F);
    bus_read(8'd1);

    /*8. write on the same clock tx_en is low: write (set) wins for one clock*/
    tx_en = 1'b0;
    bus_write(8'd1, 32'h00000003);
    bus_read(8'd1); check("start set despite tx_en low", rd, 32'h00000013);
    bus_read(8'd1); check("start cleared one clock later", rd, 32'h00000003);
    tx_en = 1'b1;

    /*9. unmapped address: write ignored, read returns 0*/
    bus_write(8'd5, 32'hFFFFFFFF);
    check("dout unchanged after unmapped write", dout, 32'hDEADBEEF);
    check("ben unchanged after unmapped write",  ben,  2'b11);
    bus_read(8'd5); check("unmapped read", rd, 32'd0);

    /*10. write with en=0 is ignored*/
    en = 1'b0; wr_rdb = 1'b1; adds = 8'd0; data1 = 32'h12345678; drv = 1'b1;
    @(negedge clk);
    bus_idle;
    check("write ignored when en=0", dout, 32'hDEADBEEF);

    /*11. bus released (high-z) when not reading*/
    #1;
    check("bus is z when idle", {31'd0, (data === 32'dz)}, 32'd1);

    /*12. reset clears everything*/
    rst = 1'b1;
    @(negedge clk);
    rst = 1'b0;
    check("dout after reset", dout, 32'd0);
    check("pen after reset",  pen,  1'b0);
    check("pph after reset",  pph,  1'b0);
    check("ben after reset",  ben,  2'd0);
    bus_read(8'd1); check("TCR after second reset", rd, 32'd0);

    $display("--------------------------------------------------");
    $display("REGIF: %0d checks, %0d errors", checks, errors);
    if(errors == 0) $display("REGIF RESULT: PASSED");
    else            $display("REGIF RESULT: FAILED");
    $display("--------------------------------------------------");
    $finish;
  end

/*watchdog*/
  initial begin
    #100000;
    $display("TIMEOUT");
    $finish;
  end
endmodule

/*UART Top level Test Bench with Score Board Implementation
  compile order: see sim/run.do (no `include needed)                         */
`timescale 1ns/1ps
module tb_top_uart();
  wire          en,
                 p,
                wr,
               txd,
               pen,
               pph,
               clk,
               rst,
              read,
         frame_err,
              done,
               eot;
  wire [7:0]   din;
  wire [8:0]  temp;

/*---stimulus generator---*/
  stimgen_uart s0 (.p(p), .en(en), .wr(wr), .pen(pen), .pph(pph),
                   .clk(clk), .rst(rst), .eot(eot), .din(din), .done(done));

/*---------------UART transmitter DUT---------------*/
  dut_uart_transmitter u0 (.en(en), .pen(pen), .p(p), .pph(pph),
                           .clk(clk), .rst(rst), .din(din),
                           .txd(txd), .done(done));

/*-------Receiver model-------*/
  tb_uart_rx_model rx0 (.txd(txd), .pen(pen), .pph(pph),
                         .clk(clk), .rst(rst), .temp(temp), .read(read),
                         .frame_err(frame_err));

/*----UART score board---*/
  uart_score_board sb0 (.clk(clk), .rst(rst), .wr(wr), .read(read),
                        .frame_err(frame_err), .pen(pen), .pph(pph), .eot(eot),
                        .din(din), .temp(temp));

/*watchdog*/
  initial begin
    #2000000;
    $display("TIMEOUT: end of test was never reached");
    $finish;
  end

/* dump variables into 'vcd' file*/
  initial begin
    $dumpfile("uart.vcd");
    $dumpvars(0, tb_top_uart);
  end
endmodule

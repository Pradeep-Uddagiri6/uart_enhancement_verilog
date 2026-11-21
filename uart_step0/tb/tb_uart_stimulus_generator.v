/*--UART Stimulus Generator--
  Drives one word at a time (din/pen/pph/p + a one-clock wr strobe).
  Words are sent back to back: the next word is applied while the previous
  frame is in its stop-bit cycle (done=1), which is when the TX re-captures.
  Two clocks after a word is captured, the inputs are scrambled.
  All stimulus is driven on the falling clock edge.                        */
`timescale 1ns/1ps
module stimgen_uart(
  output reg         p,
                     en,
                     wr,
                     pen,
                     pph,
                     clk,
                     rst,
                     eot,                 /*end of test*/
  output reg [7:0]   din,

  input              done
);

/*internal declarations*/
  reg         a,
              b,
              first;                      /*1 = TX is idle, next word starts a new frame*/
  reg  [31:0] r;
  integer     seed,
              i;

/*clock generation 50mhz*/
  initial clk = 1'b0;
  always #10 clk = ~clk;

/*drive one word; call on a falling edge*/
  task send_word;
    input [7:0] d;
    input       pe;
    input       ph;
    begin
      if(first) begin
        en    = 1'b1;
        first = 1'b0;
      end
      else begin
        @(posedge done);                  /*previous frame is in its stop bit*/
        @(negedge clk);
      end
      din = d;  pen = pe;  pph = ph;
      a = ^d;  b = a ^ ph;  p = ~b;       /*parity bit: pph=1 even, pph=0 odd*/
      wr  = 1'b1;
      @(negedge clk);
      wr  = 1'b0;
      /*the frame has been captured by now: scramble the inputs so any logic
        that reads them live, instead of its latched copy, is caught*/
      @(negedge clk);
      din = ~d;  pen = ~pe;  pph = ~ph;  p = ~p;
    end
  endtask

/*return the transmitter to idle and wait a few clocks*/
  task go_idle;
    begin
      @(posedge done);
      @(negedge clk);
      en    = 1'b0;
      first = 1'b1;
      repeat(6) @(negedge clk);
    end
  endtask

/*---test sequence---*/
  initial begin
    rst = 1'b1;  en = 1'b0;  wr = 1'b0;  eot = 1'b0;
    pen = 1'b0;  pph = 1'b0; din = 8'd0; p = 1'b0;
    first = 1'b1;
    seed  = 32'h0000_1234;               /*fixed seed: reproducible run*/

    repeat(3) @(negedge clk);
    rst = 1'b0;
    @(negedge clk);

    /*directed: every pen/pph combination on 00, FF, A5, 5A (back to back)*/
    for(i=0; i<16; i=i+1) begin
      case(i/4)
        0: send_word(8'h00, i[1], i[0]);
        1: send_word(8'hFF, i[1], i[0]);
        2: send_word(8'hA5, i[1], i[0]);
        3: send_word(8'h5A, i[1], i[0]);
      endcase
    end

    /*walking one, parity on and off*/
    for(i=0; i<8; i=i+1) send_word(8'h01 << i, 1'b1, i[0]);
    for(i=0; i<8; i=i+1) send_word(8'h01 << i, 1'b0, i[0]);

    /*return to idle, then restart from the idle state*/
    go_idle;
    send_word(8'hC3, 1'b1, 1'b0);
    send_word(8'h3C, 1'b0, 1'b1);
    go_idle;

    /*random words, back to back*/
    for(i=0; i<40; i=i+1) begin
      r = $random(seed);
      send_word(r[7:0], r[8], r[9]);
    end

    go_idle;
    repeat(5) @(negedge clk);
    eot = 1'b1;
    #100 $finish;
  end
endmodule

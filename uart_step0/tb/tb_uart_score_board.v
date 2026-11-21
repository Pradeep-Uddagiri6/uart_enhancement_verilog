/*----UART Scoreboard----
  Every word the stimulus generator sends (wr strobe) is pushed into an
  expected-data queue. Every frame the receiver model delivers (read pulse)
  is popped and compared:  data bits always, parity bit when pen=1.
  A frame_err pulse from the receiver model (bad stop bit) counts as a failure.
  Expected parity is computed here from din/pph, independent of the DUT.    */
`timescale 1ns/1ps
module uart_score_board(
  input        clk,
               rst,
               wr,
               read,
               frame_err,
               pen,
               pph,
               eot,
  input [7:0]  din,
  input [8:0]  temp                       /*{data[7:0], parity bit}*/
);

/*internal signals declaration*/
  reg [9:0] exp_q [0:255];                /*{din, pen, pph}*/
  reg [7:0] wptr, rptr;                   /*8-bit pointers wrap on their own*/
  integer   sent, received, pass_cnt, fail_cnt;
  reg [9:0] e;
  reg [7:0] e_din;
  reg       e_pen, e_pph, e_par, ok;

  initial begin
    wptr = 0; rptr = 0;
    sent = 0; received = 0; pass_cnt = 0; fail_cnt = 0;
  end

/*-----------push expected / pop and compare received-----------*/
  always @(posedge clk) begin
    if(rst) begin
      wptr = 0; rptr = 0;
    end
    else begin
      if(wr) begin
        exp_q[wptr] = {din, pen, pph};
        wptr = wptr + 1;
        sent = sent + 1;
      end

      if(frame_err) begin
        fail_cnt = fail_cnt + 1;
        $display("%0t SB ERROR: framing error (stop bit is not 1)", $time);
      end

      if(read) begin
        received = received + 1;
        if(rptr == wptr) begin
          fail_cnt = fail_cnt + 1;
          $display("%0t SB ERROR: frame received with nothing expected, temp=%h", $time, temp);
        end
        else begin
          e     = exp_q[rptr];
          rptr  = rptr + 1;
          e_din = e[9:2];  e_pen = e[1];  e_pph = e[0];
          e_par = ~((^e_din) ^ e_pph);
          ok    = (temp[8:1] === e_din);
          if(e_pen) ok = ok && (temp[0] === e_par);
          if(ok) begin
            pass_cnt = pass_cnt + 1;
            $display("%0t SB OK   : din=%h pen=%b pph=%b  rx data=%h parity=%b", $time, e_din, e_pen, e_pph, temp[8:1], temp[0]);
          end
          else begin
            fail_cnt = fail_cnt + 1;
            $display("%0t SB ERROR: expected din=%h pen=%b par=%b, got data=%h parity=%b", $time, e_din, e_pen, e_par, temp[8:1], temp[0]);
          end
        end
      end
    end
  end

/*-----------end of test summary-----------*/
  always @(posedge eot) begin
    if(rptr != wptr) begin
      fail_cnt = fail_cnt + 1;
      $display("%0t SB ERROR: %0d word(s) sent but never received", $time, sent - received);
    end
    $display("--------------------------------------------------");
    $display("SCOREBOARD: sent=%0d received=%0d pass=%0d fail=%0d", sent, received, pass_cnt, fail_cnt);
    if(fail_cnt == 0 && pass_cnt == sent && sent != 0) $display("SCOREBOARD RESULT: PASSED");
    else                                               $display("SCOREBOARD RESULT: FAILED");
    $display("--------------------------------------------------");
  end
endmodule

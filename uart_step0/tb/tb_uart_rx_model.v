/*-----------UART Receiver Model - testbench component------------*/
`timescale 1ns/1ps
module tb_uart_rx_model(
/*input control signals*/ input        txd,
                                       pen,
/*input status signals*/               pph,
/*global signals*/                     clk,
                                       rst,

/*output data port*/      output reg [8:0] temp,     /*{data[7:0], parity bit}*/
/*output status signals*/ output reg       read,     /*one-clock pulse: frame received*/
                          output reg       frame_err /*one-clock pulse: stop bit was not 1*/
);

/*parameters declaration*/
  parameter s0 =4'b0000,
            s1 =4'b0001,
            s2 =4'b0010,
            s3 =4'b0011,
            s4 =4'b0100,
            s5 =4'b0101,
            s6 =4'b0110,
            s7 =4'b0111,
            s8 =4'b1000,
            s9 =4'b1001,
            s10=4'b1010;

/*internal signals declaration*/
  reg [3:0] present_state,
               next_state;
  reg       pen_l;                       /*pen captured at the start bit*/

/*--------next state logic--------*/
  always @(*) begin
    case(present_state)
      s0 :if(txd==1'b0) next_state=s1; else next_state=s0;
      s1 :next_state=s2;
      s2 :next_state=s3;
      s3 :next_state=s4;
      s4 :next_state=s5;
      s5 :next_state=s6;
      s6 :next_state=s7;
      s7 :next_state=s8;
      s8 :if(pen_l==1'b1) next_state=s9; else next_state=s10;
      s9 :next_state=s10;
      s10:next_state=s0;
      default: next_state=s0;
    endcase
  end

/*------state register------*/
  always @(posedge clk) begin
    if(rst) present_state <= s0;
    else    present_state <= next_state;
  end

/*----------------------output-----------------------*/
  always @(posedge clk) begin
    if(rst) begin
      temp      <= 9'd0;
      read      <= 1'b0;
      frame_err <= 1'b0;
      pen_l     <= 1'b0;
    end
    else begin
      frame_err <= 1'b0;                     /*default; s10 may override*/
      case(present_state)
        s0 :if(txd==1'b0) pen_l <= pen;
        s1 :temp[1] <= txd;
        s2 :temp[2] <= txd;
        s3 :temp[3] <= txd;
        s4 :temp[4] <= txd;
        s5 :temp[5] <= txd;
        s6 :temp[6] <= txd;
        s7 :temp[7] <= txd;
        s8 :begin
              temp[8] <= txd;
              if(pen_l==1'b0) begin temp[0] <= 1'b0; read <= 1'b1; end
            end
        s9 :begin temp[0] <= txd; read <= 1'b1; end
        s10:begin
              read <= 1'b0;
              if(txd !== 1'b1) frame_err <= 1'b1;   /*stop bit check*/
            end
        default: ;
      endcase
    end
  end
endmodule

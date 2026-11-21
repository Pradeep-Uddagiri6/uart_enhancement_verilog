/*------DUT UART transmitter------*/
`timescale 1ns/1ps
module dut_uart_transmitter (
/*control signals*/ input        en,
                                 pen,

/*status signals*/               p,
                                 pph,

/*global signals*/               clk,
                                 rst,

/*data*/            input [7:0]  din,

/*serial output*/   output reg   txd,

/*status signals*/  output reg   done
);

/*parameter declaration*/
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
            s10=4'b1010,
            s11=4'b1011;

/*---internal signals---*/
  reg [3:0] present_state,
               next_state;

/*frame registers: inputs are captured once, at the start of every frame*/
  reg [7:0] din_l;
  reg       pen_l,
            p_l;

/*-----------------next state / output logic (combinational)-----------------*/
  always @(*) begin
    txd        = 1'b1;
    done       = 1'b0;
    next_state = s0;
    case(present_state)
      s0 :begin txd=1'b1;        next_state = en ? s1 : s0; end          /*idle*/
      s1 :begin txd=1'b0;        next_state = s2;  end                   /*start bit*/
      s2 :begin txd=din_l[0];    next_state = s3;  end
      s3 :begin txd=din_l[1];    next_state = s4;  end
      s4 :begin txd=din_l[2];    next_state = s5;  end
      s5 :begin txd=din_l[3];    next_state = s6;  end
      s6 :begin txd=din_l[4];    next_state = s7;  end
      s7 :begin txd=din_l[5];    next_state = s8;  end
      s8 :begin txd=din_l[6];    next_state = s9;  end
      s9 :begin txd=din_l[7];    next_state = pen_l ? s10 : s11; end
      s10:begin txd=p_l;         next_state = s11; end                   /*parity bit*/
      s11:begin txd=1'b1; done=1'b1; next_state = en ? s1 : s0; end      /*stop bit, frame done*/
      default: next_state = s0;
    endcase
  end

/*----state register and frame capture----*/
  always @(posedge clk) begin
    if(rst) begin
      present_state <= s0;
      din_l         <= 8'd0;
      pen_l         <= 1'b0;
      p_l           <= 1'b0;
    end
    else begin
      present_state <= next_state;
      /*the frame starts on the clock edge that moves the FSM into s1*/
      if((present_state==s0 || present_state==s11) && en) begin
        din_l <= din;
        pen_l <= pen;
        p_l   <= p;
      end
    end
  end
endmodule

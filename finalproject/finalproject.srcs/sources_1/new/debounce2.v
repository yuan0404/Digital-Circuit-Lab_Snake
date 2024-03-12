`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: Chun-Jen Tsai
// 
// Create Date:    09:43:16 10/20/2015 
// Design Name: 
// Module Name:    debounce
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module debounce2(input clk, input sw_input, output sw_output);

parameter DEBOUNCE_PERIOD = 2_000_000; /* 20 msec = (100,000,000*0.2) ticks @100MHz */

reg [$clog2(DEBOUNCE_PERIOD):0] counter;

assign sw_output = (counter == DEBOUNCE_PERIOD);

always@(posedge clk) begin
  if (sw_input == 0)
    counter <= 0;
  else
    counter <= counter + (counter != DEBOUNCE_PERIOD);
end

endmodule
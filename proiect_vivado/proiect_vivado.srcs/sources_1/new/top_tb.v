`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/08/2026 01:59:57 PM
// Design Name: 
// Module Name: top_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module tb_top(

);
    reg clk;
    reg res;

    top DUT(
        .clk(clk),
        .res(res)
    );
    
    initial begin
        clk = 0; res = 0;
        #10 res = 1;
        #10 res = 0;
        #260 $finish;
    end

    always #5 clk = ~clk;

endmodule

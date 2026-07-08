`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/04/2026 04:21:50 PM
// Design Name: 
// Module Name: top
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


module top(
    input clk,
    input res
    );
    
    wire ALUSrcB;       //EXECUTE
	wire [1:0] ALUOp;   //EXECUTE
	wire MemRead;   //MEM ACCES
	wire MemWrite;  //MEM ACCES
	wire Branch;    //MEM ACCES
	wire RegWrite;   //WRITE BACK
	wire MemtoReg;   //WRITE BACK
	
	wire [6:0] op_code;
	wire [2:0] fun3;
	wire fun7;
	
	data_path DP(
	    clk,
        res,
    
        ALUSrcB,       //EXECUTE
        ALUOp,   //EXECUTE
        MemRead,   //MEM ACCES
        MemWrite,  //MEM ACCES
        Branch,    //MEM ACCES
        RegWrite,   //WRITE BACK
        MemtoReg,   //WRITE BACK
        
        op_code,
        fun3,
        fun7
	);
	
	control_path CP(
         clk,
         res,
        
        ALUSrcB,       //EXECUTE
        ALUOp,   //EXECUTE
        MemRead,   //MEM ACCES
        MemWrite,  //MEM ACCES
        Branch,    //MEM ACCES
        RegWrite,   //WRITE BACK
        MemtoReg,   //WRITE BACK
        
        op_code,
        fun3
	);
	
endmodule

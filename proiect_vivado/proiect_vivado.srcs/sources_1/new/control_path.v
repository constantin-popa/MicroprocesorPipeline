`timescale 1ns / 1ps

module control_path(
	input clk,
	input res,

	output ALUSrcB,       //EXECUTE
	output [1:0] ALUOp,   //EXECUTE
	output MemRead,   //MEM ACCES
	output MemWrite,  //MEM ACCES
	output Branch,    //MEM ACCES
	output RegWrite,   //WRITE BACK
	output MemtoReg,   //WRITE BACK

	//  output PCSource --> BRANCH and ALUZero, nu necesita un semnal aparte	
	
	input [6:0] op_code,
	input [2:0] fun3,
	input ControlSelect
    );
       
    reg [7:0] control;
    
    assign { ALUSrcB, ALUOp, MemRead, MemWrite,Branch, RegWrite,MemtoReg} = control; 

    always@(*) begin
        if(ControlSelect == 0) begin
            control = 8'b0;
        end else
            casex({op_code, fun3}) //ALUSrcB, ALUOp, MemRead, MemWrite,Branch, RegWrite, MemtoReg
                10'b0000011_010 : control = 8'b1_00_1_0_0_1_1;   //lw
                10'b0100011_010 : control = 8'b1_00_0_1_0_0_x;   //sw
                10'b0110011_xxx : control = 8'b0_10_0_0_0_1_0;   //R type instructions
                10'b1100011_000 : control = 8'b0_01_0_0_1_0_x;   //beq
                10'b0010011_xxx : control = 8'b1_11_0_0_0_1_0;   //I type instructions
                
                default: control = 8'bx;
            endcase
    end
    
endmodule
    
`timescale 1ns / 1ps

module data_path(
    input clk,
    input res,
    
	input ALUSrcB,       //EXECUTE
	input [1:0] ALUOp,   //EXECUTE
	input MemRead,   //MEM ACCES
	input MemWrite,  //MEM ACCES
	input Branch,    //MEM ACCES
	input RegWrite,   //WRITE BACK
	input MemtoReg,   //WRITE BACK
	
	output [6:0] op_code,
	output [2:0] fun3
);

reg [31:0] IR;
reg [31:0] PC;
reg [31:0] imm32;
//memoria procesorului (1024 de cuvite de 8 biti)
reg [7:0] mem [0:1023];
// registrii procesorului (x0 - x31)
reg [31:0] regs [0:31];
wire [31:0] addr_mem;
//data din registrul A
wire [31:0] da;
//data din registrul B
wire [31:0] db; 

//rezultat pc + imm
wire sum;
//iesiri alu
wire Zero;  //activa in cazul in care o operatie are ca rezultat 0
reg [31:0] alu; //rezultatul efectiv al operatiei executate de alu

reg [31:0] MDR; //datele citite din memoria de date

reg [63:0] IF_ID;   //intre InstructionFetch si InstructionDecode se transmit PC ( pentru un branch eventual) si instructiunea din memorie de la adresa PC

reg [128:0] ID_EX;    //intre InstructionDecode si Execution se transmite PC, datele din registrii sursa si valoarea imediata
reg [96:0] EX_MEM;   //intre Execution si Memory acces se transmit sum, iesirea Zero a Alu si rezultatul operatiei din Alu si registrul sursa 2

reg [128:0] MEM_WB;   //intre Memory si WriteBack se transmit rezultatul lui alu si data ce s a citit din memorie


//stabileste op_code 
assign op_code = IR[6:0];
//stabileste fun3
assign fun3 = IR[14:12];

//extragere valoare imediata in functie de opcode
always@(IR) begin
	case(IR[6:0])
        7'b0000011,
        7'b0001111,
        7'b0011011,
        7'b1100111,
        7'b1110011,
        7'b0010011: imm32 = { {20{IR[31]}}, IR[31:20]};
        7'b0100011: imm32 = { {20{IR[31]}}, IR[31:25], IR[11:7]};
        7'b1100011: imm32 = { {20{IR[31]}}, IR[7], IR[30:25], IR[11:8], 1'b0};            
        7'b1101111: imm32 = { {12{IR[31]}}, IR[19:12], IR[20], IR[30:25], IR[11:8], 1'b0};            
        7'b0010111,
        7'b0110111: imm32 = { IR[31:12], {12{1'b0}}}; 
        default:
            imm32 = 32'h0000_0000;
	endcase
end

//IR 
always@(posedge clk) begin
	casex({res, IRWrite})
		2'b1_x : IR <= 0;
		2'b0_1 : begin  // daca reset este inactiv si IRWrite este activ
			IR[31:24] 	<= mem[addr_mem+3];
			IR[23:16] 	<= mem[addr_mem+2];
			IR[15:8] 	<= mem[addr_mem+1];
			IR[7:0] 	<= mem[addr_mem];
			end
	endcase
end

// IF_ID
//intre InstructionFetch si InstructionDecode se transmit PC ( pentru un branch eventual) si instructiunea din memorie de la adresa PC
always @(posedge clk) begin
    IF_ID = {PC, IR};
end

//registrul sursa 1
wire [4:0] ra = IR[19:15];
assign da = regs[ra];       //valoarea din registrul sursa 1
//registrul sursa 2
wire [4:0] rb = IR[24:20]; 
assign db = regs[rb];       // valoarea din registrul sursa 2
wire [4:0] rd;
//registrul destinatie
assign rd = IR[11:7];

// ID_EX
//intre InstructionDecode si Execution se transmite PC ( pentru un branch eventual),  datele din registrii sursa si valoarea imediata ( pentru operatiile din Execute )
always @(posedge clk) begin
    ID_EX = {IF_ID[63:32] /* PC */ , da, db, imm32};
end

//Activ pe 1 daca alu == 0
assign Zero = (alu == 0) ? 1 : 0;

//Sumator care calculeaza adresa de salt pentru brench
assign sum = PC + imm32;

//EX_MEM
//intre Execution si Memory acces se transmit PC (calculat cu val imediata in caz de brench), iesirea Zero a Alu si rezultatul operatiei din Alu si registrul sursa 2 ( pentru sw)
always @(posedge clk) begin
    EX_MEM = {sum, Zero, alu, ID_EX[63:32] /*rs2*/};
end

//valoarea extrasa din memoria de date in etapa de memory acces
always@(posedge clk) begin
	MDR[31:24] 	<= mem[addr_mem+3];
	MDR[23:16] 	<= mem[addr_mem+2];
	MDR[15:8] 	<= mem[addr_mem+1];
	MDR[7:0] 	<= mem[addr_mem];	
end

//MEM_WB
always @(posedge clk) begin
    MEM_WB = {MDR, EX_MEM[63:32] /* alu */ };
end
endmodule

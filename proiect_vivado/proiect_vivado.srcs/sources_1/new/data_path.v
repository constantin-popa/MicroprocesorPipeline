`timescale 1ns / 1ps

`define BITI_CONTROL 8

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
	output [2:0] fun3,
	output fun7
);

wire [7:0] control;
    
assign control = { ALUSrcB, ALUOp, MemRead, MemWrite,Branch, RegWrite,MemtoReg}; 


wire [31:0] IR;
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
wire [31:0] PCSum;
//iesiri alu
wire Zero;  //activa in cazul in care o operatie are ca rezultat 0
reg [31:0] alu; //rezultatul efectiv al operatiei executate de alu

wire [31:0] MDR; //datele citite din memoria de date

reg [63:0] IF_ID;   //intre InstructionFetch si InstructionDecode se transmit PC ( pentru un branch eventual) si instructiunea din memorie de la adresa PC
                    
reg [154:0] ID_EX;    //intre InstructionDecode si Execution se transmite PC, datele din registrii sursa si valoarea imediata
                       //+ toate semnalele de control + fun3 + 1bit din fun7
reg [106:0] EX_MEM;   //intre Execution si Memory acces se transmit sum, iesirea Zero a Alu si rezultatul operatiei din Alu si registrul sursa 2
                       //+ semnalele de control pentru mem si wb
reg [70:0] MEM_WB;   //intre Memory si WriteBack se transmit rezultatul lui alu si data ce s a citit din memorie
                       //+ semnalele de control pentru wb
reg [1:0] ForwardA;
reg [1:0] ForwardB;
wire [31:0] wb_data;
//stabileste op_code 
assign op_code = IF_ID[6:0];
//stabileste fun3
assign fun3 = IF_ID[14:12];
//stabileste fun7
assign fun7 = IF_ID[31:25];

//extragere valoare imediata in functie de opcode
always@(IF_ID[31:0]) begin
	case(IF_ID[6:0])
        7'b0000011,
        7'b0001111,
        7'b0011011,
        7'b1100111,
        7'b1110011,
        7'b0010011: imm32 = { {20{IF_ID[31]}}, IF_ID[31:20]};
        7'b0100011: imm32 = { {20{IF_ID[31]}}, IF_ID[31:25], IF_ID[11:7]};
        7'b1100011: imm32 = { {20{IF_ID[31]}}, IF_ID[7], IF_ID[30:25], IF_ID[11:8], 1'b0};            
        7'b1101111: imm32 = { {12{IF_ID[31]}}, IF_ID[19:12], IF_ID[20], IF_ID[30:25], IF_ID[11:8], 1'b0};            
        7'b0010111,
        7'b0110111: imm32 = { IF_ID[31:12], {12{1'b0}}}; 
        default:
            imm32 = 32'h0000_0000;
	endcase
end

//Sumator care calculeaza adresa de salt pentru brench
assign PCSum = ID_EX[127:96] + imm32;  //PC-ul corespunzator instructiunii curente 

//logica PC
always@(posedge clk) begin
    if( res == 1 ) begin
        PC <= 0;
    end else
    //in loc de branch si Zero, ne uitam la bitul din EX_MEM corespunzator
    if( EX_MEM[64] /*Zero*/ & EX_MEM[99] /*branch*/ ) begin   //conditia echivalenta cu PCSrc
        PC <= EX_MEM[96:65];
    end
    else begin
        PC <= PC + 4;
    end
end

//IR 
assign IR = {
    mem[PC+3],
    mem[PC+2],
    mem[PC+1], 
    mem[PC]
};


// IF_ID
//intre InstructionFetch si InstructionDecode se transmit PC ( pentru un branch eventual) si instructiunea din memorie de la adresa PC
always @(posedge clk) begin
    if(res)
        IF_ID <= 63'b0;
    else
    IF_ID <= {
/*63:32*/       PC,
/*31:0*/        IR
    };
end

//registrul sursa 1
wire [4:0] ra = IF_ID[19:15];
assign da = (ra == 5'b0) ? 32'b0 :  //registrul 0
            ((MEM_WB[65] && (MEM_WB[70:66] == ra)) ?  
            wb_data : //valoarea care se scrie in acest moment 
            regs[ra] );//valoarea din registrul sursa 1

//registrul sursa 2
wire [4:0] rb = IF_ID[24:20]; 
assign db = (rb == 5'b0) ? 32'b0 :  //registrul 0
            ((MEM_WB[65] && (MEM_WB[70:66] == rb)) ?
            wb_data :   //valoarea care se scrie in acest moment 
            regs[rb] );       // valoarea din registrul sursa 2
wire [4:0] rd;
//registrul destinatie
assign rd = IF_ID[11:7];

// ID_EX
//intre InstructionDecode si Execution se transmite PC ( pentru un branch eventual),  datele din registrii sursa si valoarea imediata ( pentru operatiile din Execute )
//toate semnalele de control
always @(posedge clk) begin
    if(res)
        ID_EX <= 154'b0;
    else
    ID_EX <= {
/*154:150*/    IF_ID[19:15],  //rs1
/*149:145*/    IF_ID[24:20],  //rs2
/*144:140*/    IF_ID[11:7],   // registrul de scrierere  -> folosit pt wb si forwarding
/*139*/        IF_ID[30],     //al 2lea MSB din fun7 care influenteaza operatiile in alu
/*138:136*/    IF_ID[14:12],  //fun3
/*135:128*/    control,   //ALUSrcB, ALUOp, MemRead, MemWrite,Branch, RegWrite,MemtoReg
/*127:96*/     IF_ID[63:32],  /* PC */ 
/*95:64*/      da,
/*63:32*/      db,
/*31:0*/       imm32};
end

//Activ pe 1 daca alu == 0
assign Zero = (alu == 0) ? 1 : 0;

//alu
wire [31:0] a = (ForwardA == 2'b00) ? ID_EX[95:64]: //valoarea din registri
            ((ForwardA == 2'b10) ? EX_MEM[63:32] :  //[forward] valoarea de la alu
            wb_data) ; //[forward] valoarea de la date sau un alu anterior


//(ID_EX[135] == 0) ? ID_EX[63:32] /*db*/ : ID_EX[31:0]; /*imm32*/
wire [31:0] b = (ForwardB == 2'b00) ?  ((ID_EX[135] == 0) ? ID_EX[63:32] /*db*/ : ID_EX[31:0]) :
            ((ForwardB == 2'b10) ? EX_MEM[63:32] :  //[forward] valoarea de la alu
            wb_data) ; //[forward] valoarea de la date sau un alu anterior


always@(*) begin
    casex({ID_EX[134:133], ID_EX[139:136]})
        6'b00_x_xxx : alu = a + b;  //lw si sw
        6'b01_x_xxx : alu = a - b;  //brench
        
        6'b10_0_000 : alu = a + b;  //R type
        6'b10_1_000 : alu = a - b;
        6'b10_0_111 : alu = a & b;
        6'b10_0_110 : alu = a | b;
        
        6'b11_x_000 : alu = a + b;
        6'b11_x_111 : alu = a & b;
        6'b11_x_110 : alu = a | b;
   
        default:
            alu = 32'b0;
	endcase

end

always@(*) begin
    //hazarduri de EX
    ForwardA = 2'b00;
    ForwardB = 2'b00;
    if ( EX_MEM[98] & 
         (EX_MEM[106:102] != 5'b0) &
         (EX_MEM[106:102] == ID_EX[154:150])  //EX_MEM rd = ID_EX rs1
        ) begin
        ForwardA = 2'b10;
    end
    if ( EX_MEM[98] & 
         (EX_MEM[106:102] != 5'b0) &
         (EX_MEM[106:102] == ID_EX[149:145]) // EX_MEM rd = ID_EX rs2
        ) begin
        ForwardB = 2'b10;
    end
    //hazarduri de MEM
    if ( MEM_WB[65] & 
         (MEM_WB[70:66] != 5'b0) &
         ~(EX_MEM[98] & (EX_MEM[106:102] != 0) & (EX_MEM[106:102] == ID_EX[154:150]) ) &
         (MEM_WB[70:66] == ID_EX[154:150]) // MEM_WB rd = ID_EX rs1
        ) begin
        ForwardA = 2'b01;
    end
    
    if ( MEM_WB[65] & 
         (MEM_WB[70:66] != 5'b0) &
         ~(EX_MEM[98] & (EX_MEM[106:102] != 0) & (EX_MEM[106:102] == ID_EX[149:145]) ) &
         (MEM_WB[70:66] == ID_EX[149:145]) // MEM_WB rd = ID_EX rs2
        ) begin
        ForwardB = 2'b01;
    end
    
end

//EX_MEM
//intre Execution si Memory acces se transmit PC (calculat cu val imediata in caz de brench), iesirea Zero a Alu si rezultatul operatiei din Alu si registrul sursa 2 ( pentru sw)
//semnalele de control pentru mem si wb
always @(posedge clk) begin
    if(res)
        EX_MEM <= 106'b0;
    else
    EX_MEM <= {
/*106:102*/  ID_EX[144:140], //registrul de scriere
/*101:97*/   ID_EX[132:128], /*MemRead, MemWrite,Branch, RegWrite,MemtoReg*/ 
/*96:65*/    PCSum,
/*64*/       Zero,
/*63:32*/    alu,
/*31:0*/     ID_EX[63:32] // db            
    };
end

//MEM_WB
//intre Memory si WriteBack se transmit rezultatul lui alu si data ce s a citit din memorie
// semnalele de control pentru wb
always @(posedge clk) begin
    if(res)
        MEM_WB <= 70'b0;
    else
    MEM_WB <= {
/*70:66*/       EX_MEM[106:102], //registru de scriere
/*65:64*/       EX_MEM[98:97],   //RegWrite,MemtoReg
/*63:32*/       mem[EX_MEM[63:32]+3],
                mem[EX_MEM[63:32]+2],
                mem[EX_MEM[63:32]+1],
                mem[EX_MEM[63:32]],
/*31:0*/        EX_MEM[63:32] /* alu */ 
    };
end

//Scriere in memorie : MemWrite
always@(posedge clk) begin
    if( /*MemWrite*/ EX_MEM[100] == 1) begin
        mem[EX_MEM[63:32]+3]	<= EX_MEM[31:24];
		mem[EX_MEM[63:32]+2] <= EX_MEM[23:16];
		mem[EX_MEM[63:32]+1] <= EX_MEM[15:8];
		mem[EX_MEM[63:32]+0] <= EX_MEM[7:0];	
    end
end

//valoarea extrasa din memoria de date in etapa de memory acces
//Citire din memorie
//always@(posedge clk) begin
////    if(res == 1) begin
////        MDR <= 32'b0;
////    end else 
//    if(/*MemRead*/ EX_MEM[101] == 1) begin
//        MDR[31:24] 	= mem[EX_MEM[63:32]+3];
//        MDR[23:16] 	= mem[EX_MEM[63:32]+2];
//        MDR[15:8] 	= mem[EX_MEM[63:32]+1];
//        MDR[7:0] 	= mem[EX_MEM[63:32]];	
//    end
//end


assign wb_data = ( MEM_WB[64] == 1) ? MEM_WB[63:32] : MEM_WB[31:0];
//Scrierea in registru
always@(posedge clk) begin 
	if (res == 1) begin
		regs[0] <= 0; regs[1] <= 0; regs[2] <= 0; regs[3] <= 0; regs[4] <= 0; regs[5] <= 0;
		regs[6] <= 0; regs[7] <= 0; regs[8] <= 0; regs[9] <= 0; regs[10] <= 0; regs[11] <= 0;
		regs[12] <= 0; regs[13] <= 0; regs[14] <= 0; regs[15] <= 0; regs[16] <= 0; regs[17] <= 0;
		regs[18] <= 0; regs[19] <= 0; regs[20] <= 0; regs[21] <= 0; regs[22] <= 0; regs[23] <= 0;
		regs[24] <= 0; regs[25] <= 0; regs[26] <= 0; regs[27] <= 0; regs[28] <= 0; regs[29] <= 0;
		regs[30] <= 0; regs[31] <= 0;
		
	end else if ( MEM_WB[65] == 1) //daca destinatia este 0, se sare peste scriere
		regs[ MEM_WB[70:66] ] <= wb_data; 
       //regs[rd] <=  (MemToReg == 1) ? MDR : AluOut;
end

integer i;
reg [31:0] temp_mem [0:512];  // Adjust depth as needed
initial begin
	$readmemh("mem.mem", temp_mem);
    `define TEXT_OFFSET 0
    `define TEXT_WORDS 64
    `define DATA_OFFSET 256
    `define DATA_WORDS (1024-`DATA_OFFSET)
    for (i = 0; i < `TEXT_WORDS; i = i + 1) begin
      mem[i*4 + 3+`TEXT_OFFSET] = temp_mem[i+`TEXT_OFFSET][31:24];
      mem[i*4 + 2+`TEXT_OFFSET] = temp_mem[i+`TEXT_OFFSET][23:16];
      mem[i*4 + 1+`TEXT_OFFSET] = temp_mem[i+`TEXT_OFFSET][15:8];
      mem[i*4 + 0+`TEXT_OFFSET] = temp_mem[i+`TEXT_OFFSET][7:0];
    end
    for (i = 0; i < `DATA_WORDS; i = i + 1) begin
      mem[i*4 + 3+`DATA_OFFSET] = temp_mem[i+`DATA_OFFSET][31:24];
      mem[i*4 + 2+`DATA_OFFSET] = temp_mem[i+`DATA_OFFSET][23:16];
      mem[i*4 + 1+`DATA_OFFSET] = temp_mem[i+`DATA_OFFSET][15:8];
      mem[i*4 + 0+`DATA_OFFSET] = temp_mem[i+`DATA_OFFSET][7:0];
    end
end

endmodule





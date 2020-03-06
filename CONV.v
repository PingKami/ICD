
`timescale 1ns/10ps

module  CONV(clk,reset,busy,ready,iaddr,idata,cwr,caddr_wr,cdata_wr,crd,caddr_rd,cdata_rd,csel);
//basic
input clk;
input reset;
output reg busy;
input ready;
//read input image
output reg [11:0] iaddr;
input signed [19:0] idata;
//write data to temporary memory
output reg cwr;
output reg [11:0] caddr_wr;
output reg signed [19:0] cdata_wr;
//read data from temporary memory
output reg crd;
output reg [11:0] caddr_rd;
input signed [19:0] cdata_rd;
//determine which temporary memory to read or write
output reg [2:0] csel;
//constants
parameter [3:0] INITIAL=0, READ_L0=1, L0_W0=2, L0_W1=3, L0_R0=4, L0_R1=5, L1_W0=6, L1_W1=7, L1_R0=8, L1_R1=9, FLATTEN=10, L2_W=11;
parameter [0:359] KERNAL_0={40'sh000000A89E, 40'sh00000092D5, 40'sh0000006D43, 40'sh0000001004, 40'shFFFFFF8F71, 40'shFFFFFF6E54, 40'shFFFFFFA6D7, 40'shFFFFFFC834, 40'shFFFFFFAC19};
parameter [0:359] KERNAL_1={40'shFFFFFFDB55, 40'sh0000002992, 40'shFFFFFFC994, 40'sh00000050FD, 40'sh0000002F20, 40'sh000000202D, 40'sh0000003BD7, 40'shFFFFFFD369, 40'sh0000005E68};
parameter integer shift=16;
parameter [2:0] NONE=3'b000, L0_MEM0=3'b001, L0_MEM1=3'b010, L1_MEM0=3'b011, L1_MEM1=3'b100, L2_MEM=3'b101;
parameter signed [39:0] BIAS_0=40'sh0000001310, BIAS_1=40'shFFFFFF7295;
//internal variables
reg[3:0] Q_NOW, Q_NEXT;
reg signed [19:0] buffer[0:191];
reg done, column_counter_buf;
reg signed [39:0] conv_temp;
reg signed [39:0] debug[0:9];
reg [6:0] row_counter;
reg [5:0] column_counter;
//FSM
always@(posedge clk)begin
    if(reset)begin
        Q_NOW <= INITIAL;
    end
    else begin
        Q_NOW <= Q_NEXT;
    end
end
always@(*)begin
end
//state transition logic
always@(*)begin
    if(reset) Q_NEXT = INITIAL;
    else begin
        case(Q_NOW)
	    INITIAL:begin
		if(ready) Q_NEXT = READ_L0;
		else Q_NEXT = INITIAL;
	    end
	    READ_L0:begin
		if(column_counter==63) Q_NEXT = L0_W0;
		else Q_NEXT = READ_L0;
	    end
	    L0_W0:begin
		if(column_counter==63) Q_NEXT = L0_W1;
		else Q_NEXT = L0_W0;
	    end
	    L0_W1:begin
		if(done) Q_NEXT = L0_R0;
		else if(column_counter==63) Q_NEXT = READ_L0;
		else Q_NEXT = L0_W1;
	    end
	    L0_R0:begin
		if(column_counter==63&&row_counter[0]==1) Q_NEXT = L1_W0;
		else Q_NEXT = L0_R0;
	    end
	    L1_W0:begin
		if(done) Q_NEXT = L0_R1;
		else if(column_counter==62) Q_NEXT = L0_R0;
		else Q_NEXT = L1_W0;
	    end
	    L0_R1:begin
		if(column_counter==63&&row_counter[0]==1) Q_NEXT = L1_W1;
		else Q_NEXT = L0_R1;
	    end
	    L1_W1:begin
		if(done) Q_NEXT = L1_R0;
		else if(column_counter==62) Q_NEXT =L0_R1;
		else Q_NEXT = L1_W1;
	    end
	    L1_R0:begin
		if(column_counter==63) Q_NEXT = L1_R1;
		else Q_NEXT = L1_R0;
	    end
	    L1_R1:begin
		if(column_counter==63) Q_NEXT = L2_W;
		else Q_NEXT = L1_R1;
	    end
	    L2_W:begin
		if(done) Q_NEXT = INITIAL;
		else if(column_counter==63&&column_counter_buf) Q_NEXT = L1_R0;
		else Q_NEXT = L2_W;
	    end
	    default: Q_NEXT = INITIAL;
	endcase
    end
end
//done
always@(posedge clk)begin
    if(done==1) done <= 0;
    else begin
	case(Q_NOW)
	    L0_W1:begin
		if(column_counter==62&&row_counter==65) done <= 1;
		else done <= 0;
	    end
	    L1_W0:begin
		if(column_counter==60&&row_counter==63) done <= 1;
		else done <= 0;
	    end
	    L1_W1:begin
		if(column_counter==60&&row_counter==63) done <= 1;
		else done <= 0;
	    end
	    L2_W:begin
		if(column_counter==63&&row_counter==15&&(!column_counter_buf)) done <= 1;
		else done <= 0;
	    end
	    default: done <= 0;
	endcase
    end
end
//busy output logic
always@(posedge clk)begin
    if(reset) busy <= 0;
    else if(ready) busy <= 1;
    else if(Q_NOW==INITIAL) busy <= 0;
    else busy <= busy;
end
//row_counter
always@(posedge clk)begin
    if(Q_NOW==READ_L0||Q_NOW==L0_W0||Q_NOW==L0_W1)begin
	if(reset||done) row_counter <= 0;
	else if(row_counter==65) row_counter <= row_counter;
	else if(column_counter==63&&Q_NEXT==READ_L0) row_counter <= row_counter+1;
	else row_counter <= row_counter;
    end
    else if(Q_NOW==L0_R0||Q_NOW==L0_R1)begin
	if(reset||done) row_counter <= 0;
	else if(row_counter==63) row_counter <= row_counter;
	else if(column_counter==63&&(Q_NEXT==L0_R0||Q_NEXT==L0_R1)) row_counter <= row_counter+1;
	else row_counter <= row_counter;
    end
    else if(Q_NOW==L1_W0||Q_NOW==L1_W1)begin
	if(reset||done) row_counter <= 0;
	else if(column_counter==62) row_counter <= row_counter+1;
	else row_counter <= row_counter;
    end
    else if(Q_NOW==L2_W)begin
	if(reset||done) row_counter <= 0;
	else if(row_counter==15) row_counter <= row_counter;
	else if(column_counter==63&&Q_NEXT==L1_R0) row_counter <= row_counter+1;
	else row_counter <= row_counter;
    end
    else begin
	if(reset) row_counter <= 0;
	else row_counter <= row_counter;
    end
end
//column_counter
always@(posedge clk)begin
    if(Q_NOW==READ_L0||Q_NOW==L0_W0||Q_NOW==L0_W1)begin
	if(reset||done) column_counter <= 0;
	else if(column_counter==63) column_counter <= 0;
	else column_counter <= column_counter+1;
    end
    else if(Q_NOW==L0_R0||Q_NOW==L0_R1)begin
	if(reset||done) column_counter <= 0;
	else if(column_counter==63) column_counter <= 0;
	else column_counter <= column_counter+1;
    end
    else if(Q_NOW==L1_W0||Q_NOW==L1_W1)begin
	if(reset||done) column_counter <= 0;
	else if(column_counter==62) column_counter <= 0;
	else column_counter <= column_counter+2;
    end
    else if(Q_NOW==L1_R0||Q_NOW==L1_R1)begin
	if(reset||done) column_counter <= 0;
	else if(column_counter==63) column_counter <= 0;
	else column_counter <= column_counter+1;
    end
    else if(Q_NOW==L2_W)begin
	if(reset||done)begin
	    column_counter <= 0;
	    column_counter_buf <= 0;
	end
	else begin
	    column_counter_buf <= ~column_counter_buf;
	    if(column_counter_buf)begin
		column_counter <= (column_counter==63)?0:column_counter+1;
	    end
	    else column_counter <= column_counter;
	end
    end
    else begin
	if(reset)begin
	    column_counter <= 0;
	    column_counter_buf <= 0;
	end
	else begin
	    column_counter <= column_counter;
	    column_counter_buf <= column_counter_buf;
	end
    end
end
//iaddr output logic
always@(*)begin
    if(reset) iaddr = 0;
    else if(Q_NOW==READ_L0&&row_counter>0&&row_counter<65)begin
	iaddr = (row_counter-1)*64+column_counter;
    end
    else iaddr = 0;
end
//csel output logic
always@(*)begin
    case(Q_NOW)
	L0_W0: csel=L0_MEM0;
	L0_W1: csel=L0_MEM1;
	L0_R0: csel=L0_MEM0;
	L0_R1: csel=L0_MEM1;
	L1_W0: csel=L1_MEM0;
	L1_W1: csel=L1_MEM1;
	L1_R0: csel=L1_MEM0;
	L1_R1: csel=L1_MEM1;
	L2_W: csel=L2_MEM;
	default: csel=NONE;
    endcase
end
//cwr output logic
always@(*)begin
    case(Q_NOW)
	L0_W0: cwr=1;
	L0_W1: cwr=1;
	L1_W0: cwr=1;
	L1_W1: cwr=1;
	L2_W: cwr=1;
	default: cwr=0;
    endcase
end
//crd output logic
always@(*)begin
    case(Q_NOW)
	L0_R0: crd=1;
	L0_R1: crd=1;
	L1_R0: crd=1;
	L1_R1: crd=1;
	default: crd=0;
    endcase
end
//buffer(READ_L0, L0_R0, L0_R1, L1_R0, L1_R1)
always@(posedge clk)begin
    case(Q_NOW)
	READ_L0:begin
	    if(row_counter==0||row_counter==65)begin
		buffer[column_counter+128] <= 0;
		buffer[column_counter+64] <= buffer[column_counter+128];
		buffer[column_counter] <= buffer[column_counter+64];
	    end
	    else begin
		buffer[column_counter+128] <= idata;
		buffer[column_counter+64] <= buffer[column_counter+128];
		buffer[column_counter] <= buffer[column_counter+64];
	    end
	end
	L0_R0:begin
	    if(row_counter[0]==0)begin
		buffer[column_counter] <= cdata_rd;
	    end
	    else begin
		buffer[column_counter+64] <= cdata_rd;
	    end
	end
	L0_R1:begin
	    if(row_counter[0]==0)begin
		buffer[column_counter] <= cdata_rd;
	    end
	    else begin
		buffer[column_counter+64] <= cdata_rd;
	    end
	end
	L1_R0: buffer[column_counter] <= cdata_rd;
	L1_R1: buffer[column_counter+64] <= cdata_rd;
	default: buffer[0] <= buffer[0];
    endcase
end
//caddr_rd
always@(*)begin
    if(reset) caddr_rd = 0;
    else begin
	case(Q_NOW)
	    L0_R0: caddr_rd = row_counter*64+column_counter;
	    L0_R1: caddr_rd = row_counter*64+column_counter;
	    L1_R0: caddr_rd = row_counter*64+column_counter;
	    L1_R1: caddr_rd = row_counter*64+column_counter;
	    default: caddr_rd = 0;
	endcase
    end
end
//caddr_wr
always@(*)begin
    if(reset) caddr_wr = 0;
    else begin
	case(Q_NOW)
	    L0_W0:begin
		if(row_counter>=2) caddr_wr = (row_counter-2)*64+column_counter;
		else caddr_wr = 0;
	    end
	    L0_W1:begin
		if(row_counter>=2) caddr_wr = (row_counter-2)*64+column_counter;
		else caddr_wr = 0;
	    end
	    L1_W0: caddr_wr = (row_counter>>1)*32+(column_counter>>1);
	    L1_W1: caddr_wr = (row_counter>>1)*32+(column_counter>>1);
	    L2_W: caddr_wr = row_counter*128+column_counter+column_counter_buf*64;
	    default: caddr_wr = 0;
	endcase
    end
end
//cdata_wr & conv_temp & max_pooling_temp(auxiliary variable)
always@(*)begin
    case(Q_NOW)
	L0_W0:begin
	    if(column_counter!=0&&column_counter!=63)begin
		debug[0] = $signed(KERNAL_0[0:39])*{{20{buffer[column_counter-1][19]}},buffer[column_counter-1]};
		debug[1] = $signed(KERNAL_0[40:79])*{{20{buffer[column_counter][19]}},buffer[column_counter]};
		debug[2] = $signed(KERNAL_0[80:119])*{{20{buffer[column_counter+1][19]}},buffer[column_counter+1]};
		debug[3] = $signed(KERNAL_0[120:159])*{{20{buffer[column_counter+63][19]}},buffer[column_counter+63]};
		debug[4] = $signed(KERNAL_0[160:199])*{{20{buffer[column_counter+64][19]}},buffer[column_counter+64]};
		debug[5] = $signed(KERNAL_0[200:239])*{{20{buffer[column_counter+65][19]}},buffer[column_counter+65]};
		debug[6] = $signed(KERNAL_0[240:279])*{{20{buffer[column_counter+127][19]}},buffer[column_counter+127]};
		debug[7] = $signed(KERNAL_0[280:319])*{{20{buffer[column_counter+128][19]}},buffer[column_counter+128]};
		debug[8] = $signed(KERNAL_0[320:359])*{{20{buffer[column_counter+129][19]}},buffer[column_counter+129]};
		debug[9] = debug[0]+debug[1]+debug[2]+debug[3]+debug[4]+debug[5]+debug[6]+debug[7]+debug[8];
		conv_temp = (debug[9][15]==1)?((debug[9]>>>shift)+40'sh0000000001+BIAS_0):((debug[9]>>>shift)+BIAS_0);
		cdata_wr = (conv_temp>=0)?conv_temp[19:0]:20'sh00000;
	    end
	    else if(column_counter==0)begin
		debug[1] = $signed(KERNAL_0[40:79])*{{20{buffer[column_counter][19]}},buffer[column_counter]};
		debug[2] = $signed(KERNAL_0[80:119])*{{20{buffer[column_counter+1][19]}},buffer[column_counter+1]};
		debug[4] = $signed(KERNAL_0[160:199])*{{20{buffer[column_counter+64][19]}},buffer[column_counter+64]};
		debug[5] = $signed(KERNAL_0[200:239])*{{20{buffer[column_counter+65][19]}},buffer[column_counter+65]};
		debug[7] = $signed(KERNAL_0[280:319])*{{20{buffer[column_counter+128][19]}},buffer[column_counter+128]};
		debug[8] = $signed(KERNAL_0[320:359])*{{20{buffer[column_counter+129][19]}},buffer[column_counter+129]};
		debug[9] = debug[1]+debug[2]+debug[4]+debug[5]+debug[7]+debug[8];
		conv_temp = (debug[9][15]==1)?((debug[9]>>>shift)+40'sh0000000001+BIAS_0):((debug[9]>>>shift)+BIAS_0);
		cdata_wr = (conv_temp>=0)?conv_temp[19:0]:20'sh00000;
	    end
	    else begin
		debug[0] = $signed(KERNAL_0[0:39])*{{20{buffer[column_counter-1][19]}},buffer[column_counter-1]};
		debug[1] = $signed(KERNAL_0[40:79])*{{20{buffer[column_counter][19]}},buffer[column_counter]};
		debug[3] = $signed(KERNAL_0[120:159])*{{20{buffer[column_counter+63][19]}},buffer[column_counter+63]};
		debug[4] = $signed(KERNAL_0[160:199])*{{20{buffer[column_counter+64][19]}},buffer[column_counter+64]};
		debug[6] = $signed(KERNAL_0[240:279])*{{20{buffer[column_counter+127][19]}},buffer[column_counter+127]};
		debug[7] = $signed(KERNAL_0[280:319])*{{20{buffer[column_counter+128][19]}},buffer[column_counter+128]};
		debug[9] = debug[0]+debug[1]+debug[3]+debug[4]+debug[6]+debug[7];
		conv_temp = (debug[9][15]==1)?((debug[9]>>>shift)+40'sh0000000001+BIAS_0):((debug[9]>>>shift)+BIAS_0);
		cdata_wr = (conv_temp>=0)?conv_temp[19:0]:20'sh00000;
	    end
	end
	L0_W1:begin
	    if(column_counter!=0&&column_counter!=63)begin
		debug[0] = $signed(KERNAL_1[0:39])*{{20{buffer[column_counter-1][19]}},buffer[column_counter-1]};
		debug[1] = $signed(KERNAL_1[40:79])*{{20{buffer[column_counter][19]}},buffer[column_counter]};
		debug[2] = $signed(KERNAL_1[80:119])*{{20{buffer[column_counter+1][19]}},buffer[column_counter+1]};
		debug[3] = $signed(KERNAL_1[120:159])*{{20{buffer[column_counter+63][19]}},buffer[column_counter+63]};
		debug[4] = $signed(KERNAL_1[160:199])*{{20{buffer[column_counter+64][19]}},buffer[column_counter+64]};
		debug[5] = $signed(KERNAL_1[200:239])*{{20{buffer[column_counter+65][19]}},buffer[column_counter+65]};
		debug[6] = $signed(KERNAL_1[240:279])*{{20{buffer[column_counter+127][19]}},buffer[column_counter+127]};
		debug[7] = $signed(KERNAL_1[280:319])*{{20{buffer[column_counter+128][19]}},buffer[column_counter+128]};
		debug[8] = $signed(KERNAL_1[320:359])*{{20{buffer[column_counter+129][19]}},buffer[column_counter+129]};
		debug[9] = debug[0]+debug[1]+debug[2]+debug[3]+debug[4]+debug[5]+debug[6]+debug[7]+debug[8];
		conv_temp = (debug[9][15]==1)?((debug[9]>>>shift)+40'sh0000000001+BIAS_1):((debug[9]>>>shift)+BIAS_1);
		cdata_wr = (conv_temp>=0)?conv_temp[19:0]:20'sh00000;
	    end
	    else if(column_counter==0)begin
		debug[1] = $signed(KERNAL_1[40:79])*{{20{buffer[column_counter][19]}},buffer[column_counter]};
		debug[2] = $signed(KERNAL_1[80:119])*{{20{buffer[column_counter+1][19]}},buffer[column_counter+1]};
		debug[4] = $signed(KERNAL_1[160:199])*{{20{buffer[column_counter+64][19]}},buffer[column_counter+64]};
		debug[5] = $signed(KERNAL_1[200:239])*{{20{buffer[column_counter+65][19]}},buffer[column_counter+65]};
		debug[7] = $signed(KERNAL_1[280:319])*{{20{buffer[column_counter+128][19]}},buffer[column_counter+128]};
		debug[8] = $signed(KERNAL_1[320:359])*{{20{buffer[column_counter+129][19]}},buffer[column_counter+129]};
		debug[9] = debug[1]+debug[2]+debug[4]+debug[5]+debug[7]+debug[8];
		conv_temp = (debug[9][15]==1)?((debug[9]>>>shift)+40'sh0000000001+BIAS_1):((debug[9]>>>shift)+BIAS_1);
		cdata_wr = (conv_temp>=0)?conv_temp[19:0]:20'sh00000;
	    end
	    else begin
		debug[0] = $signed(KERNAL_1[0:39])*{{20{buffer[column_counter-1][19]}},buffer[column_counter-1]};
		debug[1] = $signed(KERNAL_1[40:79])*{{20{buffer[column_counter][19]}},buffer[column_counter]};
		debug[3] = $signed(KERNAL_1[120:159])*{{20{buffer[column_counter+63][19]}},buffer[column_counter+63]};
		debug[4] = $signed(KERNAL_1[160:199])*{{20{buffer[column_counter+64][19]}},buffer[column_counter+64]};
		debug[6] = $signed(KERNAL_1[240:279])*{{20{buffer[column_counter+127][19]}},buffer[column_counter+127]};
		debug[7] = $signed(KERNAL_1[280:319])*{{20{buffer[column_counter+128][19]}},buffer[column_counter+128]};
		debug[9] = debug[0]+debug[1]+debug[3]+debug[4]+debug[6]+debug[7];
		conv_temp = (debug[9][15]==1)?((debug[9]>>>shift)+40'sh0000000001+BIAS_1):((debug[9]>>>shift)+BIAS_1);
		cdata_wr = (conv_temp>=0)?conv_temp[19:0]:20'sh00000;
	    end
	end
	L1_W0:begin
	    if((buffer[column_counter]>=buffer[column_counter+1])&&(buffer[column_counter]>=buffer[column_counter+64])&&(buffer[column_counter]>=buffer[column_counter+65]))begin
		cdata_wr = buffer[column_counter];
	    end
	    else if((buffer[column_counter+1]>=buffer[column_counter+64])&&(buffer[column_counter+1]>=buffer[column_counter+65]))begin
		cdata_wr = buffer[column_counter+1];
	    end
	    else if(buffer[column_counter+64]>=buffer[column_counter+65])begin
		cdata_wr = buffer[column_counter+64];
	    end
	    else begin
		cdata_wr = buffer[column_counter+65];
	    end
	end
	L1_W1:begin
	    if((buffer[column_counter]>=buffer[column_counter+1])&&(buffer[column_counter]>=buffer[column_counter+64])&&(buffer[column_counter]>=buffer[column_counter+65]))begin
		cdata_wr = buffer[column_counter];
	    end
	    else if((buffer[column_counter+1]>=buffer[column_counter+64])&&(buffer[column_counter+1]>=buffer[column_counter+65]))begin
		cdata_wr = buffer[column_counter+1];
	    end
	    else if(buffer[column_counter+64]>=buffer[column_counter+65])begin
		cdata_wr = buffer[column_counter+64];
	    end
	    else begin
		cdata_wr = buffer[column_counter+65];
	    end
	end
	L2_W:begin
	    if(column_counter[0]==0)begin
		cdata_wr = buffer[(column_counter>>1)+32*column_counter_buf];
	    end
	    else cdata_wr = buffer[(column_counter>>1)+32*column_counter_buf+64];
	end
	default: cdata_wr = 0;
    endcase
end
//cdata_wr & conv_temp & max_pooling_temp(auxiliary variable)

endmodule






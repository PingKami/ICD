module LCD_CTRL(clk, reset, IROM_Q, cmd, cmd_valid, IROM_EN, IROM_A, IRB_RW, IRB_D, IRB_A, busy, done);
input clk;
input reset;
input [7:0] IROM_Q;
input [2:0] cmd;
input cmd_valid;
output reg IROM_EN;
output reg [5:0] IROM_A;
output reg IRB_RW;
output reg [7:0] IRB_D;
output reg [5:0] IRB_A;
output reg busy;
output reg done;
//define FSM
//total 12 state
//initial read commend indle&0~7 done
//internal variables
parameter [3:0] INITIAL=0, CMD_IDLE=1, CMD_WRITE=2, CMD_SHIFT_UP=3, CMD_SHIFT_DOWN=4, CMD_SHIFT_LEFT=5, CMD_SHIFT_RIGHT=6, CMD_AVERAGE=7, CMD_MIRROR_X=8, CMD_MIRROR_Y=9, READ=10, DONE=11;
reg [3:0] Q_NOW=INITIAL, Q_NEXT;
reg dummy;
reg cmd_done=0;
reg write_begin=0;
reg [8:0] counter=0;
reg [7:0] buffer[0:63];
wire [9:0] average_temp;
reg [3:0] operation_point_x=4, operation_point_y=4;

//initialize
initial begin
IROM_EN = 1;
IROM_A = 0;
IRB_RW = 1;
busy = 1;
done = 0;
end
//reset&state transition
always@(posedge clk)begin
    if(reset)begin
        Q_NOW <= INITIAL;
        //busy <= 1;
        //IROM_A <= 0;
    end
    else begin
        Q_NOW <= Q_NEXT;
    end
end
//state transition logic
always@(*)begin
    case(Q_NOW)
        INITIAL:begin
            if(!reset)begin
                Q_NEXT=READ;
            end
            else begin
                Q_NEXT=INITIAL;
            end
        end
        READ:begin
            if(cmd_done) begin
                Q_NEXT=CMD_IDLE;
            end
            else begin
                Q_NEXT=READ;
            end
        end
        CMD_IDLE:begin
            if(cmd_valid)begin
            case(cmd)
                0:
                    Q_NEXT=CMD_WRITE;
                1:
                    Q_NEXT=CMD_SHIFT_UP;
                2:
                    Q_NEXT=CMD_SHIFT_DOWN;
                3:
                    Q_NEXT=CMD_SHIFT_LEFT;
                4:
                    Q_NEXT=CMD_SHIFT_RIGHT;
                5:
                    Q_NEXT=CMD_AVERAGE;
                6:
                    Q_NEXT=CMD_MIRROR_X;
                7:
                    Q_NEXT=CMD_MIRROR_Y;
                default:
                    Q_NEXT=CMD_IDLE;
            endcase
            end
            else begin
                Q_NEXT=CMD_IDLE;
            end
        end
        CMD_WRITE:begin
            if(cmd_done) begin
                Q_NEXT=DONE;
            end
            else begin
                Q_NEXT=CMD_WRITE;
            end
        end
        CMD_SHIFT_UP:begin
            if(cmd_done) begin
                Q_NEXT=CMD_IDLE;
            end
            else begin
                Q_NEXT=CMD_SHIFT_UP;
            end
        end
        CMD_SHIFT_DOWN:begin
            if(cmd_done) Q_NEXT=CMD_IDLE;
            else Q_NEXT=CMD_SHIFT_DOWN;
        end
        CMD_SHIFT_LEFT:begin
            if(cmd_done) Q_NEXT=CMD_IDLE;
            else Q_NEXT=CMD_SHIFT_LEFT;
        end
        CMD_SHIFT_RIGHT:begin
            if(cmd_done) Q_NEXT=CMD_IDLE;
            else Q_NEXT=CMD_SHIFT_RIGHT;
        end
        CMD_AVERAGE:begin
            if(cmd_done) Q_NEXT=CMD_IDLE;
            else Q_NEXT=CMD_AVERAGE;
        end
        CMD_MIRROR_X:begin
            if(cmd_done) Q_NEXT=CMD_IDLE;
            else Q_NEXT=CMD_MIRROR_X;
        end
        CMD_MIRROR_Y:begin
            if(cmd_done) Q_NEXT=CMD_IDLE;
            else Q_NEXT=CMD_MIRROR_Y;
        end
        DONE:begin
            Q_NEXT=DONE;
        end
        default:begin
            Q_NEXT=Q_NOW;
        end
    endcase
end
always@(*)begin
    case(Q_NOW)
        INITIAL:
            busy=1;
        READ:
            busy=1;
        CMD_IDLE:
            busy=0;
        CMD_SHIFT_UP:
            busy=1;
        CMD_SHIFT_DOWN:
            busy=1;
        CMD_SHIFT_LEFT:
            busy=1;
        CMD_SHIFT_RIGHT:
            busy=1;
        CMD_AVERAGE:
            busy=1;
        CMD_MIRROR_X:
            busy=1;
        CMD_MIRROR_Y:
            busy=1;
        CMD_WRITE:
            busy=1;
        DONE:
            busy=0;
        default:
            busy=1;
endcase
end
//always@(negedge clk)begin
    //if(Q_NOW==CMD_IDLE) cmd_done <= 0;
    //else cmd_done <= cmd_done;
//end
always@(*)begin
    if(Q_NOW==DONE) done=1;
    else done=0;
end
//internal variables and output controller
always@(posedge clk)begin
    if(Q_NOW==READ)begin
    IROM_A <= (IROM_A==63)?IROM_A:IROM_A+1;
    end
    else IROM_A <= 0;
end
always@(posedge clk)begin
    if(Q_NOW==CMD_WRITE) IRB_A <= (IRB_A==63)?IRB_A:IRB_A+1;
    else IRB_A <= 0;
end
always@(*)begin
    if(Q_NOW==CMD_WRITE) write_begin=1;
    else write_begin=0;
end
always@(posedge clk)begin
    if(Q_NOW==READ)begin
        counter <= (counter==64)?counter:counter+1;
    end
    else counter <= 0;
end
//auxiliary temp value for CMD_AVERAGE
assign average_temp = (buffer[(operation_point_y-1)*8+operation_point_x-1]+buffer[(operation_point_y-1)*8+operation_point_x]+buffer[operation_point_y*8+operation_point_x-1]+buffer[operation_point_y*8+operation_point_x])/4;
//sequential part
always@(posedge clk)begin
case(Q_NOW)
    CMD_IDLE:begin
        cmd_done <= 0;
    end
    READ:begin
        if(IROM_A==63)begin
            cmd_done <= 1;
        end
        else begin
            dummy <= 0;
        end
    end
    CMD_WRITE:begin
        if(IRB_A==62)begin
        cmd_done <= 1;
        end
        else dummy <= 0;
    end
    CMD_SHIFT_UP:begin
        if(!cmd_done) operation_point_y <= (operation_point_y==1)?1:operation_point_y-1;
        else operation_point_y <= operation_point_y;
        cmd_done <= 1;
    end
    CMD_SHIFT_DOWN:begin
        if(!cmd_done) operation_point_y <= (operation_point_y==7)?7:operation_point_y+1;
        else operation_point_y <= operation_point_y;
        cmd_done <= 1;
    end
    CMD_SHIFT_LEFT:begin
        if(!cmd_done) operation_point_x <= (operation_point_x==1)?1:operation_point_x-1;
        else operation_point_y <= operation_point_y;
        cmd_done <= 1;
    end
    CMD_SHIFT_RIGHT:begin
        if(!cmd_done) operation_point_x <= (operation_point_x==7)?7:operation_point_x+1;
        else operation_point_y <= operation_point_y;
        cmd_done <= 1;
    end
    CMD_AVERAGE:begin
        cmd_done <= 1;
    end
    CMD_MIRROR_X:begin
        cmd_done <= 1;
    end
    CMD_MIRROR_Y:begin
        cmd_done <= 1;
    end
    //default(just in case)
    default:begin
        dummy <= 0;
    end
endcase
end
//combinational part
always@(*)begin
    if(Q_NOW==READ) IROM_EN = 0;
    else IROM_EN = 1;
end
always@(*)begin
    if(Q_NOW==CMD_WRITE) IRB_RW = 0;
    else IRB_RW = 1;
end
always@(negedge clk)begin
    if(Q_NOW==CMD_WRITE)begin
        if(IRB_A>=0) IRB_D <= buffer[IRB_A];
        else IRB_D <= 0;
    end
    else IRB_D <= 0;
end
always@(posedge clk)begin
case(Q_NOW)
    READ:begin
        if(!cmd_done&&IROM_A>0) buffer[IROM_A-1] <= IROM_Q;
        else if(cmd_done) buffer[63] <= IROM_Q;
        else buffer[0] <= IROM_Q;
    end
    CMD_AVERAGE:begin
        buffer[(operation_point_y-1)*8+operation_point_x-1] <= average_temp;
        buffer[(operation_point_y-1)*8+operation_point_x] <= average_temp;
        buffer[operation_point_y*8+operation_point_x-1] <= average_temp;
        buffer[operation_point_y*8+operation_point_x] <= average_temp;
    end
    CMD_MIRROR_X:begin
        if(!cmd_done)begin
        buffer[(operation_point_y-1)*8+operation_point_x-1] <= buffer[operation_point_y*8+operation_point_x-1];
        buffer[(operation_point_y-1)*8+operation_point_x] <= buffer[operation_point_y*8+operation_point_x];
        buffer[operation_point_y*8+operation_point_x-1] <= buffer[(operation_point_y-1)*8+operation_point_x-1];
        buffer[operation_point_y*8+operation_point_x] <= buffer[(operation_point_y-1)*8+operation_point_x];
        end
        else dummy <= 0;    
    end
    CMD_MIRROR_Y:begin
        if(!cmd_done)begin
        buffer[(operation_point_y-1)*8+operation_point_x-1] <= buffer[(operation_point_y-1)*8+operation_point_x];
        buffer[(operation_point_y-1)*8+operation_point_x] <= buffer[(operation_point_y-1)*8+operation_point_x-1];
        buffer[operation_point_y*8+operation_point_x-1] <= buffer[operation_point_y*8+operation_point_x];
        buffer[operation_point_y*8+operation_point_x] <= buffer[operation_point_y*8+operation_point_x-1];
        end
        else dummy <= 0;
    end
    default:begin
        IRB_D <= 0;
    end
endcase
end      


endmodule


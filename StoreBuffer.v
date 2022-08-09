// Copyright @ 2022 Yuqing Guo
// Store Buffer

module store_buffer (   clk,
                        resetb,
                        Rob_SwAddr,
                        PhyReg_StoreData,
                        Rob_CommitMemWrite,
                        SB_Full,
                        SB_Stall,
                        Rob_TopPtr,
                        SB_FlushSw,
                        SB_FlushSwTag,
                        SBTag_counter,
                        SB_DataDmem,
                        SB_AddrDmem,
                        SB_DataValid,
                        DCE_WriteBusy,
                        DCE_WriteDone
                        );

// global
input clk;
input resetb;

// interface with ROB
input [31:0] Rob_SwAddr;
input [31:0] PhyReg_StoreData;
input Rob_CommitMemWrite;
output SB_Full;
output SB_Stall;
input [4:0] Rob_TopPtr;

// interface with SAB
output SB_FlushSw;
output [1:0] SB_FlushSwTag;
output [1:0] SBTag_counter;

// interface with Data Cache
output [31:0] SB_DataDmem;
output [31:0] SB_AddrDmem;
output SB_DataValid;
input DCE_WriteBusy;
input DCE_WriteDone;

// array
reg [31:0] address_array [0:3];
reg [31:0] data_array [0:3];
reg valid_array [0:3];
reg [1:0] SBTag_array [0:3];

// signals
reg [1:0] counter;
reg [1:0] SBTag_counter;
reg [1:0] SB_FlushSwTag;
 
wire send;
wire SB_Full;

assign send = (!DCE_WriteBusy && valid_array[3]);

assign SB_Full = (counter == 2'b00 && valid_array[0]);
assign SB_Stall = (DCE_WriteBusy && SB_Full);
assign SB_FlushSw = (DCE_WriteDone);
// write to data cache
assign SB_DataDmem = data_array[3];
assign SB_AddrDmem = address_array[3];
assign SB_DataValid = valid_array[3];

always @ (posedge clk or negedge resetb) begin
    
    if (!resetb) begin
        counter <= 2'b11;
        SBTag_counter <= 2'b00;
        valid_array[0] <= 0;
        valid_array[1] <= 0;
        valid_array[2] <= 0;
        valid_array[3] <= 0;
    end

    else begin // posedge clock

// array update: shift when send = 1  
        if (send) begin 
            valid_array[3] <= valid_array[2];
            address_array[3] <= address_array[2];
            data_array[3] <= data_array[2];
            SBTag_array[3] <= SBTag_array[2];

            valid_array[2] <= valid_array[1];
            address_array[2] <= address_array[1];
            data_array[2] <= data_array[1];
            SBTag_array[2] <= SBTag_array[1];
            
            valid_array[1] <= valid_array[0];
            address_array[1] <= address_array[0];
            data_array[1] <= data_array[0];
            SBTag_array[1] <= SBTag_array[0];            
            
            SB_FlushSwTag <= SBTag_array[3]; // Signal for SAB to flush
        end

// array update related to Rob_CommitMemWrite
        if (Rob_CommitMemWrite && !SB_Full) begin
            if (send) begin
                valid_array[counter+1]      <= 1;
                address_array[counter+1]    <= Rob_SwAddr;
                data_array[counter+1]       <= PhyReg_StoreData;
                SBTag_array[counter+1]      <= SBTag_counter;
                SBTag_counter               <= SBTag_counter + 1;
            end
            else begin
                valid_array[counter]        <= 1;
                address_array[counter]      <= Rob_SwAddr;
                data_array[counter]         <= PhyReg_StoreData;
                SBTag_array[counter]        <= SBTag_counter;
                SBTag_counter               <= SBTag_counter + 1;
            end
        end
        else if (!Rob_CommitMemWrite) begin
            if (send) valid_array[0] <= 0;
        end

// counter behavior
        if (send && !Rob_CommitMemWrite && (counter != 2'b11) && !SB_Full) begin
            counter <= counter + 1;
        end
        else if (!send && Rob_CommitMemWrite && (counter != 2'b00)) begin
            counter <= counter - 1;
        end

    end

end

endmodule
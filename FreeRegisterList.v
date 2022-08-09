// Copyright @ 2022 Yuqing Guo
// Free Register List


module Frl( clk, 
            resetb,
            Cdb_Flush,
            Rob_CommitPrePhyAddr,
            Rob_Commit,
            Rob_CommitRegWrite,
            Cfc_FrlHeadPtr,
            Frl_RdPhyAddr,
            Dis_FrlRead,
            Frl_Empty,
            Frl_HeadPtr
            ) ;
parameter WIDTH = 6;
parameter DEPTH = 16;
parameter PTR_WIDTH = 5;

input clk;
input resetb;
input Cdb_Flush;

//interface with ROB
input [WIDTH-1:0] Rob_CommitPrePhyAddr;
input Rob_Commit;   		
input Rob_CommitRegWrite;
input [PTR_WIDTH-1:0] Cfc_FrlHeadPtr;

//Interface with Dispatch Unit
output [WIDTH-1:0] Frl_RdPhyAddr;
input Dis_FrlRead;
output Frl_Empty;

//Interface with CFC
output [PTR_WIDTH-1:0] Frl_HeadPtr;

reg [PTR_WIDTH-1:0] Frl_HeadPtr;
reg [PTR_WIDTH-1:0] Frl_TailPtr;
reg [WIDTH-1:0] FreeRegArray [0:DEPTH-1];

integer i;

assign Frl_Empty = (Frl_TailPtr-Frl_HeadPtr == 5'b00000);
assign Frl_RdPhyAddr = FreeRegArray[Frl_HeadPtr[PTR_WIDTH-2:0]];

always @ (posedge clk or negedge resetb) begin
    
    if (!resetb) begin
        Frl_HeadPtr <= 5'b00000;
        Frl_TailPtr <= 5'b10000;
        for (i = 0; i < DEPTH; i = i + 1) begin
            FreeRegArray[i] <= 32 + i;
        end
    end

    else begin
        
        if (Rob_Commit & Rob_CommitRegWrite) begin
            FreeRegArray[Frl_TailPtr[PTR_WIDTH-2:0]] <= Rob_CommitPrePhyAddr;
            Frl_TailPtr <= Frl_TailPtr + 1;
        end
        
        if (Dis_FrlRead == 1 && Frl_TailPtr-Frl_HeadPtr != 5'b00000) begin
            Frl_HeadPtr <= Frl_HeadPtr + 1;
        end

        if (Cdb_Flush) begin
            Frl_HeadPtr <= Cfc_FrlHeadPtr;
        end
    end

end

endmodule

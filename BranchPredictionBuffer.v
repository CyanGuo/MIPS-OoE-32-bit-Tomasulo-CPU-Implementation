// Copyright @ 2022 Yuqing Guo

//Branch Predicton Buffer

module bpb( clk,
            resetb,
            Dis_CdbUpdBranch,
            Dis_CdbUpdBranchAddr,
            Dis_CdbBranchOutcome,
            Dis_BpbBranchPCBits,
            Dis_BpbBranch,
            Bpb_BranchPrediction
            );

    input clk;
    input resetb;
    // interface with cdb
    input Dis_CdbUpdBranch; 
    input [2:0] Dis_CdbUpdBranchAddr;
    input Dis_CdbBranchOutcome;
    // interface with dispatch unit
    input [2:0] Dis_BpbBranchPCBits; // PC[4:2]
    input Dis_BpbBranch;
    output Bpb_BranchPrediction;

    reg [1:0] bpb_array [0:7];
    wire [1:0] bpb_read_status;
    
    assign bpb_read_status = bpb_array[Dis_BpbBranchPCBits];
    assign Bpb_BranchPrediction = Dis_BpbBranch ? bpb_read_status[1] : 0;
    
    always @ (posedge clk or negedge resetb) begin
        
        if (!resetb) begin
            bpb_array[0] <= 2'b01;
            bpb_array[1] <= 2'b10;
            bpb_array[2] <= 2'b01;
            bpb_array[3] <= 2'b10;
            bpb_array[4] <= 2'b01;
            bpb_array[5] <= 2'b10;
            bpb_array[6] <= 2'b01;
            bpb_array[7] <= 2'b10;
        end
        
        else begin
            if (Dis_CdbBranchOutcome && Dis_CdbUpdBranch) begin
                if (bpb_array[Dis_CdbUpdBranchAddr] != 2'b11) 
                    bpb_array[Dis_CdbUpdBranchAddr] <= bpb_array[Dis_CdbUpdBranchAddr] + 1;
            end
            else if (!Dis_CdbBranchOutcome && Dis_CdbUpdBranch) begin
                if (bpb_array[Dis_CdbUpdBranchAddr] != 2'b00) 
                    bpb_array[Dis_CdbUpdBranchAddr] <= bpb_array[Dis_CdbUpdBranchAddr] - 1;                    
            end
        end
    end

endmodule
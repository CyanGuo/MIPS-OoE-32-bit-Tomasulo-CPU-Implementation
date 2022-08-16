// Copyright @ Yuqing Guo 2022

// Copy Free Checkpoint
// including RRAT, FRAT in 8 checkpoints
// First Version: 08/15/2022

module cfc (clk,
            resetb,
            Dis_InstValid,
            Dis_CfcBranchTag,
            Dis_CfcRdAddr,
            Dis_CfcRsAddr,
            Dis_CfcRtAddr,
            Dis_CfcNewRdPhyAddr,
            Dis_CfcRegWrite,
            Dis_CfcBranch,
            Dis_Jr31Inst,
            Cfc_RdPhyAddr,
            Cfc_RsPhyAddr,
            Cfc_RtPhyAddr,
            Cfc_Full,
            Rob_TopPtr,
            Rob_Commit,
            Rob_CommitRdAddr,
            Rob_CommitRegWrite,
            Rob_CommitCurrPhyAddr,
            Cfc_RobTag,
            Frl_HeadPtr,
            Cfc_FrlHeadPtr,
            Cdb_Flush,
            Cdb_RobTag,
            Cdb_RobDepth
            );
// global signals
input clk;               
input resetb;                
// interface with dispatch unit
input Dis_InstValid;                // Flag indicating if the instruction dispatched is valid or not
input [4:0] Dis_CfcBranchTag;       // ROB Tag of the branch instruction 
input [4:0] Dis_CfcRdAddr;          // Rd Logical Address
input [4:0] Dis_CfcRsAddr;          // Rs Logical Address
input [4:0] Dis_CfcRtAddr;          // Rt Logical Address
input [5:0] Dis_CfcNewRdPhyAddr;    // New Physical Register Address assigned to Rd by Dispatch
input Dis_CfcRegWrite;              // Flag indicating whether current instruction being dispatched is register writing or not
input Dis_CfcBranch;                // Flag indicating whether current instruction being dispatched is branch or not
input Dis_Jr31Inst;                 // Flag indicating if the current instruction is Jr 31 or not
		
output [5:0] Cfc_RdPhyAddr;         // Previous Physical Register Address of Rd
output [5:0] Cfc_RsPhyAddr;         // Latest Physical Register Address of Rs
output [5:0] Cfc_RtPhyAddr;         // Latest Physical Register Address of Rt
output Cfc_Full;                    // Flag indicating whether checkpoint table is full or not
				
//interface with ROB
input [4:0] Rob_TopPtr;             // ROB tag of the intruction at the Top
input Rob_Commit;                   // Flag indicating whether instruction is committing in this cycle or not
input [4:0] Rob_CommitRdAddr;       // Rd Logical Address of committing instruction
input Rob_CommitRegWrite;           // Indicates if instruction is writing to register or not
input [5:0] Rob_CommitCurrPhyAddr;	// Physical Register Address of Rd of committing instruction		

// signals for CDB flush
output [4:0] Cfc_RobTag;            // Rob Tag of the instruction to which rob_bottom is moved after branch misprediction (also to php)

// interface with FRL
input [4:0] Frl_HeadPtr;            // Head Pointer of the FRL when a branch is dispatched
output [4:0] Cfc_FrlHeadPtr;        // Value to which FRL has to jump on CDB Flush
 		
// interface with CDB
input Cdb_Flush;                    // Flag indicating that current instruction is mispredicted or not
input [4:0] Cdb_RobTag;             // ROB Tag of the mispredicted branch
input [4:0] Cdb_RobDepth;           // Depth of mispredicted branch from ROB Top

// BRAM array for checkpoints
reg [5:0] Cfc_RsList [0:255];
reg [5:0] Cfc_RtList [0:255];
reg [5:0] Cfc_RdList [0:255];

// Retirement RAT (RRAT)
reg [5:0] Committed_RsList [0:31];
reg [5:0] Committed_RtList [0:31];
reg [5:0] Committed_RdList [0:31];

// Dirty Falg Array (DFA)
reg [0:0] Dfa_List [0:7][0:31];

// Checkpoint_Tag Array (ROB Tag)
reg [4:0] Checkpoint_TagArray [0:7];

reg [4:0] Frl_HeadPtrArray [0:7];

reg [4:0] Depth_Array;
// Cfc_Valid Array
reg [0:0] Cfc_ValidArray [0:7];

// signals
wire full, empty;
reg [2:0] Head_Pointer, Tail_Pointer;
reg [2:0] Next_Head_Pointer;
reg [7:0] Checkpoint_MatchArray;
reg Dfa_RsValid, Dfa_RtValid, Dfa_RdValid;

integer i, j;

assign Cfc_Full = full;
assign full = ((Head_Pointer+1) == Tail_Pointer) ? 1'b1 : 1'b0;
assign empty = (Head_Pointer == Tail_Pointer) ? 1'b1 : 1'b0;

assign Cfc_FrlHeadPtr = Frl_HeadPtrArray[Next_Head_Pointer];
assign Cfc_RobTag = Checkpoint_TagArray[Next_Head_Pointer];

// behavior
always @ (*) begin
    Depth_Array[0] = Checkpoint_TagArray[0] - Rob_TopPtr;
    Depth_Array[1] = Checkpoint_TagArray[1] - Rob_TopPtr;
    Depth_Array[2] = Checkpoint_TagArray[2] - Rob_TopPtr;
    Depth_Array[3] = Checkpoint_TagArray[3] - Rob_TopPtr;
    Depth_Array[4] = Checkpoint_TagArray[4] - Rob_TopPtr;
    Depth_Array[5] = Checkpoint_TagArray[5] - Rob_TopPtr;
    Depth_Array[6] = Checkpoint_TagArray[6] - Rob_TopPtr;
    Depth_Array[7] = Checkpoint_TagArray[7] - Rob_TopPtr;
end

always @ (*) begin
    Checkpoint_MatchArray[0] = (Checkpoint_TagArray[0] == Cdb_RobTag) & (Cfc_ValidArray[0] == 1'b1);
    Checkpoint_MatchArray[1] = (Checkpoint_TagArray[1] == Cdb_RobTag) & (Cfc_ValidArray[1] == 1'b1);
    Checkpoint_MatchArray[2] = (Checkpoint_TagArray[2] == Cdb_RobTag) & (Cfc_ValidArray[2] == 1'b1);
    Checkpoint_MatchArray[3] = (Checkpoint_TagArray[3] == Cdb_RobTag) & (Cfc_ValidArray[3] == 1'b1);
    Checkpoint_MatchArray[4] = (Checkpoint_TagArray[4] == Cdb_RobTag) & (Cfc_ValidArray[4] == 1'b1);
    Checkpoint_MatchArray[5] = (Checkpoint_TagArray[5] == Cdb_RobTag) & (Cfc_ValidArray[5] == 1'b1);
    Checkpoint_MatchArray[6] = (Checkpoint_TagArray[6] == Cdb_RobTag) & (Cfc_ValidArray[6] == 1'b1);
    Checkpoint_MatchArray[7] = (Checkpoint_TagArray[7] == Cdb_RobTag) & (Cfc_ValidArray[7] == 1'b1);
end

// combinational logic to determine new head pointer during branch misprediction
always @ (*) begin : cdbflush_logic
    Next_Head_Pointer = Head_Pointer;
    if (Cdb_Flush) begin
        case (Checkpoint_MatchArray)
            8'b0000_0001: Next_Head_Pointer = 3'b000;
            8'b0000_0010: Next_Head_Pointer = 3'b001;
            8'b0000_0100: Next_Head_Pointer = 3'b010;
            8'b0000_1000: Next_Head_Pointer = 3'b011;
            8'b0001_0000: Next_Head_Pointer = 3'b100;
            8'b0010_0000: Next_Head_Pointer = 3'b101;
            8'b0100_0000: Next_Head_Pointer = 3'b110;
            8'b1000_0000: Next_Head_Pointer = 3'b111;
            default: Next_Head_Pointer = 3'bxxx;
        endcase
    end
end




// CFC update logic
always @ (posedge clk or negedge resetb) begin: cfcupdate
    
    if (!resetb) begin
        // reset pointer, dfa, valid
        Head_Pointer <= 0;
        Tail_Pointer <= 0;
        
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 32; j = j + 1) begin
                Dfa_List[i][j] <= 0;
            end
            Cfc_ValidArray[i] <= 0;
        end
    end

    else begin
        // release the oldeset checkpoints if Branch reaches to top of ROB
        if ((Rob_Commit) && (Rob_TopPtr == Checkpoint_TagArray[Tail_Pointer]) && (Tail_Pointer - Next_Head_Pointer != 2'b00)) begin
            Tail_Pointer <= Tail_Pointer + 1;
            Cfc_ValidArray[Tail_Pointer] <= 0;
            for (i = 0; i < 32; i = i + 1) begin
                Dfa_List[Tail_Pointer][i] <= 0;
            end
        end

        if (Cdb_Flush) begin

            // clear active active dfa
            for (j = 0; j < 32; j = j + 1) begin
                Dfa_List[Head_Pointer][j] <= 0;
            end
            // flush mispredicted branch 
            for (i = 0; i < 8; i = i + 1) begin
                // use CDB_ROB_DEPTH compare DEPTH_ARRAY(Tag to RobTopPtr)
                if (Cdb_RobDepth < Depth_Array[i]) begin
                    Cfc_ValidArray[i] <= 0;
                    for (j = 0; j < 32; j = j + 1) begin
                        Dfa_List[i][j] <= 0; 
                    end
                end
                if (Cdb_RobDepth == Depth_Array[i]) begin
                    Cfc_ValidArray[i] <= 0;
                    // Headpointer points to active FRAT, valid = 0
                end
            end
            Head_Pointer <= Next_Head_Pointer;
        end

        else begin 
            // UPDATE DFA
            if (Dis_CfcRegWrite && Dis_InstValid) begin
                Dfa_List[Head_Pointer][Dis_CfcRdAddr] <= 1;
            end
            // create a new checkpoint for dispatched branch
            if ((Dis_CfcBranch || Dis_Jr31Inst) && Dis_InstValid && 
                (!full || (Rob_Commit && Rob_TopPtr == Checkpoint_TagArray[Tail_Pointer]))) begin
                
                Checkpoint_TagArray[Head_Pointer] <= Dis_CfcBranchTag;
                Cfc_ValidArray[Head_Pointer] <= 1;
                Frl_HeadPtrArray[Head_Pointer] <= Frl_HeadPtr;
                Head_Pointer <= Head_Pointer + 1;
            end
        end

    end
end

// -------------------------- Rs Searching

reg [2:0] rs_pointer1;
reg [2:0] rs_pointer2;
reg found_rs1;
reg found_rs2;
reg [2:0] BRAM_Rspointer;
reg [5:0] Cfc_RsList_temp;
reg [5:0] Committed_RsList_temp;

always @ (*) begin
        for (i = 7; i >= 0; i = i - 1) begin
            if (i <= Head_Pointer) begin
                if (Dfa_List[i][Dis_CfcRsAddr]) begin: rs_search1
                    rs_pointer1 = i;
                    found_rs1 = 1;
                    disable rs_search1;
                end
                else found_rs1 = 0;
            end
        end

        for (i = 7; i >= 0; i = i - 1) begin
            if (i >= Tail_Pointer) begin
                if (Dfa_List[i][Dis_CfcRsAddr]) begin: rs_search2
                    rs_pointer2 = i;
                    found_rs2 = 1;
                    disable rs_search2;
                end
                else found_rs2 = 0;
            end
        end

        if (found_rs1)          BRAM_Rspointer = rs_pointer1;
        else if (found_rs2)     BRAM_Rspointer = rs_pointer2;
        else                    BRAM_Rspointer = 0;
end

always @ (posedge clk or negedge resetb) begin

    if (!resetb) begin
        for (j = 0; j < 32; j = j + 1) begin
            Committed_RsList[j] <= j;
        end
    end

    else begin
/*        
        for (i = 7; i >= 0; i = i - 1) begin
            if (i <= Head_Pointer) begin
                if (Dfa_List[i][Dis_CfcRsAddr]) begin: rs_search1
                    rs_pointer1 = i;
                    found_rs1 = 1;
                    disable rs_search1;
                end
                else found_rs1 = 0;
            end
        end

        for (i = 7; i >= 0; i = i - 1) begin
            if (i >= Tail_Pointer) begin
                if (Dfa_List[i][Dis_CfcRsAddr]) begin: rs_search2
                    rs_pointer2 = i;
                    found_rs2 = 1;
                    disable rs_search2;
                end
                else found_rs2 = 0;
            end
        end

        if (found_rs1)          BRAM_Rspointer = rs_pointer1;
        else if (found_rs2)     BRAM_Rspointer = rs_pointer2;
        else                    BRAM_Rspointer = 0;
*/
        if (found_rs1 || found_rs2) Dfa_RsValid <= 1;
        else                        Dfa_RsValid <= 0;

        if (Rob_Commit && Rob_CommitRegWrite) Committed_RsList[Rob_CommitRdAddr] <= Rob_CommitCurrPhyAddr;

        if (Dis_InstValid) begin
            if (Dis_CfcRegWrite) begin
                Cfc_RsList[{Head_Pointer, Dis_CfcRdAddr}] <= Dis_CfcNewRdPhyAddr;
            end
            Cfc_RsList_temp <= Cfc_RsList[{BRAM_Rspointer, Dis_CfcRdAddr}];
            Committed_RsList_temp <= Committed_RsList[Dis_CfcRdAddr];
        end

    end

end

assign Cfc_RsPhyAddr = (Dfa_RsValid) ? Cfc_RsList_temp : Committed_RsList_temp;

// -------------------------- Rt Searching

reg [2:0] rt_pointer1;
reg [2:0] rt_pointer2;
reg found_rt1;
reg found_rt2;
reg [2:0] BRAM_Rtpointer;
reg [5:0] Cfc_RtList_temp;
reg [5:0] Committed_RtList_temp;

always @ (*) begin
        for (i = 7; i >= 0; i = i - 1) begin
            if (i <= Head_Pointer) begin
                if (Dfa_List[i][Dis_CfcRtAddr]) begin: rt_search1
                    rt_pointer1 = i;
                    found_rt1 = 1;
                    disable rt_search1;
                end
                else found_rt1 = 0;
            end
        end

        for (i = 7; i >= 0; i = i - 1) begin
            if (i >= Tail_Pointer) begin
                if (Dfa_List[i][Dis_CfcRtAddr]) begin: rt_search2
                    rt_pointer2 = i;
                    found_rt2 = 1;
                    disable rt_search2;
                end
                else found_rt2 = 0;
            end
        end

        if (found_rt1)          BRAM_Rtpointer = rt_pointer1;
        else if (found_rt2)     BRAM_Rtpointer = rt_pointer2;
        else                    BRAM_Rtpointer = 0;
end

always @ (posedge clk or negedge resetb) begin

    if (!resetb) begin
        for (j = 0; j < 32; j = j + 1) begin
            Committed_RtList[j] <= j;
        end
    end

    else begin
/*        
        for (i = 7; i >= 0; i = i - 1) begin
            if (i <= Head_Pointer) begin
                if (Dfa_List[i][Dis_CfcRsAddr]) begin: rs_search1
                    rs_pointer1 = i;
                    found_rs1 = 1;
                    disable rs_search1;
                end
                else found_rs1 = 0;
            end
        end

        for (i = 7; i >= 0; i = i - 1) begin
            if (i >= Tail_Pointer) begin
                if (Dfa_List[i][Dis_CfcRsAddr]) begin: rs_search2
                    rs_pointer2 = i;
                    found_rs2 = 1;
                    disable rs_search2;
                end
                else found_rs2 = 0;
            end
        end

        if (found_rs1)          BRAM_Rspointer = rs_pointer1;
        else if (found_rs2)     BRAM_Rspointer = rs_pointer2;
        else                    BRAM_Rspointer = 0;
*/
        if (found_rt1 || found_rt2) Dfa_RtValid <= 1;
        else                        Dfa_RtValid <= 0;

        if (Rob_Commit && Rob_CommitRegWrite) Committed_RtList[Rob_CommitRdAddr] <= Rob_CommitCurrPhyAddr;

        if (Dis_InstValid) begin
            if (Dis_CfcRegWrite) begin
                Cfc_RtList[{Head_Pointer, Dis_CfcRdAddr}] <= Dis_CfcNewRdPhyAddr;
            end
            Cfc_RtList_temp <= Cfc_RtList[{BRAM_Rtpointer, Dis_CfcRtAddr}];
            Committed_RtList_temp <= Committed_RtList[Dis_CfcRtAddr];
        end

    end

end

assign Cfc_RtPhyAddr = (Dfa_RtValid) ? Cfc_RtList_temp : Committed_RtList_temp;

// -------------------------- Rd Searching

reg [2:0] rd_pointer1;
reg [2:0] rd_pointer2;
reg found_rd1;
reg found_rd2;
reg [2:0] BRAM_Rdpointer;
reg [5:0] Cfc_RdList_temp;
reg [5:0] Committed_RdList_temp;

always @ (*) begin
        for (i = 7; i >= 0; i = i - 1) begin
            if (i <= Head_Pointer) begin
                if (Dfa_List[i][Dis_CfcRdAddr]) begin: rd_search1
                    rd_pointer1 = i;
                    found_rd1 = 1;
                    disable rd_search1;
                end
                else found_rd1 = 0;
            end
        end

        for (i = 7; i >= 0; i = i - 1) begin
            if (i >= Tail_Pointer) begin
                if (Dfa_List[i][Dis_CfcRdAddr]) begin: rd_search2
                    rd_pointer2 = i;
                    found_rd2 = 1;
                    disable rd_search2;
                end
                else found_rd2 = 0;
            end
        end

        if (found_rd1)          BRAM_Rdpointer = rd_pointer1;
        else if (found_rd2)     BRAM_Rdpointer = rd_pointer2;
        else                    BRAM_Rdpointer = 0;
end

always @ (posedge clk or negedge resetb) begin

    if (!resetb) begin
        for (j = 0; j < 32; j = j + 1) begin
            Committed_RdList[j] <= j;
        end
    end

    else begin
/*        
        for (i = 7; i >= 0; i = i - 1) begin
            if (i <= Head_Pointer) begin
                if (Dfa_List[i][Dis_CfcRsAddr]) begin: rs_search1
                    rs_pointer1 = i;
                    found_rs1 = 1;
                    disable rs_search1;
                end
                else found_rs1 = 0;
            end
        end

        for (i = 7; i >= 0; i = i - 1) begin
            if (i >= Tail_Pointer) begin
                if (Dfa_List[i][Dis_CfcRsAddr]) begin: rs_search2
                    rs_pointer2 = i;
                    found_rs2 = 1;
                    disable rs_search2;
                end
                else found_rs2 = 0;
            end
        end

        if (found_rs1)          BRAM_Rspointer = rs_pointer1;
        else if (found_rs2)     BRAM_Rspointer = rs_pointer2;
        else                    BRAM_Rspointer = 0;
*/
        if (found_rd1 || found_rd2) Dfa_RdValid <= 1;
        else                        Dfa_RdValid <= 0;

        if (Rob_Commit && Rob_CommitRegWrite) Committed_RdList[Rob_CommitRdAddr] <= Rob_CommitCurrPhyAddr;

        if (Dis_InstValid) begin
            if (Dis_CfcRegWrite) begin
                Cfc_RdList[{Head_Pointer, Dis_CfcRdAddr}] <= Dis_CfcNewRdPhyAddr;
            end
            Cfc_RdList_temp <= Cfc_RdList[{BRAM_Rdpointer, Dis_CfcRdAddr}];
            Committed_RdList_temp <= Committed_RdList[Dis_CfcRdAddr];
        end

    end

end

assign Cfc_RdPhyAddr = (Dfa_RdValid) ? Cfc_RdList_temp : Committed_RdList_temp;

endmodule

// Issue Unit
// CopyRight @2022 Yuqing Guo

module issue_unit ( clk,
                    resetb,
                    IssInt_Rdy,
                    IssMul_Rdy,
                    IssDiv_Rdy,
                    IssLsb_Rdy,
                    Iss_Int,
                    Iss_Mult,
                    Iss_Div,
                    Iss_Lsb,
                    Div_ExeRdy
);

input clk;
input resetb;
input IssInt_Rdy;
input IssMul_Rdy;
input IssDiv_Rdy;
input IssLsb_Rdy;
input Div_ExeRdy;

output reg Iss_Int;
output reg Iss_Lsb;
output Iss_Mult;
output Iss_Div;

reg [5:0] cdb_slot;
reg lru_bit; // for L/S, R-Type
 
always @ (posedge clk or negedge resetb) begin
    
    if (!resetb) begin
        cdb_slot <= 0;
        lru_bit <= 0;
    end

    else begin
        
        cdb_slot <= cdb_slot >> 1;
        if (Div_ExeRdy && IssDiv_Rdy) cdb_slot[5] <= 1;
        if (!cdb_slot[3] && IssMul_Rdy) cdb_slot[2] <= 1;
        
        if (!cdb_slot[0]) begin
            if      (IssInt_Rdy && !IssLsb_Rdy) lru_bit <= 1;
            else if (!IssInt_Rdy && IssLsb_Rdy) lru_bit <= 0;
            else if (IssInt_Rdy && IssLsb_Rdy)  lru_bit <= ~lru_bit;
        end
        
    end 

end

always @ (*) begin
 
    case ({cdb_slot[0], IssInt_Rdy, IssLsb_Rdy})

        3'b010: begin
            Iss_Int = 1;
            Iss_Lsb = 0;
        end

        3'b001: begin
            Iss_Int = 0;
            Iss_Lsb = 1;            
        end

        3'b011: begin
            Iss_Int = ~lru_bit;
            Iss_Lsb = lru_bit;            
        end

        default: begin
            Iss_Int = 0;
            Iss_Lsb = 0;            
        end

    endcase

/*
    if ({cdb_slot[0], IssInt_Rdy, IssLsb_Rdy} == 3'b010) begin
        Iss_Int = 1;
        Iss_Lsb = 0;
    end
    else if ({cdb_slot[0], IssInt_Rdy, IssLsb_Rdy} == 3'b001) begin
        Iss_Int = 0;
        Iss_Lsb = 1;
    end
    else if ({cdb_slot[0], IssInt_Rdy, IssLsb_Rdy} == 3'b011) begin
        Iss_Int = ~lru_bit;
        Iss_Lsb = lru_bit;  
    end
    else begin
        Iss_Int = 0;
        Iss_Lsb = 0;
    end
*/
end

assign Iss_Div = (Div_ExeRdy && IssDiv_Rdy) ? 1 : 0;
assign Iss_Mult = (!cdb_slot[3] && IssMul_Rdy) ? 1 : 0;

endmodule
import rv32i_types::*;

module cmp
(
    input cmp_ops cmpop,
    input rv32i_word a, b,
    output logic br_en
);

logic agb;  // A > B
logic aeqb; // A = B
logic alb;  // A < B
logic agbu; // _A > _B
logic albu; // _A < _B

always_comb
begin
    agb = $signed(a) > $signed(b);
	aeqb = (a == b);
	alb = (!agb) && (!aeqb);
	 
	agbu = a > b;
	albu = (!agbu) && (!aeqb);
	 
    unique case (cmpop)
        cmp_beq:  br_en = aeqb;
        cmp_bne:  br_en = !aeqb;
        cmp_blt:  br_en = alb;
        cmp_bltu: br_en = albu;
        cmp_bge:  br_en = !alb;
        cmp_bgeu: br_en = !albu;
        cmp_jmp:  br_en = 1;
        cmp_njp:  br_en = 0;
    endcase
end

endmodule : cmp
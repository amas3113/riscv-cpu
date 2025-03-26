module register #(parameter width = 32) (
    input clk_i,
    input rst_i,
    input load_i,
    input [width-1:0] data_i,
    output logic [width-1:0] data_o
);

logic [width-1:0] data = 1'b0;

always_ff @(posedge clk_i)
begin
    if (rst_i) begin
        data <= '0;
    end else if (load_i) begin
        data <= data_i;
    end else begin
        data <= data_o;
    end
end

always_comb begin
    data_o = data;
end

endmodule : register

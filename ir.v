`timescale 1ns / 1ps

// MODULE IR RIENG DU PHONG: luu opcode 8 bit khi load.
// top.v hien dung module register cho instruction_register, khong tao ir nay.
module ir(clk, rst, load, bus, out);

input clk;
input rst;
input load;
input [15:0] bus;
output [7:0] out;

reg[7:0] data;

always @(posedge clk or posedge rst) begin
	if (rst) begin
		data <= 8'b0;
	end else if (load) begin
		data <= bus[7:0];
	end
end

assign out = data;

endmodule

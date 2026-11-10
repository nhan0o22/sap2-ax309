/**
 * Module: flags
 * Description: Zero and Sign flags register
 *
 * Flags:
 *   [1] Zero (Z):  Set when register value = 0
 *   [0] Sign (S):  Copy of bit 7 (MSB = sign bit for signed numbers)
 *
 * Can load flags from any of the three registers (A, B, or C)
 * Used for conditional jumps (JZ, JNZ, JM)
 */
// CO TRANG THAI: Z=1 neu gia tri bang 0; S la bit 7 cua gia tri.
// Lay mau o canh xuong de thay ket qua thanh ghi da doi o canh len.
// Demo giam C, kiem tra Z, roi JZ thoat vong lap khi C bang 0.
module flags(clk, rst, a, b, c, load_a, load_b, load_c, out);

input clk;
input rst;
input [7:0] a;
input [7:0] b;
input [7:0] c;
input load_a;
input load_b;
input load_c;
output [1:0] out;

localparam FLAG_Z = 1;  // Zero flag bit position
localparam FLAG_S = 0;  // Sign flag bit position

reg[1:0] flags;

// Note: Using negedge to match top.v stage register timing
// Flags are sampled on opposite clock edge from data path
always @(negedge clk or posedge rst) begin
	if (rst) begin
		flags <= 2'b0;
	end else if (load_a) begin
		flags[FLAG_Z] <= (a == 0) ? 1'b1 : 1'b0;
		flags[FLAG_S] <= (a[7] == 1) ? 1'b1 : 1'b0;
	end else if (load_b) begin
		flags[FLAG_Z] <= (b == 0) ? 1'b1 : 1'b0;
		flags[FLAG_S] <= (b[7] == 1) ? 1'b1 : 1'b0;
	end else if (load_c) begin
		flags[FLAG_Z] <= (c == 0) ? 1'b1 : 1'b0;
		flags[FLAG_S] <= (c[7] == 1) ? 1'b1 : 1'b0;
	end
end

assign out = flags;

endmodule

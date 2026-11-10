// PC 16 BIT: giu dia chi byte chuong trinh se doc tiep theo.
// inc tang mot BYTE, khong nhat thiet la mot LENH (lenh co the nhieu byte).
// load dung cho lenh nhay; vi du lenh 3E 00 ket thuc thi PC bang 0002.
module pc(clk, rst, inc, load, bus, out);

input clk;
input rst;
input inc;
input load;
input [15:0] bus;
output [15:0] out;

reg[15:0] pc;

always @(posedge clk or posedge rst) begin
	if (rst) begin
		pc <= 16'b0;
	end else if (load) begin
		pc <= bus;
	end else if (inc) begin
		pc <= pc + 16'd1;
	end
end

assign out = pc;

endmodule

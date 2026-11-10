// THANH GHI 8 BIT: dung chung cho A, B, C va IR trong top.v.
// Thu tu uu tien: reset -> nap byte thap tu bus -> tang 1 -> giam 1.
// Khi khong co lenh dieu khien thi giu nguyen gia tri.
module register(clk, rst, load, inc, dec, bus, out);

input clk;
input rst;
input load;
input inc;
input dec;
input [15:0] bus;
output [7:0] out;

reg[7:0] data;

always @(posedge clk or posedge rst) begin
	if (rst) begin
		data <= 8'b0;
	end else if (load) begin
		data <= bus[7:0];
	end else if (inc) begin
		data <= data + 8'd1;
	end else if (dec) begin
		data <= data - 8'd1;
	end
end

assign out = data;

endmodule

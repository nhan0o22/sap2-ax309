// MODULE CLOCK CU: chan clock khi hlt=1.
// top.v hien lay cpu_clk tu ax309_io, khong tao module clock nay.
module clock(hlt, clk_in, clk_out);

input hlt;
input clk_in;
output clk_out;

assign clk_out = (hlt) ? 1'b0 : clk_in;

endmodule

`timescale 1ns / 1ps

module io_demo_tb;
// MO PHONG DEMO I/O: kiem tra reset, nut, LED chay va quet hien thi.

reg CLK;
reg RST;
reg KEY1_N, KEY2_N, KEY3_N, KEY4_N;
wire [7:0] SEG;
wire [5:0] SEL;
wire [3:0] LED;
integer failures;
reg [1:0] led_index_before;

io_demo #(.SIMULATION(1)) dut(
	.CLK(CLK), .RST(RST),
	.KEY1_N(KEY1_N), .KEY2_N(KEY2_N), .KEY3_N(KEY3_N), .KEY4_N(KEY4_N),
	.SEG(SEG), .SEL(SEL), .LED(LED)
);

always #5 CLK = ~CLK;

task press_key1;
	begin
		KEY1_N = 1'b0; repeat (16) @(negedge CLK);
		KEY1_N = 1'b1; repeat (16) @(negedge CLK);
	end
endtask

task press_key2;
	begin
		KEY2_N = 1'b0; repeat (16) @(negedge CLK);
		KEY2_N = 1'b1; repeat (16) @(negedge CLK);
	end
endtask

task press_key3;
	begin
		KEY3_N = 1'b0; repeat (16) @(negedge CLK);
		KEY3_N = 1'b1; repeat (16) @(negedge CLK);
	end
endtask

task press_key4;
	begin
		KEY4_N = 1'b0; repeat (16) @(negedge CLK);
		KEY4_N = 1'b1; repeat (16) @(negedge CLK);
	end
endtask

initial begin
	$dumpfile("io_demo_tb.vcd");
	$dumpvars(0, io_demo_tb);
	CLK = 1'b0;
	RST = 1'b0;
	KEY1_N = 1'b1;
	KEY2_N = 1'b1;
	KEY3_N = 1'b1;
	KEY4_N = 1'b1;
	failures = 0;

	repeat (8) @(negedge CLK);
	if ((LED !== 4'b0001) || (dut.last_key !== 3'd0)) begin
		$display("FAIL: io_demo reset state is incorrect");
		failures = failures + 1;
	end
	RST = 1'b1;

	press_key1;
	if (dut.last_key !== 3'd1) begin $display("FAIL: KEY1 event missing"); failures = failures + 1; end
	press_key2;
	if (dut.last_key !== 3'd2) begin $display("FAIL: KEY2 event missing"); failures = failures + 1; end
	press_key3;
	if (dut.last_key !== 3'd3) begin $display("FAIL: KEY3 event missing"); failures = failures + 1; end
	press_key4;
	if (dut.last_key !== 3'd4) begin $display("FAIL: KEY4 event missing"); failures = failures + 1; end

	led_index_before = dut.led_index;
	repeat (24) @(negedge CLK);
	if (dut.led_index == led_index_before) begin
		$display("FAIL: LED walking pattern did not advance");
		failures = failures + 1;
	end
	if (SEL === 6'b111111 || SEG === 8'bxxxxxxxx) begin
		$display("FAIL: display diagnostic has no active digit or segment pattern");
		failures = failures + 1;
	end

	if (failures == 0)
		$display("PASS: io_demo reset, four keys, LED walk, and display scan passed");
	else
		$display("FAIL: io_demo reported %0d failures", failures);
	$finish;
end

endmodule

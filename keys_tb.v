`timescale 1ns / 1ps
module keys_tb;
// MO PHONG NUT: tao doi phim, giu nut, nha va nhan lai de kiem tra loc nut.
reg clk = 0;
reg rst_n = 0;
reg [3:0] keys = 4'b1111;
wire cpu_clk;
wire [7:0] seg;
wire [5:0] sel;
wire [3:0] led;
integer failures = 0;
integer events1 = 0, events2 = 0, events3 = 0, events4 = 0;
ax309_io #(.SIMULATION(1)) dut(clk, rst_n, keys[0], keys[1], keys[2], keys[3],
    8'd0, 8'd0, 8'd0, 16'd0, 1'b0, 1'b0, cpu_clk, seg, sel, led);
always #5 clk = ~clk;
always @(negedge clk) begin
    if (dut.key1_event) events1 = events1 + 1;
    if (dut.key2_event) events2 = events2 + 1;
    if (dut.key3_event) events3 = events3 + 1;
    if (dut.key4_event) events4 = events4 + 1;
end
task ticks;
    input integer n;
    begin repeat(n) @(negedge clk); #1; end
endtask
task check_counts;
    input integer expected;
    begin
        if (events1 != expected || events2 != expected || events3 != expected || events4 != expected) begin
            $display("FAIL: key events expected %d got %d/%d/%d/%d", expected, events1, events2, events3, events4);
            failures = failures + 1;
        end
    end
endtask
initial begin
    ticks(4); rst_n = 1; ticks(8);
    // Sub-threshold contact bounce on all four inputs.
    repeat(5) begin keys = 0; ticks(1); keys = 15; ticks(1); end
    ticks(8); check_counts(0);
    keys = 0; ticks(32); check_counts(1);
    // A brief release must not re-arm a held key.
    keys = 15; ticks(1); keys = 0; ticks(32); check_counts(1);
    keys = 15; ticks(16); keys = 0; ticks(32); check_counts(2);
    // One bouncing key cannot delay a different stable button.
    keys = 15; ticks(16); keys[0] = 0;
    repeat(12) begin keys[3] = ~keys[3]; ticks(1); end
    if (events1 != 3 || events4 != 2) begin
        $display("FAIL: independent key debounce"); failures = failures + 1;
    end
    if (failures == 0) $display("PASS: four independent keys bounce/hold/release/repress");
    else $display("FAIL: %0d key checks failed", failures);
    $finish;
end
endmodule

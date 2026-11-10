`timescale 1ns / 1ps
// Run the unchanged regression with a trace of the first instruction fetches.
module trace_tb;
// THEO DOI CPU: in stage, microcode, RAM, MDR, bus, IR va PC theo canh clock.
// Dung de tim cho du lieu sai, khong phai chuong trinh nap xuong FPGA.
top_tb test();
integer edges = 0;
always @(test.dut.cpu_clk) begin
    if (edges < 100) begin
        $display("TRACE t=%0t clk=%b stage=%d rom_addr=%h ctrl=%h MAR=%h RAM_Q=%h MDR=%h bus=%h IR=%h PC=%h",
            $time, test.dut.cpu_clk, test.dut.stage,
            test.dut.ctrl_addr, test.dut.ctrl_word,
            test.dut.mem.mar, test.dut.mem.ram_data_reg, test.dut.mem.mdr,
            test.dut.bus, test.dut.ir_out, test.dut.pc_out);
        edges = edges + 1;
    end
end
endmodule

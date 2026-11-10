`timescale 1ns / 1ps

module top_tb;
// MO PHONG CPU: kiem tra tung lenh, nut, toc do, HLT va reset chay lai.
// Chi dung trong simulation, khong chon module nay lam top tong hop.

initial begin
    #3000000;
    $display("FAIL: global simulation timeout stage=%d PC=%h IR=%h run=%b active=%b speed=%d",
        dut.stage, dut.pc_out, dut.ir_out, dut.io.run_mode, dut.io.instruction_active, dut.io.speed_mode);
    $finish;
end

reg CLK;
reg RST;
reg KEY1_N, KEY2_N, KEY3_N, KEY4_N;
wire [7:0] SEG;
wire [5:0] SEL;
wire [3:0] LED;
integer failures;
integer cpu_rise_count;
integer timeout;
integer speed;
integer board_ticks = 0;
integer last_start;
integer expected_interval;
integer start_count;
reg active_prev;
reg check_intervals;
reg pause_toggle;

top #(.SIMULATION(1)) dut(
	.CLK(CLK), .RST(RST),
	.KEY1_N(KEY1_N), .KEY2_N(KEY2_N), .KEY3_N(KEY3_N), .KEY4_N(KEY4_N),
	.SEG(SEG), .SEL(SEL), .LED(LED)
);

always #5 CLK = ~CLK;

// Observe settled front-panel state away from its updating edge.
always @(negedge CLK) begin
    board_ticks = board_ticks + 1;
    if (check_intervals && dut.io.instruction_active && !active_prev) begin
        if (start_count > 0 && board_ticks - last_start != expected_interval) begin
            $display("FAIL: scheduler interval expected %0d got %0d", expected_interval, board_ticks-last_start);
            failures = failures + 1;
        end
        last_start = board_ticks;
        start_count = start_count + 1;
    end
    active_prev = dut.io.instruction_active;
end

task press_key1;
    begin
        KEY1_N = 1'b0; repeat (16) @(negedge CLK);
        KEY1_N = 1'b1; repeat (16) @(negedge CLK);
    end
endtask

always @(posedge dut.cpu_clk)
	cpu_rise_count = cpu_rise_count + 1;

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

task step_instruction;
	input [15:0] expected_pc;
	input [7:0] expected_a;
	input [7:0] expected_b;
	input [7:0] expected_c;
	reg toggle_before;
	integer timeout;
	begin
		toggle_before = dut.instruction_done_toggle;
		press_key2;
		timeout = 0;
		while ((dut.instruction_done_toggle === toggle_before) && (timeout < 5000)) begin
			@(posedge CLK);
			timeout = timeout + 1;
		end
		if (timeout == 5000) begin
			$display("FAIL: KEY2 did not complete one instruction");
			failures = failures + 1;
		end
		timeout = 0;
		while ((dut.io.instruction_active === 1'b1) && (timeout < 128)) begin
			@(posedge CLK);
			timeout = timeout + 1;
		end
		if ((dut.pc.pc !== expected_pc) || (dut.reg_a.data !== expected_a) ||
		    (dut.reg_b.data !== expected_b) || (dut.reg_c.data !== expected_c) ||
		    (dut.io.instruction_active !== 1'b0) || (dut.cpu_clk !== 1'b0)) begin
			$display("FAIL: step expected PC=%h A=%h B=%h C=%h; got PC=%h A=%h B=%h C=%h",
				expected_pc, expected_a, expected_b, expected_c,
				dut.pc.pc, dut.reg_a.data, dut.reg_b.data, dut.reg_c.data);
			$display("      diagnostic: IR=%h MDR=%h RAM_Q=%h pending=%b stage=%d",
				dut.instruction_register.data, dut.mem.mdr, dut.mem.ram_data_reg,
				dut.mem.ram_read_pending, dut.stage);
			failures = failures + 1;
		end
	end
endtask

task wait_for_halt;
	integer timeout;
	begin
		timeout = 0;
		while ((dut.hlt !== 1'b1) && (timeout < 100000)) begin
			@(posedge CLK);
			timeout = timeout + 1;
		end
		if (timeout == 100000) begin
			$display("FAIL: continuous run did not reach HLT");
			failures = failures + 1;
		end
        // HLT is decoded on a CPU falling edge. Allow its synchronized panel
        // response to settle before checking stopped-clock state.
        repeat (8) @(negedge CLK);
	end
endtask

task check_reset_state;
	begin
		if ((dut.stage !== 4'd0) || (dut.ctrl_active !== 1'b0) ||
		    (dut.ctrl_word !== 35'd0) || (dut.instruction_done_toggle !== 1'b0) ||
		    (dut.sequencer_primed !== 1'b0) ||
		    (dut.hlt !== 1'b0) || (dut.pc.pc !== 16'd0) ||
		    (dut.reg_a.data !== 8'd0) || (dut.reg_b.data !== 8'd0) ||
		    (dut.reg_c.data !== 8'd0) || (dut.flags_out !== 2'd0) ||
		    (dut.mem.mar !== 16'd0) || (dut.mem.mdr !== 16'd0) ||
		    (dut.mem.return_addr !== 16'd0) || (dut.io.cpu_clk !== 1'b0) ||
		    (dut.io.instruction_active !== 1'b0) || (dut.io.run_mode !== 1'b0) ||
		    (dut.io.display_page !== 1'b0)) begin
			$display("FAIL: reset did not restore deterministic paused state");
			failures = failures + 1;
		end
	end
endtask

// This checks the same initialized Block-RAM image that will be embedded in
// the bitstream.  It catches a missing/stale program.bin before the front
// panel behaviour is interpreted as a CPU or button failure.
task check_program_image;
	begin
		if ((dut.mem.ram[0] !== 8'h3e) || (dut.mem.ram[1] !== 8'h00) ||
		    (dut.mem.ram[2] !== 8'h06) || (dut.mem.ram[3] !== 8'h0c) ||
		    (dut.mem.ram[4] !== 8'h0e) || (dut.mem.ram[5] !== 8'h08) ||
		    (dut.mem.ram[6] !== 8'h80) || (dut.mem.ram[7] !== 8'h0d) ||
		    (dut.mem.ram[8] !== 8'hca) || (dut.mem.ram[9] !== 8'h0e) ||
		    (dut.mem.ram[10] !== 8'h00) || (dut.mem.ram[11] !== 8'hc3) ||
		    (dut.mem.ram[12] !== 8'h06) || (dut.mem.ram[13] !== 8'h00) ||
		    (dut.mem.ram[14] !== 8'h76) || (dut.mem.ram[15] !== 8'h00) ||
            (dut.mem.ram[32767] !== 8'h00)) begin
			$display("FAIL: program image differs from expected 3E 00 06 0C 0E 08 ... 76");
			failures = failures + 1;
		end
	end
endtask

initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);
    end
	CLK = 1'b0;
	RST = 1'b0;
	KEY1_N = 1'b1;
	KEY2_N = 1'b1;
	KEY3_N = 1'b1;
	KEY4_N = 1'b1;
	failures = 0;
	cpu_rise_count = 0;
    active_prev = 0;
    check_intervals = 0;
    start_count = 0;

	repeat (20) @(negedge CLK);
	check_program_image;
	check_reset_state;
	RST = 1'b1;

	// The paused reset state must never free-run the CPU.
	repeat (128) @(posedge CLK);
	if ((dut.pc.pc !== 16'd0) || (cpu_rise_count != 0)) begin
		$display("FAIL: CPU advanced while reset-started panel was paused");
		failures = failures + 1;
	end

	// Program setup: LD A,00; LD B,0C; LD C,08.
	step_instruction(16'h0002, 8'h00, 8'h00, 8'h00);
	step_instruction(16'h0004, 8'h00, 8'h0c, 8'h00);
	step_instruction(16'h0006, 8'h00, 8'h0c, 8'h08);
    step_instruction(16'h0007, 8'h0c, 8'h0c, 8'h08);

    // KEY1 changes speed without resetting or advancing the CPU.
    press_key1;
    if (dut.io.speed_mode !== 2'd1 || dut.pc_out !== 16'h0007) begin
        $display("FAIL: KEY1 speed change reset/advanced CPU"); failures = failures + 1;
    end
    press_key1;
    press_key1;
    if (dut.io.speed_mode !== 2'd0) begin
        $display("FAIL: KEY1 speed wrap"); failures = failures + 1;
    end

	// KEY4 affects only the display page and never the CPU state.
	press_key4;
	if ((dut.io.display_page !== 1'b1) || (dut.pc.pc !== 16'h0007) ||
	    (dut.reg_a.data !== 8'h0c) || (dut.reg_b.data !== 8'h0c) ||
	    (dut.reg_c.data !== 8'h08)) begin
		$display("FAIL: KEY4 did not change only the display page");
		failures = failures + 1;
	end

	// A KEY3 pause request during an active instruction must not cut the
	// instruction short; it takes effect at the next instruction boundary.
	press_key3;
    // The short DEC instruction can already have completed when the key
    // helper returns, while its done toggle is still crossing the panel.
    // Wait for that request to retire, then target the next active command.
    timeout = 0;
    while (dut.io.instruction_active && timeout < 5000) begin
        @(negedge CLK); timeout = timeout + 1;
    end
	timeout = 0;
	while ((dut.io.instruction_active !== 1'b1) && (timeout < 5000)) begin
		@(posedge CLK);
		timeout = timeout + 1;
	end
	if (timeout == 5000) begin
		$display("FAIL: continuous mode never started an instruction");
		failures = failures + 1;
	end else begin
		pause_toggle = dut.instruction_done_toggle;
		press_key3;
		timeout = 0;
		while ((dut.io.instruction_active === 1'b1) && (timeout < 5000)) begin
			@(posedge CLK);
			timeout = timeout + 1;
		end
		if ((dut.io.run_mode !== 1'b0) || (dut.io.instruction_active !== 1'b0) ||
		    (dut.instruction_done_toggle === pause_toggle) || (dut.cpu_clk !== 1'b0)) begin
			$display("FAIL: KEY3 pause did not finish exactly at an instruction boundary");
            $display("pause: run=%b active=%b done=%b before=%b clk=%b t=%t", dut.io.run_mode,
                dut.io.instruction_active, dut.instruction_done_toggle, pause_toggle, dut.cpu_clk, $time);
			failures = failures + 1;
		end
	end

	// KEY3 starts continuous mode. The simulated interval is shortened, while
	// hardware uses the same logic to start one instruction every second.
	press_key3;
	if (dut.io.run_mode !== 1'b1) begin
		$display("FAIL: KEY3 did not enable continuous run");
		failures = failures + 1;
	end
	wait_for_halt;
	if ((dut.reg_a.data !== 8'h60) || (dut.reg_c.data !== 8'h00) ||
	    (dut.io.cpu_clk !== 1'b0) || (dut.io.instruction_active !== 1'b0)) begin
		$display("FAIL: HLT expected A=60 C=00 with stopped CPU clock");
		failures = failures + 1;
	end

	// Reset remains asynchronous and effective after HLT has forced cpu_clk low.
	RST = 1'b0;
	#1;
	check_reset_state;
	RST = 1'b1;
	repeat (12) @(negedge CLK);
	press_key3;
	wait_for_halt;
	if ((dut.reg_a.data !== 8'h60) || (dut.reg_c.data !== 8'h00)) begin
		$display("FAIL: reset-restart did not reproduce A=60 C=00");
		failures = failures + 1;
	end

    // Full demo at all speeds, checking actual start-to-start periods.
    for (speed = 0; speed < 3; speed = speed + 1) begin
        $display("TEST: full demo speed index %0d", speed);
        RST = 0; repeat (12) @(negedge CLK);
        check_reset_state;
        RST = 1; repeat (12) @(negedge CLK);
        repeat (speed) press_key1;
        expected_interval = (1024 >> speed) + 1;
        start_count = 0; check_intervals = 1;
        press_key3;
        wait_for_halt;
        check_intervals = 0;
        if (dut.a_out !== 8'h60 || dut.c_out !== 8'h00 || start_count != 35) begin
            $display("FAIL: speed %0d A=%h C=%h instructions=%0d", speed, dut.a_out, dut.c_out, start_count);
            failures = failures + 1;
        end
        // Display and speed still work after HLT; KEY2/KEY3 cannot restart it.
        press_key1; press_key4; press_key2; press_key3;
        if (dut.pc_out !== 16'h000f || dut.cpu_clk !== 0 || dut.io.run_mode !== 0 ||
            dut.io.display_page !== 1 || dut.io.speed_mode !== ((speed == 2) ? 0 : speed+1)) begin
            $display("FAIL: front panel after HLT"); failures = failures + 1;
        end
    end

    // A held KEY2 must complete only one instruction, even after it is ready.
    RST = 0; repeat (12) @(negedge CLK); RST = 1;
    repeat (12) @(negedge CLK);
    KEY2_N = 0; repeat (200) @(negedge CLK);
    if (dut.pc_out !== 16'h0002 || dut.io.instruction_active !== 0) begin
        $display("FAIL: held KEY2 repeated or did not complete"); failures = failures + 1;
    end
    KEY2_N = 1; repeat (16) @(negedge CLK);
    step_instruction(16'h0004, 8'h00, 8'h0c, 8'h00);

    // Simultaneous KEY2/KEY3 while running and waiting must pause, not step.
    press_key3;
    timeout = 0;
    while (dut.io.instruction_active && timeout < 5000) begin
        @(negedge CLK); timeout = timeout + 1;
    end
    repeat (8) @(negedge CLK);
    KEY2_N = 0; KEY3_N = 0; repeat (16) @(negedge CLK);
    KEY2_N = 1; KEY3_N = 1; repeat (128) @(negedge CLK);
    if (dut.io.run_mode !== 0 || dut.io.instruction_active !== 0 || dut.pc_out !== 16'h0006) begin
        $display("FAIL: KEY3 priority over simultaneous KEY2"); failures = failures + 1;
    end

	if (failures == 0)
		$display("PASS: instruction-step, display page, run scheduler, reset-restart passed; A=60 C=00");
	else
		$display("FAIL: %0d SAP2 demo checks failed", failures);
	$finish;
end

endmodule

// AX309 front panel and instruction-level scheduler for the SAP2 demo.
// CPU clocks are produced only while a requested instruction is executing.
// CUM 4 - GIAO TIEP BOARD: doc nut, hen gio chay lenh, quet LED 7 doan.
// RST reset; KEY1 doi 1/2/4 lenh moi giay; KEY2 mot lenh; KEY3 chay/dung;
// KEY4 doi trang AxxBxx / CxxPxx. Tat ca gia tri hien thi o he hex.
module ax309_io(clk, rst_n, key1_n, key2_n, key3_n, key4_n,
	reg_a, reg_b, reg_c, pc, halted, instruction_done_toggle,
	cpu_clk, seg, sel, led);

parameter SIMULATION = 0;

input clk;
input rst_n;
input key1_n;
input key2_n;
input key3_n;
input key4_n;
input [7:0] reg_a;
input [7:0] reg_b;
input [7:0] reg_c;
input [15:0] pc;
input halted;
input instruction_done_toggle;
output reg cpu_clk;
output reg [7:0] seg;
output reg [5:0] sel;
output [3:0] led;

// 1 kHz is the fastest internal CPU rate. Simulation keeps the state
// machine but shortens all counters.
localparam [14:0] CPU_HALF_TICKS = SIMULATION ? 15'd2 : 15'd24999;
// CPU microclock 1 kHz khac voi nhip khoi dong lenh 1/2/4 lan moi giay.
// Mot lenh gom nhieu micro-step nhanh, xong thi doi nut hoac lich chay tiep.
localparam [19:0] DEBOUNCE_TICKS = SIMULATION ? 20'd4 : 20'd1000000;
localparam [4:0] CHAR_P = 5'd16;

reg [14:0] cpu_half_counter;
reg [25:0] run_interval_counter;
reg instruction_active;
reg run_mode;
reg display_page;

reg [1:0] speed_mode;
reg [25:0] run_interval_limit;
wire key1_event, key2_event, key3_event, key4_event;
ax309_key #(.STABLE_TICKS(DEBOUNCE_TICKS)) key1_filter
    (clk, rst_n, key1_n, key1_event);
ax309_key #(.STABLE_TICKS(DEBOUNCE_TICKS)) key2_filter
    (clk, rst_n, key2_n, key2_event);
ax309_key #(.STABLE_TICKS(DEBOUNCE_TICKS)) key3_filter
    (clk, rst_n, key3_n, key3_event);
ax309_key #(.STABLE_TICKS(DEBOUNCE_TICKS)) key4_filter
    (clk, rst_n, key4_n, key4_event);

function [25:0] speed_limit;
    input [1:0] speed;
    begin
        case (speed)
            2'd1: speed_limit = SIMULATION ? 26'd512 : 26'd24999999;
            2'd2: speed_limit = SIMULATION ? 26'd256 : 26'd12499999;
            default: speed_limit = SIMULATION ? 26'd1024 : 26'd49999999;
        endcase
    end
endfunction

// A toggle crosses from the CPU clock domain to the 50 MHz front-panel
// domain. It cannot be missed the way a one-cycle CPU-domain pulse could.
reg done_sync0, done_sync1, done_seen;
// Hai tang dong bo toggle hoan thanh tu mien clock CPU ve clock 50 MHz.
wire instruction_done_event;
assign instruction_done_event = (done_sync1 != done_seen);

reg [15:0] scan_counter;
reg [4:0] digit_char;

// LED[0] = RUN, LED[1] = paused/ready, LED[2] = display page, LED[3] = HLT.
// Electrical polarity stays in one assignment for the board-observation pass.
assign led = {halted, display_page, (~run_mode & ~halted), run_mode};

always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		cpu_half_counter <= 15'd0;
		run_interval_counter <= 26'd0;
		instruction_active <= 1'b0;
		run_mode <= 1'b0;
		display_page <= 1'b0;
		cpu_clk <= 1'b0;

		speed_mode <= 2'd0;
		run_interval_limit <= speed_limit(2'd0);

		done_sync0 <= 1'b0;
		done_sync1 <= 1'b0;
		done_seen <= 1'b0;
	end else begin
		done_sync0 <= instruction_done_toggle;
		done_sync1 <= done_sync0;
		if (instruction_done_event)
			done_seen <= done_sync1;

		if (key1_event)
			// Chi doi toc do, khong reset va khong tu chay CPU dang pause.
			speed_mode <= (speed_mode == 2'd2) ? 2'd0 : speed_mode + 1'b1;

		if (key4_event)
			display_page <= ~display_page;

		// KEY3 changes continuous-run state only at an instruction boundary.
		if (key3_event && !halted) begin
			if (run_mode) begin
				run_mode <= 1'b0;
			end else begin
				run_mode <= 1'b1;
				if (!instruction_active) begin
					instruction_active <= 1'b1;
					run_interval_counter <= 26'd0;
					run_interval_limit <= speed_limit(speed_mode);
				end
			end
		end

		// KEY2 starts exactly one instruction only while the panel is paused.
		if (key2_event && !key3_event && !run_mode && !instruction_active && !halted)
			instruction_active <= 1'b1;

		if (run_mode && !halted) begin
			if (run_interval_counter < run_interval_limit)
				run_interval_counter <= run_interval_counter + 1'b1;
		end else if (!instruction_active) begin
			run_interval_counter <= 26'd0;
		end

		if (halted) begin
			// HLT dung clock muc thap; nut doi trang/toc do van duoc xu ly.
			instruction_active <= 1'b0;
			run_mode <= 1'b0;
			cpu_half_counter <= 15'd0;
			cpu_clk <= 1'b0;
		end else if (instruction_active) begin
			if (instruction_done_event) begin
				instruction_active <= 1'b0;
				cpu_half_counter <= 15'd0;
				cpu_clk <= 1'b0;
			end else if (cpu_half_counter == CPU_HALF_TICKS) begin
				cpu_half_counter <= 15'd0;
				cpu_clk <= ~cpu_clk;
			end else begin
				cpu_half_counter <= cpu_half_counter + 1'b1;
			end
		end else begin
			cpu_half_counter <= 15'd0;
			cpu_clk <= 1'b0;
			if (run_mode && !key3_event &&
			    (run_interval_counter == run_interval_limit)) begin
				instruction_active <= 1'b1;
				run_interval_counter <= 26'd0;
				run_interval_limit <= speed_limit(speed_mode);
			end
		end
	end
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n)
		scan_counter <= 16'd0;
	else
		scan_counter <= scan_counter + 1'b1;
end

always @(*) begin
	sel = 6'b111111;
	// Quet nhanh tung digit; mat nguoi thay nhu ca sau digit cung sang.
	// SEL va SEG tich cuc muc thap. SEL[5] o tren, SEL[0] o duoi tren board.
	case (scan_counter[15:13])
		3'd0: begin sel = 6'b111110; digit_char = select_char(display_page, reg_a, reg_b, reg_c, pc, 3'd0); end
		3'd1: begin sel = 6'b111101; digit_char = select_char(display_page, reg_a, reg_b, reg_c, pc, 3'd1); end
		3'd2: begin sel = 6'b111011; digit_char = select_char(display_page, reg_a, reg_b, reg_c, pc, 3'd2); end
		3'd3: begin sel = 6'b110111; digit_char = select_char(display_page, reg_a, reg_b, reg_c, pc, 3'd3); end
		3'd4: begin sel = 6'b101111; digit_char = select_char(display_page, reg_a, reg_b, reg_c, pc, 3'd4); end
		default: begin sel = 6'b011111; digit_char = select_char(display_page, reg_a, reg_b, reg_c, pc, 3'd5); end
	endcase
	seg = char_to_7seg(digit_char);
end

function [4:0] select_char;
	input page;
	input [7:0] a, b, c;
	input [15:0] p;
	input [2:0] index;
	reg [29:0] view;
	begin
		if (!page)
			view = {5'h0a, {1'b0, a[7:4]}, {1'b0, a[3:0]},
				5'h0b, {1'b0, b[7:4]}, {1'b0, b[3:0]}};
		else
			view = {5'h0c, {1'b0, c[7:4]}, {1'b0, c[3:0]},
				CHAR_P, {1'b0, p[7:4]}, {1'b0, p[3:0]}};
		select_char = view[(index * 5) +: 5];
	end
endfunction

function [7:0] char_to_7seg;
	input [4:0] value;
	begin
		case (value)
			5'h00: char_to_7seg = 8'b11000000;
			5'h01: char_to_7seg = 8'b11111001;
			5'h02: char_to_7seg = 8'b10100100;
			5'h03: char_to_7seg = 8'b10110000;
			5'h04: char_to_7seg = 8'b10011001;
			5'h05: char_to_7seg = 8'b10010010;
			5'h06: char_to_7seg = 8'b10000010;
			5'h07: char_to_7seg = 8'b11111000;
			5'h08: char_to_7seg = 8'b10000000;
			5'h09: char_to_7seg = 8'b10010000;
			5'h0a: char_to_7seg = 8'b10001000;
			5'h0b: char_to_7seg = 8'b10000011;
			5'h0c: char_to_7seg = 8'b11000110;
			5'h0d: char_to_7seg = 8'b10100001;
			5'h0e: char_to_7seg = 8'b10000110;
			5'h0f: char_to_7seg = 8'b10001110;
			CHAR_P: char_to_7seg = 8'b10001100;
			default: char_to_7seg = 8'b11111111;
		endcase
	end
endfunction

endmodule

// Independent, stable-state debounce. Both press and release must stay
// unchanged for STABLE_TICKS clocks; a held button generates one pulse.
module ax309_key(clk, rst_n, key_n, pressed);
// LOC NUT: dong bo hai tang, doi trang thai moi on dinh 20 ms moi chap nhan.
// pressed chi cao mot clock khi nhan; giu nut khong lap, phai nha on dinh.
parameter [19:0] STABLE_TICKS = 20'd1000000;
input clk, rst_n, key_n;
output reg pressed;
(* ASYNC_REG = "TRUE" *) reg sync0, sync1;
reg stable;
reg [19:0] count;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sync0 <= 1'b1;
        sync1 <= 1'b1;
        stable <= 1'b1;
        count <= 20'd0;
        pressed <= 1'b0;
    end else begin
        sync0 <= key_n;
        sync1 <= sync0;
        pressed <= 1'b0;
        if (sync1 == stable)
            count <= 20'd0;
        else if (count == STABLE_TICKS - 1'b1) begin
            count <= 20'd0;
            stable <= sync1;
            pressed <= !sync1;
        end else
            count <= count + 1'b1;
    end
end
endmodule

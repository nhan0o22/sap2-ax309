// Standalone AX309 front-panel diagnostic.
// It deliberately does not instantiate SAP2, RAM, or microcode.
// DEMO I/O RIENG: kiem tra nut, cuc tinh va thu tu LED; khong chay CPU SAP2.
// Hien 012345, 89AbCd, quet so 8 tung vi tri va bao ma nut vua bam.
module io_demo(CLK, RST, KEY1_N, KEY2_N, KEY3_N, KEY4_N, SEG, SEL, LED);

parameter SIMULATION = 0;

input CLK;
input RST;
input KEY1_N;
input KEY2_N;
input KEY3_N;
input KEY4_N;
output reg [7:0] SEG;
output reg [5:0] SEL;
output [3:0] LED;

localparam [19:0] DEBOUNCE_TICKS = SIMULATION ? 20'd4 : 20'd999999;
localparam [24:0] DEMO_TICKS = SIMULATION ? 25'd8 : 25'd24999999;

reg key1_sync0, key1_sync1, key1_prev;
reg key2_sync0, key2_sync1, key2_prev;
reg key3_sync0, key3_sync1, key3_prev;
reg key4_sync0, key4_sync1, key4_prev;
reg [19:0] debounce_counter;
reg key1_event, key2_event, key3_event, key4_event;

reg [24:0] demo_counter;
reg [1:0] led_index;
reg [2:0] display_phase;
reg [2:0] last_key;
reg [1:0] key_notice_ticks;
reg [15:0] scan_counter;
reg [3:0] digit_value;

assign LED = (4'b0001 << led_index);

always @(posedge CLK or negedge RST) begin
	if (!RST) begin
		key1_sync0 <= 1'b1;
		key1_sync1 <= 1'b1;
		key1_prev <= 1'b1;
		key2_sync0 <= 1'b1;
		key2_sync1 <= 1'b1;
		key2_prev <= 1'b1;
		key3_sync0 <= 1'b1;
		key3_sync1 <= 1'b1;
		key3_prev <= 1'b1;
		key4_sync0 <= 1'b1;
		key4_sync1 <= 1'b1;
		key4_prev <= 1'b1;
		debounce_counter <= 20'd0;
		key1_event <= 1'b0;
		key2_event <= 1'b0;
		key3_event <= 1'b0;
		key4_event <= 1'b0;
		demo_counter <= 25'd0;
		led_index <= 2'd0;
		display_phase <= 3'd0;
		last_key <= 3'd0;
		key_notice_ticks <= 2'd0;
		scan_counter <= 16'd0;
	end else begin
		key1_sync0 <= KEY1_N;
		key1_sync1 <= key1_sync0;
		key2_sync0 <= KEY2_N;
		key2_sync1 <= key2_sync0;
		key3_sync0 <= KEY3_N;
		key3_sync1 <= key3_sync0;
		key4_sync0 <= KEY4_N;
		key4_sync1 <= key4_sync0;

		key1_event <= 1'b0;
		key2_event <= 1'b0;
		key3_event <= 1'b0;
		key4_event <= 1'b0;
		if (debounce_counter == DEBOUNCE_TICKS) begin
			debounce_counter <= 20'd0;
			if (key1_prev && !key1_sync1) key1_event <= 1'b1;
			if (key2_prev && !key2_sync1) key2_event <= 1'b1;
			if (key3_prev && !key3_sync1) key3_event <= 1'b1;
			if (key4_prev && !key4_sync1) key4_event <= 1'b1;
			key1_prev <= key1_sync1;
			key2_prev <= key2_sync1;
			key3_prev <= key3_sync1;
			key4_prev <= key4_sync1;
		end else begin
			debounce_counter <= debounce_counter + 1'b1;
		end

		if (demo_counter == DEMO_TICKS) begin
			demo_counter <= 25'd0;
			led_index <= led_index + 1'b1;
			if (display_phase == 3'd7)
				display_phase <= 3'd0;
			else
				display_phase <= display_phase + 1'b1;
			if (key_notice_ticks != 2'd0)
				key_notice_ticks <= key_notice_ticks - 1'b1;
		end else begin
			demo_counter <= demo_counter + 1'b1;
		end

		if (key1_event) begin
			last_key <= 3'd1;
			key_notice_ticks <= 2'd2;
		end else if (key2_event) begin
			last_key <= 3'd2;
			key_notice_ticks <= 2'd2;
		end else if (key3_event) begin
			last_key <= 3'd3;
			key_notice_ticks <= 2'd2;
		end else if (key4_event) begin
			last_key <= 3'd4;
			key_notice_ticks <= 2'd2;
		end

		scan_counter <= scan_counter + 1'b1;
	end
end

always @(*) begin
	SEL = 6'b111111;
	digit_value = 4'h0;
	if (key_notice_ticks != 2'd0) begin
		case (scan_counter[15:13])
			3'd0: begin SEL = 6'b111110; digit_value = {1'b0, last_key}; end
			3'd1: begin SEL = 6'b111101; digit_value = 4'h0; end
			3'd2: begin SEL = 6'b111011; digit_value = 4'h0; end
			3'd3: begin SEL = 6'b110111; digit_value = 4'h0; end
			3'd4: begin SEL = 6'b101111; digit_value = 4'h0; end
			default: begin SEL = 6'b011111; digit_value = 4'h0; end
		endcase
	end else if (display_phase == 3'd0) begin
		// AX309 observation: SEL[0] drives the bottom physical digit and
		// SEL[5] drives the top one.  Reverse test values so the human-facing
		// display reads 012345 from top to bottom.
		case (scan_counter[15:13])
			3'd0: begin SEL = 6'b111110; digit_value = 4'h5; end
			3'd1: begin SEL = 6'b111101; digit_value = 4'h4; end
			3'd2: begin SEL = 6'b111011; digit_value = 4'h3; end
			3'd3: begin SEL = 6'b110111; digit_value = 4'h2; end
			3'd4: begin SEL = 6'b101111; digit_value = 4'h1; end
			default: begin SEL = 6'b011111; digit_value = 4'h0; end
		endcase
	end else if (display_phase == 3'd1) begin
		case (scan_counter[15:13])
			3'd0: begin SEL = 6'b111110; digit_value = 4'hd; end
			3'd1: begin SEL = 6'b111101; digit_value = 4'hc; end
			3'd2: begin SEL = 6'b111011; digit_value = 4'hb; end
			3'd3: begin SEL = 6'b110111; digit_value = 4'ha; end
			3'd4: begin SEL = 6'b101111; digit_value = 4'h9; end
			default: begin SEL = 6'b011111; digit_value = 4'h8; end
		endcase
	end else begin
		case (display_phase)
			3'd2: SEL = 6'b011111;
			3'd3: SEL = 6'b101111;
			3'd4: SEL = 6'b110111;
			3'd5: SEL = 6'b111011;
			3'd6: SEL = 6'b111101;
			default: SEL = 6'b111110;
		endcase
		digit_value = 4'h8;
	end
	SEG = hex_to_7seg(digit_value);
end

function [7:0] hex_to_7seg;
	input [3:0] value;
	begin
		case (value)
			4'h0: hex_to_7seg = 8'b11000000;
			4'h1: hex_to_7seg = 8'b11111001;
			4'h2: hex_to_7seg = 8'b10100100;
			4'h3: hex_to_7seg = 8'b10110000;
			4'h4: hex_to_7seg = 8'b10011001;
			4'h5: hex_to_7seg = 8'b10010010;
			4'h6: hex_to_7seg = 8'b10000010;
			4'h7: hex_to_7seg = 8'b11111000;
			4'h8: hex_to_7seg = 8'b10000000;
			4'h9: hex_to_7seg = 8'b10010000;
			4'ha: hex_to_7seg = 8'b10001000;
			4'hb: hex_to_7seg = 8'b10000011;
			4'hc: hex_to_7seg = 8'b11000110;
			4'hd: hex_to_7seg = 8'b10100001;
			4'he: hex_to_7seg = 8'b10000110;
			default: hex_to_7seg = 8'b10001110;
		endcase
	end
endfunction

endmodule

/**
 * Module: top
 * Mo ta: CPU SAP2 xu ly du lieu 8 bit, dieu khien bang microcode.
 * Phan cung: Xilinx Spartan-6 XC6SLX9 tren board AX309.
 *
 * Architecture:
 *   - 16-bit system bus (Von Neumann)
 *   - 8-bit registers: A, B, C (general purpose)
 *   - 16-bit PC (Program Counter)
 *   - 32KB Block RAM (program + data)
 *   - 4096×35 Microcode ROM
 *   - ALU: 8 operations (ADD,SUB,AND,OR,XOR,CMA,RAL,RAR)
 *   - Flags: Zero (Z), Sign (S)
 *
 * Instruction Execution:
 *   Stage 0-2: Fetch instruction from memory
 *   Stage 3+:  Execute (microcode-driven, instruction dependent)
 *   CTRL_END signal returns to stage 0
 *
 * Control Signals (35 bits):
 *   [34]    - CTRL_END (end of instruction)
 *   [33]    - HLT (halt CPU)
 *   [32:29] - A register control (load, enable, inc, dec)
 *   [28:25] - B register control
 *   [24:21] - C register control
 *   [20:18] - Flags control (load_a, load_b, load_c)
 *   [17:13] - ALU control (op[2:0], load, enable)
 *   [12]    - IR load
 *   [11:9]  - PC control (inc, load, enable)
 *   [8:6]   - Memory control (MAR_loadh, MAR_loadl, MDR_load)
 *   [5]     - MDR enable
 *   [4:2]   - RAM control (load, enable_h, enable_l)
 *   [1:0]   - Subroutine control (call, ret)
 */
// CUM 1 - NOI CAC KHOI CPU: day la module tong, duoc chon lam top trong ISE.
// FPGA tao thanh phan cung CPU; program.bin chua lenh ma CPU se doc va thuc thi.
// Luong chinh: PC -> RAM -> IR -> microcode -> bus/ALU/thanh ghi -> hien thi.
module top(CLK, RST, KEY1_N, KEY2_N, KEY3_N, KEY4_N, SEG, SEL, LED);
parameter SIMULATION = 0;

input CLK;
input RST, KEY1_N, KEY2_N, KEY3_N, KEY4_N;
output [7:0] SEG;
output [5:0] SEL;
output [3:0] LED;

// ============================================================================
// BUS HE THONG: duong truyen du lieu chung rong 16 bit
// ============================================================================
reg [15:0] bus;
// Bus la duong truyen chung. Khoi ben duoi chon mot nguon dua du lieu len bus.
// A/B/C va ALU dung 8 bit; PC va dia chi dung 16 bit.

// ============================================================================
// HANG SO: vi tri bit dieu khien, opcode nhay va co trang thai
// ============================================================================
localparam CTRL_END = 34;       // Bit bao ket thuc mot lenh may
localparam OP_JZ = 8'hCA;       // Nhay neu co Z bang 1 (ket qua bang 0)
localparam OP_JNZ = 8'hC2;      // Nhay neu co Z bang 0
localparam OP_JM = 8'hFA;       // Nhay neu co S bang 1 (bit dau bang 1)
localparam FLAG_Z = 1;          // Vi tri co Zero trong flags_out
localparam FLAG_S = 0;          // Vi tri co Sign trong flags_out

// ============================================================================
// DIEU KHIEN MICROCODE: tra ROM de phat tin hieu cho tung micro-step
// ============================================================================
// CUM 2 - DIEU KHIEN: moi lenh may duoc chia thanh nhieu micro-step (stage).
// ROM microcode cho biet stage nao can nap thanh ghi, doc RAM, cong hay nhay.
reg [34:0] ctrl_word_raw;       // Dau ra ROM da chot, khong reset bat dong bo
reg ctrl_active;                // Cho phep dieu khien; reset thi che cac tin hieu cu
reg instruction_done_toggle;    // Dao trang thai moi khi hoan tat lenh thong thuong
reg sequencer_primed;           // Da nap dieu khien stage 0 sau reset hay chua
wire [34:0] ctrl_word;          // Tu dieu khien thuc te sau khi che reset
(* ROM_STYLE = "BLOCK" *) reg [34:0] ctrl_rom [0:4095];  // 4096 tu, moi tu 35 bit
reg [3:0] stage;                // Micro-step hien tai, tu 0 den 15
reg [3:0] next_stage;           // Micro-step ke tiep do logic to hop tinh
// Fetch dung chung stage 0..2 cua opcode 00, tranh dung opcode cu con trong IR.
// Tu stage 3, dia chi ROM ghep opcode 8 bit voi stage 4 bit (tong 12 bit).
wire [3:0] rom_stage = sequencer_primed ? next_stage : 4'd0;
wire [11:0] ctrl_addr = (rom_stage <= 4'd2) ?
    {8'h00, rom_stage} : {ir_out, rom_stage};

initial begin
	// File nay la bang dieu khien CPU, khong phai chuong trinh phep tinh.
	$readmemb("ctrl_rom.bin", ctrl_rom);
end

// Keep the ROM output register free of asynchronous reset so XST can infer
// Block RAM. ctrl_active is asynchronously cleared instead, immediately
// masking HLT and all control signals while reset holds cpu_clk low.
assign ctrl_word = ctrl_active ? ctrl_word_raw : 35'b0;
// Khi reset, che ngay tin hieu dieu khien/HLT du clock CPU da dung.
// Khong reset truc tiep dau ra ROM de giu kha nang suy dien Block RAM.

// ============================================================================
// BO CHON BUS (logic to hop)
// Sau nguon A, B, C, ALU, PC, MDR; chon theo thu tu uu tien if/else
// ============================================================================
always @(*) begin
	if (a_en) begin
		bus = a_out;            // Register A → Bus
	end else if (b_en) begin
		bus = b_out;            // Register B → Bus
	end else if (c_en) begin
		bus = c_out;            // Register C → Bus
	end else if (alu_en) begin
		bus = alu_out;          // ALU result → Bus
	end else if (pc_en) begin
		bus = pc_out;           // Program Counter → Bus
	end else if (mdr_en) begin
		bus = mem_out;          // Memory Data Register → Bus
	end else begin
		bus = 16'b0;            // Default: Bus idle (all zeros)
	end
end


// ============================================================================
// CLOCK VA RESET: RST ngoai board tich cuc thap, rst noi bo tich cuc cao
// ============================================================================
wire rst;
assign rst = ~RST;             // Dedicated active-low board reset only
wire hlt;                        // Halt signal from control word
wire clk;                        // CPU clock (from I/O module)
wire cpu_clk;                    // Divided/stepped clock from ax309_io
wire [7:0] seg_out;
wire [5:0] sel_out;
assign SEG = seg_out;
assign SEL = sel_out;
assign clk = cpu_clk;

// ============================================================================
// BO DEM CHUONG TRINH PC 16 BIT: giu dia chi byte can doc
// ============================================================================
wire pc_inc;                     // Increment PC
wire pc_load;                    // Load PC from bus
wire pc_en;                      // Enable PC onto bus
wire [15:0] pc_out;              // PC output
pc pc(
	.clk(clk),
	.rst(rst),
	.inc(pc_inc),
	.load(pc_load),
	.bus(bus),
	.out(pc_out)
);

// ============================================================================
// THANH GHI LENH IR 8 BIT: giu opcode, dung lai module register
// ============================================================================
wire ir_load;                    // Load IR from bus
wire [7:0] ir_out;               // Current instruction opcode
register instruction_register(
	.clk(clk),
	.rst(rst),
	.load(ir_load),
	.inc(1'b0),
	.dec(1'b0),
	.bus(bus),
	.out(ir_out)
);

// ============================================================================
// BO NHO 32 KiB BLOCK RAM: chua lenh va du lieu
// ============================================================================
wire mar_loadh;                  // Load MAR high byte
wire mar_loadl;                  // Load MAR low byte
wire mdr_load;                   // Load MDR from bus
wire mdr_en;                     // Enable MDR onto bus
wire ram_load;                   // Write to RAM
wire ram_enh;                    // Read RAM high byte
wire ram_enl;                    // Read RAM low byte
wire call;                       // Save return address
wire ret;                        // Restore return address
wire [15:0] mem_out;             // MDR output
memory mem(
	.clk(clk),
	.rst(rst),
	.mar_loadh(mar_loadh),
	.mar_loadl(mar_loadl),
	.mdr_load(mdr_load),
	.ram_load(ram_load),
	.ram_enh(ram_enh),
	.ram_enl(ram_enl),
	.call(call),
	.ret(ret),
	.bus(bus),
	.out(mem_out)
);

// ============================================================================
// THANH GHI A 8 BIT: giu tong tich luy trong demo
// ============================================================================
wire a_load;
wire a_en;
wire a_inc;
wire a_dec;
wire [7:0] a_out;
// CUM 3 - DU LIEU: demo dung A lam tong, B la so cong, C la so vong lap.
register reg_a(
	.clk(clk),
	.rst(rst),
	.load(a_load),
	.inc(a_inc),
	.dec(a_dec),
	.bus(bus),
	.out(a_out)
);

// ============================================================================
// THANH GHI B 8 BIT: giu so duoc cong (0C hex = 12) trong demo
// ============================================================================
wire b_load;
wire b_en;
wire b_inc;
wire b_dec;
wire [7:0] b_out;
register reg_b(
	.clk(clk),
	.rst(rst),
	.load(b_load),
	.inc(b_inc),
	.dec(b_dec),
	.bus(bus),
	.out(b_out)
);

// ============================================================================
// THANH GHI C 8 BIT: dem so vong lap con lai trong demo
// ============================================================================
wire c_load;
wire c_en;
wire c_inc;
wire c_dec;
wire [7:0] c_out;
register reg_c(
	.clk(clk),
	.rst(rst),
	.load(c_load),
	.inc(c_inc),
	.dec(c_dec),
	.bus(bus),
	.out(c_out)
);

// ============================================================================
// KHOI SO HOC VA LOGIC ALU: demo dung phep ADD, khong dung bo nhan rieng
// ============================================================================
wire [2:0] alu_op;               // ALU operation select
wire alu_load;                   // Load temp register from bus
wire alu_en;                     // Enable ALU result onto bus
wire [7:0] alu_out;              // ALU result
alu alu(
	.clk(clk),
	.rst(rst),
	.a(a_out),
	.load(alu_load),
	.op(alu_op),
	.bus(bus),
	.out(alu_out)
);

// ============================================================================
// CO TRANG THAI: Zero bao bang 0, Sign lay bit 7
// ============================================================================
wire [1:0] flags_out;            // [1]=Zero, [0]=Sign
wire flags_lda;                  // Load flags from register A
wire flags_ldb;                  // Load flags from register B
wire flags_ldc;                  // Load flags from register C
flags flags(
	.clk(clk),
	.rst(rst),
	.a(a_out),
	.b(b_out),
	.c(c_out),
	.load_a(flags_lda),
	.load_b(flags_ldb),
	.load_c(flags_ldc),
	.out(flags_out)
);

// ============================================================================
// GIAO TIEP AX309: loc nut, chay tung lenh/tu dong, hien thi thanh ghi
// ============================================================================
ax309_io #(.SIMULATION(SIMULATION)) io(
	.clk(CLK), .rst_n(RST), .key1_n(KEY1_N),
	.key2_n(KEY2_N), .key3_n(KEY3_N), .key4_n(KEY4_N),
	.reg_a(a_out), .reg_b(b_out), .reg_c(c_out), .pc(pc_out), .halted(hlt),
	.instruction_done_toggle(instruction_done_toggle),
	.cpu_clk(cpu_clk), .seg(seg_out), .sel(sel_out), .led(LED)
);

// ============================================================================
// THANH GHI STAGE VA DOC ROM MICROCODE (logic tuan tu)
// Note: Using negedge to sample next_stage computed on posedge.
// ctrl_active resets asynchronously because HLT stops cpu_clk low; the ROM
// output register itself stays synchronous to preserve Block RAM inference.
// The first falling CPU edge after reset primes ctrl_word_raw with stage 0.
// No instruction-completion toggle is issued for this bootstrap edge.
// ============================================================================
// Canh len thuc hien du lieu; canh xuong cap nhat stage va dieu khien.
// Lan dau sau reset chi nap stage 0, chua duoc bao hoan thanh mot lenh.
always @(negedge clk or posedge rst) begin
	if (rst) begin
		stage <= 4'b0000;
		ctrl_active <= 1'b0;
		instruction_done_toggle <= 1'b0;
		sequencer_primed <= 1'b0;
	end else if (!hlt) begin
		ctrl_active <= 1'b1;
		if (!sequencer_primed) begin
			stage <= 4'd0;
			sequencer_primed <= 1'b1;
		end else begin
			stage <= next_stage;
			if ((stage != 4'd0) && (next_stage == 4'd0))
				// Doi toggle sau thao tac cuoi de I/O dung dung tai bien lenh.
				instruction_done_toggle <= ~instruction_done_toggle;
		end
	end
end

always @(negedge clk) begin
	if (!hlt) begin
		ctrl_word_raw <= ctrl_rom[ctrl_addr];
	end
end

// ============================================================================
// LOGIC TO HOP TINH STAGE KE TIEP
// Determines next execution stage based on current state
// ============================================================================
always @(*) begin
	// Default: Stage 0 (prevents latches)
	// Stage 0..2 lay opcode; stage tiep theo thuc hien theo opcode trong IR.
	next_stage = 4'b0000;

	// Stage 2: Check for NOP instruction (0x00)
	if (stage == 4'd2) begin
		if (ir_out == 8'h00)
			next_stage = 4'b0000;  // NOP: restart immediately
		else
			next_stage = 4'd3;     // Continue to execute stage

	// Stage 6: Check for failed conditional jumps
	// (Jump condition not met → skip jump, restart fetch)
	end else if ((ir_out == OP_JZ && stage == 4'd6 && flags_out[FLAG_Z] == 1'b0) ||
	           (ir_out == OP_JNZ && stage == 4'd6 && flags_out[FLAG_Z] == 1'b1) ||
	           (ir_out == OP_JM && stage == 4'd6 && flags_out[FLAG_S] == 1'b0)) begin
		next_stage = 4'b0000;  // Condition false: don't jump

	// Check CTRL_END flag: instruction complete
	end else if (ctrl_word[CTRL_END]) begin
		next_stage = 4'b0000;  // End of instruction: restart fetch

	// Default: advance to next stage
	end else begin
		next_stage = stage + 4'd1;
	end
end

// ============================================================================
// TACH TU DIEU KHIEN 35 BIT THANH CAC TIN HIEU CHO TUNG KHOI
// Microcode ROM output drives all CPU components
// ============================================================================
assign {
	hlt,                             // [33]    Halt CPU
	a_load, a_en, a_inc, a_dec,      // [32:29] Register A control
	b_load, b_en, b_inc, b_dec,      // [28:25] Register B control
	c_load, c_en, c_inc, c_dec,      // [24:21] Register C control
	flags_lda, flags_ldb, flags_ldc, // [20:18] Flags load control
	alu_op, alu_load, alu_en,        // [17:13] ALU operation and control
	ir_load,                         // [12]    Instruction Register load
	pc_inc, pc_load, pc_en,          // [11:9]  Program Counter control
	mar_loadh, mar_loadl, mdr_load,  // [8:6]   Memory address/data control
	mdr_en,                          // [5]     MDR enable to bus
	ram_load, ram_enh, ram_enl,      // [4:2]   RAM read/write control
	call, ret                        // [1:0]   Subroutine call/return
} = ctrl_word[33:0];

endmodule




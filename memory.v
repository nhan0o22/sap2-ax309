// BO NHO: MAR giu dia chi, MDR giu du lieu, RAM luu chuong trinh va du lieu.
// return_addr giu dia chi quay ve khi CALL/RET. RAM thuc te co 32768 byte.
module memory(clk, rst, mar_loadh, mar_loadl, mdr_load, ram_load,
	ram_enh, ram_enl, call, ret, bus, out);

input clk;
input rst;
input mar_loadh;
input mar_loadl;
input mdr_load;
input ram_load;
input ram_enh;
input ram_enl;
input call;
input ret;
input [15:0] bus;
output [15:0] out;

reg[15:0] mar;
reg[15:0] mdr;
reg[15:0] return_addr;
(* RAM_STYLE = "BLOCK" *) reg[7:0] ram[0:32767];
reg[7:0] ram_data_reg;
// A Block RAM read is synchronous.  These bits remember which MDR byte is
// being fetched so that the fresh BRAM output is visible to the microcode on
// the following CPU stage, rather than the stale output from the last address.
reg[1:0] ram_read_pending;

// Declare the array before passing it to a system task: XST's elaborator
// can otherwise resolve the forward reference as a scalar [0:0]. The file
// has exactly 32768 words, so explicit readmemh index arguments are unneeded.
initial begin
	// Anh du 32768 byte duoc script sinh tu program.bin, phan du dien 00.
	// Phai khai bao ram truoc initial de tranh loi elaboration cua XST.
	$readmemh("program_ise.mem", ram);
end

// A registered read plus write on the same clock is XST's Block-RAM template.
// Keeping ram_data_reg on the RAM output is essential: reading ram directly
// from the MDR process makes XST implement this 32 KiB store as LUT RAM.
always @(posedge clk) begin
	// Doc dong bo: ram_data_reg chi nhan du lieu moi sau canh clock nay.
	// Khong xoa toan bo mang RAM khi reset; giu mau suy dien Block RAM.
	if (ram_load) begin
		ram[mar[14:0]] <= mdr[7:0];
	end
	ram_data_reg <= ram[mar[14:0]];
end

// Control registers. Reset is asynchronous so CPU reset also works after HLT
// has stopped the generated CPU clock.
always @(posedge clk or posedge rst) begin
	// Reset bat dong bo van xoa thanh ghi khi CPU dung clock sau HLT.
	if (rst) begin
		mar <= 16'b0;
		mdr <= 16'b0;
		return_addr <= 16'b0;
		ram_read_pending <= 2'b00;
	end else begin
		if (ram_enh)
			ram_read_pending <= 2'b10;
		else if (ram_enl)
			ram_read_pending <= 2'b01;
		else
			ram_read_pending <= 2'b00;

		if (mar_loadh) begin
			mar[15:8] <= bus[15:8];
		end

		if (mar_loadl) begin
			mar[7:0] <= bus[7:0];
		end

		if (call) begin
			return_addr <= bus;
		end

		if (ret) begin
			mdr <= return_addr;
		end else if (mdr_load) begin
			// An explicit bus write has priority over a completed RAM fetch.
			// The supplied microcode never overlaps these controls, and this
			// priority keeps standalone memory writes deterministic.
			mdr[7:0] <= bus[7:0];
		end else if (ram_read_pending[1]) begin
			mdr[15:8] <= ram_data_reg;
		end else if (ram_read_pending[0]) begin
			mdr[7:0] <= ram_data_reg;
		end
	end
end

// During the stage immediately after a RAM read, expose the just-registered
// Block-RAM output on the bus.  The same edge copies it into MDR for later
// stages (for example while constructing a 16-bit address).
assign out = ram_read_pending[1] ? {ram_data_reg, mdr[7:0]} :
             ram_read_pending[0] ? {mdr[15:8], ram_data_reg} : mdr;
// Pending chon byte RAM vua doc de stage sau khong nhan du lieu cu.
// Dong thoi du lieu se duoc luu vao MDR de dung o cac stage tiep theo.

endmodule

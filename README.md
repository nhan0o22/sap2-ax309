# SAP2 CPU trên FPGA AX309

CPU SAP2 mô tả bằng Verilog cho board ALINX AX309, FPGA **Xilinx Spartan-6 xc6slx9-ftg256-2**, clock ngoài **50 MHz**, công cụ **ISE 14.7**.

Chương trình mẫu tính **12 × 8 bằng cộng lặp**. Kết quả cuối: **A = 60h (96 thập phân), B = 0Ch, C = 00h**.

## Mở và build

1. Clone hoặc tải repository, giải nén toàn bộ vào một thư mục.
2. Mở **sap2v2.xise** bằng ISE 14.7; kiểm tra top Implementation là **top**, không phải testbench.
3. Chạy Synthesize, Implement Design và Generate Programming File.
4. Nạp **top.bit vừa tạo** qua JTAG. Nếu build lỗi, không nạp file bit cũ.

Ảnh `program_ise.mem` đầy đủ đã có sẵn. Khi sửa `program.bin`, chạy PowerShell trong thư mục repository:

```powershell
.\prepare-program.ps1
```

Sau đó build và nạp lại. Không cần thư mục staging hoặc script đồng bộ khi build trực tiếp từ repository này.

## Điều khiển

| Nút | Chức năng |
|---|---|
| RST | Reset CPU, pause, trang A/B, tốc độ 1 lệnh/giây |
| KEY1 | Đổi tốc độ 1 / 2 / 4 lệnh mỗi giây |
| KEY2 | Thực hiện một lệnh đầy đủ khi pause |
| KEY3 | Chạy / tạm dừng tại biên lệnh |
| KEY4 | Chuyển trang AxxBxx / CxxPxx |

Sau reset, ba lần KEY2 đầu cho PC = 02, 04, 06; B = 0C, C = 08. Lần tiếp theo A = 0C. Khi chương trình dừng: A = 60, C = 00, PC = 000F. Giá trị LED hiển thị theo hệ hex.

## Cấu trúc

- `top.v`: nối CPU, sequencer và ROM microcode.
- `memory.v`: RAM 32 KiB, MAR/MDR và địa chỉ quay về.
- `register.v`, `pc.v`, `alu.v`, `flags.v`: thanh ghi, PC, tính toán và cờ.
- `ax309_io.v`: nút, clock CPU, lịch chạy và hiển thị.
- `program.bin`: chương trình; `program_ise.mem`: ảnh RAM dẫn xuất; `ctrl_rom.bin`: microcode.
- `ax309.ucf`: chân board và timing; `sap2v2.xise`: project CPU.
- `prepare-program.ps1`: tạo lại ảnh RAM khi đổi chương trình.

Repository giữ bộ nguồn cần build và README sử dụng. Demo I/O, testbench, tài liệu ôn thi, script phụ và output build không nằm trong bản này.

Demo xác nhận chương trình mẫu, chưa chứng minh mọi opcode. ALU/thanh ghi 8 bit có thể tràn; cơ chế return_addr hiện không phải stack gọi lồng nhiều mức.

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

Sau đó build và nạp lại. Script `sync-ise-staging.ps1` chỉ cần khi dùng hai thư mục nguồn/staging riêng; truyền `-StagingRoot` đúng máy của bạn.

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
- `io_demo.xise`: project kiểm tra I/O độc lập.
- `*_tb.v`: testbench mô phỏng; không dùng làm top tổng hợp.

## Mô phỏng

Windows cần Icarus Verilog (`iverilog.exe`, `vvp.exe`). Bộ công cụ không được đóng gói trong repository:

```powershell
.\run-sim.ps1 -ToolRoot 'C:\duong-dan\iverilog\bin' -Trace
```

Trong môi trường dòng lệnh ISE Linux đã nạp thiết lập công cụ:

```bash
bash run-sim-ise.sh
```

Không suy kết quả PASS từ synthesis: cần chạy simulator và đọc log PASS/FAIL. Xem giới hạn, lịch sử kiểm thử và xác nhận board trong [SIMULATION_RESULTS.md](SIMULATION_RESULTS.md).

## Tài liệu tiếng Việt

- [Hướng dẫn AX309](README_AX309.md)
- [Thuyết trình 2–3 phút](THUYET_TRINH_SAP2.md)
- [Ôn thi vấn đáp và chức năng từng file](ON_THI_VAN_DAP_SAP2.md)

Demo xác nhận chương trình mẫu, chưa chứng minh mọi opcode. ALU/thanh ghi 8 bit có thể tràn; cơ chế return_addr hiện không phải stack gọi lồng nhiều mức. Repository chỉ chứa nguồn và tài liệu; bitstream, log và artifact ISE/ISim được bỏ qua.

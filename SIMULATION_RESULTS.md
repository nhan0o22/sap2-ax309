# Kết quả kiểm thử SAP2 — 2026-11-05

## Xác nhận sau cùng trên board

Ngày 05/11/2026, người dùng xác nhận code đã chạy đúng trên FPGA sau các
sửa cuối và yêu cầu lưu bài học thành skill. Đây là xác nhận từ người dùng;
không phải phép đo độc lập từng tốc độ hoặc một lần chạy XST/PAR/TRCE mới
do agent thực hiện. Các mục chẩn đoán bên dưới lưu bằng chứng tại từng thời điểm.

Skill tái sử dụng: `fpga-ise-bram-debug` trong thư mục Codex skills cá nhân.

## Baseline trước chỉnh sửa

Chạy Icarus Verilog trên top_tb hiện có: ba bước khởi tạo PC=0002/0004/0006
đã qua. Một kiểm tra HLT thất bại vì kiểm tra phản ứng I/O ngay ở thời điểm
HLT xuất hiện, trước khi bộ điều khiển nhận trạng thái này.

Trace trước sửa xác nhận: RAM_Q=3E, bus=003E ở cạnh nạp IR; sau đó IR=3E,
PC=0001 ở cuối fetch và PC=0002 khi hoàn thành lệnh LD A,00.
Các log baseline nằm trong sim-results/baseline*.log (artifact cục bộ).

## Bản nguồn mới

Lệnh: `./run-sim.ps1 -Trace`

- PASS: memory reset/write/read-low/read-high/call/ret.
- PASS: bốn nút với bounce, giữ, nhả ngắn, nhả ổn định và nhấn lại.
- PASS: io_demo reset, bốn nút, LED walk và display scan.
- PASS: từng lệnh khởi tạo và ADD đầu tiên: PC=02/04/06/07, B=0C, C=08, A=0C.
- PASS: KEY1 đổi tốc độ và quay vòng, không reset/tiến CPU khi pause.
- PASS: KEY4 chỉ đổi trang; KEY3 pause tại biên lệnh.
- PASS: 35 yêu cầu thực thi, A=60 C=00 ở cả ba tốc độ; đo khoảng cách khởi động
  1025/513/257 clock mô phỏng (tương ứng 1000/500/250 ms trên phần cứng).
- PASS: reset sau HLT, chạy lại, KEY1/KEY4 sau HLT, giữ KEY2 không lặp và
  KEY3 ưu tiên khi đồng thời KEY2 trong thời gian chờ tự chạy.

Log bản mới: sim-results/{memory_tb,keys_tb,io_demo_tb,top_tb,trace_tb}.log.

SHA256 baseline giữ nguyên:

```text
program.bin  CABDA7B1D835F6D9CA80D4BBF75F9A26D7D586CA753CB62E18F00C6D21001FE1
ctrl_rom.bin 42B7141624C388BB0EC1B65B176AA21B2C9471403954A8B7C26A5FA067160BEA
```

## Lịch sử chẩn đoán và giới hạn tại thời điểm sửa

Các ghi nhận chưa xác nhận board trong mục này thuộc lịch sử trước xác nhận
sau cùng ở đầu tài liệu; giữ lại để phân biệt kết quả mô phỏng với build và nạp.

Cập nhật lỗi HDLCompiler:532: bản dùng `program_ise.mem` từng gọi readmemh
trước khai báo ram và dùng đối số chỉ số 0..32767. XST báo ram có phạm vi
[0:0] khi elaboration. Đã chuyển toàn bộ khai báo lên trước initial và dùng
readmemh hai đối số với ảnh RAM đầy đủ. Chạy lại run-sim.ps1: cả bốn nhóm
PASS. Chưa xác nhận bằng XST trên bản sửa thứ tự khai báo.

Báo cáo lỗi trong staging ngày 05/11 lúc 12:00 mới hơn top.bit lúc 10:36;
bitstream đó không chứa bản sửa ảnh RAM. Đã thêm check-ise-build.ps1 để
từ chối bitstream khi XST lỗi hoặc bitstream cũ hơn báo cáo/nguồn.

Cập nhật sau khi board tiếp tục báo P01: đã kiểm tra báo cáo build ngày 05/11
10:36. XST dùng đúng nguồn mới, SIMULATION=0, RAM và control ROM là Block RAM;
TRCE ghi Timing errors: 0. Như vậy lỗi không được giải thích bằng việc chọn
nhầm top tổng hợp trong lần build này.

Đã đổi đầu vào khởi tạo RAM sang `program_ise.mem`: ảnh đầy đủ 32768 byte,
mỗi dòng một byte, sinh tự động từ 15 byte `program.bin` và điền phần còn lại
bằng 00. File gốc chương trình và microcode không đổi. Chạy lại run-sim.ps1:
tất cả bốn testbench PASS, không còn cảnh báo thiếu dữ liệu khởi tạo.
Đây là thay đổi để loại bỏ phụ thuộc định dạng/khởi tạo thiếu; chưa có kết
quả XST hoặc thử board với ảnh đầy đủ để chứng minh nguyên nhân cuối cùng.

Chưa tái hiện được lỗi P01/A=B=C=00 của board trong mô phỏng RTL. Thay đổi
fetch và nút đã qua regression, nhưng không đủ bằng chứng kết luận nguyên
nhân lỗi board đã được xử lý.

Không có XST/PAR/TRCE ở PATH Windows; chưa chạy ISE trên bản dùng ảnh RAM đầy đủ.
Cần clean build rồi xác nhận RAM/ROM vẫn là Block RAM, RAMB16 trong giới hạn,
TS_CLK/TS_CPU_CLK đạt timing và nạp top.bit vừa tạo để đối chiếu board.
Các báo cáo ISE ngày 03/11 là của bản trước, không được tính cho lần sửa này.

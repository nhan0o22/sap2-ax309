# Thuyết trình SAP2 trên FPGA trong 2–3 phút

## Cách chia code thành bốn cụm

| Cụm | File nên mở | Ý chính cần hiểu |
|---|---|---|
| 1. Chương trình và bộ nhớ | `program.bin`, `memory.v`, `pc.v` | RAM chứa lệnh; PC chỉ địa chỉ byte; MAR giữ địa chỉ truy cập, MDR giữ dữ liệu. |
| 2. Bộ điều khiển | `top.v`, `ctrl_rom.bin` | IR giữ opcode; stage chia lệnh thành thao tác nhỏ; microcode phát tín hiệu điều khiển. |
| 3. Tính toán và lưu kết quả | `register.v`, `alu.v`, `flags.v` | A giữ tổng, B giữ số cộng, C đếm vòng; ALU cộng; cờ Z giúp kết thúc vòng lặp. |
| 4. Nút và hiển thị | `ax309_io.v` | Nhận nút đã lọc, cho chạy một lệnh/tự động, hiển thị giá trị thanh ghi. |

`top.v` nối tất cả các cụm. `io_demo_top.v` chỉ kiểm tra phần cứng I/O;
`ir.v` và `clock.v` là module riêng hiện không được top sử dụng.
Các file `_tb.v` dùng mô phỏng kiểm tra, không phải phần cứng để nạp board.

## Lời nói mẫu khoảng 2 phút 40 giây

### 1. Giới thiệu — 25 giây

“Đề tài của em là xây dựng CPU SAP2 trên FPGA AX309. Ban đầu có thể hình dung
CPU bằng sơ đồ Logisim; ở đây em mô tả các khối bằng Verilog và dùng công cụ
ISE tạo bitstream để cấu hình FPGA thành mạch CPU thực tế. FPGA không chạy
file Verilog như một chương trình phần mềm. Sau khi cấu hình, CPU do em tạo
sẽ đọc chương trình trong RAM và thực hiện từng lệnh.”

### 2. Luồng thực hiện một lệnh — 40 giây

“Code được chia thành bốn cụm: bộ nhớ, điều khiển, tính toán và giao tiếp.
PC giữ địa chỉ byte cần đọc. Bộ nhớ đưa mã lệnh vào thanh ghi IR. Trong top,
bộ điều khiển đọc bảng microcode để chia một lệnh thành nhiều thao tác nhỏ,
như đọc dữ liệu, đưa dữ liệu lên bus, tính toán và ghi kết quả.
Bus là đường truyền chung giữa các khối. ALU thực hiện phép toán, còn các
thanh ghi giữ kết quả. Vì một lệnh có thể dài nhiều byte nên một lần chạy
lệnh không nhất thiết làm PC tăng đúng một.”

### 3. Phép tính đang chạy — 35 giây

“Chương trình mẫu tính 12 nhân 8 bằng cộng lặp. Đầu tiên CPU đặt A bằng 0,
B bằng 12 và C bằng 8. Mỗi vòng, CPU cộng B vào A rồi giảm C một đơn vị.
Khi C bằng 0, cờ Zero được bật, chương trình nhảy ra khỏi vòng lặp và dừng
bằng lệnh HLT. Kết quả A bằng 96 ở hệ thập phân, tương ứng 60 ở hệ hex.
Trên LED, B hiển thị 0C nghĩa là 12, C hiển thị 08 nghĩa là 8.”

### 4. Thao tác trình diễn — 40 giây

“Em nhấn RST để đưa CPU về ban đầu và tạm dừng. KEY2 thực hiện đúng một lệnh
máy đầy đủ. Ba lần đầu, PC lần lượt là 02, 04, 06; B trở thành 0C và C
trở thành 08. Lệnh tiếp theo làm A thành 0C. KEY4 đổi giữa trang A/B và C/PC.
KEY3 bật hoặc tắt tự chạy, KEY1 đổi tốc độ 1, 2 hoặc 4 lệnh mỗi giây.
Khi yêu cầu tạm dừng, CPU hoàn tất lệnh đang chạy rồi mới dừng.”

### 5. Kết luận — 20 giây

“Khi chạy hết chương trình, A bằng 60 và C bằng 00, cho thấy CPU đã đọc
lệnh, tính toán, lặp và dừng theo chương trình mẫu. Muốn đổi phép tính dùng
các lệnh đã có, em sửa program.bin, tạo lại ảnh RAM, build và nạp bitstream
mới. Phần cứng CPU và bảng microcode không cần đổi cho ví dụ chỉ đổi số
được cộng và số lần lặp.”

## Kịch bản demo ngắn để không phải chờ 35 giây

1. RST. Trang A/B là `A00B00`.
2. KEY2 một lần; KEY4 sang trang C/PC: `C00P02`.
3. KEY2 lần hai: `C00P04`; KEY4 xem `A00B0C`.
4. KEY2 lần ba; KEY4 xem `C08P06`.
5. KEY2 lần bốn; KEY4 xem `A0CB0C`.
6. KEY1 hai lần chọn 4 lệnh/giây, KEY3 chạy. Nói phần kết luận trong lúc chờ.
7. Khi HLT, kiểm tra `A60B0C` và trang còn lại `C00P0F`.

KEY1 không có trang hiển thị tốc độ riêng trong giao diện hiện tại;
sau reset, hai lần nhấn là cách chọn 4 lệnh/giây. Nhấn và nhả rõ từng lần.

## Ba câu hỏi thường gặp

- **program.bin và ctrl_rom.bin khác gì?** Program là các lệnh của bài toán;
  microcode mô tả phần cứng phải làm những thao tác nhỏ nào để thực hiện mỗi loại lệnh.
- **Tại sao KEY2 làm PC tăng 2?** Lệnh như `3E 00` có một byte opcode và một byte dữ liệu;
  KEY2 chạy cả lệnh, còn PC đếm byte.
- **A60 có phải số 60 không?** Đây là hex: `0x60 = 6 × 16 = 96` thập phân.

Đây là demo chương trình mẫu; kết quả này không thay thế việc kiểm thử toàn bộ opcode CPU.

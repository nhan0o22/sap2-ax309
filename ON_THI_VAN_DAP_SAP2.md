# Ôn cấp tốc vấn đáp: CPU SAP2 trên FPGA AX309

## 1. Hiểu đề tài bằng một câu

**Em mô tả một CPU bằng Verilog, cấu hình FPGA thành CPU đó, rồi cho CPU đọc chương trình trong RAM để tính 12 × 8 bằng cộng lặp và hiển thị kết quả.**

Có hai lớp khác nhau:

- **Phần cứng CPU:** PC, thanh ghi, ALU, RAM, bộ điều khiển, giao tiếp. Mô tả bằng các file `.v`.
- **Chương trình CPU:** các byte lệnh trong `program.bin`. Đây là bài toán CPU thực hiện.

Verilog mô tả phần cứng hoạt động đồng thời. Không giải thích rằng FPGA chạy lần lượt các dòng Verilog như C. Trong CPU đã tạo, các lệnh máy vẫn được thực hiện theo trình tự do PC và bộ điều khiển quyết định.

## 2. Cây phần cứng: đọc từ top xuống

```text
top.v                        Nối và điều khiển toàn CPU
├── pc.v                     Con trỏ địa chỉ chương trình
├── register.v × 4            IR, A, B, C là bốn instance riêng
├── memory.v                 RAM, MAR, MDR, địa chỉ quay về
├── alu.v                    Tính toán số học và logic
├── flags.v                  Cờ Z và S
├── ROM microcode trong top  Bảng điều khiển từng micro-step
└── ax309_io.v               Nút, lịch chạy, clock CPU, LED/7 đoạn
    └── ax309_key × 4        Đồng bộ và lọc riêng từng nút
```

**Module** là bản thiết kế một khối; **instance** là một khối cụ thể được tạo từ bản thiết kế. Dùng cùng `register.v` không có nghĩa A/B/C/IR dùng chung một ô nhớ: mỗi instance có trạng thái riêng.

Trong cây ISE, `reg_a - register` nghĩa là instance tên `reg_a`, thuộc module `register`.

## 3. Chức năng các file

### Nhóm phần cứng CPU cần thuộc

| File | Chức năng | Câu trả lời ngắn khi được hỏi |
|---|---|---|
| `top.v` | Nối các module; chọn bus; tra ROM microcode; quản lý stage; xét nhảy điều kiện; tách control word | “Đây là khối tổng và bộ điều khiển CPU.” |
| `pc.v` | Thanh ghi 16 bit, reset 0, tăng một byte hoặc nạp địa chỉ nhảy | “PC chỉ vị trí byte tiếp theo cần đọc.” |
| `register.v` | Thanh ghi 8 bit, ưu tiên reset → load → inc → dec; dùng byte thấp bus | “Tạo riêng A, B, C và IR từ cùng một module.” |
| `memory.v` | RAM 32768 × 8 bit; MAR/MDR 16 bit; đọc đồng bộ; lưu địa chỉ CALL/RET | “MAR là địa chỉ, MDR là dữ liệu; RAM chứa cả lệnh và dữ liệu.” |
| `alu.v` | A và toán hạng tạm tmp; chọn ADD/SUB/AND/OR/XOR/đảo bit/dịch-xoay | “Tính kết quả rồi bộ điều khiển cho ghi về thanh ghi.” |
| `flags.v` | Chốt Z nếu giá trị bằng 0; S bằng bit 7; nhận từ A/B/C theo điều khiển | “Lưu điều kiện để thực hiện nhảy có điều kiện.” |
| `ax309_io.v` | Nhận nút; scheduler 1/2/4 lệnh mỗi giây; tạo microclock; quét hiển thị | “Giúp người dùng điều khiển và nhìn trạng thái CPU.” |

### Nhóm dữ liệu, cấu hình và công cụ

| File | Chức năng |
|---|---|
| `program.bin` | Byte chương trình viết dạng hex trong file text; ví dụ `3E 00` là lệnh nạp A bằng 0. Đuôi `.bin` không quyết định định dạng đọc. |
| `program_ise.mem` | Ảnh RAM đủ 32768 byte, sinh từ chương trình, phần dư bằng 00; `memory.v` đọc bằng `$readmemh`. |
| `ctrl_rom.bin` | Bảng microcode 4096 từ × 35 bit, đọc bằng `$readmemb`; mỗi từ là các tín hiệu điều khiển một micro-step. |
| `ax309.ucf` | Gán chân FPGA cho clock, reset, nút, LED; khai báo chuẩn điện và constraint timing. |
| `sap2v2.xise` | Cấu hình project ISE, danh sách nguồn, top, chip đích `xc6slx9-ftg256-2`. |
| `prepare-program.ps1` | Kiểm tra byte chương trình và tạo ảnh RAM đầy đủ. |
| `sync-ise-staging.ps1` | Tạo ảnh RAM, chép nguồn workspace sang staging rồi kiểm tra hash. |
| `run-sim.ps1` / `run-sim-ise.sh` | Chạy mô phỏng bằng công cụ tương ứng; đọc script để biết môi trường cần có. |
| `check-ise-build.ps1` | Phát hiện XST lỗi hoặc bitstream cũ; không thay thế toàn bộ kiểm tra implementation/board. |
| `top.bit` | Kết quả build dùng cấu hình FPGA qua JTAG; không phải mã lệnh SAP2 độc lập. |

### Nhóm kiểm thử và file không nằm trong CPU đang dùng

- `top_tb.v`: mô phỏng toàn hệ thống, kiểm tra bước lệnh, tốc độ, kết quả, HLT và reset.
- `memory_tb.v`: kiểm tra đọc/ghi bộ nhớ, reset, CALL/RET.
- `keys_tb.v`: kiểm tra bounce, giữ nút, nhả và bấm lại.
- `trace_tb.v`: in tín hiệu nội bộ để theo dấu lỗi.
- `io_demo_top.v`, `io_demo_tb.v`, `io_demo.xise`, `io_demo.ucf`: demo I/O độc lập để xác minh chân, LED và nút; không phải CPU SAP2.
- `ir.v`: module IR riêng có trong project, nhưng `top.v` hiện dùng `register instruction_register`, không dùng module này.
- `clock.v`: module chặn clock cũ có trong project, nhưng `top.v` hiện lấy clock từ `ax309_io`.
- `README_AX309.md`, `SIMULATION_RESULTS.md`, `THUYET_TRINH_SAP2.md`: hướng dẫn, bằng chứng kiểm thử, lời thuyết trình.

Testbench tạo kích thích và kiểm tra kết quả trong simulator. Không chọn testbench làm top tổng hợp, không nạp testbench lên FPGA.

## 4. Dữ liệu đi như thế nào?

### Bước A — Fetch: lấy mã lệnh

1. PC cung cấp địa chỉ qua bus; MAR nhận địa chỉ truy cập.
2. RAM đọc đồng bộ tại địa chỉ MAR; dữ liệu ra được chốt vào `ram_data_reg`.
3. Logic pending cho bus thấy byte RAM vừa đọc; IR nhận opcode. PC tăng theo byte đã đọc.

Stage 0–2 dùng chuỗi fetch chung. Sau đó bộ điều khiển chọn chuỗi thực hiện theo opcode IR.

### Bước B — Decode/control: chọn thao tác

Địa chỉ ROM microcode rộng 12 bit: ghép opcode 8 bit và stage 4 bit.
Riêng fetch lấy stage 0–2 từ vùng opcode 00. ROM trả về control word 35 bit.
Các bit điều khiển việc nạp A/B/C, chọn bus, tăng PC, đọc RAM, phép toán ALU và kết thúc lệnh.

Không cần thuộc 35 vị trí bit. Cần biết `CTRL_END` ở bit 34, `HLT` ở bit 33, và đoạn `assign {...} = ctrl_word[33:0]` tách các bit còn lại ra các dây điều khiển.

### Bước C — Execute: ví dụ ADD B

“B được đưa lên bus để nạp vào thanh ghi tạm tmp của ALU. ALU tính A + tmp.
Kết quả ALU được chọn lên bus và nạp về A theo microcode.”

Đây là tóm tắt các thao tác của lệnh, không phải tất cả xảy ra trong một cạnh clock.

### Bước D — Kết thúc lệnh hoặc dừng

Khi lệnh thông thường hoàn tất, sequencer quay về stage 0 và đảo `instruction_done_toggle`.
I/O đồng bộ toggle về clock 50 MHz để biết có thể dừng hoặc chờ lịch lệnh tiếp theo.
HLT có tín hiệu riêng để dừng CPU; không cần chờ toggle hoàn thành thông thường.

## 5. Chương trình hiện tại: phải thuộc bảng này

Tên gợi nhớ dưới đây dùng để giải thích ý nghĩa byte, không phải một file assembly đang được compiler dịch trong project.

| Địa chỉ hex | Byte hex | Ý nghĩa |
|---|---|---|
| 0000 | `3E 00` | A ← 00 |
| 0002 | `06 0C` | B ← 0C, tức 12 |
| 0004 | `0E 08` | C ← 08, tức 8 |
| 0006 | `80` | A ← A + B |
| 0007 | `0D` | C ← C − 1 |
| 0008 | `CA 0E 00` | Nếu Z=1, nhảy đến 000E |
| 000B | `C3 06 00` | Nhảy về 0006 |
| 000E | `76` | HLT |

Địa chỉ trong lệnh nhảy lưu byte thấp trước: `0E 00` là 000E.

```text
A = 0; B = 12; C = 8
lap:
    A = A + B
    C = C - 1
    neu C == 0: dung
    quay lai lap
```

| Sau lần KEY2 | A | B | C | PC |
|---|---|---|---|---|
| Reset | 00 | 00 | 00 | 0000 |
| 1 | 00 | 00 | 00 | 0002 |
| 2 | 00 | 0C | 00 | 0004 |
| 3 | 00 | 0C | 08 | 0006 |
| 4 | 0C | 0C | 08 | 0007 |
| 5 | 0C | 0C | 07 | 0008 |
| Chạy hết | 60 | 0C | 00 | 000F |

**60 hex = 6 × 16 = 96 thập phân = 12 × 8.**
Không gọi “PC tăng một bit”: PC tăng một đơn vị địa chỉ byte; bit là đơn vị nhị phân 0/1.

## 6. Verilog tối thiểu để đọc được code

| Cú pháp | Cách hiểu đúng trong project |
|---|---|
| `input`, `output` | Các cổng tín hiệu vào/ra của module. |
| `wire` | Dây kết nối; không tự lưu trạng thái. |
| `reg` | Biến được gán trong khối thủ tục Verilog; không phải cứ khai báo reg là tạo thanh ghi vật lý. |
| `reg [7:0] data` | Biến 8 bit; trong khối clock của register thì được tổng hợp thành thanh ghi. |
| `always @(*)` | Logic tổ hợp, tính lại theo đầu vào; phải gán đủ nhánh để tránh latch ngoài ý muốn. |
| `always @(posedge clk ...)` | Logic hoạt động tại cạnh lên clock, thường dùng lưu trạng thái. |
| `negedge clk` | Cạnh xuống; stage và flags trong thiết kế dùng cạnh này. |
| `<=` | Gán nonblocking trong logic tuần tự; các vế phải dùng giá trị trước cập nhật của cùng cạnh. |
| `=` | Gán blocking; trong logic tổ hợp giúp mô tả cách tính theo thứ tự trong khối. |
| `assign out = data` | Kết nối tổ hợp liên tục, không phải một lệnh chạy một lần. |
| `8'h0C`, `4'd2`, `1'b0` | Độ rộng, cơ số, giá trị: 8 bit hex 0C; 4 bit thập phân 2; 1 bit 0. |
| `bus[7:0]` | Lấy byte thấp của bus. |
| `{ir_out, rom_stage}` | Ghép các nhóm bit thành một vector. |
| `parameter SIMULATION` | Tham số chọn cấu hình khi elaboration; bản nạp board là 0, testbench có thể chọn 1 để rút ngắn bộ đếm. |

`initial $readmemh(...)` ở đây được công cụ dùng để khởi tạo RAM khi cấu hình FPGA.
Không hiểu rằng CPU mở file trên Windows trong lúc đang chạy. Nhấn RST chỉ reset các thanh ghi/điều khiển, không tự đọc lại file và không xóa toàn bộ RAM.

## 7. Những điểm thiết kế hay bị hỏi sâu

### CPU 8 bit sao bus và PC 16 bit?

A/B/C và ALU xử lý dữ liệu 8 bit. PC/bus rộng 16 bit để mang địa chỉ và dữ liệu địa chỉ.
Tuy nhiên RAM hiện có 32 KiB, chỉ dùng `mar[14:0]`. Không được nói thiết kế có đủ 64 KiB RAM chỉ vì PC 16 bit; hai địa chỉ khác bit 15 sẽ ánh xạ cùng vị trí RAM.

### Hai clock khác nhau để làm gì?

Clock board là 50 MHz. I/O chia thành CPU microclock 1 kHz khi có lệnh cần chạy.
Scheduler khởi động lệnh theo nhịp 1/2/4 lệnh mỗi giây để người xem theo dõi.
**1 lệnh/giây không có nghĩa clock CPU là 1 Hz.** Một lệnh gồm nhiều micro-step.
Thiết kế dùng cạnh lên cho datapath, cạnh xuống cho stage/flags và ROM control.

### Tại sao dùng Block RAM và pending?

RAM 32 KiB và control ROM khá lớn, nên dùng tài nguyên nhớ chuyên dụng trong FPGA.
Đọc RAM đồng bộ có độ trễ; `ram_read_pending` đánh dấu byte đang được đọc và chọn dữ liệu mới ra bus.
Nếu dùng dữ liệu cũ hoặc lệch stage, IR có thể nhận opcode sai. Không thể kết luận nguyên nhân chỉ từ PC tăng và thanh ghi đứng yên; phải xem trace.

### Reset sau HLT làm sao hoạt động?

HLT dừng CPU clock. Các thanh ghi cần reset dùng reset bất đồng bộ nên không phải chờ CPU clock.
Đầu ra ROM control không thêm async reset để giữ mẫu suy diễn BRAM; `ctrl_active` được reset để che ngay điều khiển cũ, bao gồm HLT.

### Vì sao nút cần đồng bộ và debounce?

Nút không đồng bộ với clock, nên dùng hai flip-flop đồng bộ để giảm rủi ro metastability.
Tiếp điểm cơ khí có bounce; lọc trạng thái ổn định 20 ms để một lần nhấn chỉ tạo một sự kiện.
Hai cơ chế xử lý hai vấn đề khác nhau. Nhả cũng phải ổn định trước lần bấm tiếp theo.

### Bài học từ lỗi A/B/C không chạy?

“Em kiểm tra theo chuỗi ảnh chương trình → RAM → bus → IR → microcode → thanh ghi,
đối chiếu mô phỏng và log build. Dự án có sửa định dạng ảnh khởi tạo đầy đủ và thứ tự khai báo RAM cho XST.
Một lần synthesis lỗi nhưng top.bit cũ còn trên đĩa nên cần kiểm tra đúng bitstream mới.
Sau các sửa cuối, regression qua và thử trên board đã chạy đúng. Chưa có phép thử cô lập chứng minh một thay đổi duy nhất giải thích mọi lần lỗi trước.”

## 8. Hỏi nhanh – đáp gọn

**1. Đề tài làm gì?** Tạo CPU SAP2 trên FPGA, chạy chương trình mẫu và quan sát trạng thái trên LED.

**2. FPGA và vi điều khiển khác nhau ở đây thế nào?** FPGA được cấu hình thành các mạch CPU do em mô tả; vi điều khiển thông thường có lõi CPU đã được chế tạo sẵn.

**3. Logisim liên quan thế nào?** Giúp hình dung và mô phỏng sơ đồ CPU; Verilog/ISE hiện thực các khối đó lên FPGA. Demo này chưa chứng minh tương đương mọi opcode với Logisim.

**4. Có dùng bộ nhân không?** Chương trình mẫu không dùng bộ nhân; thực hiện nhân bằng cộng lặp qua ALU.

**5. PC và IR khác gì?** PC giữ địa chỉ; IR giữ mã loại lệnh đang thực hiện.

**6. MAR và MDR khác gì?** MAR giữ địa chỉ truy cập RAM; MDR giữ dữ liệu.

**7. Program và microcode khác gì?** Program chọn chuỗi lệnh của bài toán; microcode chọn các thao tác phần cứng cho từng loại lệnh.

**8. KEY2 là một xung clock à?** Không. KEY2 yêu cầu thực hiện đầy đủ một lệnh, gồm nhiều micro-step.

**9. Tại sao PC sau lần bấm đầu là 02?** Lệnh `3E 00` dài hai byte.

**10. Dừng bằng cách nào?** Chương trình đến HLT; I/O giữ CPU clock thấp. Clock 50 MHz của giao tiếp vẫn chạy.

**11. Quét LED là gì?** Lần lượt kích từng digit và đặt mẫu segment tương ứng, đủ nhanh để mắt thấy cả dãy.

**12. Vì sao số 96 lại hiện 60?** Giá trị đang hiển thị theo hệ hex.

**13. Đổi thành 5 × 3?** Đổi byte nạp B từ 0C thành 05, byte nạp C từ 08 thành 03; tạo ảnh RAM, đồng bộ, build và nạp lại; kết quả 0F.

**14. C có thể đặt bằng 0 để nhân 0 không?** Vòng lặp hiện kiểm tra sau khi cộng và giảm. C=0 sẽ giảm quay vòng thành FF; không phải chạy 0 vòng. Muốn xử lý đúng cần kiểm tra C=0 trước vòng lặp.

**15. Kết quả lớn hơn 255?** A chỉ 8 bit, phần vượt bị bỏ; ví dụ tổng 256 trở thành 00. Thiết kế hiện không có cờ Carry trong flags.

**16. Có mấy cờ?** Hai: Z và S. Không nói là có đủ mọi cờ của một CPU thương mại.

**17. Mọi phép ALU đã đúng theo tên chưa?** Cần nhìn code và test từng phép. Nhánh tên RAL hiện xoay trái; nhánh tên RAR hiện chỉ dịch phải, chưa đưa bit 0 về bit 7. Demo ADD không dùng hai nhánh này.

**18. CALL/RET đã có stack chưa?** `memory.v` chỉ lưu một `return_addr`; riêng cơ chế này không phải stack hỗ trợ gọi lồng nhiều mức.

**19. Build thành công có chắc CPU đúng không?** Không. Cần mô phỏng hành vi, timing và kiểm tra thực tế; mỗi tầng chứng minh một phần.

**20. Các bước từ code ra board?** HDL → synthesis ra mạch logic → Translate/Map/PAR đưa mạch vào chip → kiểm tra timing → BitGen tạo top.bit → nạp JTAG.

**21. UCF làm gì?** Gắn tên tín hiệu với chân thật và ràng buộc điện/timing; nếu thiếu hoặc sai, mạch có thể không giao tiếp đúng board dù HDL mô phỏng đúng.

**22. Code còn hạn chế gì?** Chưa chứng minh mọi opcode; dữ liệu 8 bit có tràn, RAM 32 KiB, CALL/RET một mức và một số phép ALU cần kiểm tra thêm. Kết quả demo xác nhận chương trình mẫu.

## 9. Lịch học một giờ trước thi

1. **10 phút:** thuộc cây module và vai trò PC/IR/MAR/MDR/A/B/C/ALU/flags.
2. **15 phút:** tự giải thích từng dòng chương trình và tính A sau mỗi vòng.
3. **10 phút:** mở top.v, tìm bus mux, ctrl_addr, next_stage và assign tách control word.
4. **10 phút:** đọc các cú pháp Verilog ở mục 6; phân biệt clock, instruction và micro-step.
5. **10 phút:** trả lời thành tiếng các câu hỏi ở mục 8, đặc biệt giới hạn thực tế.
6. **5 phút:** tập bài nói trong THUYET_TRINH_SAP2.md và demo ba bước khởi tạo.

Nếu giám khảo hỏi ngoài phần đã kiểm chứng, trình bày cấu trúc đang có và cách sẽ kiểm tra; không khẳng định đã hỗ trợ tính năng chỉ vì tên module hoặc opcode có trong file.

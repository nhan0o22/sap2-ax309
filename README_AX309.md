# SAP2 demo cho ALINX AX309

Hướng dẫn chia code thành bốn cụm, lời nói mẫu 2–3 phút và kịch bản bấm nút:
xem [THUYET_TRINH_SAP2.md](THUYET_TRINH_SAP2.md).

Ôn cấu trúc từng file, luồng fetch/execute, cú pháp Verilog và câu hỏi vấn đáp:
xem [ON_THI_VAN_DAP_SAP2.md](ON_THI_VAN_DAP_SAP2.md).

Project này có hai bitstream nạp qua JTAG. Luôn nạp `io_demo` trước khi dùng
`sap2_demo`: nếu LED hoặc sáu LED 7 đoạn chưa được xác nhận thì không thể kết
luận CPU bị lỗi chỉ từ những gì nhìn thấy trên board.

## FPGA đang làm gì?

Logisim là nơi quan sát một CPU bằng mô phỏng: có dây nối, thanh ghi, ALU và
RAM ảo. Các file Verilog ở đây mô tả lại phần cứng đó. Khi ISE tổng hợp, nó
biến mô tả thành LUT, flip-flop và Block RAM trong Spartan-6. File `.bit` nạp
qua JTAG cấu hình FPGA thành phần cứng SAP2; FPGA không đọc và thực thi file
Verilog như phần mềm trên máy tính.

Luồng dữ liệu của demo là:

```text
program.bin -> program_ise.mem -> RAM chương trình --+
                                  |-> CPU SAP2 -> A/B/C/PC -> 7 đoạn và LED
ctrl_rom.bin -> ROM vi lệnh ------+
```

- `program.bin` chứa byte lệnh máy.
- `program_ise.mem` là ảnh RAM đầy đủ 32768 dòng, mỗi dòng một byte hex:
  15 byte chương trình giữ nguyên, phần còn lại điền `00`. `memory.v` dùng
  ảnh này cho cả mô phỏng và tổng hợp. Chạy `prepare-program.ps1` để tái tạo;
  `sync-ise-staging.ps1` và `run-sim.ps1` tự thực hiện bước đó.
- `ctrl_rom.bin` chứa các control word vi lệnh; chúng điều khiển từng
  micro-step bên trong một lệnh CPU.
- `top.v` nối các thanh ghi, ALU, RAM, sequencer và front panel AX309.
- `ax309_io.v` chỉ điều khiển nút, nhịp demo và màn hình; nó không thay đổi
  datapath, chương trình, RAM hay microcode.

## 1. Nạp `io_demo.bit` trước

Mở `io_demo.xise`, chạy **Generate Programming File**, rồi nạp `io_demo.bit`
qua JTAG. Đây là mạch chẩn đoán I/O độc lập, không chạy SAP2.

- Bốn LED phải lần lượt chạy one-hot, mỗi bước khoảng nửa giây.
- Sáu digit lần lượt trình bày `012345`, rồi `89AbCd`, đọc từ trên xuống.
- Sau đó từng digit được bật một mình với số `8`, từ trên xuống; số `8` dùng
  đủ bảy segment để dễ nhìn digit hoặc segment bị sai.
- Nhấn `KEY1` đến `KEY4` để hiện mã nút vừa nhấn trong chốc lát. Trong project
  chẩn đoán, KEY1 là nút kiểm tra; trong SAP2 nó đổi tốc độ tự chạy.
- Nhấn nút `RST` để khởi động lại chuỗi chẩn đoán.

Quan sát trên AX309 đã xác nhận `SEL[5]` là digit trên cùng, `SEL[0]` là digit
dưới cùng, và segment đang active-low; `io_demo` đã được chỉnh theo thứ tự đó.
Nếu LED sáng khi logic dự kiến tắt hoặc segment sai, gửi ảnh/video trước khi
nạp SAP2.

## 2. Nạp SAP2 bằng `top.bit`

Mở `sap2v2.xise`, chạy **Generate Programming File**, rồi nạp `top.bit` vừa
được ISE tạo qua JTAG. Sau reset, CPU luôn ở trạng thái pause và không tự
chạy. Không dùng một `sap2_demo.bit` cũ nếu source `top.v` vừa được sửa.

| Điều khiển | Chức năng SAP2 |
|---|---|
| `RST` riêng | Reset CPU về `PC=0000`, `A=B=C=00`, pause, trang A/B và tốc độ 1 lệnh/giây |
| `KEY1` | Đổi tốc độ tự chạy: 1 → 2 → 4 → 1 lệnh/giây; không reset CPU |
| `KEY2` | Hoàn thành đúng một lệnh máy rồi pause ở biên lệnh tiếp theo |
| `KEY3` | Bật/tắt chạy liên tục; khi dừng giữa lệnh, CPU hoàn thành lệnh đang chạy rồi pause |
| `KEY4` | Đổi trang hiển thị, không làm CPU chạy |

Khi chạy liên tục, CPU bắt đầu lệnh đầu tiên sau khi nhận nhấn KEY3 và bắt đầu
lệnh mới theo chu kỳ 1000/500/250 ms. Đổi KEY1 áp dụng cho chu kỳ bắt đầu ở
lệnh kế tiếp, không cắt ngắn lệnh đang chạy. Micro-step bên trong chạy nhanh hơn,
tối đa 1 kHz; vì thế
"một lệnh/giây" không có nghĩa là "một micro-step/giây".

Cả bốn nút được đồng bộ hai tầng và phải ổn định liên tục 20 ms khi nhấn/nhả.
Giữ nút chỉ tạo một thao tác. KEY2 bị bỏ qua khi CPU bận, tự chạy hoặc HLT;
KEY3 được ưu tiên nếu cùng nhấn KEY2. KEY1 và KEY4 vẫn hoạt động sau HLT.

### Màn hình và LED

Màn hình có sáu digit, đọc theo hai trang do KEY4 chọn:

- Trang 0: `AxxBxx` — A và B ở hệ hex.
- Trang 1: `CxxPxx` — C và byte thấp của PC ở hệ hex. Chương trình demo chỉ
  nằm trong `0000h..000Eh`, nên byte cao của PC luôn là `00h`.

LED logic là `LED0=RUN`, `LED1=PAUSE/READY`, `LED2=trang 1`, `LED3=HLT`.
Ý nghĩa điện học cuối cùng của sáng/tắt được xác nhận bằng `io_demo`; hiện
chưa được suy đoán từ quan sát cũ "mọi LED đều sáng".

## 3. Chương trình mẫu chạy gì?

`program.bin` là chương trình kiểu SAP2 mở rộng với opcode gần Z80:

```text
A <- 00h
B <- 0Ch      ; 12
C <- 08h      ; 8

loop:
  A <- A + B
  C <- C - 1
  nếu C = 0 thì HLT
  nhảy về loop
```

Sau tám vòng, kết quả dự kiến là `A=60h` và `C=00h`; LED HLT được kích hoạt.
Từ reset, demo có 35 lệnh: khoảng 34–35 giây ở tốc độ mặc định,
17–18 giây ở 2 lệnh/giây, hoặc 8,5–9 giây ở 4 lệnh/giây.

Để học bằng KEY2:

1. Reset, sau đó nhấn KEY2 một lần: `PC=0002`, `A=00`. Nếu trang C/PC đang
   hiển thị, giá trị phải là `C00P02` — không phải `C00P01`.
2. Nhấn KEY2 lần hai: `PC=0004`, `B=0C`.
3. Nhấn KEY2 lần ba: `PC=0006`, `C=08`.
4. KEY2 lần bốn: `A=0C`, `PC=0007`. KEY4 xem trang C/PC; KEY3 chạy phần còn lại.
5. Khi HLT, kiểm tra `A=60`, `C=00`.

## Build trong Xilinx ISE 14.7

Workspace này là nguồn chuẩn. Thư mục ISE staging chỉ là bản sao có thể tạo
lại. Trước mọi build, chạy từ PowerShell tại workspace:

```powershell
.\sync-ise-staging.ps1
```

Sau đó trong ISE staging:

1. Chọn project phù hợp: `io_demo.xise` hoặc `sap2v2.xise`.
2. Chọn **Project → Clean Project Files**.
3. Chạy Behavioral Simulation với `io_demo_tb` hoặc `top_tb`.
4. Chạy Synthesize, Implement Design, rồi Generate Programming File.

Nếu ISE đang mở project cũ, đóng và mở lại sau khi đồng bộ để nhận danh sách
nguồn mới. Trong Implementation, chọn `top`; các file `_tb.v` chỉ dùng mô phỏng.
Nạp đúng `top.bit` ở staging, có thời gian tạo sau lần sửa nguồn mới nhất.

Sau build có thể kiểm tra từ PowerShell bằng `./check-ise-build.ps1`.
Nếu XST báo lỗi, ISE có thể vẫn để lại `top.bit` của lần build trước;
không coi việc thấy file này hoặc nạp JTAG thành công là build mới thành công.
Script kiểm tra báo cáo XST và thời gian bitstream so với nguồn.

### Chạy regression bằng dòng lệnh

Windows (Icarus Verilog):

```powershell
.\run-sim.ps1
# Nếu Icarus nằm nơi khác:
.\run-sim.ps1 -ToolRoot 'C:\iverilog\bin' -Trace
```

Bản Icarus portable phục vụ kiểm thử nằm ở `.tools/iverilog/bin`; thư mục này
không đồng bộ sang ISE. Log đặt trong `sim-results/`. Script trả lỗi nếu có
`FAIL:` hoặc thiếu `PASS:`; `-Trace` ghi stage, địa chỉ ROM, control word,
MAR, RAM output, MDR, bus, IR và PC ở các cạnh clock đầu tiên.

Trong Linux VM, mở môi trường dòng lệnh ISE 14.7, tại staging chạy:

```bash
bash run-sim-ise.sh
```

Script ISim cần `fuse` và thư viện ISE trong môi trường. Script này đã được
soạn nhưng chưa chạy trên VM; kết quả hiện có là mô phỏng Icarus.
Ảnh `program_ise.mem` phải có đủ 32768 dòng; mô phỏng không còn cảnh báo
"Not enough words". Regression kiểm tra đủ 15 byte mẫu và phần điền `00`.
Khi chạy ISim trong Linux, dùng file ảnh đã được script đồng bộ từ workspace.

### Kết quả rà lỗi PC tăng 1

Regression trước thay đổi đã thực hiện đúng ba lệnh khởi tạo; trace cho thấy
RAM output `3E`, IR `3E`, rồi PC đạt `0002`. Lỗi PC tăng 1 trên board chưa tái
hiện trong mô phỏng, nên chưa có bằng chứng xác định nguyên nhân phần cứng.
Một lỗi kiểm thử cũ kiểm tra clock quá sớm ngay khi HLT xuất hiện đã được sửa
bằng cách đợi bộ điều khiển I/O nhận HLT trước khi kiểm tra trạng thái dừng.

Phần fetch hiện dùng nhóm microcode chung cho stage 0–2, độc lập opcode cũ
trong IR; RAM vẫn giữ mẫu đọc đồng bộ. Các file ROM/RAM baseline không đổi.
Sau thay đổi phải build mới để kiểm tra Block RAM và timing; báo cáo build
cũ không xác nhận bản nguồn này.

Với SAP2, báo cáo phải vẫn dùng `xc6slx9-ftg256-2`, có cả `TS_CLK` và
`TS_CPU_CLK`, và vẫn infer `Mram_ram` cùng `Mram_ctrl_rom` thành Block RAM.
Các cảnh báo đã chấp nhận gồm ROM `ctrl_rom` đã khởi tạo, hai bit cao bus
16-bit chưa dùng trong register/ALU, các bit địa chỉ cao không dùng trong
demo RAM 32 KiB, và cảnh báo license ISE. Chúng không phải lỗi timing hay
lỗi của chương trình mẫu.

## Giới hạn đã biết

CPU có bus địa chỉ 16-bit nhưng RAM hiện thực 32 KiB; `MAR[15]` không được
giải mã. Nội dung microcode trong `ctrl_rom.bin` là baseline đang dùng. Demo
xác nhận chương trình mẫu và trạng thái cuối, không chứng minh mọi opcode
hoàn toàn tương đương một file Logisim khác.

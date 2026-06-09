# FPGA Accelerator for High-Throughput Cell Detection

Dự án này triển khai bộ tăng tốc phần cứng (Hardware Accelerator) trên Kit phát triển **Zybo Z7 (Sử dụng chip Xilinx Zynq-7000 xc7z010clg400-1)** nhằm mục đích phát hiện tế bào thời gian thực với thông lượng cao. Kiến trúc xử lý dựa trên mô hình mạng CNN lượng tử hóa 4-bit (được huấn luyện qua thư viện Brevitas) và biên dịch phần cứng tự động luồng dữ liệu thông qua AMD/Xilinx FINN Framework.

## 1. Thông số Hệ thống & Sơ đồ ngoại vi

* **Tín hiệu đầu vào:** Chuỗi tín hiệu analog thô được lấy mẫu thông qua bộ ADC với tần số cố định **10 kHz**. Dữ liệu số hóa sau đó được đóng gói thành các chuỗi vector có độ dài cố định $L=20$ (tương đương với một cửa sổ thời gian xử lý là 2 ms) trước khi truyền đẩy trực tiếp vào trục giao tiếp AXI-Stream của lõi FINN.
* **Tần số hoạt động phần cứng:** Toàn bộ lõi IP xử lý luồng dữ liệu được FINN sinh ra cấu hình chạy ở tần số ổn định **50 MHz**. Tần số này được hạ nguồn và đồng bộ pha thông qua khối Clocking Wizard (`clk_wiz_0`), lấy nguồn clock chính từ thạch anh hệ thống 125 MHz có sẵn trên board mạch Zybo Z7.
* **Giao tiếp đầu ra:** Kết quả phân loại phát hiện tế bào (giá trị Logit) sau khi được lõi mạch tính toán xong sẽ được bộ điều khiển FSM đóng gói cấu trúc dữ liệu và truyền tải ngược về máy tính thông qua giao tiếp mã UART.

### Cấu hình Chân vật lý (Pin Assignment)
Định nghĩa chi tiết kết nối phần cứng vật lý trong file ràng buộc `constraints/con.xdc`:
* `sysclk` (Xung nhịp hệ thống 125 MHz): Chân **K17**
* `uart_tx` (Tín hiệu truyền UART xuất kết quả): Chân **V12** (Kết nối qua chân Pmod hoặc cổng UART-USB tùy thuộc cấu hình hệ thống mạch của bạn)

## 2. Kiến trúc Tối ưu hóa Phần cứng (PE/SIMD)

Để đảm bảo luồng dữ liệu truyền tải liên tục không bị thắt nút cổ chai (Bottleneck), các khối xử lý tính toán ma trận vector (MVAU) trong file đồ thị phần cứng `hardware_config/final_hw_config.json` được cấu hình phân tách tham số song song hóa như sau:
* **MVAU_hls_0 (Tầng tích chập 1):** Cấu hình $PE = 1, SIMD = 4$ nhằm tiết kiệm diện tích logic.
* **MVAU_hls_1 (Tầng tích chập 2):** Mở rộng song song $PE = 4, SIMD = 8$ để giải phóng nhanh khối lượng luồng dữ liệu dồi dào được đẩy ra liên tục từ tầng trước.

## 3. Cấu trúc Thư mục Nguồn

```text
├── hardware_config/     # Tệp cấu hình phân bổ tham số phần cứng PE/SIMD (.json)
├── notebooks/           # Mã nguồn Jupyter Notebook dùng để huấn luyện và tinh gọn đồ thị mô hình (.ipynb)
├── models/              # Các file trung gian lưu trữ đồ thị mạng lượng tử hóa (.onnx)
├── hdl/                 # Mã nguồn Verilog RTL điều khiển phần cứng hệ thống tầng đỉnh (`top.v`, `sys.v`)
├── simulation/          # Môi trường testbench kiểm thử dạng sóng tín hiệu (`test.v`, `input_data.mem`)
└── constraints/         # File định nghĩa chân vật lý và cấu hình ràng buộc xung nhịp xung cho Vivado (.xdc)
```
## 4. Hướng dẫn Triển khai & Chạy Dự án 

Để chạy dự án từ bước thuật toán phần mềm xuống cấu trúc mạch số trên Kit **Zybo Z7**, thực hiện tuần tự theo 3 bước sau:

---

## Bước 1: Huấn luyện thuật toán và Xuất mô hình (Môi trường Python)

Mở terminal tại thư mục dự án và khởi động môi trường Jupyter Notebook:

```bash
jupyter notebook notebooks/2dconv.ipynb
```

Chạy toàn bộ notebook này để tiến hành:

- Huấn luyện mạng chập (CNN).
- Lượng tử hóa trọng số.
- Xuất file đồ thị mạng chuẩn ONNX:

```text
models/quant_cnn_4bit.onnx
```

Tiếp tục chạy các notebook:

```text
transform.ipynb
validate.ipynb
```

để tối ưu cấu trúc đồ thị luồng dữ liệu.

---

## Bước 2: Biên dịch khối IP tăng tốc phần cứng bằng FINN

Khởi động Docker Container của **FINN Framework** trên máy tính của bạn và trỏ đường dẫn đến file cấu hình phần cứng:

```text
hardware_config/final_hw_config.json
```

FINN sẽ tự động thực hiện quá trình **High-Level Synthesis (HLS)** để đóng gói thuật toán mạng CNN thành khối IP lõi phần cứng RTL tương thích giao tiếp **AXI-Stream**.

---

## Bước 3: Mô phỏng vi mạch và Nạp code phần cứng (Xilinx Vivado)

Mở phần mềm **Xilinx Vivado** và tạo một dự án mới (**New Project**).

Tại bảng chọn chip mục tiêu, chọn đúng mã chip của Kit Zybo Z7-10:

```text
xc7z010clg400-1
```

Tiến hành thêm các file mã nguồn tương ứng trong thư mục dự án:

### Design Sources

Thêm toàn bộ các file trong thư mục:

```text
hdl/
```

vào nhóm **Design Sources**.

### Constraints

Thêm các file trong thư mục:

```text
constraints/
```

vào nhóm **Constraints**.

### Simulation Sources

Thêm các file:

```text
simulation/test.v
simulation/input_data.mem
```

vào nhóm **Simulation Sources**.

### Chạy mô phỏng

Chọn:

```text
Run Simulation
```

để thực hiện mô phỏng dạng sóng.

Kiểm tra hoạt động bắt tay truyền nhận tín hiệu:

```text
tvalid / tready
```

theo chuẩn **AXI-Stream** giữa máy trạng thái FSM điều khiển và lõi IP FINN.

### Sinh bitstream

Sau khi dạng sóng mô phỏng hoạt động chính xác, chọn:

```text
Generate Bitstream
```

để Vivado thực hiện:

- Tổng hợp mạch (Synthesis).
- Định tuyến chân (Implementation).
- Sinh file nhị phân cấu hình FPGA:

```text
.bit
```

### Nạp xuống Kit Zybo Z7

Kết nối Kit Zybo Z7 với máy tính qua cáp USB, mở:

```text
Hardware Manager
```

và tiến hành nạp file bitstream xuống FPGA để hệ thống bắt đầu hoạt động thực tế.

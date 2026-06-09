# FPGA Acceleration of Quantized CNN for High-Throughput Cell Detection Analysis

[![Platform](https://img.shields.io/badge/Platform-Xilinx_Vivado_/_FINN-F47C22?style=flat-flat)]()
[![Language](https://img.shields.io/badge/Language-Verilog_/_Python-3776AB?style=flat-flat)]()
[![Framework](https://img.shields.io/badge/Framework-Brevitas_/_PyTorch-EE4C2C?style=flat-flat)]()

Dự án này nghiên cứu và phát triển bộ tăng tốc phần cứng (Hardware Accelerator) dựa trên kiến trúc FPGA nhằm giải quyết bài toán **phát hiện tế bào (Cell Detection)** thời gian thực với thông lượng cao (High-Throughput). Hệ thống xử lý chuỗi tín hiệu thô đầu vào, sử dụng mô hình mạng CNN Lượng tử hóa (QNN) được huấn luyện qua thư viện **Brevitas** và biên dịch phần cứng tự động sang kiến trúc luồng dữ liệu (Dataflow Architecture) tối ưu ma trận bằng **AMD/Xilinx FINN Framework**.

---

## 📌 Điểm nổi bật của Dự án (Key Features)
* **Ứng dụng Thực tế:** Tự động nhận diện và phát hiện sự hiện diện của tế bào từ chuỗi dữ liệu đầu vào thời gian thực, ứng dụng trực tiếp cho các hệ thống vi lưu (Microfluidics) thông lượng cao.
* **Tối ưu hóa Thuật toán:** Định lượng (Quantization) dữ liệu đầu vào về dạng số nguyên **8-bit** và các lớp tích chập (Conv)/tuyến tính (Linear) về số nguyên **4-bit** (`weight_bit_width=4`) giúp giảm tối đa diện tích mạch, dung lượng bộ nhớ BRAM và tài nguyên DSP mà vẫn đảm bảo độ chính xác phát hiện vượt trội (~99.4%).
* **Kiến trúc Song song hóa Tối ưu:** Cấu hình linh hoạt các tham số phần cứng chuyên biệt `PE` (Processing Elements) và `SIMD` của lõi FINN cho từng tầng chập cụ thể nhằm triệt tiêu hiện tượng thắt nút cổ chai (Bottleneck) khi dòng bit truyền tải liên tục.
* **Xác thực Vi mạch Toàn diện:** Thiết kế Máy trạng thái RTL bằng Verilog để quản lý luồng nạp dữ liệu từ bộ nhớ nội bộ vào lõi IP tăng tốc, tuân thủ nghiêm ngặt theo giao thức chuẩn công nghiệp **AXI-Stream**.

---

## 🏗️ Kiến trúc Hệ thống (System Architecture)

Luồng xử lý dữ liệu được thiết kế khép kín từ mô hình thuật toán (Phần mềm) dịch thẳng xuống cấu trúc mạch số vật lý (Phần cứng):
Tín hiệu thô (Chuỗi thời gian) ──> Lượng tử hóa 8-bit ──> Trục Giao tiếp AXI-Stream ──> Bộ tăng tốc QNN (Lõi FINN FPGA) ──> Kết quả Phát hiện (Logit)


### 1. Cấu hình Mạng CNN Lượng tử hóa (Brevitas Specification)
Mô hình được xây dựng dưới dạng cấu trúc CNN 1D để bóc tách đặc trưng chuỗi dữ liệu (được biểu diễn qua toán tử `QuantConv2d` với kích thước hạt nhân `1 x K` phù hợp):
* **QuantIdentity (Input Layer):** Thực hiện ép kiểu dải dữ liệu đầu vào về dạng số nguyên 8-bit, phạm vi giá trị từ `-5.0` đến `5.0`.
* **QuantConv2d (Layer 1):** Gồm 1 kênh đầu vào $\rightarrow$ 8 kênh đầu ra, kích thước Hạt nhân (Kernel) là `(1, 8)`, lượng tử hóa trọng số (Weights) **4-bit**.
* **QuantConv2d (Layer 2):** Gồm 8 kênh đầu vào $\rightarrow$ 16 kênh đầu ra, kích thước Hạt nhân (Kernel) là `(1, 4)`, lượng tử hóa trọng số (Weights) **4-bit**.
* **MaxPool2d (Sub-sampling):** Giảm mẫu không gian tuyến tính với Hạt nhân kích thước `(1, 10)`.
* **QuantLinear (Dense Layer):** Lớp kết nối đầy đủ cuối cùng chịu trách nhiệm phân loại, xuất ra 1 giá trị logic (Logit) quyết định sự xuất hiện của tế bào, lượng tử hóa trọng số **4-bit**.

### 2. Tối ưu hóa Phần cứng (FINN Hardware Config)
Dựa trên tệp cấu hình đồ thị phần cứng nâng cao `final_hw_config.json`, các tầng tính toán ma trận (MVAU - Matrix Vector Activation Unit) được tinh chỉnh mức độ song song hóa (Folding factors):
* **`MVAU_hls_0` (Tầng tích chập đầu tiên):** Định hình ở cấu hình song song vừa phải $PE = 1, SIMD = 4$ để tiết kiệm diện tích tài nguyên trên chip.
* **`MVAU_hls_1` (Tầng tích chập thứ hai):** Nâng cấp sức mạnh song song cao hơn hẳn với cấu hình $PE = 4, SIMD = 8$ nhằm giải phóng lượng luồng bit lớn được đẩy ra liên tục từ tầng trước đó.
* Tích hợp các khối chuyển đổi độ rộng dữ liệu tự động (`StreamingDataWidthConverter - DWC`) giữa các tầng để đồng bộ băng thông truyền tải.

---

## 💻 Giao tiếp RTL & Mô phỏng Kiểm thử (Hardware Verification)

### Máy trạng thái Điều khiển Tầng Đỉnh (`top.v` / `sys.v`)
Thiết kế phần cứng sử dụng một Máy trạng thái hữu hạn (FSM) gồm 3 trạng thái cốt lõi: `IDLE`, `SEND`, và `DONE`. Hệ thống quản lý việc đọc chuỗi mẫu dữ liệu tĩnh từ ROM nội bộ, sau đó đẩy vào lõi IP tăng tốc của FINN thông qua cơ chế bắt tay (Handshake) `tvalid` (chủ động cấp) / `tready` (lõi sẵn sàng nhận) của giao thức **AXI-Stream**.

* **Debug trên chip (Hardware Debugging):** Hệ thống tích hợp sẵn kiến trúc nạp lõi **ILA** (Integrated Logic Analyzer) và **VIO** (Virtual Input/Output) để hỗ trợ việc giám sát dạng sóng tín hiệu và kích hoạt xung phát tín hiệu thủ công trực tiếp trên Kit FPGA (Zybo/Pynq) thông qua phần mềm Vivado.

### Môi trường Mô phỏng Testbench (`test.v`)
Môi trường kiểm thử tự động nạp dữ liệu kích thích đầu vào từ tệp mảng bên ngoài (`input_data.mem`), đồng bộ hóa nghiêm ngặt theo chu kỳ xung nhịp (Clock cycle) và tích hợp cơ chế tự động bảo vệ ngắt mạch (**Timeout** tự động dừng sau 500 chu kỳ) để phòng ngừa trạng thái treo mạch phần cứng trong quá trình mô phỏng waveform.

---

## 🚀 Hướng dẫn Triển khai (How to Run)

### Giai đoạn 1: Huấn luyện và Tối ưu hóa Đồ thị mạng (Python Env)
Toàn bộ tiến trình xây dựng mạng, tối ưu cấu trúc đồ thị ONNX và lượng tử hóa được thực hiện qua các file Jupyter Notebook trong thư mục `notebooks/`:
1. Huấn luyện mạng chập lượng tử hóa: Chạy tệp `2dconv.ipynb`.
2. Thực hiện tinh gọn đồ thị, cô lập phân mảnh và phân vùng cấu trúc luồng dữ liệu (Dataflow Partitioning): Chạy tuần tự các tệp `transform.ipynb` và `validate.ipynb`.

### Giai đoạn 2: Biên dịch Phần cứng với FINN (Docker Linux Env)
Khởi động Docker Container của FINN Framework, nạp tệp cấu hình tối ưu phần cứng `hardware_config/final_hw_config.json` để thực hiện quá trình tổng hợp cấp cao (High-Level Synthesis - HLS) sinh ra các lõi IP RTL tương thích cho dự án.

### Giai đoạn 3: Tổng hợp Mạch và Mô phỏng (Xilinx Vivado GUI)
1. Khởi động phần mềm Xilinx Vivado trên máy tính.
2. Thêm các file nguồn trong thư mục `hdl/` vào **Design Sources**, file `constraints/con.xdc` vào **Constraints**.
3. Thêm file `simulation/test.v` cùng `input_data.mem` vào **Simulation Sources**.
4. Chọn **Run Simulation** để kiểm tra dạng sóng tín hiệu bắt tay hoặc bấm **Generate Bitstream** để biên dịch file mạch nạp trực tiếp xuống chip.

---
*Đề tài được nghiên cứu và phát triển phục vụ cho mục đích nghiên cứu & phát triển các hệ th

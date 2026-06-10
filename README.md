# FPGA Accelerator for High-Throughput Cell Detection

<p align="center">
<img src="![Uploading image.png…]()
" width="650">
</p>

<p align="center">
Hardware Accelerator based on Zybo Z7-10 FPGA for real-time cell detection using a 4-bit quantized CNN compiled by AMD/Xilinx FINN Framework.
</p>

---

# 1. Tổng quan hệ thống

Dự án triển khai bộ tăng tốc phần cứng trên kit **Zybo Z7-10** sử dụng FPGA **Xilinx Zynq-7000 XC7Z010CLG400-1** nhằm thực hiện phân loại tín hiệu sinh học thời gian thực với thông lượng cao.

Tín hiệu đầu vào được lấy mẫu bởi ADC với tần số cố định **10 kHz**, sau đó được đóng gói thành vector độ dài 20 mẫu và truyền trực tiếp vào bộ tăng tốc CNN được sinh tự động bởi FINN Framework.

Kết quả phân loại được truyền ngược trở lại máy tính thông qua giao tiếp UART.

---

## Thông số hệ thống

| Thông số                  | Giá trị         |
| ------------------------- | --------------- |
| Board FPGA                | Zybo Z7-10      |
| FPGA Device               | XC7Z010CLG400-1 |
| Clock hệ thống            | 125 MHz         |
| Clock xử lý               | 50 MHz          |
| Tần số lấy mẫu ADC        | 10 kHz          |
| Kích thước vector đầu vào | 20 mẫu          |
| Cửa sổ thời gian xử lý    | 2 ms            |
| Giao tiếp đầu ra          | UART            |
| Framework                 | AMD/Xilinx FINN |
| Độ lượng tử hóa           | 4-bit           |

---

# 2. Kiến trúc phần cứng

## Sơ đồ khối toàn hệ thống

```text
                  Analog Signal
                        │
                        ▼
                ┌────────────────┐
                │     ADC 10kHz  │
                └────────────────┘
                        │
                        ▼
                ┌────────────────┐
                │ Sliding Window │
                │      L = 20    │
                └────────────────┘
                        │
                        ▼
                ┌────────────────┐
                │ AXI-Stream I/F │
                └────────────────┘
                        │
                        ▼
        ┌─────────────────────────────────┐
        │        FINN CNN Accelerator     │
        │                                 │
        │ Conv1 → Conv2 → FC → Output     │
        └─────────────────────────────────┘
                        │
                        ▼
                ┌────────────────┐
                │ FSM Controller │
                └────────────────┘
                        │
                        ▼
                ┌────────────────┐
                │ UART TX Module │
                └────────────────┘
                        │
                        ▼
                     Computer
```

---

## Kiến trúc bên trong FINN Accelerator

```text
Input Vector (20 samples)
            │
            ▼
     Quantized Conv1
            │
            ▼
        MaxPool
            │
            ▼
     Quantized Conv2
            │
            ▼
      Fully Connected
            │
            ▼
         Logit Output
```

---

## Kiến trúc Clock

```text
      125 MHz Crystal
              │
              ▼
       ┌────────────┐
       │ clk_wiz_0 │
       └────────────┘
              │
              ▼
            50 MHz
              │
              ▼
      FINN Streaming IP
```

---

## Song song hóa phần cứng

### MVAU_hls_0

```text
PE = 1
SIMD = 4
```

Tối ưu tài nguyên LUT và DSP.

### MVAU_hls_1

```text
PE = 4
SIMD = 8
```

Tăng thông lượng dữ liệu và giảm bottleneck giữa các tầng.

---

## Pin Assignment

Được định nghĩa trong:

```text
constraints/con.xdc
```

| Tín hiệu | Chân FPGA |
| -------- | --------- |
| sysclk   | K17       |
| uart_tx  | V12       |

---

# 3. Cấu trúc thư mục dự án

```text
.
├── hardware_config/
│   └── final_hw_config.json
│
├── notebooks/
│   ├── 2dconv.ipynb
│   ├── transform.ipynb
│   └── validate.ipynb
│
├── models/
│   └── quant_cnn_4bit.onnx
│
├── hdl/
│   ├── top.v
│   ├── sys.v
│   ├── adc_top.v
│   ├── finn_uart_backend.v
│   └── uart_tx.v
│
├── simulation/
│   ├── test.v
│   └── input_data.mem
│
└── constraints/
    └── con.xdc
```

---

# 4. Hướng dẫn triển khai

## Bước 1: Huấn luyện mạng CNN

Mở terminal:

```bash
jupyter notebook notebooks/2dconv.ipynb
```

Chạy lần lượt:

* 2dconv.ipynb
* transform.ipynb
* validate.ipynb

Sau khi hoàn tất sẽ sinh ra:

```text
models/quant_cnn_4bit.onnx
```

---

## Bước 2: Biên dịch phần cứng bằng FINN

Khởi động Docker của FINN Framework.

Sử dụng file:

```text
hardware_config/final_hw_config.json
```

FINN sẽ tự động:

* Tối ưu đồ thị mạng
* Sinh kiến trúc streaming
* Thực hiện HLS
* Đóng gói IP hỗ trợ AXI-Stream

---

## Bước 3: Tạo project Vivado

Mở:

```text
Vivado → Create Project
```

Chọn FPGA:

```text
xc7z010clg400-1
```

---

### Design Sources

Thêm toàn bộ file trong:

```text
hdl/
```

---

### Constraints

Thêm file:

```text
constraints/con.xdc
```

---

### Simulation Sources

Thêm:

```text
simulation/test.v
simulation/input_data.mem
```

---

## Bước 4: Chạy mô phỏng

Chọn:

```text
Run Simulation
```

Kiểm tra quá trình bắt tay AXI-Stream:

```text
tvalid
tready
```

---

## Bước 5: Generate Bitstream

Chọn:

```text
Generate Bitstream
```

Vivado sẽ thực hiện:

* Synthesis
* Implementation
* Bitstream Generation

Kết quả thu được:

```text
.bit
```

---

## Bước 6: Nạp xuống FPGA

Kết nối Zybo Z7 với máy tính qua cáp USB.

Mở:

```text
Hardware Manager
```

Sau đó:

```text
Open Target
↓
Auto Connect
↓
Program Device
```

Nạp file `.bit` xuống FPGA.

Sau khi nạp thành công, bộ tăng tốc CNN sẽ hoạt động ở 50 MHz và kết quả phân loại được truyền trở lại máy tính thông qua UART.

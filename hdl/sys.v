`timescale 1ns / 1ps

module system_integration_top (
    input  wire sysclk,    
    input  wire ja_p,     
    input  wire ja_n,    
    output wire tx_out   
);

    wire clk_50mhz;
    wire pll_locked;
    wire global_reset_n;

    clk_wiz_0 global_clock_gen (
        .clk_in1(sysclk),
        .reset(1'b0),
        .clk_out1(clk_50mhz),
        .locked(pll_locked)
    );

    assign global_reset_n = pll_locked;

    wire [7:0]  axis_adc_to_finn_tdata;
    wire        axis_adc_to_finn_tvalid;
    wire        axis_adc_to_finn_tready;

    wire [15:0] axis_finn_to_uart_tdata;
    wire        axis_finn_to_uart_tvalid;
    wire        axis_finn_to_uart_tready;

    reg [4:0] reset_counter;
    reg       finn_local_rst_n;
    reg       cnn_reset_state;

    localparam STATE_RUN = 1'b0;
    localparam STATE_RST = 1'b1;

    always @(posedge clk_50mhz) begin
        if (!global_reset_n) begin
            cnn_reset_state <= STATE_RUN;
            finn_local_rst_n <= 1'b0;
            reset_counter <= 5'd0;
        end else begin
            case (cnn_reset_state)
                STATE_RUN: begin
                    finn_local_rst_n <= 1'b1;
                    if (axis_finn_to_uart_tvalid && axis_finn_to_uart_tready) begin
                        cnn_reset_state <= STATE_RST;
                        reset_counter <= 5'd0;
                        finn_local_rst_n <= 1'b0; 
                    end
                end
                
                STATE_RST: begin
                    finn_local_rst_n <= 1'b0;
                    if (reset_counter == 5'd15) begin
                        cnn_reset_state <= STATE_RUN;
                        finn_local_rst_n <= 1'b1;
                    end else begin
                        reset_counter <= reset_counter + 1;
                    end
                end
            endcase
        end
    end

    // Tín hiệu reset tổng hợp cấp cho khối FINN
    wire combined_finn_rst_n = global_reset_n & finn_local_rst_n;

    // =========================================================
    // INSTANTIATION MODULES
    // =========================================================
    adc_axis_finn_frontend data_acquisition_inst (
        .clk_50mhz     (clk_50mhz),
        .reset_n       (global_reset_n), // ADC Frontend tiếp tục chạy bằng global reset
        .ja_p          (ja_p),
        .ja_n          (ja_n),
        .m_axis_tdata  (axis_adc_to_finn_tdata),
        .m_axis_tvalid (axis_adc_to_finn_tvalid),
        .m_axis_tready (axis_adc_to_finn_tready)
    );

    finn_design_wrapper neural_network_inst (
        .ap_clk          (clk_50mhz),
        .ap_rst_n        (combined_finn_rst_n), // Sử dụng tín hiệu reset đã được điều chế
        
        // Đầu vào từ ADC
        .s_axis_0_tdata  (axis_adc_to_finn_tdata),
        .s_axis_0_tvalid (axis_adc_to_finn_tvalid),
        .s_axis_0_tready (axis_adc_to_finn_tready),
        
        // Đầu ra tới UART
        .m_axis_0_tdata  (axis_finn_to_uart_tdata),
        .m_axis_0_tvalid (axis_finn_to_uart_tvalid),
        .m_axis_0_tready (axis_finn_to_uart_tready)
    );

    finn_uart_backend serialization_inst (
        .clk_50mhz     (clk_50mhz),  
        .system_reset  (~global_reset_n),
        .s_axis_tdata  (axis_finn_to_uart_tdata),
        .s_axis_tvalid (axis_finn_to_uart_tvalid),
        .s_axis_tready (axis_finn_to_uart_tready),
        .tx_out        (tx_out)
    );

    ila_0 system_monitor_inst (
        .clk    (clk_50mhz),
        
        .probe0 (combined_finn_rst_n),      // Giám sát tín hiệu reset động (đã thay thế probe global_reset_n)
        .probe1 (tx_out),                   // 1-bit
        
        .probe2 (axis_adc_to_finn_tdata),   // 8-bit
        .probe3 (axis_adc_to_finn_tvalid),  // 1-bit
        .probe4 (axis_adc_to_finn_tready),  // 1-bit
        
        .probe5 (axis_finn_to_uart_tdata),  // 16-bit
        .probe6 (axis_finn_to_uart_tvalid), // 1-bit
        .probe7 (axis_finn_to_uart_tready)  // 1-bit
    );

endmodule
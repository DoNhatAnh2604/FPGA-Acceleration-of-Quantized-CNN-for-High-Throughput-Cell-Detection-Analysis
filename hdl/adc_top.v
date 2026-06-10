`timescale 1ns / 1ps

module adc_axis_finn_frontend (
    input  wire        clk_50mhz,    // Nguồn xung nhịp 50 MHz (cấp từ bên ngoài)
    input  wire        reset_n,      // Tín hiệu reset tích cực mức thấp (Active-Low)
    input  wire        ja_p,         // Kênh Vaux14 Positive
    input  wire        ja_n,         // Kênh Vaux14 Negative

    output wire [7:0]  m_axis_tdata,
    output reg         m_axis_tvalid,
    input  wire        m_axis_tready
);

    wire [15:0] xadc_dout;
    wire        xadc_drdy;
    wire        xadc_eoc;
    
    reg [12:0]  trigger_counter;
    reg         conv_start;

    reg [7:0]   sample_window [0:19];
    reg         start_tx;
    integer     i;

    localparam IDLE = 1'b0, SEND = 1'b1;
    reg         state;
    reg [4:0]   tx_idx;

    wire [7:0]  quantized_cnn_data;
    assign quantized_cnn_data = {~xadc_dout[15], xadc_dout[14:8]};

    always @(posedge clk_50mhz) begin
        if (!reset_n) begin
            trigger_counter <= 13'd0;
            conv_start <= 1'b0;
        end else if (trigger_counter == 13'd4999) begin
            trigger_counter <= 13'd0;
            conv_start <= 1'b1;
        end else begin
            trigger_counter <= trigger_counter + 1;
            conv_start <= 1'b0;
        end
    end

    xadc_wiz_0 xadc_inst (
        .dclk_in        (clk_50mhz),
        .den_in         (xadc_eoc),
        .dwe_in         (1'b0),
        .daddr_in       (7'h1E),      
        .di_in          (16'h0000),
        .do_out         (xadc_dout),
        .drdy_out       (xadc_drdy),
        .eoc_out        (xadc_eoc),
        .convst_in      (conv_start), 
        
        .vauxp14        (ja_p),
        .vauxn14        (ja_n),
        .vp_in          (1'b0),
        .vn_in          (1'b0)
    );

    always @(posedge clk_50mhz) begin
        if (!reset_n) begin
            start_tx <= 1'b0;
            for (i = 0; i < 20; i = i + 1) begin
                sample_window[i] <= 8'd0;
            end
        end else begin
            start_tx <= 1'b0;
            if (xadc_drdy) begin
                for (i = 0; i < 19; i = i + 1) begin
                    sample_window[i] <= sample_window[i+1];
                end
                sample_window[19] <= quantized_cnn_data;
                start_tx <= 1'b1;
            end
        end
    end

    assign m_axis_tdata = sample_window[tx_idx];

    always @(posedge clk_50mhz) begin
        if (!reset_n) begin
            state <= IDLE;
            tx_idx <= 5'd0;
            m_axis_tvalid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start_tx) begin
                        state <= SEND;
                        tx_idx <= 5'd0;
                        m_axis_tvalid <= 1'b1;
                    end else begin
                        m_axis_tvalid <= 1'b0;
                    end
                end
                
                SEND: begin
                    if (m_axis_tready) begin
                        if (tx_idx == 5'd19) begin
                            state <= IDLE;
                            m_axis_tvalid <= 1'b0;
                        end else begin
                            tx_idx <= tx_idx + 1;
                        end
                    end
                end
            endcase
        end
    end

endmodule
`timescale 1ns / 1ps

module finn_uart_backend (
    input  wire        clk_50mhz,       
    
    input  wire [15:0] s_axis_tdata,  
    input  wire        s_axis_tvalid, 
    output wire        s_axis_tready, 
    
    output wire        tx_out         // UART TX output (Pin V15)
);

    reg        tx_start = 0;
    reg  [7:0] tx_data = 0;
    wire       tx_active;
    wire       tx_done;

    // -------------------------------------------------------------------------
    // FSM and Protocol Declarations
    // -------------------------------------------------------------------------
    reg [2:0] state = 0;
    localparam WAIT_AXIS    = 3'd0,
               SEND_DATA    = 3'd1,
               WAIT_TX_DATA = 3'd2,
               SEND_CR      = 3'd3,
               WAIT_TX_CR   = 3'd4,
               SEND_LF      = 3'd5,
               WAIT_TX_LF   = 3'd6;

    reg [15:0] captured_data = 0;

    assign s_axis_tready = (state == WAIT_AXIS) && ~system_reset;

    // -------------------------------------------------------------------------
    always @(posedge clk_50mhz) begin
        if (system_reset) begin
            state         <= WAIT_AXIS;
            tx_start      <= 1'b0;
            tx_data       <= 8'h00;
            captured_data <= 16'd0;
        end else begin
            case (state)
                WAIT_AXIS: begin
                    tx_start <= 1'b0;
                    if (s_axis_tvalid && s_axis_tready) begin
                        captured_data <= s_axis_tdata;
                        state         <= SEND_DATA;
                    end
                end

                SEND_DATA: begin
                    // ASCII Conversion: Add 0x30 to the integer value
                    tx_data  <= 8'h30 + captured_data[3:0];
                    tx_start <= 1'b1;
                    state    <= WAIT_TX_DATA;
                end

                WAIT_TX_DATA: begin
                    tx_start <= 1'b0;
                    if (tx_done) state <= SEND_CR;
                end

                SEND_CR: begin
                    tx_data  <= 8'h0D; // Carriage Return (\r)
                    tx_start <= 1'b1;
                    state    <= WAIT_TX_CR;
                end

                WAIT_TX_CR: begin
                    tx_start <= 1'b0;
                    if (tx_done) state <= SEND_LF;
                end

                SEND_LF: begin
                    tx_data  <= 8'h0A; // Line Feed (\n)
                    tx_start <= 1'b1;
                    state    <= WAIT_TX_LF;
                end

                WAIT_TX_LF: begin
                    tx_start <= 1'b0;
                    if (tx_done) state <= WAIT_AXIS; // Return to ingest next frame
                end

                default: state <= WAIT_AXIS;
            endcase
        end
    end

    // Baud rate parameter: 50,000,000 Hz / 115200 baud = 434
    uart_tx #(
        .CLKS_PER_BIT(434) 
    ) tx_inst (
        .clk(clk_50mhz),
        .rst(system_reset),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx(tx_out),
        .tx_active(tx_active),
        .tx_done(tx_done)
    );


    ila_0 logic_analyzer (
        .clk(clk_50mhz),
        .probe0(s_axis_tdata),
        .probe1(s_axis_tvalid),
        .probe2(s_axis_tready),
        .probe3(tx_out),
        .probe4(state)
    );

endmodule
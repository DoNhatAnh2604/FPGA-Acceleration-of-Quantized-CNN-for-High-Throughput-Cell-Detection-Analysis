`timescale 1ns / 1ps

module fpga_verification_top(
    input wire sysclk       //125MHz on Zybo Z7
);

    // Clock Wizard
    wire ap_clk;
    wire locked;
    
    clk_wiz_0 clk_gen (
        .clk_out1(ap_clk), // 50MHz
        .locked(locked),
        .clk_in1(sysclk)
    );

    wire vio_reset_n;
    wire vio_start;
    
    wire [15:0] m_axis_0_tdata;
    wire m_axis_0_tvalid;
    reg  m_axis_0_tready;
    
    reg [7:0] s_axis_0_tdata;
    reg s_axis_0_tvalid;
    wire s_axis_0_tready;

    reg [7:0] data_rom [0:19];
    initial begin
        data_rom[0]  = 8'h01;
        data_rom[1]  = 8'h01;
        data_rom[2]  = 8'h03;
        data_rom[3]  = 8'h0C;
        data_rom[4]  = 8'h1E;
        data_rom[5]  = 8'h2E;
        data_rom[6]  = 8'h34;
        data_rom[7]  = 8'h38;
        data_rom[8]  = 8'h28;
        data_rom[9]  = 8'h05;
        data_rom[10] = 8'hE3;
        data_rom[11] = 8'hCC;
        data_rom[12] = 8'hCA;
        data_rom[13] = 8'hCB;
        data_rom[14] = 8'hD9;
        data_rom[15] = 8'hEC;
        data_rom[16] = 8'hF9;
        data_rom[17] = 8'hFF;
        data_rom[18] = 8'h00;
        data_rom[19] = 8'h00;
    end

    finn_design_wrapper dut (
        .ap_clk(ap_clk),
        .ap_rst_n(vio_reset_n),
        .m_axis_0_tdata(m_axis_0_tdata),
        .m_axis_0_tready(m_axis_0_tready),
        .m_axis_0_tvalid(m_axis_0_tvalid),
        .s_axis_0_tdata(s_axis_0_tdata),
        .s_axis_0_tready(s_axis_0_tready),
        .s_axis_0_tvalid(s_axis_0_tvalid)
    );

    reg [4:0] index;
    reg [1:0] state;
    localparam IDLE = 0, SEND = 1, DONE = 2;

    always @(posedge ap_clk or negedge vio_reset_n) begin
        if (!vio_reset_n) begin
            state <= IDLE;
            index <= 0;
            s_axis_0_tvalid <= 0;
            s_axis_0_tdata <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (vio_start) state <= SEND; 
                end
                
                SEND: begin
                    s_axis_0_tdata <= data_rom[index];
                    s_axis_0_tvalid <= 1;
                    
                    if (s_axis_0_tready) begin
                        if (index == 20) begin
                            state <= DONE;
                            s_axis_0_tvalid <= 0;
                        end else begin
                            index <= index + 1;
                        end
                    end
                end
                
                DONE: begin
                    s_axis_0_tvalid <= 0;
                end
            endcase
        end
    end

    always @(posedge ap_clk) begin
        m_axis_0_tready <= 1; 
    end

    vio_0 my_vio (
        .clk(ap_clk),
        .probe_out0(vio_reset_n), 
        .probe_out1(vio_start)   
    );

    ila_0 my_ila (
        .clk(ap_clk),
        .probe0(s_axis_0_tdata), 
        .probe1(s_axis_0_tvalid), 
        .probe2(s_axis_0_tready),
        .probe3(m_axis_0_tdata),  
        .probe4(m_axis_0_tvalid),
        .probe5(state)         
    );

endmodule
module tang_nano_20k_top #(
    parameter string PROM_PATH = "../helloworld_prg.hex",
    parameter string CROM_PATH = "../helloworld_chr.hex"
) (
    input  wire       I_clk,
    input  wire       I_rst,
    input  wire       I_key,
    output wire [5:0] O_led,
    output wire       O_tmds_clk_p,
    output wire       O_tmds_clk_n,
    output wire [2:0] O_tmds_data_p,
    output wire [2:0] O_tmds_data_n
);

wire clk27 = I_clk;

wire rst_n_async = !I_rst;
logic [1:0] rst_n_sync = 2'b00;

always_ff @(posedge clk27 or negedge rst_n_async) begin
    if (!rst_n_async)
        rst_n_sync <= 2'b00;
    else
        rst_n_sync <= {rst_n_sync[0], 1'b1};
end

wire rst_n = rst_n_sync[1];

// LEDs are active-low; use LED 0 as a direct key indicator and keep the rest off.
assign O_led = {5'b11111, I_key};

wire clk135;

wire [7:0] hdmi_r;
wire [7:0] hdmi_g;
wire [7:0] hdmi_b;
wire hdmi_hsync;
wire hdmi_vsync;
wire hdmi_de;

Gowin_rPLL hdmi_pll (
    .clkin  (clk27),
    .clkout (clk135)
);

tarunes_top #(
    .PROM_PATH(PROM_PATH),
    .CROM_PATH(CROM_PATH)
) core (
    .clk        (clk27),
    .rst        (rst_n),
    .hdmi_r     (hdmi_r),
    .hdmi_g     (hdmi_g),
    .hdmi_b     (hdmi_b),
    .hdmi_hsync (hdmi_hsync),
    .hdmi_vsync (hdmi_vsync),
    .hdmi_de    (hdmi_de)
);

DVI_TX_Top hdmi_out (
    .I_rst_n       (rst_n),
    .I_serial_clk  (clk135),
    .I_rgb_clk     (clk27),
    .I_rgb_vs      (hdmi_vsync),
    .I_rgb_hs      (hdmi_hsync),
    .I_rgb_de      (hdmi_de),
    .I_rgb_r       (hdmi_r),
    .I_rgb_g       (hdmi_g),
    .I_rgb_b       (hdmi_b),
    .O_tmds_clk_p  (O_tmds_clk_p),
    .O_tmds_clk_n  (O_tmds_clk_n),
    .O_tmds_data_p (O_tmds_data_p),
    .O_tmds_data_n (O_tmds_data_n)
);

endmodule

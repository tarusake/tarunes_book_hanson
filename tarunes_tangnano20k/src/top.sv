module tarunes_top #(
    parameter string PROM_PATH = "",
    parameter string CROM_PATH = ""
) (
    input  var logic          clk         ,
    input  var logic          rst         ,
    output var logic [9-1:0]  scanline    ,
    output var logic [9-1:0]  cycle       ,
    output var logic [8-1:0]  pixel_r     ,
    output var logic [8-1:0]  pixel_g     ,
    output var logic [8-1:0]  pixel_b     ,
    output var logic [8-1:0]  hdmi_r      ,
    output var logic [8-1:0]  hdmi_g      ,
    output var logic [8-1:0]  hdmi_b      ,
    output var logic          hdmi_hsync  ,
    output var logic          hdmi_vsync  ,
    output var logic          hdmi_de     ,
    output var logic [10-1:0] hdmi_video_x,
    output var logic [10-1:0] hdmi_video_y
);
    logic [6-1:0] pixel_index;

    tarunes___bus_if__8__16 cpubus     ();
    tarunes___bus_if__8__3  cpu_ppubus ();
    tarunes___bus_if__8__11 wrambus    ();
    tarunes___bus_if__8__15 prombus    ();
    tarunes___bus_if__8__14 ppubus     ();
    tarunes___bus_if__8__11 vrambus    ();
    tarunes___bus_if__8__13 crombus    ();
    tarunes_cpu cpu_inst (
        .clk    (clk   ),
        .rst    (rst   ),
        .cpubus (cpubus)
    );
    tarunes___memory__8__11 wram (
        .clk    (clk    ),
        .rst    (rst    ),
        .membus (wrambus)
    );
    tarunes___memory__8__15 #(
        .PATH (PROM_PATH)
    ) prom (
        .clk    (clk    ),
        .rst    (rst    ),
        .membus (prombus)
    );
    tarunes___memory__8__11 vram (
        .clk    (clk    ),
        .rst    (rst    ),
        .membus (vrambus)
    );
    tarunes___memory__8__13 #(
        .PATH (CROM_PATH)
    ) crom (
        .clk    (clk    ),
        .rst    (rst    ),
        .membus (crombus)
    );
    tarunes_bus_cpu ubus (
        .clk        (clk       ),
        .rst        (rst       ),
        .cpubus     (cpubus    ),
        .cpu_ppubus (cpu_ppubus),
        .prombus    (prombus   ),
        .wrambus    (wrambus   )
    );
    tarunes_ppu ppu_inst (
        .clk         (clk        ),
        .rst         (rst        ),
        .cpubus      (cpu_ppubus ),
        .ppubus      (ppubus     ),
        .scanline    (scanline   ),
        .cycle       (cycle      ),
        .pixel_index (pixel_index),
        .pixel_r     (pixel_r    ),
        .pixel_g     (pixel_g    ),
        .pixel_b     (pixel_b    )
    );
    tarunes_bus_ppu ppu_bus (
        .clk     (clk    ),
        .rst     (rst    ),
        .ppubus  (ppubus ),
        .crombus (crombus),
        .vrambus (vrambus)
    );
    tarunes_hdmi_480p_scaler hdmi_scaler (
        .clk              (clk         ),
        .rst              (rst         ),
        .core_cycle       (cycle       ),
        .core_scanline    (scanline    ),
        .core_pixel_index (pixel_index ),
        .hdmi_r           (hdmi_r      ),
        .hdmi_g           (hdmi_g      ),
        .hdmi_b           (hdmi_b      ),
        .hdmi_hsync       (hdmi_hsync  ),
        .hdmi_vsync       (hdmi_vsync  ),
        .hdmi_de          (hdmi_de     ),
        .video_x          (hdmi_video_x),
        .video_y          (hdmi_video_y)
    );
endmodule
//# sourceMappingURL=top.sv.map

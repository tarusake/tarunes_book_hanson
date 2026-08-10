module tarunes_hdmi_480p_scaler (
    input  var logic          clk             ,
    input  var logic          rst             ,
    input  var logic [9-1:0]  core_cycle      ,
    input  var logic [9-1:0]  core_scanline   ,
    input  var logic [6-1:0]  core_pixel_index,
    output var logic [8-1:0]  hdmi_r          ,
    output var logic [8-1:0]  hdmi_g          ,
    output var logic [8-1:0]  hdmi_b          ,
    output var logic          hdmi_hsync      ,
    output var logic          hdmi_vsync      ,
    output var logic          hdmi_de         ,
    output var logic [10-1:0] video_x         ,
    output var logic [10-1:0] video_y     
);
    localparam int unsigned          FB_PIXELS          = 256 * 240;
    localparam logic        [10-1:0] H_ACTIVE           = 10'd720;
    localparam logic        [10-1:0] H_FRONT_PORCH      = 10'd16;
    localparam logic        [10-1:0] H_SYNC             = 10'd62;
    localparam logic        [10-1:0] H_TOTAL            = 10'd858;
    localparam logic        [10-1:0] V_ACTIVE           = 10'd480;
    localparam logic        [10-1:0] V_FRONT_PORCH      = 10'd9;
    localparam logic        [10-1:0] V_SYNC             = 10'd6;
    localparam logic        [10-1:0] V_TOTAL            = 10'd525;
    localparam logic        [10-1:0] X_OFFSET           = 10'd104;
    localparam logic        [10-1:0] SCALED_WIDTH       = 10'd512;
    localparam logic        [6-1:0]  BORDER_COLOR_INDEX = 6'h0F;

    localparam logic [24-1:0] NES_PALETTE [64] = '{
        24'h666666, 24'h002A88, 24'h1412A7, 24'h3B00A4, 24'h5C007E, 24'h6E0040, 24'h6C0600, 24'h561D00, 24'h333500,
        24'h0B4800, 24'h005200, 24'h004F08, 24'h00404D, 24'h000000, 24'h000000, 24'h000000, 24'hADADAD, 24'h155FD9,
        24'h4240FF, 24'h7527FE, 24'hA01ACC, 24'hB71E7B, 24'hB53120, 24'h994E00, 24'h6B6D00, 24'h388700, 24'h0C9300,
        24'h008F32, 24'h007C8D, 24'h000000, 24'h000000, 24'h000000, 24'hFFFEFF, 24'h64B0FF, 24'h9290FF, 24'hC676FF,
        24'hF36AFF, 24'hFE6ECC, 24'hFE8170, 24'hEA9E22, 24'hBCBE00, 24'h88D800, 24'h5CE430, 24'h45E082, 24'h48CDDE,
        24'h4F4F4F, 24'h000000, 24'h000000, 24'hFFFEFF, 24'hC0DFFF, 24'hD3D2FF, 24'hE8C8FF, 24'hFBC2FF, 24'hFEC4EA,
        24'hFECCC5, 24'hF7D8A5, 24'hE4E594, 24'hCFEE96, 24'hBDF4AB, 24'hB3F3CC, 24'hB5EBF2, 24'hB8B8B8, 24'h000000,
        24'h000000
    };

    logic [6-1:0]  framebuffer   [FB_PIXELS];
    logic [10-1:0] h_count                  ;
    logic [10-1:0] v_count                  ;
    logic          core_visible             ;
    logic          active_area              ;
    logic          scaled_area              ;
    logic [16-1:0] write_addr               ;
    logic [10-1:0] scaled_x                 ;
    logic [8-1:0]  src_x                    ;
    logic [8-1:0]  src_y                    ;
    logic [16-1:0] read_addr                ;
    logic [6-1:0]  read_pixel               ;
    logic [24-1:0] palette_color            ;

    always_comb core_visible = core_cycle < 9'd256 && core_scanline < 9'd240;
    always_comb write_addr   = {core_scanline[7:0], 8'b0} + {8'b0, core_cycle[7:0]};

    always_comb active_area   = h_count < H_ACTIVE && v_count < V_ACTIVE;
    always_comb scaled_area   = active_area && h_count >= X_OFFSET && h_count < X_OFFSET + SCALED_WIDTH;
    always_comb scaled_x      = h_count - X_OFFSET;
    always_comb src_x         = scaled_x[8:1];
    always_comb src_y         = v_count[8:1];
    always_comb read_addr     = {src_y, 8'b0} + {8'b0, src_x};
    always_comb palette_color = NES_PALETTE[read_pixel];
    always_comb hdmi_r        = palette_color[23:16];
    always_comb hdmi_g        = palette_color[15:8];
    always_comb hdmi_b        = palette_color[7:0];

    always_ff @ (posedge clk) begin
        if (!rst) begin
            h_count    <= 0;
            v_count    <= 0;
            hdmi_hsync <= 1;
            hdmi_vsync <= 1;
            hdmi_de    <= 0;
            video_x    <= 0;
            video_y    <= 0;
            read_pixel <= BORDER_COLOR_INDEX;
        end else begin
            if (core_visible) begin
                framebuffer[write_addr] <= core_pixel_index;
            end

            // Keep the framebuffer read synchronous so Gowin can map this
            // 61,440 x 6 memory into BSRAM instead of hundreds of thousands
            // of flip-flops.
            if (scaled_area) begin
                read_pixel <= framebuffer[read_addr];
            end else begin
                read_pixel <= BORDER_COLOR_INDEX;
            end

            hdmi_de    <= active_area;
            hdmi_hsync <= !(h_count >= H_ACTIVE + H_FRONT_PORCH && h_count < H_ACTIVE + H_FRONT_PORCH + H_SYNC);
            hdmi_vsync <= !(v_count >= V_ACTIVE + V_FRONT_PORCH && v_count < V_ACTIVE + V_FRONT_PORCH + V_SYNC);
            video_x    <= h_count;
            video_y    <= v_count;

            if (h_count == H_TOTAL - 10'd1) begin
                h_count <= 0;
                if (v_count == V_TOTAL - 10'd1) begin
                    v_count <= 0;
                end else begin
                    v_count <= v_count + 10'd1;
                end
            end else begin
                h_count <= h_count + 10'd1;
            end
        end
    end
endmodule
//# sourceMappingURL=hdmi_480p_scaler.sv.map

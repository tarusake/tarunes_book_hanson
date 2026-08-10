module tarunes_ppu (
    input var logic                              clk        ,
    input var logic                              rst        ,
    tarunes___bus_if__8__3.slave           cpubus     ,
    tarunes___bus_if__8__14.master         ppubus     ,
    output var logic                      [9-1:0] scanline   ,
    output var logic                      [9-1:0] cycle      ,
    output var logic                      [6-1:0] pixel_index,
    output var logic                      [8-1:0] pixel_r    ,
    output var logic                      [8-1:0] pixel_g    ,
    output var logic                      [8-1:0] pixel_b
);
    localparam logic [3-1:0] PPUADDR_ADDR    = 3'd6;
    localparam logic [3-1:0] PPUDATA_ADDR    = 3'd7;
    localparam logic [9-1:0] VISIBLE_CYCLES  = 256;
    localparam logic [9-1:0] VISIBLE_LINES   = 240;
    localparam logic [9-1:0] LAST_CYCLE      = 340;
    localparam logic [9-1:0] PRE_RENDER_LINE = 261;
    localparam logic [6-1:0] LAST_TILE_X     = 31;
    localparam logic [9-1:0] PREFETCH_CYCLE  = 248;

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

    logic [24-1:0] palette_color       ;
    logic [8-1:0]  palette_ram     [32];
    logic          reg_w               ;
    logic [16-1:0] reg_v               ;
    logic [14-1:0] ppu_addr_render     ;
    logic          visible             ;
    logic          prefetch_first      ;
    logic          tile_fetch          ;
    logic [6-1:0]  tile_x              ;
    logic [6-1:0]  tile_y              ;
    logic [6-1:0]  next_tile_x         ;
    logic [6-1:0]  next_tile_y         ;
    logic [14-1:0] chr_addr            ;
    logic [8-1:0]  plane           [2] ;
    logic [8-1:0]  plane_draw      [2] ;
    logic [3-1:0]  fine_x              ;
    logic [3-1:0]  fine_y_fetch        ;
    logic [2-1:0]  color_2bit          ;

    always_comb visible        = cycle < VISIBLE_CYCLES && scanline < VISIBLE_LINES;
    always_comb prefetch_first = scanline == PRE_RENDER_LINE && cycle >= PREFETCH_CYCLE && cycle < VISIBLE_CYCLES;
    always_comb tile_fetch     = visible || prefetch_first;

    always_comb tile_x       = cycle[8:3];
    always_comb tile_y       = scanline[8:3];
    always_comb next_tile_x  = (((tile_x == LAST_TILE_X)) ? ( 6'd0 ) : ( tile_x + 6'd1 ));
    always_comb next_tile_y  = ((prefetch_first) ? ( 6'd0 ) : ((tile_x == LAST_TILE_X)) ? ( tile_y + 6'd1 ) : ( tile_y ));
    always_comb fine_x       = 7 - cycle[2:0];
    always_comb fine_y_fetch = ((prefetch_first) ? ( 0 ) : ( scanline[2:0] ));
    always_comb color_2bit   = {plane_draw[1][fine_x], plane_draw[0][fine_x]};

    function automatic logic is_palette_addr(
        input var logic [16-1:0] addr
    ) ;
        return addr[15:8] == 8'h3F;
    endfunction

    always_comb begin
        cpubus.rdata = 0;
        ppubus.addr  = ppu_addr_render;
        ppubus.wdata = 0;
        ppubus.wen   = 0;

        if ((cpubus.wen && cpubus.addr == PPUDATA_ADDR && !is_palette_addr(reg_v))) begin
            ppubus.addr  = reg_v[13:0];
            ppubus.wen   = 1;
            ppubus.wdata = cpubus.wdata;
        end
    end

    always_ff @ (posedge clk) begin
        if (!rst) begin
            reg_w       <= 0;
            reg_v       <= 0;
            palette_ram <= '{default: 8'h00};
        end else if (cpubus.wen) begin
            case ((cpubus.addr)) inside
                PPUADDR_ADDR: begin
                    reg_w <= ~reg_w;
                    if (!reg_w) begin
                        reg_v[15:8] <= cpubus.wdata;
                    end else begin
                        reg_v[7:0] <= cpubus.wdata;
                    end
                end
                PPUDATA_ADDR: begin
                    if (is_palette_addr(reg_v)) begin
                        palette_ram[reg_v[4:0]] <= cpubus.wdata;
                    end
                    reg_v <= reg_v + 16'd1;
                end
            endcase
        end
    end

    always_ff @ (posedge clk) begin
        if (!rst) begin
            cycle    <= 0;
            scanline <= 0;
        end else begin
            if ((cycle == LAST_CYCLE)) begin
                cycle <= 0;
                if ((scanline == PRE_RENDER_LINE)) begin
                    scanline <= 0;
                end else begin
                    scanline <= scanline + 9'd1;
                end
            end else begin
                cycle <= cycle + 9'd1;
            end
        end
    end

    always_ff @ (posedge clk) begin
        if (!rst) begin
            ppu_addr_render <= 0;
            chr_addr        <= 0;
            plane           <= '{default: 0};
            plane_draw      <= '{default: 0};
        end else if (tile_fetch) begin
            case ((cycle[2:0]))
                0: begin
                    logic [14-1:0] nt_addr        ;
                    nt_addr         = 14'h2000 + {3'b000, next_tile_y, 5'b00000}
                                      + {8'b00000000, next_tile_x};
                    ppu_addr_render <= nt_addr;
                end
                2: begin
                    logic [8-1:0] tile_id        ;
                    tile_id         = ppubus.rdata;
                    ppu_addr_render <= {2'b00, tile_id, 4'b0000}
                                       + {11'b00000000000, fine_y_fetch};
                    chr_addr        <= {2'b00, tile_id, 4'b0000}
                                       + {11'b00000000000, fine_y_fetch};
                end
                3: begin
                    ppu_addr_render <= chr_addr + 14'd8;
                end
                4: begin
                    plane[0] <= ppubus.rdata;
                end
                5: begin
                    plane[1] <= ppubus.rdata;
                end
                7: begin
                    plane_draw[0] <= plane[0];
                    plane_draw[1] <= plane[1];
                end
            endcase
        end
    end

    always_comb begin
        if (visible) begin
            pixel_index = palette_ram[{3'b000, color_2bit}][5:0];
        end else begin
            pixel_index = 6'h0F;
        end
    end

    always_comb palette_color = NES_PALETTE[pixel_index];
    always_comb pixel_r       = palette_color[23:16];
    always_comb pixel_g       = palette_color[15:8];
    always_comb pixel_b       = palette_color[7:0];
endmodule
//# sourceMappingURL=ppu.sv.map

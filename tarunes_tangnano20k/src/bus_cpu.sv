module tarunes_bus_cpu (
    input var logic                      clk       ,
    input var logic                      rst       ,
    tarunes___bus_if__8__16.slave  cpubus    ,
    tarunes___bus_if__8__3.master  cpu_ppubus,
    tarunes___bus_if__8__11.master wrambus   ,
    tarunes___bus_if__8__15.master prombus   
);
    logic sel_prom;
    logic sel_ppu ;
    logic sel_wram;

    always_comb sel_wram = cpubus.addr < 16'h2000;
    always_comb sel_ppu  = cpubus.addr >= 16'h2000 && cpubus.addr <= 16'h2007;
    always_comb sel_prom = cpubus.addr >= 16'h8000;

    always_comb prombus.addr    = ((sel_prom) ? ( cpubus.addr[14:0] ) : ( 'x ));
    always_comb cpu_ppubus.addr = ((sel_ppu) ? ( cpubus.addr[2:0] ) : ( 'x ));
    always_comb wrambus.addr    = ((sel_wram) ? ( cpubus.addr[10:0] ) : ( 'x ));

    always_comb cpu_ppubus.wdata = ((sel_ppu) ? ( cpubus.wdata ) : ( 'x ));
    always_comb cpu_ppubus.wen   = ((sel_ppu) ? ( cpubus.wen ) : ( 'x ));
    always_comb wrambus.wdata    = ((sel_wram) ? ( cpubus.wdata ) : ( 'x ));
    always_comb wrambus.wen      = ((sel_wram) ? ( cpubus.wen ) : ( 'x ));

    always_comb prombus.wdata = 0;
    always_comb prombus.wen   = 0;

    logic sel_prom_d;
    logic sel_ppu_d ;
    logic sel_wram_d;

    always_ff @ (posedge clk) begin
        if (!rst) begin
            sel_prom_d <= 0;
            sel_ppu_d  <= 0;
            sel_wram_d <= 0;
        end else begin
            sel_prom_d <= sel_prom;
            sel_ppu_d  <= sel_ppu;
            sel_wram_d <= sel_wram;
        end
    end

    always_comb begin
        if (sel_prom_d) begin
            cpubus.rdata = prombus.rdata;
        end else if (sel_ppu_d) begin
            cpubus.rdata = cpu_ppubus.rdata;
        end else if (sel_wram_d) begin
            cpubus.rdata = wrambus.rdata;
        end else begin
            cpubus.rdata = 'x;
        end
    end
endmodule
//# sourceMappingURL=bus_cpu.sv.map

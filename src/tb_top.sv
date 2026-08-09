`timescale 1ns/1ps

module tb_top;
    logic clk = 0;
    logic rst = 0;

    tarunes_top dut (
        .clk(clk),
        .rst(rst)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("wave.fst");
        $dumpvars(0, tb_top);

        dut.prom.mem[16'h7FFC] = 8'h00;
        dut.prom.mem[16'h7FFD] = 8'h80;
        dut.prom.mem[16'h0000] = 8'h78; // SEI
        dut.prom.mem[16'h0001] = 8'hA2; // LDX #$FF
        dut.prom.mem[16'h0002] = 8'hFF;
        dut.prom.mem[16'h0003] = 8'h9A; // TXS
        dut.prom.mem[16'h0004] = 8'hA9; // LDA #$00
        dut.prom.mem[16'h0005] = 8'h00;

        #20 rst = 1;
        #200;
        $display("PC = %h", dut.cpu_inst.reg_pc);
        $finish;
    end
endmodule
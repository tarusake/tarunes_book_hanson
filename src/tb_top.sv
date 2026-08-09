`timescale 1ns/1ps

module tb_top;
    logic clk = 0;
    logic rst = 0;

    tarunes_top #(
        .PROM_PATH("helloworld_prg.hex")
    ) dut (
        .clk(clk),
        .rst(rst)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("wave.fst");
        $dumpvars(0, tb_top);

        #20 rst = 1;
        #10000;
        $display("PC = %h", dut.cpu_inst.reg_pc);
        $finish;
    end
endmodule
module tarunes_cpu (
    input var logic                      clk   ,
    input var logic                      rst   ,
    tarunes___bus_if__8__16.master cpubus
);
    // CPU Registers
    logic [8-1:0]  reg_a ; // Accumulator
    logic [8-1:0]  reg_x ; // X register
    logic [8-1:0]  reg_y ; // Y register
    logic [8-1:0]  reg_sp; // Stack pointer
    logic [16-1:0] reg_pc; // Program counter
    logic [8-1:0]  reg_p ; // Status Register

    typedef enum logic [8-1:0] {
        opcode_t_SEI = $bits(logic [8-1:0])'(8'h78),
        opcode_t_TXS = $bits(logic [8-1:0])'(8'h9A),
        opcode_t_INX = $bits(logic [8-1:0])'(8'hE8),
        opcode_t_DEY = $bits(logic [8-1:0])'(8'h88),
        opcode_t_LDA_IMM = $bits(logic [8-1:0])'(8'hA9),
        opcode_t_LDA_ABX = $bits(logic [8-1:0])'(8'hBD),
        opcode_t_LDX_IMM = $bits(logic [8-1:0])'(8'hA2),
        opcode_t_LDY_IMM = $bits(logic [8-1:0])'(8'hA0),
        opcode_t_STA_ABS = $bits(logic [8-1:0])'(8'h8D),
        opcode_t_BNE = $bits(logic [8-1:0])'(8'hD0),
        opcode_t_JMP_ABS = $bits(logic [8-1:0])'(8'h4C)
    } opcode_t;
    logic [8-1:0] opcode;
    logic [8-1:0] op1   ;

    typedef enum logic [3-1:0] {
        cpu_state_t_RESET0,
        cpu_state_t_RESET1,
        cpu_state_t_RESET2,
        cpu_state_t_FETCH,
        cpu_state_t_DECODE,
        cpu_state_t_OP1,
        cpu_state_t_OP2,
        cpu_state_t_EXEC
    } cpu_state_t;
    cpu_state_t state;
    always_comb begin
        cpubus.addr  = 0;
        cpubus.wen   = 0;
        cpubus.wdata = 0;
        case ((state))
            cpu_state_t_RESET0: begin
                cpubus.addr = 16'hFFFC;
            end
            cpu_state_t_RESET1: begin
                cpubus.addr = 16'hFFFD;
            end
            cpu_state_t_FETCH: begin
                cpubus.addr = reg_pc;
            end
            cpu_state_t_DECODE: begin
                case ((cpubus.rdata))
                    opcode_t_LDX_IMM: begin
                        cpubus.addr = reg_pc + 16'd1;
                    end
                    opcode_t_LDA_IMM: begin
                        cpubus.addr = reg_pc + 16'd1;
                    end
                    opcode_t_LDY_IMM: begin
                        cpubus.addr = reg_pc + 16'd1;
                    end
                    opcode_t_STA_ABS: begin
                        cpubus.addr = reg_pc + 16'd1;
                    end
                    opcode_t_LDA_ABX: begin
                        cpubus.addr = reg_pc + 16'd1;
                    end
                    opcode_t_BNE: begin
                        cpubus.addr = reg_pc + 16'd1;
                    end
                    opcode_t_JMP_ABS: begin
                        cpubus.addr = reg_pc + 16'd1;
                    end
                    default: begin
                        cpubus.addr = 0;
                    end
                endcase
            end
            cpu_state_t_OP1: begin
                case ((opcode))
                    opcode_t_STA_ABS: begin
                        cpubus.addr = reg_pc + 16'd2;
                    end
                    opcode_t_LDA_ABX: begin
                        cpubus.addr = reg_pc + 16'd2;
                    end
                    opcode_t_JMP_ABS: begin
                        cpubus.addr = reg_pc + 16'd2;
                    end
                endcase
            end
            cpu_state_t_OP2: begin
                case ((opcode))
                    opcode_t_STA_ABS: begin
                        cpubus.addr  = {cpubus.rdata, op1};
                        cpubus.wdata = reg_a;
                        cpubus.wen   = 1'b1;
                    end
                    opcode_t_LDA_ABX: begin
                        cpubus.addr = {cpubus.rdata, op1} + {8'd0, reg_x};
                    end
                endcase
            end
            default: begin
                cpubus.addr = 0;
            end
        endcase
    end
    always_ff @ (posedge clk) begin
        if (!rst) begin
            state  <= cpu_state_t_RESET0;
            reg_pc <= 0;
            reg_p  <= 8'h24;
        end else begin
            case ((state))
                cpu_state_t_RESET0: begin
                    state <= cpu_state_t_RESET1;
                end
                cpu_state_t_RESET1: begin
                    reg_pc[7:0] <= cpubus.rdata;
                    state       <= cpu_state_t_RESET2;
                end
                cpu_state_t_RESET2: begin
                    reg_pc[15:8] <= cpubus.rdata;
                    state        <= cpu_state_t_FETCH;
                end
                cpu_state_t_FETCH: begin
                    state <= cpu_state_t_DECODE;
                end
                cpu_state_t_DECODE: begin
                    case ((cpubus.rdata))
                        opcode_t_SEI: begin
                            $display("[DECODE] PC=%04h OPCODE=SEI", reg_pc);
                            reg_p[2] <= 1'b1;
                            state    <= cpu_state_t_FETCH;
                            reg_pc   <= reg_pc + 16'd1;
                        end
                        opcode_t_TXS: begin
                            $display("[DECODE] PC=%04h OPCODE=TXS", reg_pc);
                            reg_sp <= reg_x;
                            reg_pc <= reg_pc + 16'd1;
                            state  <= cpu_state_t_FETCH;
                        end
                        opcode_t_INX: begin
                            logic [8-1:0] result;
                            result = reg_x + 8'd1;
                            $display("[DECODE] PC=%04h OPCODE=INX", reg_pc);
                            reg_x    <= result;
                            reg_p[1] <= (result == 0);
                            reg_p[7] <= result[7];
                            state    <= cpu_state_t_FETCH;
                            reg_pc   <= reg_pc + 16'd1;
                        end
                        opcode_t_DEY: begin
                            logic [8-1:0] result;
                            result = reg_y - 8'd1;
                            $display("[DECODE] PC=%04h OPCODE=DEY", reg_pc);
                            reg_y    <= result;
                            reg_p[1] <= (result == 0);
                            reg_p[7] <= result[7];
                            state    <= cpu_state_t_FETCH;
                            reg_pc   <= reg_pc + 16'd1;
                        end
                        opcode_t_LDX_IMM: begin
                            $display("[DECODE] PC=%04h OPCODE=LDX_IMM", reg_pc);
                            opcode <= cpubus.rdata;
                            state  <= cpu_state_t_OP1;
                        end
                        opcode_t_LDA_IMM: begin
                            $display("[DECODE] PC=%04h OPCODE=LDA_IMM", reg_pc);
                            opcode <= cpubus.rdata;
                            state  <= cpu_state_t_OP1;
                        end
                        opcode_t_LDY_IMM: begin
                            $display("[DECODE] PC=%04h OPCODE=LDY_IMM", reg_pc);
                            opcode <= cpubus.rdata;
                            state  <= cpu_state_t_OP1;
                        end
                        opcode_t_STA_ABS: begin
                            $display("[DECODE] PC=%04h OPCODE=STA_ABS", reg_pc);
                            opcode <= cpubus.rdata;
                            state  <= cpu_state_t_OP1;
                        end
                        opcode_t_LDA_ABX: begin
                            $display("[DECODE] PC=%04h OPCODE=LDA_ABX", reg_pc);
                            opcode <= cpubus.rdata;
                            state  <= cpu_state_t_OP1;
                        end
                        opcode_t_BNE: begin
                            $display("[DECODE] PC=%04h OPCODE=BNE", reg_pc);
                            opcode <= cpubus.rdata;
                            state  <= cpu_state_t_OP1;
                        end
                        opcode_t_JMP_ABS: begin
                            $display("[DECODE] PC=%04h OPCODE=JMP_ABS", reg_pc);
                            opcode <= cpubus.rdata;
                            state  <= cpu_state_t_OP1;
                        end
                        default: begin
                            $display("[DECODE] Unknown Opcode : PC=%04h OPCODE=%02h", reg_pc, cpubus.rdata);
                        end
                    endcase
                end
                cpu_state_t_OP1: begin
                    case ((opcode))
                        opcode_t_LDX_IMM: begin
                            reg_x    <= cpubus.rdata;
                            reg_p[1] <= (cpubus.rdata == 0);
                            reg_p[7] <= cpubus.rdata[7];
                            reg_pc   <= reg_pc + 16'd2;
                            state    <= cpu_state_t_FETCH;
                        end
                        opcode_t_LDA_IMM: begin
                            reg_a    <= cpubus.rdata;
                            reg_p[1] <= (cpubus.rdata == 0);
                            reg_p[7] <= cpubus.rdata[7];
                            reg_pc   <= reg_pc + 16'd2;
                            state    <= cpu_state_t_FETCH;
                        end
                        opcode_t_LDY_IMM: begin
                            reg_y    <= cpubus.rdata;
                            reg_p[1] <= (cpubus.rdata == 0);
                            reg_p[7] <= cpubus.rdata[7];
                            reg_pc   <= reg_pc + 16'd2;
                            state    <= cpu_state_t_FETCH;
                        end
                        opcode_t_STA_ABS: begin
                            op1   <= cpubus.rdata;
                            state <= cpu_state_t_OP2;
                        end
                        opcode_t_LDA_ABX: begin
                            op1   <= cpubus.rdata;
                            state <= cpu_state_t_OP2;
                        end
                        opcode_t_BNE: begin
                            $display("[EXECUTE] PC=%04h OPCODE=BNE", reg_pc);
                            if (reg_p[1] == 0) begin
                                reg_pc <= $signed(reg_pc) + 2 + {{8{cpubus.rdata[7]}}, cpubus.rdata};
                            end else begin
                                reg_pc <= reg_pc + 16'd2;
                            end
                            state <= cpu_state_t_FETCH;
                        end
                        opcode_t_JMP_ABS: begin
                            op1   <= cpubus.rdata;
                            state <= cpu_state_t_OP2;
                        end
                    endcase
                end
                cpu_state_t_OP2: begin
                    case ((opcode))
                        opcode_t_STA_ABS: begin
                            reg_pc <= reg_pc + 16'd3;
                            state  <= cpu_state_t_FETCH;
                        end
                        opcode_t_LDA_ABX: begin
                            state <= cpu_state_t_EXEC;
                        end
                        opcode_t_JMP_ABS: begin
                            $display("[EXECUTE] PC=%04h OPCODE=JMP_ABS", reg_pc);
                            reg_pc <= {cpubus.rdata, op1};
                            state  <= cpu_state_t_FETCH;
                        end
                    endcase
                end
                cpu_state_t_EXEC: begin
                    case ((opcode))
                        opcode_t_LDA_ABX: begin
                            reg_a    <= cpubus.rdata;
                            reg_p[1] <= (cpubus.rdata == 0);
                            reg_p[7] <= cpubus.rdata[7];
                            reg_pc   <= reg_pc + 16'd3;
                            state    <= cpu_state_t_FETCH;
                        end
                    endcase
                end
            endcase
        end
    end
endmodule
//# sourceMappingURL=cpu.sv.map

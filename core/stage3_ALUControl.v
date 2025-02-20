/* 
Explanation:
This module performs arithmetic and logical operations based on the control signals provided.

ALUOp: A 2-bit control signal generated by the ControlUnit that indicates the type of operation.

2'b00: Load/Store instructions (ADD operation).
2'b01: Branch instructions (Subtract or Set Less Than operations).
2'b10: R-type instructions (ADD, SUB, AND, OR, etc.).
2'b11: I-type instructions (ADDI, SLTI, etc.).
Funct7: A 7-bit function code from the instruction that helps to specify the exact ALU operation for R-type and I-type instructions.

Funct3: A 3-bit function code from the instruction that helps to specify the ALU operation.

ALUControl: A 4-bit control signal generated by this module to be sent to the ALU to perform the correct operation.

Operation Codes:

4'b0000: AND
4'b0001: OR
4'b0010: ADD
4'b0011: XOR
4'b0100: SLL (Shift Left Logical)
4'b0101: SRL (Shift Right Logical)
4'b0110: SUB
4'b0111: SRA (Shift Right Arithmetic)
4'b1000: SLT (Set Less Than)
4'b1001: SLTU (Set Less Than Unsigned)
This implementation ensures that the ALUControlUnit generates the appropriate ALU control signals based on the instruction being executed. 

*/

module ALUControlUnit (
    input [1:0] ALUOp,        // ALU operation code
    input [6:0] Funct7,       // Function code 7 bits
    input [2:0] Funct3,       // Function code 3 bits
    input [6:0] opcode,       // Opcode to distinguish CSR instructions
    output reg [4:0] ALUControl // ALU control signal
);

    // ALU control logic
    always @(*) begin
        case (ALUOp)
            2'b00: begin // Load/Store instructions
                ALUControl = 4'b0010; // ADD operation
            end
            2'b01: begin // Branch instructions
                case (Funct3)
                    3'b000: ALUControl = 5'b00110; // BEQ (Subtract)
                    3'b001: ALUControl = 5'b00110; // BNE (Subtract)
                    3'b100: ALUControl = 5'b00111; // BLT (Set Less Than)
                    3'b101: ALUControl = 5'b00111; // BGE (Set Less Than)
                    3'b110: ALUControl = 5'b00111; // BLTU (Set Less Than Unsigned)
                    3'b111: ALUControl = 5'b00111; // BGEU (Set Less Than Unsigned)
                    default: ALUControl = 5'b00000; // Default case
                endcase
            end
            2'b10: begin // R-type instructions
                case ({Funct7, Funct3})
                    10'b0000000_000: ALUControl = 5'b00010; // ADD
                    10'b0100000_000: ALUControl = 5'b00110; // SUB
                    10'b0000000_111: ALUControl = 5'b00000; // AND
                    10'b0000000_110: ALUControl = 5'b00001; // OR
                    10'b0000000_100: ALUControl = 5'b00011; // XOR
                    10'b0000000_001: ALUControl = 5'b00100; // SLL (Shift Left Logical)
                    10'b0000000_101: ALUControl = 5'b00101; // SRL (Shift Right Logical)
                    10'b0100000_101: ALUControl = 5'b00111; // SRA (Shift Right Arithmetic)
                    10'b0000000_010: ALUControl = 5'b01000; // SLT (Set Less Than)
                    10'b0000000_011: ALUControl = 5'b01001; // SLTU (Set Less Than Unsigned)
                    default: ALUControl = 4'b0000; // Default case
                endcase
            end
            2'b11: begin // I-type instructions
                case (Funct3)
                    3'b000: ALUControl = 5'b00010; // ADDI
                    3'b010: ALUControl = 5'b01000; // SLTI (Set Less Than Immediate)
                    3'b011: ALUControl = 5'b01001; // SLTIU (Set Less Than Immediate Unsigned)
                    3'b100: ALUControl = 5'b00011; // XORI
                    3'b110: ALUControl = 5'b00001; // ORI
                    3'b111: ALUControl = 5'b00000; // ANDI
                    3'b001: ALUControl = 5'b00100; // SLLI (Shift Left Logical Immediate)
                    3'b101: begin
                        case (Funct7)
                            7'b0000000: ALUControl = 5'b00101; // SRLI (Shift Right Logical Immediate)
                            7'b0100000: ALUControl = 5'b00111; // SRAI (Shift Right Arithmetic Immediate)
                            default: ALUControl = 5'b00000; // Default case
                        endcase
                    end

                    default: begin
                        if (opcode == 7'b0110111) begin // LUI and AUIPC
                            ALUControl = 5'b1010; // LUI
                        end else if (opcode == 7'b1110011) begin //Csr instructions
                            case (Funct3)
                                3'b001: ALUControl = 5'b10010; // CSRRW
                                3'b010: ALUControl = 5'b10001; // CSRRS
                                3'b011: ALUControl = 5'b10000; // CSRRC
                                3'b101: ALUControl = 5'b11010; // CSRRWI
                                3'b110: ALUControl = 5'b11001; // CSRRSI
                                3'b111: ALUControl = 5'b11000; // CSRRCI
                                default: ALUControl = 5'b00000; // Default case
                            endcase
                        
                        end else begin
                                ALUControl = 5'b00000; // Default case
                        end
                    end
                    
                endcase
            end
            default: ALUControl = 5'b00000; // Default case
        endcase
    end

endmodule

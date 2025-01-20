/* 
In a pipelined processor, each stage of the pipeline typically has an enable signal that controls whether the stage should perform its operation or stall. The EX_stage module having both execute_enable and ID_EX_enable_out as inputs might seem redundant, but it depends on the design context. Here's how you can decide if you need both signals or just one:

Understanding the Signals
execute_enable: 
This signal usually indicates whether the execute stage (EX) should perform its operation. It is generally controlled by the previous stage (ID stage) or the control unit.
ID_EX_enable_out: 
This signal might be propagated from the decode stage (ID stage) to indicate the status of decoding and whether the execute stage should proceed.

Decision Criteria
Redundancy: 
If execute_enable is derived directly from ID_EX_enable_out or if both signals essentially control the same behavior, you might only need one of them.

Control Logic: 
If execute_enable is part of a more complex control logic that takes into account multiple factors (e.g., hazards, stalls, etc.), you might need to keep both signals. 
    
*/

module EX_stage (
    //system signals
    input wire clk,                      // Clock input
    input wire reset_n,                  // Asynchronous reset (active low)

    //golobal stall signal
    input wire combined_stall,           // Combined stall signal

    //enable signals from previous stage
    input wire ID_EX_enable_out,         // Input from ID stage, indicating enable
    
    //from previous stage
    input wire [31:0] ID_EX_PC,          // Input from ID/EX pipeline register, Program Counter
    input wire [31:0] ID_EX_ReadData1,   // Input from ID/EX pipeline register, Read Data 1
    input wire [31:0] ID_EX_ReadData2,   // Input from ID/EX pipeline register, Read Data 2
    input wire [31:0] ID_EX_Immediate,   // Input from ID/EX pipeline register, Immediate value
    input wire [4:0] ID_EX_Rd,           // Input from ID/EX pipeline register, destination register
    input wire [6:0] ID_EX_Funct7,       // Input from ID/EX pipeline register, funct7 field
    input wire [2:0] ID_EX_Funct3,       // Input from ID/EX pipeline register, funct3 field

    //from control unit
    input wire ID_EX_ALUSrc,          // Output from ControlUnit, ALU source control signal
    input wire [1:0] ID_EX_ALUOp,        // Input from ControlUnit, ALU operation control signal
    input wire ID_EX_Branch,        // Output from ControlUnit, Register write control signal
    input wire ID_EX_MemRead,         // Output from ControlUnit, Memory read control signal
    input wire ID_EX_MemWrite,        // Output from ControlUnit, Memory write control signal
    input wire ID_EX_MemtoReg,        // Output from ControlUnit, Memory to register control signal
    input wire ID_EX_RegWrite,        // Output from ControlUnit, Register write control signal

    //output
    output reg [31:0] EX_MEM_PC,         // Output to EX/MEM pipeline register, Program Counter
    output reg [31:0] EX_MEM_ALUResult,  // Output to EX/MEM pipeline register, ALU result
    output reg [31:0] EX_MEM_WriteData,  // Output to EX/MEM pipeline register, Write Data
    output reg [4:0] EX_MEM_Rd,          // Output to EX/MEM pipeline register, destination register
    output reg EX_MEM_MemRead,    // out: Memory read enable to MEM stage
    output reg EX_MEM_MemWrite,   // out: Memory write enable to MEM stage
    output reg EX_MEM_MemToReg,   // out: Memory to register signal to MEM stage
    output reg EX_MEM_RegWrite,          // Output to EX/MEM pipeline register, Register write control signal

    //enable signal to next stage
    output reg EX_MEM_enable_out  // out: Enable signal to MEM stage
);

    wire [31:0] ALUResult;               // Wire for ALU result
    wire Zero;                           // Wire for Zero flag from ALU
    wire [3:0] ALUControl;               // Internal wire for ALU control signal

    // Instantiate ALUControl
    ALUControlUnit alu_cu (
        .ALUOp(ID_EX_ALUOp),             // Input signal
        .Funct7(ID_EX_Funct7),           // Input signal
        .Funct3(ID_EX_Funct3),           // Input signal
        .ALUControl(ALUControl)          // Output signal
    );

    // Select ALU second input based on ALUSrc signal
    assign ALUInput2 = ID_EX_ALUSrc ? ID_EX_Immediate : ID_EX_ReadData2;

    // Instantiate ALU
    ALU alu (
        .A(ID_EX_ReadData1),             // Input signal
        .B(ALUInput2),                   // Input signal
        .ALUControl(ALUControl),         // Input signal
        .Result(ALUResult),              // Output signal
        .Zero(Zero)                      // Output signal
    );

    always @(posedge clk or negedge reset_n) begin
        if (~reset_n) begin
            // Reset logic
            EX_MEM_PC <= 32'b0;
            EX_MEM_ALUResult <= 32'b0;
            EX_MEM_WriteData <= 32'b0;
            EX_MEM_Rd <= 5'b0;
            EX_MEM_RegWrite <= 1'b0;
            EX_MEM_MemRead <= 1'b0;
            EX_MEM_MemWrite <= 1'b0;
            EX_MEM_MemToReg <= 1'b0;
            EX_MEM_Branch <= 1'b0;
            EX_MEM_enable_out <= 1'b0;
        end else if (combined_stall) begin
            // Insert bubble (NOP) into the pipeline
            EX_MEM_PC <= 32'b0;
            EX_MEM_ALUResult <= 32'b0;
            EX_MEM_WriteData <= 32'b0;
            EX_MEM_Rd <= 5'b0;
            EX_MEM_RegWrite <= 1'b0;
            EX_MEM_MemRead <= 1'b0;
            EX_MEM_MemWrite <= 1'b0;
            EX_MEM_MemToReg <= 1'b0;
            EX_MEM_enable_out <= 1'b0;
        end else if (ID_EX_enable_out) begin
            // ID_EX_enable_out = 1, pipeline active
            if (ID_EX_Branch && Zero) begin
                // Branch taken
                EX_MEM_PC <= ID_EX_PC + (ID_EX_Immediate << 1);
            end else begin
                // Normal operation
                EX_MEM_PC <= ID_EX_PC;
            end
            EX_MEM_ALUResult <= ALUResult;
            EX_MEM_WriteData <= ID_EX_ReadData2;
            EX_MEM_Rd <= ID_EX_Rd;
            EX_MEM_RegWrite <= ID_EX_RegWrite;
            EX_MEM_MemRead <= ID_EX_MemRead;
            EX_MEM_MemWrite <= ID_EX_MemWrite;
            EX_MEM_MemToReg <= ID_EX_MemToReg;
            EX_MEM_enable_out <= 1'b1; // Enable next stage
        end else begin
            EX_MEM_enable_out <= 1'b0; // Disable next stage
        end
    end

endmodule
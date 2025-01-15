module APB_Slave_UART #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,   
    parameter BASE_ADDR = 32'h1000_0000    
    parameter FIFO_DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 16,
) (
    // APB 接口
    input wire PCLK,
    input wire PRESETn,
    input wire [31:0] PADDR,
    input wire PSEL,
    input wire PENABLE,
    input wire PWRITE,
    input wire [31:0] PWDATA,
    output wire [31:0] PRDATA,
    // UART 接口
    input wire RX,
    output wire TX
);

    // 内部寄存器定义
    reg [31:0] control_reg;
    reg [31:0] clk_div_reg; // 新增 clk_div 寄存器
    reg [31:0] tx_fifo_ctrl_reg;
    reg [31:0] rx_fifo_ctrl_reg;        
    reg [31:0] tx_status_reg;
    reg [31:0] rx_status_reg;
    reg [31:0] tx_data_reg;
    reg [31:0] rx_data_reg;

    reg [7:0] tx_shift; // 新增 tx_shift 寄存器
    reg [7:0] rx_shift; // 新增 rx_shift 寄存器

    // Register offset definitions
    localparam CONTROL_REG_OFFSET      = 32'h00;
    localparam CLK_DIV_REG_OFFSET      = 32'h04;   
    localparam TX_FIFO_CTLR_REG_OFFSET = 32'h20;
    localparam RX_FIFO_CTLR_REG_OFFSET = 32'h24;
    localparam TX_STATUS_REG_OFFSET    = 32'h40;
    localparam RX_STATUS_REG_OFFSET    = 32'h44;
    localparam TX_DATA_REG_OFFSET      = 32'h80;
    localparam RX_DATA_REG_OFFSET      = 32'h84;

    // ctrl register bit positions
    localparam TX_EN_BIT   = 0;
    localparam RX_EN_BIT   = 1;

    // tx fifo ctrl register bit positions
    localparam CLK_DIV_FRAC_BIT   = 0;     
    localparam CLK_DIV_FRAC_WIDTH   = 4;        
    localparam CLK_DIV_INT_BIT   = 16;
    localparam CLK_DIV_INT_WIDTH   = 16;
 
    // clk div register bit positions
    localparam TX_FIFO_WATERMARK_BIT   = 0;

    // rx fifo ctrl register bit positionsR
    localparam RX_FIFO_WATERMARK_TH_BIT   = 0;
    localparam RX_FIFO_FLOWCTRL_TH_BIT   = 8;   

    // tx Status register bit positions
    localparam TX_FIFO_FILL_BIT        = 0;
    localparam TX_FIFO_EMPTY_BIT       = 8;
    localparam TX_FIFO_FULL_BIT        = 9;
    localparam TX_FIFO_WATERMARK_BIT   = 10;    
    localparam TX_SHIFT_IDLE_BIT       = 16;

     // tx Status register bit positions   
    localparam RX_FIFO_FILL_BIT        = 0;    
    localparam RX_FIFO_EMPTY_BIT       = 8;
    localparam RX_FIFO_FULL_BIT        = 9;
    localparam RX_FIFO_WATERMARK_BIT   = 10;        
    localparam RX_SHIFT_FULL_BIT       = 16;
    localparam RX_SHIFT_ERR_BREAK_BIT  = 20;

    // Register default value definitions
    localparam CONTROL_REG_DEFAULT_VALUE      = 0 << TX_EN_BIT + 0 << RX_EN_BIT;
    localparam CLK_DIV_REG_DEFAULT_VALUE      = 5 << CLK_DIV_FRAC_BIT + 208 << CLK_DIV_INT_BIT;
    localparam TX_FIFO_CTLR_REG_DEFAULT_VALUE = 8 <<TX_FIFO_WATERMARK_BIT;
    localparam RX_FIFO_CTLR_DEFAULT_VALUE = 8 << RX_FIFO_WATERMARK_TH_BIT + (FIFO_DEPTH - 2) << RX_FIFO_FLOWCTRL_TH_BIT;   

    // translate from fifo depth to FIFO addr width    
    localparam FIFO_ADDR_WIDTH = $clog2(FIFO_DEPTH)

    // 发送 FIFO 实例化
    AsyncFIFO #(
      .FIFO_DATA_WIDTH(FIFO_DATA_WIDTH),
      .FIFO_ADDR_WIDTH(FIFO_ADDR_WIDTH)
    ) tx_fifo (
     .wr_clk(PCLK),
     .rd_clk(PCLK),
     .wr_en(tx_wr_en),
     .rd_en(tx_rd_en),
     .wr_data(tx_wr_data),
     .rd_data(tx_rd_data),
     .full(tx_full),
     .empty(tx_empty),
     .fifo_fill_cnt(tx_fifo_fill_cnt)
    );

    // 接收 FIFO 实例化
    AsyncFIFO #(
      .FIFO_DATA_WIDTH(FIFO_DATA_WIDTH),
      .FIFO_ADDR_WIDTH(FIFO_ADDR_WIDTH)
    ) rx_fifo (
     .wr_clk(PCLK),
     .rd_clk(PCLK),
     .wr_en(rx_wr_en),
     .rd_en(rx_rd_en),
     .wr_data(rx_wr_data),
     .rd_data(rx_rd_data),
     .full(rx_full),
     .empty(rx_empty),
     .fifo_fill_cnt(rx_fifo_fill_cnt)
    );

    // 内部信号定义
    wire tx_wr_en;
    wire tx_rd_en;
    wire [FIFO_DATA_WIDTH-1:0] tx_wr_data;
    wire [FIFO_DATA_WIDTH-1:0] tx_rd_data;
    wire tx_full;
    wire tx_empty;
    wire [FIFO_ADDR_WIDTH:0] tx_fifo_fill_cnt;
    wire [FIFO_ADDR_WIDTH:0] tx_flow_ctrl_th;
    wire tx_flow_ctrl_rts_n;
    wire [FIFO_ADDR_WIDTH:0] tx_water_mark_th;
    wire tx_water_mark;

    wire rx_wr_en;
    wire rx_rd_en;
    wire [FIFO_DATA_WIDTH-1:0] rx_wr_data;
    wire [FIFO_DATA_WIDTH-1:0] rx_rd_data;
    wire rx_full;
    wire rx_empty;
    wire [FIFO_ADDR_WIDTH:0] rx_fifo_fill_cnt;
    wire [FIFO_ADDR_WIDTH:0] rx_flow_ctrl_th;
    wire rx_flow_ctrl_rts_n;
    wire [FIFO_ADDR_WIDTH:0] rx_water_mark_th;
    wire rx_water_mark;

    wire [15:0] int_div;
    wire [3:0] frac_div;
    wire [31:0] div_value;

    wire uart_bit_clk_x16;
    wire uart_bit_clk;

    // get int_div 和 frac_div
    assign frac_div = clk_div_reg[CLK_DIV_FRAC_BIT+CLK_DIV_FRAC_WIDTH-1:CLK_DIV_FRAC_BIT];
    assign int_div = clk_div_reg[CLK_DIV_INT_BIT+CLK_DIV_INT_WIDTH-1:CLK_DIV_INT_BIT];
    assign div_value = (int_div * 16) + frac_div;

    // 生成 uart_bit_clk_x16 和 uart_bit_clk 时钟信号
    assign uart_bit_clk_x16 = (div_value == 0)? 1'b0 : (PCLK % div_value == 0);
    assign uart_bit_clk = (div_value == 0)? 1'b0 : (PCLK % (div_value * 16) == 0);

    // get fifo watermark/flowctrl th
    assign tx_water_mark_th = tx_fifo_ctrl_reg[TX_FIFO_WATERMARK_BIT+FIFO_ADDR_WIDTH-1:TX_FIFO_WATERMARK_BIT];
    assign rx_water_mark_th = rx_fifo_ctrl_reg[RX_FIFO_WATERMARK_BIT+FIFO_ADDR_WIDTH-1:RX_FIFO_WATERMARK_BIT]; 
    assign rx_flow_ctrl_th = rx_fifo_ctrl_reg[RX_FIFO_FLOWCTRL_TH_BIT+FIFO_ADDR_WIDTH-1:RX_FIFO_FLOWCTRL_TH_BIT];

    // Flow control logic
    assign tx_flow_ctrl_rts_n = (tx_fifo_fill_cnt < tx_flow_ctrl_th);
    assign rx_flow_ctrl_rts_n = (rx_fifo_fill_cnt < rx_flow_ctrl_th);

    // Watermark status logic
    assign tx_water_mark = (tx_fifo_fill_cnt >= tx_water_mark_th);
    assign rx_water_mark = (rx_fifo_fill_cnt >= rx_water_mark_th);

    // 新增信号用于指示 tx_shift 和 rx_shift 的状态
    wire tx_shift_idle; // tx_shift 处于空闲状态
    wire rx_shift_full; // rx_shift 已接收完整一帧数据

    // APB 写操作
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            control_reg <= CONTROL_REG_DEFAULT_VALUE;
            clk_div_reg <= CLK_DIV_REG_DEFAULT_VALUE; // 复位 clk_div 寄存器
            tx_fifo_ctrl_reg <= TX_FIFO_CTLR_REG_DEFAULT_VALUE;   
            tx_fifo_ctrl_reg <= RX_FIFO_CTLR_DEFAULT_VALUE;      
            tx_data_reg <= 32'b0;        
            tx_shift <= 8'b0; // 复位 tx_shift 寄存器
            rx_shift <= 8'b0; // 复位 rx_shift 寄存器
        end else if (PSEL && PENABLE && PWRITE) begin
            case (PADDR)
                BASE_ADDR + CONTROL_REG_OFFSET: control_reg <= PWDATA; // 控制寄存器
                BASE_ADDR + CLK_DIV_REG_OFFSET: clk_div_reg <= PWDATA; // 发送数据寄存器
                BASE_ADDR + TX_FIFO_CTLR_REG_OFFSET: tx_fifo_ctrl_reg <= PWDATA; // tx-fifo ctrl 寄存器
                BASE_ADDR + RX_FIFO_CTLR_REG_OFFSET: rx_fifo_ctrl_reg <= PWDATA; // rx-fifo ctrl 寄存器    
                BASE_ADDR + TX_DATA_REG_OFFSET: tx_data_reg <= PWDATA; // tx-data 寄存器                             
                // 可以添加更多寄存器的写操作

                default: ;
            endcase
                    end
                end

    // APB 读操作
    always @(*) begin
        if (PSEL && PENABLE && !PWRITE) begin
            case (PADDR)
                BASE_ADDR + CONTROL_REG_OFFSET: PRDATA = control_reg; // 控制寄存器
                BASE_ADDR + CLK_DIV_REG_OFFSET: PRDATA = clk_div_reg;
                BASE_ADDR + TX_FIFO_CTLR_REG_OFFSET: PRDATA = tx_fifo_ctrl_reg;
                BASE_ADDR + RX_FIFO_CTLR_REG_OFFSET: PRDATA = rx_fifo_ctrl_reg; 
                BASE_ADDR + RX_DATA_REG_OFFSET: PRDATA = rx_data_reg; // 接收数据寄存器
                BASE_ADDR + TX_STATUS_REG_OFFSET: PRDATA = tx_status_reg; // 发送状态寄存器
                BASE_ADDR + RX_STATUS_REG_OFFSET: PRDATA = rx_status_reg; // 接收状态寄存器
                default: PRDATA = 32'b0;
            endcase
        end else begin
            PRDATA = 32'b0;
        end
    end

    // UART fifo ctrl
    assign tx_wr_en = PSEL && PENABLE && PWRITE && (PADDR & ~(32'hF)) == BASE_ADDR && PADDR[3:0] == 4'h4;
    assign tx_rd_en = (tx_shift_idle &&!tx_empty); // 当 tx_shift 空闲且 tx_fifo 不空时，从 tx_fifo 读取数据
    always @(posedge PCLK) begin
        if (tx_wr_en) begin
            tx_wr_data <= PWDATA[FIFO_DATA_WIDTH-1:0];
        end
        if (tx_rd_en) begin
            // 当 tx_shift 空闲且 tx_fifo 不空时，将数据从 tx_fifo 移入 tx_shift
            tx_shift <= tx_rd_data;
            tx_shift_idle = 0;          //get a char to shift , idle = 0
        end
    end

    assign rx_wr_en = rx_shift_full;
    assign rx_rd_en = PSEL && PENABLE && PWRITE && (PADDR & ~(32'hF)) == BASE_ADDR && PADDR[3:0] == 4'h8;   //apb 访问 rx-data register
    always @(posedge PCLK) begin
        if (rx_wr_en) begin
            // 当 rx_shift 接收完一帧数据且 rx_fifo 不满时，将数据从 rx_shift 写入 rx_fifo
            rx_wr_data <= rx_shift;
        end
        if (rx_rd_en) begin
            PRDATA[FIFO_DATA_WIDTH-1:0] <= rx_rd_data;
        end
    end


    // 使用 uart_bit_clk 将 tx_shift 里的数据按位发送，并添加起始位/结束位
    always @(posedge uart_bit_clk or negedge PRESETn) begin
        if (!PRESETn) begin
            tx_bit_index <= 4'b0;
        end else if (tx_shift_idle) begin
            tx_bit_index <= 4'b0;
        end else begin
            case (tx_bit_index)
                4'b0000: TX <= 1'b0; // 发送起始位
                4'b1000: TX <= 1'b1; // 发送停止位
                default: begin
                    TX <= tx_shift[0]; // 发送数据位
                    tx_shift <= {1'b0, tx_shift[7:1]}; // 右移数据
                end
            endcase

            if (tx_bit_index < 4'b1000) begin
                tx_bit_index <= tx_bit_index + 1;
            end else begin
                tx_bit_index <= 4'b0000;
                tx_shift_idle = 1;              //shift a char, idle = 1
            end
        end
    end

    // UART 检测 rx start, 接收数据，并检查stop 
    always @(posedge uart_bit_clk_x16 or negedge PRESETn) begin
        if (!PRESETn) begin
            rx_sample_count <= 4'b0;
            rx_sample_state <= 3'b0;
            rx_bit_index <= 4'b0;
            rx_shift_err_break <= 1'b0;
        end else begin
            case (rx_sample_state)
                3'b000: begin // 寻找起始位
                    if (RX == 1'b0) begin
                        rx_sample_count <= rx_sample_count + 1;
                        if (rx_sample_count == 4'b1000) begin
                            rx_sample_state <= 3'b001; // 找到起始位，开始接收数据
                            rx_sample_count <= 4'b0;
                        end
                    end else begin
                        rx_sample_count <= 4'b0;
                    end
                end
                3'b001: begin // 接收数据位和检查停止位
                    rx_sample_state <= 3'b010; // 直接进入检查停止位状态，使用 uart_bit_clk 进行采样
                end
                3'b010: begin // 检查停止位
                    // 等待 uart_bit_clk 上升沿
                end
                default: rx_sample_state <= 3'b000; // 其他状态，回到寻找起始位状态
            endcase
        end
    end

    always @(posedge uart_bit_clk or negedge PRESETn) begin
        if (!PRESETn) begin
            rx_bit_index <= 4'b0;
        end else if (rx_sample_state == 3'b010) begin
            if (rx_bit_index < 4'b1000) begin
                // 接收数据位
                rx_shift[rx_bit_index] <= RX;
                rx_bit_index <= rx_bit_index + 1;
            end else if (rx_bit_index == 4'b1000) begin
                // 开始检查停止位
                if (RX == 1'b1) begin
                    // 假设停止位为 1 位
                    rx_shift_full <= 1'b1; // 接收完一帧数据且停止位正确
                    rx_sample_state <= 3'b000; // 回到寻找起始位状态
                    rx_bit_index <= 4'b0;
                end else begin
                    rx_shift_err_break <= 1'b1; // 停止位错误
                    rx_sample_state <= 3'b000; // 回到寻找起始位状态
                    rx_bit_index <= 4'b0;
                end
            end
        end
    end


    // UART 状态更新
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            tx_status_reg <= 32'b0;
            rx_status_reg <= 32'b0;
            end else begin
            tx_status_reg[TX_FIFO_FILL_BIT+FIFO_ADDR_WIDTH-1: TX_FIFO_FILL_BIT] <= tx_fifo_fill_cnt;
            tx_status_reg[TX_FIFO_EMPTY_BIT] <=tx_empty;
            tx_status_reg[TX_FIFO_FULL_BIT] <= tx_full;  
            tx_status_reg[TX_FIFO_WATERMARK_BIT] <= tx_water_mark; 
            tx_status_reg[TX_SHIFT_IDLE_BIT] <= tx_shift_idle; 

            tx_status_reg[RX_FIFO_FILL_BIT+FIFO_ADDR_WIDTH-1: RX_FIFO_FILL_BIT] <= rx_fifo_fill_cnt;
            tx_status_reg[RX_FIFO_EMPTY_BIT] <= rx_empty; 
            tx_status_reg[RX_FIFO_FULL_BIT] <= rx_full; 
            tx_status_reg[RX_FIFO_WATERMARK_BIT] <= rx_water_mark; 
            tx_status_reg[RX_SHIFT_FULL_BIT] <= rx_shift_full;
            tx_status_reg[RX_SHIFT_ERR_BREAK_BIT] <= rx_shift_err_break;           

            // 可以添加更多状态信息更新
        end
    end

endmodule
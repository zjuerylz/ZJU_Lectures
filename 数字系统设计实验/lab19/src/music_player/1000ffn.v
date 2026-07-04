`timescale 1ns / 1ps

// ============================================================================
// 模块名称: divider
// 功能描述: 节拍基准发生器 (输出单周期高电平脉冲)
// 参数说明: 
//     n            - 分频比 (例如: 1000)
//     counter_bits - 内部计数器的位宽 (例如: n=1000 时，位宽需 >= 10)
// ============================================================================
module divider #(
    parameter n = 1000,
    parameter counter_bits = 10
)(
    input  wire clk,      // 系统时钟输入
    input  wire reset,    // 异步复位信号，高电平有效
    output reg  clk_out   // 节拍脉冲输出 (一个 clk 周期的正脉冲)
);

    // 定义内部状态计数器
    reg [counter_bits-1:0] count;

    // 分频与脉冲生成逻辑
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count   <= 0;
            clk_out <= 1'b0;
        end 
        else begin
            // 当计数器达到 n-1 时，输出一个单周期高电平脉冲，并清零计数器
            // 此时正好度过了 n 个时钟周期
            if (count >= (n - 1)) begin
                count   <= 0;
                clk_out <= 1'b1;
            end 
            else begin
                count   <= count + 1'b1;
                clk_out <= 1'b0;
            end
        end
    end

endmodule
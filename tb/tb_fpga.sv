`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/29/2026 11:19:56 PM
// Design Name: 
// Module Name: onlyFPGA
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_cadence();
     
    


logic clock;
logic rst_n_async;

parameter WIDTHxSS = 4, SIZES = 16;
parameter BYTESIZESS = 2*WIDTHxSS *SIZES;

parameter LENGTH = 840;
reg [31:0] cnt5;
logic  [23:0]dout_mem[LENGTH-1:0];


initial begin
  clock = 1;
  $readmemh("/run/media/xmen/3dae8433-5866-41d4-a50e-ed4d30bb9f05/home/valmyrsilva07/Área de Trabalho/SystolicCore/tb/mem8x8_without_pads.hex",dout_mem);

  rst_n_async =1;
  #1rst_n_async= 0;
  #1rst_n_async= 1;
end
logic s_axi_t_ready;
always #1 clock = ~clock;
always@(posedge clock, negedge rst_n_async)begin
    if(!rst_n_async) cnt5 <= 0;
    else begin 
        
        if(s_axi_t_ready)begin
            cnt5<= (cnt5 < 296) ? cnt5+1 : 0;
        end
    end
end 




AXI_Stream_Systolic_Core #(.BYTESIZES(BYTESIZESS), .WIDTHx(WIDTHxSS),.SIZE(SIZES),.WIDTH(2*WIDTHxSS)) uut_systolic_tb (
        // Sinais de sistema
        .clock(clock),
        .resetn(rst_n_async),

        // Interface Slave AXI Stream (Entrada)
        .s_axis_tvalid('b1),
        .s_axis_tready(s_axi_t_ready),
        .s_axis_tdata(dout_mem[cnt5]),
        .s_axis_tlast(),
        // ... outros sinais opcionais como TUSER

        // Interface Master AXI Stream (Saída) 
        .m_axis_tvalid(),
        .m_axis_tready('b1),
        .m_axis_tdata(),
        .m_axis_tlast()
        // ... outros sinais opcionais
);

    
    
    
endmodule

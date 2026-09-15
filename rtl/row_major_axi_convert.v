`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/02/2026 07:37:56 PM
// Design Name: 
// Module Name: row_major_axi_convert
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


module row_major_axi_convert#(parameter  BYTESIZES = 64,WIDTH=8)(
        // Sinais de sistema
        input wire          clock,
        input wire          resetn,

        // Interface Slave AXI Stream (Entrada)
        input wire          s_axis_tvalid,
        output wire         s_axis_tready,
        input wire [BYTESIZES-1:0]   s_axis_tdata,
        input wire          s_axis_tlast,
        // ... outros sinais opcionais como TUSER

        // Interface Master AXI Stream (Saída) 
        output wire          m_axis_tvalid,
        input wire          m_axis_tready,
        output wire [BYTESIZES-1:0]   m_axis_tdata,
        output wire          m_axis_tlast
        // ... outros sinais opcionais
        

        
);
        assign m_axis_tvalid = s_axis_tvalid;
        assign s_axis_tready = m_axis_tready;
        assign m_axis_tlast = s_axis_tlast;
        assign {<<(WIDTH){m_axis_tdata}} = s_axis_tdata;// descomente ao testar com o DMA
        
        

endmodule
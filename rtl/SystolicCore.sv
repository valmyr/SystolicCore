`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Valmir F. Silva
// 
// Create Date: 10/20/2025 09:23:21 AM
// Design Name: 
// Module Name: SystoliCore
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


module SystolicCoreTop#(
    parameter  BYTESIZES = 8, WIDTHx = 4,SIZE = 16,WIDTH =8
)(
    input  logic                    clock                     ,
    input  logic                    rst_n_async               ,
    input  logic [BYTESIZES-1:0]    uart_data_rx_out          ,
    output logic [BYTESIZES-1:0]    uart_data_tx_in           ,
    output logic                    uart_ready_rx_out         ,
    input  logic                    uart_ready_tx_out         ,
    output logic                    uart_valid_tx_in          ,
    input logic                     uart_valid_rx_in          ,
    input logic                     s_axis_tlast              ,
    output logic                    m_axis_tlast
);

localparam SIZE_WINDOW = 6;
localparam SIZE_KER = 3;
localparam OUT_SIZE = SIZE_WINDOW - SIZE_KER + 1;
localparam OUT_SIZE_NORM = SIZE;

//Pinout Unidade de Controle.
//-------------------------------------------------------------------------------------------------
logic                   systolicControlUnit_clock                                                               ;
logic                   systolicControlUnit_rst_n_async                                                         ;
(*dont_touch = "true"*)
logic                   systolicControlUnit_uart_valid_rx_in                                                    ;
logic                   systolicControlUnit_serial2mem_opa_rvalid_o                                             ;
logic                   systolicControlUnit_serial2mem_opb_rvalid_o                                             ;
logic                   systolicControlUnit_syst_rvalid_o                                                       ;
logic                   systolicControlUnit_mem2serial_rvalid_o                                                 ;
logic                   systolicControlUnit_serial2mem_opa_valid_i                                              ;
logic                   systolicControlUnit_serial2mem_opb_valid_i                                              ;
logic                   systolicControlUnit_serial2mem_opa_rw                                                   ;
logic                   systolicControlUnit_serial2mem_opb_rw                                                   ;
logic                   systolicControlUnit_serial2mem_opa_rready_i                                             ;
logic                   systolicControlUnit_serial2mem_opb_rready_i                                             ;
logic                   systolicControlUnit_mem2serial_valid_i                                                  ;
logic                   systolicControlUnit_mem2serial_rready_i                                                 ;
logic                   systolicControlUnit_uart_valid_tx_in                                                    ;
logic                   systolicControlUnit_syst_valid_i                                                        ;
logic                   systolicControlUnit_syst_rready_i                                                       ;
logic                   systolicControlUnit_starting_frame_identified                                           ;
logic                   systolicControlUnit_uart_ready_rx                                                       ;
logic                   systolicControlUnit_serial2mem_opa_ready_o                                              ;
logic                   systolicControlUnit_serial2mem_opb_ready_o                                              ;
logic                   systolicControlUnit_read_done                                                           ;
logic             [31:0]systolicControlUnit_frame_start                                                         ;
logic                   systolicControlUnit_s_axis_tlast                                                        ;
//-------------------------------------------------------------------------------------------------
//-------------------------------------------------------------------------------------------------
//Pinout Systolic
//--------------------------------------------------------------------------------------------------
logic                     syst_clock                                                                            ;
logic                     syst_rst_n_async                                                                      ;
logic                     syst_valid_i                                                                          ;
logic                     syst_rready_i                                                                         ;
logic [WIDTHx-1:0]   syst_a_input [SIZE-1:0]                                                                    ;
logic [WIDTHx-1:0]   syst_b_input [SIZE-1:0]                                                                    ;
logic                     syst_ready_o                                                                          ;
logic                     syst_rvalid_o                                                                         ;
(*dont_touch = "true"*) 
logic [WIDTH-1:0]         syst_output_produc_a_b [SIZE-1:0][SIZE-1:0]                                           ;
logic                     syst_read_done                                                                        ;
//--------------------------------------------------------------------------------------------------
//Pinout MEMA
logic                   serial2mem_opa_clock                                                                    ;
logic                   serial2mem_opa_rst_n_async                                                              ;
logic                   serial2mem_opa_rw                                                                       ;
logic                   serial2mem_opa_valid_i                                                                  ;
logic                   serial2mem_opa_rready_i                                                                 ;
logic                   serial2mem_opa_rvalid_o                                                                 ;
logic                   serial2mem_opa_ready_o                                                                  ;
logic [WIDTHx*SIZE-1:0] serial2mem_opa_in_data                                                                  ;
logic [WIDTHx-1:0]      serial2mem_opa_out_data [SIZE_WINDOW-1:0][SIZE_WINDOW-1:0]                              ;
logic [WIDTHx-1:0]      serial2mem_opa_buf_data [SIZE_WINDOW-1:0][SIZE_WINDOW-1:0]                              ;
logic                   syst_ena_mac                                                                            ;
//---------------------------------------------------------------------------------------------------
//-----Pinout Bank Register Flow Data Time Structure---------------------------------------------
logic [WIDTHx-1:0] flow_data_time_structure_OPA [SIZE-1:0];
logic [WIDTHx-1:0] flow_data_time_structure_OPB [SIZE-1:0];
logic [WIDTHx-1:0] flow_data_time_structure_OUTA[SIZE-1:0];
logic [WIDTHx-1:0] flow_data_time_structure_OUTB[SIZE-1:0];

logic shiftdata_clock;
logic shiftdata_rst_n_async;
logic img2row_clock;
logic img2row_rst_n_sync;
logic flow_data_time_structure_rst_n_async;


//--------------------------------------------------------------------------------------------------
logic                   serial2mem_opb_clock                                                                    ;
logic                   serial2mem_opb_rst_n_async                                                              ;
logic                   serial2mem_opb_rw                                                                       ;
logic                   serial2mem_opb_valid_i                                                                  ;
logic                   serial2mem_opb_rready_i                                                                 ;
logic                   serial2mem_opb_ready_o                                                                  ;
logic                   serial2mem_opb_rvalid_o                                                                 ;
logic [WIDTHx*SIZE-1:0] serial2mem_opb_in_data                                                                  ;
logic [WIDTHx-1:0]      serial2mem_opb_out_data [SIZE_WINDOW-1:0][SIZE_WINDOW-1:0]                                            ;
logic [WIDTHx-1:0]      serial2mem_opb_buf_data [SIZE_WINDOW-1:0][SIZE_WINDOW-1:0]                                            ;

//---------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------
//Pinout MEM2SERIAL
logic                   mem2serial_clock                                                                        ;
logic                   mem2serial_rst_n_async                                                                  ;
(*dont_touch = "true"*) 
logic [WIDTH-1:0]       mem2serial_pmatrix_in [SIZE-1:0][SIZE-1:0]                                              ;
logic                   mem2serial_valid_i                                                                      ;
logic                   mem2serial_rready_i                                                                     ;
logic                   mem2serial_rvalid_o                                                                     ;
logic                   mem2serial_ready_o                                                                      ;
logic  [BYTESIZES-1:0]  mem2serial_smatrix_out                                                                  ;
logic                   mem2serial_m_axis_tlast                                                                 ;
//---------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------
//Pinout SampleHatePC
logic ref_clock_in_clock                                                                                        ;
logic ref_clock_rst_n_async                                                                                     ;
logic ref_clock_out_clock_ref     ;
logic debug_handsheak;                                                                              
//---------------------------------------------------------------------------------------------------


//---------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------
//Pinout img2row


logic u_im2row_clock;
logic u_im2row_rst_n_sync;
logic u_im2row_data_valid_i;
logic u_im2row_module_ready_o;
logic u_im2row_result_rvalid_o;
logic u_im2row_downstream_ready_i;
logic [WIDTHx-1:0] u_im2row_input_a_image[SIZE_WINDOW-1:0][SIZE_WINDOW-1:0];
logic [WIDTHx-1:0] u_im2row_input_b_image[SIZE_WINDOW-1:0][SIZE_WINDOW-1:0];
logic [WIDTHx-1:0] u_im2row_col_a_matrix[OUT_SIZE_NORM-1:0][OUT_SIZE_NORM-1:0];
logic [WIDTHx-1:0] u_im2row_col_b_matrix_transpose[OUT_SIZE_NORM-1:0][OUT_SIZE_NORM-1:0];
logic [WIDTHx-1:0] u_im2row_col_b_matrix[OUT_SIZE_NORM-1:0][OUT_SIZE_NORM-1:0];
//---------------------------------------------------------------------------------------------------
//Registradores para o tratamento de harzards entre estágios do pipeline da unidade de controle
//---------------------------------------------------------------------------------------------------
logic [WIDTHx-1:0]      pipeline_serial2mem_opa_out_data[SIZE_WINDOW-1:0][SIZE_WINDOW-1:0];
logic [WIDTHx-1:0]      pipeline_serial2mem_opb_out_data[SIZE_WINDOW-1:0][SIZE_WINDOW-1:0];
logic [WIDTHx-1:0]      pipeline_u_im2row_col_a_matrix  [OUT_SIZE_NORM-1:0][OUT_SIZE_NORM-1:0];           
logic [WIDTHx-1:0]      pipeline_u_im2row_col_b_matrix  [OUT_SIZE_NORM-1:0][OUT_SIZE_NORM-1:0];         
logic [WIDTH-1:0]       pipeline_syst_output_produc_a_b  [SIZE-1:0][SIZE-1:0];

logic sampling_pipeline_stage_1_mem_write;
logic sampling_pipeline_stage_2_img2row  ;
logic sampling_pipeline_stage_3_systolic ;
logic sampling_pipeline_stage_4_send2host;


//---------------------------------------------------------------------------------------------------
//Shiftdata
//---------------------------------------------------------------------------------------------------

logic [WIDTHx-1:0] shift_opa_out_data[OUT_SIZE_NORM-1:0][OUT_SIZE_NORM-1:0];
logic [WIDTHx-1:0] shift_opb_out_data[OUT_SIZE_NORM-1:0][OUT_SIZE_NORM-1:0];

//---------------------------------------------------------------------------------------------------------------------------------
//AXI

assign m_axis_tlast = mem2serial_m_axis_tlast;
//---------------------------------------------------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------------------
//Atribuição de clocks
assign syst_clock                = clock                                                                        ;
assign uart_clock                = clock                                                                        ;
assign mem2serial_clock          = clock                                                                        ;//A definir 5kHz
assign serial2mem_opa_clock      = clock                                                                        ;
assign serial2mem_opb_clock      = clock                                                                        ;
assign systolicControlUnit_clock = clock                                                                        ;
assign ref_clock_in_clock        = clock                                                                        ;
assign shiftdata_clock = clock;
assign u_im2row_clock =clock;
assign u_im2row_rst_n_sync=rst_n_async;
//Atribuição de rst_n_async

assign syst_rst_n_async                = rst_n_async                                                                      ;
assign uart_rst_n_async                = rst_n_async                                                                      ;
assign serial2mem_opa_rst_n_async      = rst_n_async                                                                      ;
assign serial2mem_opb_rst_n_async      = rst_n_async                                                                      ;
assign mem2serial_rst_n_async          = rst_n_async                                                                      ;
assign ref_clock_rst_n_async           = rst_n_async                                                                      ; 
assign systolicControlUnit_rst_n_async = rst_n_async                                                                      ;
assign shiftdata_rst_n_async           = rst_n_async                                                                      ;
assign img2row_rst_n_sync              = rst_n_async                                                                      ;                                                                
assign uart_data_tx_in                 = mem2serial_smatrix_out                                                           ;


//---------------------------------------------------------------------------------------------------------------------------------
logic [BYTESIZES-1:0]serial2mem_ops_in_data;
// ATRIBUIÇÂO MEMORIA A/B           
assign serial2mem_opa_in_data = uart_data_rx_out;//: 0            ;
assign serial2mem_opb_in_data = uart_data_rx_out;//: 0            ;uart_data_rx_out

//assign serial2mem_opa_in_data = serial2mem_ops_in_data;//: 0            ;
//assign serial2mem_opb_in_data = serial2mem_ops_in_data;//: 0            ;uart_data_rx_out
assign syst_a_input =  flow_data_time_structure_OUTA                            ;
assign syst_b_input =  flow_data_time_structure_OUTB ;
(*dont_touch = "true"*) 

assign systolicControlUnit_serial2mem_opa_ready_o = serial2mem_opa_ready_o ;
assign systolicControlUnit_serial2mem_opb_ready_o = serial2mem_opb_ready_o ;
//---------------------------------------------------------------------------------------------------------------------------------

//Atribuições unidade de Controle
//---------------------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------------------
assign systolicControlUnit_serial2mem_opa_rvalid_o =  serial2mem_opa_rvalid_o                                   ;
assign systolicControlUnit_serial2mem_opb_rvalid_o =  serial2mem_opb_rvalid_o                                   ;
assign systolicControlUnit_syst_rvalid_o           =  syst_rvalid_o                                             ;
assign systolicControlUnit_mem2serial_rvalid_o     =  mem2serial_rvalid_o                                       ;
assign systolicControlUnit_read_done               =  syst_read_done                                            ;
assign serial2mem_opa_valid_i                      =  systolicControlUnit_serial2mem_opa_valid_i                ;
assign serial2mem_opb_valid_i                      =  systolicControlUnit_serial2mem_opb_valid_i                ;
assign serial2mem_opa_rw                           =  systolicControlUnit_serial2mem_opa_rw                     ;
assign serial2mem_opb_rw                           =  systolicControlUnit_serial2mem_opb_rw                     ;
assign serial2mem_opa_rready_i                     =  systolicControlUnit_serial2mem_opa_rready_i               ;
assign serial2mem_opb_rready_i                     =  systolicControlUnit_serial2mem_opb_rready_i               ;
assign mem2serial_valid_i                          =  systolicControlUnit_mem2serial_valid_i                    ;
assign mem2serial_rready_i                         =  systolicControlUnit_mem2serial_rready_i                   ;
assign syst_valid_i                                =  systolicControlUnit_syst_valid_i                          ;
assign syst_rready_i                               =  systolicControlUnit_syst_rready_i                         ;  
assign systolicControlUnit_uart_ready_rx           =  uart_ready_rx_out;
assign systolicControlUnit_uart_valid_rx_in        =  uart_valid_rx_in;


//---------------------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------------------
systolicMatrixMultiply  #(.WIDTH(WIDTH),.WIDTHx(WIDTHx),.SIZE(SIZE)) u_systolic_matrix_mul_unit(
    .rst_n_async                (syst_rst_n_async                           )                  ,
    .valid_i                    (syst_valid_i                               )                  ,
    .rready_i                   (syst_rready_i                              )                  ,
    .a_input                    (syst_a_input                               )                  ,
    .b_input                    (syst_b_input                               )                  ,
    .ready_o                    (syst_ready_o                               )                  ,
    .rvalid_o                   (syst_rvalid_o                              )                  ,
    .clock                      (syst_clock                                 )                  ,
    .output_produc_a_b          (syst_output_produc_a_b                     )                  ,
    .read_done                  (syst_read_done                             )                  ,
    .ena_shift_data             (syst_ena_mac                               )
);
(*dont_touch = "true"*) 
serial2mem #(.WIDTH(WIDTHx), .SIZE(SIZE_WINDOW))u_serial2mem_opa_unit(
    .clock                      (serial2mem_opa_clock                       )                 ,  
    .rst_n_async                (serial2mem_opa_rst_n_async                 )                 ,// r=1,w=0
    .rw                         (serial2mem_opa_rw                          )                 , //Dado válido na entrada
    .valid_i                    (serial2mem_opa_valid_i                     )                 , //Dado válido na entrada
    .rready_i                   (serial2mem_opa_rready_i                    )                 , //Pronto para receber uma resposta
    .rvalid_o                   (serial2mem_opa_rvalid_o                    )                 , //Resposta Válida(Operação concluida)
    .ready_o                    (serial2mem_opa_ready_o                     )                 , //Pronto para receber um dado valido na entrada
    .in_data                    (serial2mem_opa_in_data                     )                 ,
    .out_data                   (serial2mem_opa_out_data                    )                 ,
    .single_port_ram_di         (                                           )                 ,
    .uart_ready_rx_out          (uart_ready_rx_out && uart_valid_rx_in      )                 

);
(*dont_touch = "true"*) 
serial2mem #(.WIDTH(WIDTHx), .SIZE(SIZE_WINDOW))u_serial2mem_opb_unit(
    .clock                      (serial2mem_opb_clock                       )                 ,  
    .rst_n_async                (serial2mem_opb_rst_n_async                 )                 ,// r=1,w=0
    .rw                         (serial2mem_opb_rw                          )                 , //Dado válido na entrada
    .valid_i                    (serial2mem_opb_valid_i                     )                 , //Dado válido na entrada
    .rready_i                   (serial2mem_opb_rready_i                    )                 , //Pronto para receber uma resposta
    .rvalid_o                   (serial2mem_opb_rvalid_o                    )                 , //Resposta Válida(Operação concluida)
    .ready_o                    (serial2mem_opb_ready_o                     )                 , //Pronto para receber um dado valido na entrada
    .in_data                    (serial2mem_opb_in_data                     )                 ,
    .out_data                   (serial2mem_opb_out_data                    )                 ,
    .single_port_ram_di         (                                           )                 ,
    .uart_ready_rx_out          (uart_ready_rx_out && uart_valid_rx_in      )
    //.fifo_d(fifo_d_b)
);
(*dont_touch = "true"*) 
mem2seriala #(.SIZE(SIZE),.WIDTH(WIDTH),.BYTESIZES(BYTESIZES)) u_mem2serial_unit(
    .clock                      (mem2serial_clock                           )                 ,
    .rst_n_async                (mem2serial_rst_n_async                     )                 ,
    .pmatrix_in                 (mem2serial_pmatrix_in                      )                 ,
    .valid_i                    (mem2serial_valid_i                         )                 , //Dado válido na entrada
    .rready_i                   (mem2serial_rready_i                        )                 , //Pronto para receber uma resposta
    .rvalid_o                   (mem2serial_rvalid_o                        )                 , //Resposta Válida(Operação concluida)
    .ready_o                    (mem2serial_ready_o                         )                 , //Pronto para receber um dado valido na entrada
    .smatrix_out                (mem2serial_smatrix_out                     )                 ,
    .m_axis_tlast               (mem2serial_m_axis_tlast                    )                 ,
    .event_send_data            (uart_ready_tx_out                          )                 ,    //Avaliação 1.1
    .uart_valid_tx_in           (uart_valid_tx_in)
);

(*dont_touch = "true"*) 
systolicControlUnitTop #(.SIZE(SIZE),.WIDTH(WIDTH),.BYTESIZES(BYTESIZES))u_systolic_control_unit(
    .clock                              (systolicControlUnit_clock                      )                ,
    .rst_n_async                        (systolicControlUnit_rst_n_async                )                ,
    .uart_valid_rx_in                   (systolicControlUnit_uart_valid_rx_in           )                ,
    .serial2mem_opa_rvalid_o            (systolicControlUnit_serial2mem_opa_rvalid_o    )                ,
    .serial2mem_opb_rvalid_o            (systolicControlUnit_serial2mem_opb_rvalid_o    )                ,
    .syst_rvalid_o                      (systolicControlUnit_syst_rvalid_o              )                ,
    .mem2serial_rvalid_o                (systolicControlUnit_mem2serial_rvalid_o        )                ,
    .serial2mem_opa_valid_i             (systolicControlUnit_serial2mem_opa_valid_i     )                ,    
    .serial2mem_opb_valid_i             (systolicControlUnit_serial2mem_opb_valid_i     )                ,    
    .serial2mem_opa_rw                  (systolicControlUnit_serial2mem_opa_rw          )                ,    
    .serial2mem_opb_rw                  (systolicControlUnit_serial2mem_opb_rw          )                ,    
    .serial2mem_opa_rready_i            (systolicControlUnit_serial2mem_opa_rready_i    )                ,    
    .serial2mem_opb_rready_i            (systolicControlUnit_serial2mem_opb_rready_i    )                ,    
    .mem2serial_valid_i                 (systolicControlUnit_mem2serial_valid_i         )                ,    
    .mem2serial_rready_i                (systolicControlUnit_mem2serial_rready_i        )                ,    
    .uart_valid_tx_in                   (systolicControlUnit_uart_valid_tx_in           )                ,    
    .syst_valid_i                       (systolicControlUnit_syst_valid_i               )                ,    
    .syst_rready_i                      (systolicControlUnit_syst_rready_i              )                ,
    .uart_data_rx_out                   (uart_data_rx_out[7:0]                          )                ,
    .starting_frame_identified          (systolicControlUnit_starting_frame_identified  )                ,
    .uart_ready_rx                      (systolicControlUnit_uart_ready_rx              )                ,
    .serial2mem_opa_ready_o             (systolicControlUnit_serial2mem_opa_ready_o     )                ,
    .serial2mem_opb_ready_o             (systolicControlUnit_serial2mem_opb_ready_o     )                ,
    .read_done                          (systolicControlUnit_read_done                  )                ,
    .frame_start                        (systolicControlUnit_frame_start                )                ,
    .axi_debug                          (uart_data_rx_out                               )                ,
    .u_im2row_data_valid_i              (u_im2row_data_valid_i                          )                , 
    .u_im2row_module_ready_o            (u_im2row_module_ready_o                        )                ,
    .u_im2row_result_rvalid_o           (u_im2row_result_rvalid_o                       )                ,
    .u_im2row_downstream_ready_i        (u_im2row_downstream_ready_i                    )                ,        
    .sampling_pipeline_stage_1_mem_write(sampling_pipeline_stage_1_mem_write            )                ,
    .sampling_pipeline_stage_2_img2row  (sampling_pipeline_stage_2_img2row              )                ,
    .sampling_pipeline_stage_3_systolic (sampling_pipeline_stage_3_systolic             )                ,
    .sampling_pipeline_stage_4_send2host(sampling_pipeline_stage_4_send2host            )                ,
    .serial2mem_ops_in_data             (serial2mem_ops_in_data                         )                ,       
    .debug_handsheak                    (debug_handsheak                                )                 ,
    .uart_ready_rx_out(uart_ready_rx_out)
);  

shiftdata #(.WIDTHx(WIDTHx),.SIZE(SIZE)) u_shiftdata_unit(
    .clock(shiftdata_clock),
    .rst_n_async(shiftdata_rst_n_async),
    .ena_shift(syst_ena_mac),
    .opa_out_data(shift_opa_out_data),
    .opb_out_data(shift_opb_out_data),
    .flow_data_time_structure_OUTA(flow_data_time_structure_OUTA),
    .flow_data_time_structure_OUTB(flow_data_time_structure_OUTB) 
);

img2row #(.WIDTH(WIDTHx),.SIZE_KER(SIZE_KER),.SIZE_WINDOW(SIZE_WINDOW),.STRIDE(1),.OUT_SIZE_NORM(SIZE))u_img2col_b_unit (
    .clk         (u_im2row_clock),
    .rst_n_sync  (u_im2row_rst_n_sync),
    .valid_i     (u_im2row_data_valid_i),
    .ready_o     (u_im2row_module_ready_o),
    .rvalid_o    (u_im2row_result_rvalid_o),
    .rready_i    (u_im2row_downstream_ready_i),
    .img         (u_im2row_input_a_image),
    .colout      (),
    .colout_tsnp (u_im2row_col_a_matrix)
);




img2row #(.WIDTH(WIDTHx),.SIZE_KER(SIZE_KER),.SIZE_WINDOW(SIZE_WINDOW),.STRIDE(3),.OUT_SIZE_NORM(SIZE))u_ker2col_a_unit (
    .clk         (u_im2row_clock),
    .rst_n_sync  (u_im2row_rst_n_sync),
    .valid_i     (u_im2row_data_valid_i),
    .ready_o     (                     ),
    .rvalid_o    (                      ),
    .rready_i    (u_im2row_downstream_ready_i),
    .img         (u_im2row_input_b_image),
    .colout      (),
    .colout_tsnp (u_im2row_col_b_matrix)

);
//---------------------------------------------------------------------------------------------------
//Registradores para o tratamento de harzards entre estágios do pipeline da unidade de controle     
//---------------------------------------------------------------------------------------------------

always_ff@(posedge clock, negedge rst_n_async)begin
    if(!rst_n_async)begin
        pipeline_serial2mem_opa_out_data <= '{default:0};
        pipeline_serial2mem_opb_out_data <= '{default:0};
        pipeline_u_im2row_col_a_matrix   <= '{default:0};           
        pipeline_u_im2row_col_b_matrix   <= '{default:0};         
        pipeline_syst_output_produc_a_b   <= '{default:0};  
    end else begin
        pipeline_serial2mem_opa_out_data <= (sampling_pipeline_stage_1_mem_write) ? serial2mem_opa_out_data : pipeline_serial2mem_opa_out_data;
        pipeline_serial2mem_opb_out_data <= (sampling_pipeline_stage_1_mem_write) ? serial2mem_opb_out_data : pipeline_serial2mem_opb_out_data;
        pipeline_u_im2row_col_a_matrix   <= (sampling_pipeline_stage_2_img2row)   ? u_im2row_col_a_matrix   : pipeline_u_im2row_col_a_matrix;
        pipeline_u_im2row_col_b_matrix   <= (sampling_pipeline_stage_2_img2row)   ? u_im2row_col_b_matrix   : pipeline_u_im2row_col_b_matrix;
        pipeline_syst_output_produc_a_b  <= (sampling_pipeline_stage_3_systolic)  ? syst_output_produc_a_b   : pipeline_syst_output_produc_a_b;
    end
end


assign u_im2row_input_a_image = pipeline_serial2mem_opb_out_data;
assign u_im2row_input_b_image = pipeline_serial2mem_opa_out_data;
assign shift_opa_out_data     = pipeline_u_im2row_col_a_matrix;
assign shift_opb_out_data     = pipeline_u_im2row_col_b_matrix;
assign mem2serial_pmatrix_in  = pipeline_syst_output_produc_a_b;

wire [23:0] matrix_img2colA [0:5];
wire [23:0] matrix_img2colB [0:5];
genvar ii;

generate
    for (ii = 0; ii < 6; ii = ii + 1) begin
        assign matrix_img2colA[ii] =
            {>>(4){serial2mem_opa_out_data[ii]}};
    end
endgenerate

//wire [23:0] matrix_img2colB [0:5];

genvar jj;

generate
    for (jj = 0; jj < 6; jj =jj + 1) begin
        assign matrix_img2colB[jj] =
            {>>(4){serial2mem_opb_out_data[jj]}};
    end
endgenerate

ila_1 ila_img2col (
	.clk(clock), // input wire clk


	.probe0 (matrix_img2colA[0] ), // input wire [7:0]  probe0  
	.probe1 (matrix_img2colA[1] ), // input wire [7:0]  probe1 
	.probe2 (matrix_img2colA[2] ), // input wire [7:0]  probe2 
	.probe3 (matrix_img2colA[3] ), // input wire [7:0]  probe3 
	.probe4 (matrix_img2colA[4] ), // input wire [7:0]  probe4 
	.probe5 (matrix_img2colA[5] ), // input wire [7:0]  probe4 
	.probe6 (sampling_pipeline_stage_1_mem_write)
);

ila_1 ilb_img2col (
	.clk(clock), // input wire clk


	.probe0 (matrix_img2colB[0] ), // input wire [7:0]  probe0  
	.probe1 (matrix_img2colB[1] ), // input wire [7:0]  probe1 
	.probe2 (matrix_img2colB[2] ), // input wire [7:0]  probe2 
	.probe3 (matrix_img2colB[3] ), // input wire [7:0]  probe3 
	.probe4 (matrix_img2colB[4] ), // input wire [7:0]  probe4 
	.probe5 (matrix_img2colB[5] ), // input wire [7:0]  probe4 
    .probe6 (sampling_pipeline_stage_1_mem_write)
);


wire [63:0] matrix_A [0:15];

genvar i;

generate
    for (i = 0; i < 16; i = i + 1) begin
        assign matrix_A[i] =
            {>>(4){pipeline_u_im2row_col_a_matrix[i]}};
    end
endgenerate

wire [63:0] matrix_B [0:15];

genvar j;

generate
    for (j = 0; j < 16; j =j + 1) begin
        assign matrix_B[j] =
            {>>(4){pipeline_u_im2row_col_b_matrix[j]}};
    end
endgenerate

//{>>(WIDTH){pmatrix_in[j_counter]}};
ila_4 matrizes_ila0 (
	.clk(clock), // input wire clk


	.probe0 (matrix_A[0] ), // input wire [127:0]  probe0  
	.probe1 (matrix_A[1] ), // input wire [127:0]  probe1 
	.probe2 (matrix_A[2] ), // input wire [127:0]  probe2 
	.probe3 (matrix_A[3] ), // input wire [127:0]  probe3 
	.probe4 (matrix_A[4] ), // input wire [127:0]  probe4 
	.probe5 (matrix_A[5] ), // input wire [127:0]  probe5 
	.probe6 (matrix_A[6] ), // input wire [127:0]  probe6 
	.probe7 (matrix_A[7] ), // input wire [127:0]  probe7 
	.probe8 (matrix_A[8] ), // input wire [127:0]  probe8 
	.probe9 (matrix_A[9] ), // input wire [127:0]  probe9 
	.probe10(matrix_A[10]), // input wire [127:0]  probe10 
	.probe11(matrix_A[11]), // input wire [127:0]  probe11 
	.probe12(matrix_A[12]), // input wire [127:0]  probe12 
	.probe13(matrix_A[13]), // input wire [127:0]  probe13 
	.probe14(matrix_A[14]), // input wire [127:0]  probe14 
	.probe15(matrix_A[15]), // input wire [127:0]  probe15
	.probe16(sampling_pipeline_stage_2_img2row)
);



//{>>(WIDTH){pmatrix_in[j_counter]}};
ila_4 matrizes_ila1 (
	.clk(clock), // input wire clk


	.probe0 (matrix_B[0] ), // input wire [127:0]  probe0  
	.probe1 (matrix_B[1] ), // input wire [127:0]  probe1 
	.probe2 (matrix_B[2] ), // input wire [127:0]  probe2 
	.probe3 (matrix_B[3] ), // input wire [127:0]  probe3 
	.probe4 (matrix_B[4] ), // input wire [127:0]  probe4 
	.probe5 (matrix_B[5] ), // input wire [127:0]  probe5 
	.probe6 (matrix_B[6] ), // input wire [127:0]  probe6 
	.probe7 (matrix_B[7] ), // input wire [127:0]  probe7 
	.probe8 (matrix_B[8] ), // input wire [127:0]  probe8 
	.probe9 (matrix_B[9] ), // input wire [127:0]  probe9 
	.probe10(matrix_B[10]), // input wire [127:0]  probe10 
	.probe11(matrix_B[11]), // input wire [127:0]  probe11 
	.probe12(matrix_B[12]), // input wire [127:0]  probe12 
	.probe13(matrix_B[13]), // input wire [127:0]  probe13 
	.probe14(matrix_B[14]), // input wire [127:0]  probe14 
	.probe15(matrix_B[15]), // input wire [127:0]  probe15
	.probe16(sampling_pipeline_stage_2_img2row)
);

wire [127:0] matrix_C [0:15];

genvar k;

generate
    for (k = 0; k < 16; k =k + 1) begin
        assign matrix_C[k] =
            {>>(8){pipeline_syst_output_produc_a_b[k]}};
    end
endgenerate
ila_5 matrizes_ilc1 (
	.clk(clock), // input wire clk


	.probe0 (matrix_C[0] ), // input wire [127:0]  probe0  
	.probe1 (matrix_C[1] ), // input wire [127:0]  probe1 
	.probe2 (matrix_C[2] ), // input wire [127:0]  probe2 
	.probe3 (matrix_C[3] ), // input wire [127:0]  probe3 
	.probe4 (matrix_C[4] ), // input wire [127:0]  probe4 
	.probe5 (matrix_C[5] ), // input wire [127:0]  probe5 
	.probe6 (matrix_C[6] ), // input wire [127:0]  probe6 
	.probe7 (matrix_C[7] ), // input wire [127:0]  probe7 
	.probe8 (matrix_C[8] ), // input wire [127:0]  probe8 
	.probe9 (matrix_C[9] ), // input wire [127:0]  probe9 
	.probe10(matrix_C[10]), // input wire [127:0]  probe10 
	.probe11(matrix_C[11]), // input wire [127:0]  probe11 
	.probe12(matrix_C[12]), // input wire [127:0]  probe12 
	.probe13(matrix_C[13]), // input wire [127:0]  probe13 
	.probe14(matrix_C[14]), // input wire [127:0]  probe14 
	.probe15(matrix_C[15]), // input wire [127:0]  probe15
	.probe16(sampling_pipeline_stage_3_systolic),
	.probe17(debug_handsheak)
);



wire [127:0] matrix_shifta [0:15];

genvar u;

generate
    for (u = 0; u < 16; u =u + 1) begin
        assign matrix_shifta[u] =
            {>>(4){flow_data_time_structure_OUTA[u]}};
    end
endgenerate
ila_5 matrizes_ilshifta (
	.clk(clock), // input wire clk


	.probe0 (matrix_shifta[0] ), // input wire [127:0]  probe0  
	.probe1 (matrix_shifta[1] ), // input wire [127:0]  probe1 
	.probe2 (matrix_shifta[2] ), // input wire [127:0]  probe2 
	.probe3 (matrix_shifta[3] ), // input wire [127:0]  probe3 
	.probe4 (matrix_shifta[4] ), // input wire [127:0]  probe4 
	.probe5 (matrix_shifta[5] ), // input wire [127:0]  probe5 
	.probe6 (matrix_shifta[6] ), // input wire [127:0]  probe6 
	.probe7 (matrix_shifta[7] ), // input wire [127:0]  probe7 
	.probe8 (matrix_shifta[8] ), // input wire [127:0]  probe8 
	.probe9 (matrix_shifta[9] ), // input wire [127:0]  probe9 
	.probe10(matrix_shifta[10]), // input wire [127:0]  probe10 
	.probe11(matrix_shifta[11]), // input wire [127:0]  probe11 
	.probe12(matrix_shifta[12]), // input wire [127:0]  probe12 
	.probe13(matrix_shifta[13]), // input wire [127:0]  probe13 
	.probe14(matrix_shifta[14]), // input wire [127:0]  probe14 
	.probe15(matrix_shifta[15]), // input wire [127:0]  probe15
	.probe16(sampling_pipeline_stage_3_systolic),
	.probe17(debug_handsheak)
);

wire [127:0] matrix_shiftb [0:15];

genvar uu;

generate
    for (uu = 0; uu < 16; uu =uu + 1) begin
        assign matrix_shiftb[uu] =
            {>>(4){flow_data_time_structure_OUTB[uu]}};
    end
endgenerate
ila_5 matrizes_ilshiftb (
	.clk(clock), // input wire clk


	.probe0 (matrix_shiftb[0] ), // input wire [127:0]  probe0  
	.probe1 (matrix_shiftb[1] ), // input wire [127:0]  probe1 
	.probe2 (matrix_shiftb[2] ), // input wire [127:0]  probe2 
	.probe3 (matrix_shiftb[3] ), // input wire [127:0]  probe3 
	.probe4 (matrix_shiftb[4] ), // input wire [127:0]  probe4 
	.probe5 (matrix_shiftb[5] ), // input wire [127:0]  probe5 
	.probe6 (matrix_shiftb[6] ), // input wire [127:0]  probe6 
	.probe7 (matrix_shiftb[7] ), // input wire [127:0]  probe7 
	.probe8 (matrix_shiftb[8] ), // input wire [127:0]  probe8 
	.probe9 (matrix_shiftb[9] ), // input wire [127:0]  probe9 
	.probe10(matrix_shiftb[10]), // input wire [127:0]  probe10 
	.probe11(matrix_shiftb[11]), // input wire [127:0]  probe11 
	.probe12(matrix_shiftb[12]), // input wire [127:0]  probe12 
	.probe13(matrix_shiftb[13]), // input wire [127:0]  probe13 
	.probe14(matrix_shiftb[14]), // input wire [127:0]  probe14 
	.probe15(matrix_shiftb[15]), // input wire [127:0]  probe15
	.probe16(sampling_pipeline_stage_3_systolic),
	.probe17(debug_handsheak)
);
endmodule




module systolicControlUnitTop#(parameter SIZE=32,WINDOW =6,WIDTH=8,BYTESIZES =256)(
    input  logic       clock                        ,
    input  logic       rst_n_async                  ,
    input  logic       uart_valid_rx_in             ,
    input  logic       uart_ready_rx                ,
    input  logic       u_im2row_module_ready_o      ,        
    input  logic       u_im2row_result_rvalid_o     ,
    input  logic       serial2mem_opa_rvalid_o      ,
    input  logic       serial2mem_opb_rvalid_o      ,
    input  logic       serial2mem_opa_ready_o       ,
    input  logic       serial2mem_opb_ready_o       ,
    input  logic       syst_rvalid_o                ,
    input  logic       mem2serial_rvalid_o          ,
    input  logic       read_done                    ,
    input  logic [7:0] uart_data_rx_out             ,
    output logic       serial2mem_opa_valid_i       ,    
    output logic       serial2mem_opb_valid_i       ,    
    output logic       serial2mem_opa_rw            ,    
    output logic       serial2mem_opb_rw            ,    
    output logic       serial2mem_opa_rready_i      ,    
    output logic       serial2mem_opb_rready_i      ,    
    output logic       mem2serial_valid_i           ,    
    output logic       mem2serial_rready_i          ,       
    output logic       syst_valid_i                 ,    
    output logic       syst_rready_i                ,
    output logic       uart_valid_tx_in             ,
    output logic       starting_frame_identified    ,
    output logic [31:0] frame_start                 ,
    input  logic [SIZE*WIDTH-1:0] axi_debug         ,
    output logic u_im2row_data_valid_i              ,      
    output logic u_im2row_downstream_ready_i        ,
    output logic sampling_pipeline_stage_1_mem_write,
    output logic sampling_pipeline_stage_2_img2row  ,
    output logic sampling_pipeline_stage_3_systolic ,
    output logic sampling_pipeline_stage_4_send2host,
    output logic [BYTESIZES-1:0]serial2mem_ops_in_data,
    output logic debug_handsheak

);

                             


localparam MAX_COUNTER_STAGES=31;
logic       s_axis_tlast;
logic ena_mem_write_counter, ena_mem_read_systolic_counter, ena_send2host_counter,ena_out_img2row;
logic clean_counter_all;
logic [MAX_COUNTER_STAGES-1:0]counter_out_opA ;
logic [MAX_COUNTER_STAGES-1:0]counter_out_systolic_read_mem;
logic [MAX_COUNTER_STAGES-1:0]counter_out_send_fpga2host;
logic [MAX_COUNTER_STAGES-1:0]counter_out_img2row;
logic sampling_pipeline_stage_1_mem_write_reg;
logic sampling_pipeline_stage_2_img2row_reg;
logic sampling_pipeline_stage_3_systolic_reg;
logic sampling_pipeline_stage_4_send2host_reg;




enum {IDLE,WRITE_MEM,IMG2ROW,SYSTOLIC_READ_MEM,SEND_FPGA2DMA} fsm_unit_control, fsm_unit_control_next;
enum {IDLE_W        ,    WRITE_P} fsm_pipeline_s1, fsm_pipeline_next_s1;
enum {IDLE_E        ,    EXEC_P } fsm_pipeline_s2, fsm_pipeline_next_s2;
enum {IDLE_I        ,    EXEC_I} fsm_pipeline_s4, fsm_pipeline_next_s4;
enum {IDLE_S        ,SEND2HOST_P} fsm_pipeline_s3, fsm_pipeline_next_s3;

logic handsheak;

logic clock_sample;


always_ff@(posedge clock, negedge rst_n_async)begin
    if(!rst_n_async)begin
        clock_sample <= 0;
    end else begin
        clock_sample <= ~clock_sample;
    
    end 
    
end


always_ff@(posedge clock, negedge rst_n_async)begin
    if(!rst_n_async)begin
        frame_start        <= 0;
        handsheak <= 0;

    end else begin
        handsheak <= uart_valid_rx_in && uart_ready_rx;
        frame_start[07:00] <= (uart_valid_rx_in && uart_ready_rx)  ? uart_data_rx_out  :frame_start[07:00];
        frame_start[15:08] <= (uart_valid_rx_in && uart_ready_rx)  ? frame_start[07:00]:frame_start[15:08];
        frame_start[23:16] <= (uart_valid_rx_in && uart_ready_rx)  ? frame_start[15:08]:frame_start[23:16];
        frame_start[31:24] <= (uart_valid_rx_in && uart_ready_rx)  ? frame_start[23:16]:frame_start[31:24];
    end
end
 
assign debug_handsheak = handsheak;


always_ff@(posedge clock, negedge rst_n_async)begin
    if(!rst_n_async)begin
        fsm_unit_control <= IDLE;
    end else begin
        fsm_unit_control <= fsm_unit_control_next;
    end
end
always_comb case(fsm_unit_control)
    IDLE:begin
        serial2mem_opa_rw             = 0;
        serial2mem_opb_rw             = 0;
        serial2mem_opa_rready_i       = 0;
        serial2mem_opb_rready_i       = 0;
        mem2serial_rready_i           = 1;
        syst_rready_i                 = 1;  
        u_im2row_downstream_ready_i   = 0; 
        uart_valid_tx_in              = 0;        
        syst_valid_i                  = 0; 
        mem2serial_valid_i            = 0; 
       
        starting_frame_identified     = 1;
        s_axis_tlast =0;
        if(uart_valid_rx_in && uart_ready_rx && {frame_start[15:0],uart_data_rx_out} == 16'hffff) begin //Verifcado
        //if(uart_valid_rx_in && uart_ready_rx && frame_start[15:0] == 16'hffff) begin // Dump
        //if(uart_valid_rx_in && uart_ready_rx && frame_start[15:0] == 16'hffff) begin
                fsm_unit_control_next    =WRITE_MEM;
                serial2mem_opb_valid_i   =0;
                serial2mem_opa_valid_i   =0;
                s_axis_tlast             =1;
        end else begin
                serial2mem_opb_valid_i  =0;
                fsm_unit_control_next   =IDLE;
                serial2mem_opa_valid_i  =0;
                s_axis_tlast            =1;
        end
        ena_mem_write_counter           =0;
        ena_mem_read_systolic_counter   =0;
        ena_send2host_counter           =0;
        ena_out_img2row                 =0;


            
            
            
        fsm_pipeline_next_s1            =IDLE_W; 
        fsm_pipeline_next_s2            =IDLE_E;
        fsm_pipeline_next_s3            =IDLE_S;
        fsm_pipeline_next_s4            =IDLE_I;


        u_im2row_data_valid_i           =0;  

        serial2mem_ops_in_data = 0;
    end
    WRITE_MEM:begin
        syst_valid_i                  = 0;          
        mem2serial_valid_i            = 0;
        serial2mem_opa_valid_i        =  counter_out_opA < WINDOW;
        serial2mem_opb_valid_i        =  counter_out_opA  >=  WINDOW;
        serial2mem_opa_rw             = 0;  
        serial2mem_opb_rw             = 0; 
        serial2mem_opa_rready_i       = 0;
        serial2mem_opb_rready_i       = 0;    

        mem2serial_rready_i           = 0;
        u_im2row_downstream_ready_i   = 0;
        syst_rready_i                 = serial2mem_opa_rvalid_o && serial2mem_opb_rvalid_o;  


        fsm_unit_control_next         = serial2mem_opa_rvalid_o && serial2mem_opb_rvalid_o &&  counter_out_opA >= 3*SIZE-1+5?  IMG2ROW : WRITE_MEM;
        uart_valid_tx_in              = 0;
        starting_frame_identified     = 1;
        s_axis_tlast                  = serial2mem_opa_rvalid_o ? 1 : 0;

        ena_mem_write_counter         = 1;
        ena_out_img2row               = 0;
        ena_mem_read_systolic_counter = 0;
        ena_send2host_counter         = 0;
        serial2mem_ops_in_data = axi_debug;
        
         
         
        fsm_pipeline_next_s1          = WRITE_P;
        fsm_pipeline_next_s2          = IDLE_E;
        fsm_pipeline_next_s3          = IDLE_S;
        fsm_pipeline_next_s4          = IDLE_I;


        u_im2row_data_valid_i         = 0;  



    end
    IMG2ROW:begin
        syst_valid_i                  = 0;
        u_im2row_data_valid_i         = 1;
        serial2mem_opa_valid_i        =  counter_out_opA < WINDOW+1;
        serial2mem_opb_valid_i        =  counter_out_opA  >=  WINDOW+1;
        serial2mem_opa_rw             = 0;  
        serial2mem_opb_rw             = 0;
        serial2mem_opa_rready_i       = counter_out_img2row==0;
        serial2mem_opb_rready_i       = counter_out_img2row==0;
        u_im2row_downstream_ready_i   = 0;
        syst_rready_i                 = serial2mem_opa_rvalid_o && serial2mem_opb_rvalid_o; 




        ena_mem_write_counter         = 1;
        ena_out_img2row               = 1;
        ena_mem_read_systolic_counter = 0;
        ena_send2host_counter         = 0;

        fsm_unit_control_next         = u_im2row_result_rvalid_o && counter_out_img2row >=3*SIZE-1+5?SYSTOLIC_READ_MEM : IMG2ROW;


        
         
         
        fsm_pipeline_next_s1          = WRITE_P;
        fsm_pipeline_next_s2          = IDLE_E;
        fsm_pipeline_next_s3          = IDLE_S;
        fsm_pipeline_next_s4          = EXEC_I;
        serial2mem_ops_in_data = axi_debug;

    
    end
    SYSTOLIC_READ_MEM:begin
        syst_valid_i                  = 1; 
        mem2serial_valid_i            = 0;
        serial2mem_opa_valid_i        =  counter_out_opA < WINDOW+1;
        serial2mem_opb_valid_i        =  counter_out_opA  >=  WINDOW+1;
        serial2mem_opa_rw             = 0;  
        serial2mem_opb_rw             = 0;  
        serial2mem_opa_rready_i       = counter_out_systolic_read_mem==0;
        serial2mem_opb_rready_i       = counter_out_systolic_read_mem==0;
        u_im2row_downstream_ready_i   = counter_out_img2row == 0;
        mem2serial_rready_i           = 0;
        syst_rready_i                 = serial2mem_opa_rvalid_o && serial2mem_opb_rvalid_o;
         
        uart_valid_tx_in              = 0;

        
        fsm_unit_control_next         = syst_rvalid_o &&  counter_out_systolic_read_mem >= 3*SIZE-1+5? SEND_FPGA2DMA : SYSTOLIC_READ_MEM ;
        starting_frame_identified     = 0;
        s_axis_tlast                  = 1; 

        ena_mem_write_counter         = 1;
        ena_out_img2row               = 1;
        ena_mem_read_systolic_counter = 1;
        ena_send2host_counter         = 0;

        
         
         
        fsm_pipeline_next_s1          = WRITE_P;
        fsm_pipeline_next_s2          = EXEC_P;
        fsm_pipeline_next_s3          = IDLE_S;
        fsm_pipeline_next_s4          = EXEC_I;  
        ena_out_img2row               = 1;
        serial2mem_ops_in_data = axi_debug;
    end
    SEND_FPGA2DMA:begin
        s_axis_tlast= 0;
        serial2mem_opa_valid_i        =  counter_out_opA < WINDOW+1;
        serial2mem_opb_valid_i        =  counter_out_opA  >=  WINDOW+1;
        serial2mem_opa_rw             = 0;  
        serial2mem_opb_rw             = 0;
        mem2serial_rready_i           = mem2serial_rvalid_o && counter_out_send_fpga2host >= 3*SIZE-1 +5;    
        syst_rready_i                 = syst_rvalid_o &&  counter_out_send_fpga2host >= 3*SIZE-1 +5;
        serial2mem_opa_rready_i       = counter_out_send_fpga2host ==0;
        serial2mem_opb_rready_i       = counter_out_send_fpga2host ==0;
        mem2serial_valid_i            = 1;
      
        syst_valid_i                  = 1;
  
        uart_valid_tx_in              = 1;
        fsm_unit_control_next         = uart_valid_rx_in && uart_ready_rx && frame_start[15:0] == 16'heaea ? IDLE: fsm_unit_control;
        starting_frame_identified     = 0;

        ena_mem_write_counter         = 1;
        ena_out_img2row               = 1;
        ena_mem_read_systolic_counter = 1;
        ena_send2host_counter         = 1;
  
        fsm_pipeline_next_s1          = WRITE_P;
        fsm_pipeline_next_s2          = EXEC_P;
        fsm_pipeline_next_s3          = SEND2HOST_P;
        fsm_pipeline_next_s4          = EXEC_I;
        serial2mem_ops_in_data = uart_valid_rx_in && uart_ready_rx && frame_start[15:0] == 16'heaea ? 0 : axi_debug ;
        ena_out_img2row               = 1;
    end
    default:begin
        mem2serial_valid_i            = 0;
        syst_valid_i                  = 0; 
        fsm_unit_control_next         = IDLE;
        serial2mem_opa_valid_i        = 0;
        serial2mem_opb_valid_i        = 0;
        serial2mem_opa_rw             = 0;
        serial2mem_opb_rw             = 0;
        serial2mem_opa_rready_i       = 0;
        serial2mem_opb_rready_i       = 0;
        mem2serial_rready_i           = 1;
        syst_rready_i                 = 0;

        uart_valid_tx_in              = 0;        
 
          
        starting_frame_identified     = 1;
        s_axis_tlast                  = 1;

        ena_out_img2row               = 0;
        ena_send2host_counter         = 0;
        ena_mem_read_systolic_counter = 0;
        ena_mem_write_counter         = 0;

        fsm_pipeline_next_s4          = IDLE_I;
        fsm_pipeline_next_s3          = IDLE_S;    
        fsm_pipeline_next_s2          = IDLE_E;    
        fsm_pipeline_next_s1          = IDLE_W; 
        serial2mem_ops_in_data = 0;
        

    end
endcase


assign clean_counter_all = fsm_unit_control == IDLE;
counter#(.MAX_COUNTER(MAX_COUNTER_STAGES)) counter_opA(

        .clock          (clock                                          )                           ,
        .rst_n_async    (rst_n_async                                    )                           ,
        .ena            (ena_mem_write_counter                          )                           ,
        .counter        (counter_out_opA                                )                           ,
        .clean          (counter_out_opA >= 3*SIZE-1+5 || clean_counter_all                  )
);

counter#(.MAX_COUNTER(MAX_COUNTER_STAGES)) counter_read_mem(

        .clock          (clock                                          )                           ,
        .rst_n_async    (rst_n_async                                    )                           ,
        .ena            (ena_mem_read_systolic_counter                  )                           ,
        .counter        (counter_out_systolic_read_mem                  )                           ,
        .clean          (counter_out_systolic_read_mem >= 3*SIZE-1+5 || clean_counter_all    )
);

counter#(.MAX_COUNTER(MAX_COUNTER_STAGES)) counter_write_mem(

        .clock          (clock                                                              )                           ,
        .rst_n_async    (rst_n_async                                                        )                           ,
        .ena            (ena_send2host_counter                                              )                           ,
        .counter        (counter_out_send_fpga2host                                         )                           ,
        .clean          (counter_out_send_fpga2host >= 3*SIZE-1+5 || clean_counter_all      )
);

counter#(.MAX_COUNTER(MAX_COUNTER_STAGES)) counter_img2row(

        .clock          (clock                                                     )                                     ,
        .rst_n_async    (rst_n_async                                               )                                     ,
        .ena            (ena_out_img2row                                           )                                     ,
        .counter        (counter_out_img2row                                       )                                     ,
        .clean          (counter_out_img2row >= 3*SIZE-1+5 || clean_counter_all    )
);





always_ff@(posedge clock, negedge rst_n_async)begin
    if(!rst_n_async)begin
        fsm_pipeline_s4                         <=IDLE_I;
        fsm_pipeline_s3                         <=IDLE_S;
        fsm_pipeline_s2                         <=IDLE_E;
        fsm_pipeline_s1                         <=IDLE_W; 
        sampling_pipeline_stage_1_mem_write_reg <= 0;
        sampling_pipeline_stage_2_img2row_reg   <= 0;
        sampling_pipeline_stage_3_systolic_reg  <= 0;
        sampling_pipeline_stage_4_send2host_reg <= 0;  
    end else begin
        fsm_pipeline_s4                         <=fsm_pipeline_next_s4;      
        fsm_pipeline_s3                         <=fsm_pipeline_next_s3;      
        fsm_pipeline_s2                         <=fsm_pipeline_next_s2;      
        fsm_pipeline_s1                         <=fsm_pipeline_next_s1;
        sampling_pipeline_stage_1_mem_write_reg <= counter_out_opA == 3*SIZE-1+5;
        sampling_pipeline_stage_2_img2row_reg   <= counter_out_img2row == 3*SIZE-1+5;
        sampling_pipeline_stage_3_systolic_reg  <= counter_out_systolic_read_mem == 3*SIZE-1+5;
        sampling_pipeline_stage_4_send2host_reg <= counter_out_send_fpga2host == 3*SIZE-1+5; 
    end
    
end

assign sampling_pipeline_stage_1_mem_write = sampling_pipeline_stage_1_mem_write_reg;
assign sampling_pipeline_stage_2_img2row = sampling_pipeline_stage_2_img2row_reg;
assign sampling_pipeline_stage_3_systolic = sampling_pipeline_stage_3_systolic_reg;
assign sampling_pipeline_stage_4_send2host = sampling_pipeline_stage_4_send2host_reg;


logic capture_start_fram;

assign capture_start_fram =uart_valid_rx_in && uart_ready_rx && {frame_start[15:0],uart_data_rx_out} == 16'hffff;

ila_2 your_instance_name (
	.clk(clock), // input wire clk

//fsm_unit_control
	.probe0(frame_start), // input wire [7:0]  probe0  
	.probe1(fsm_unit_control), // input wire [7:0]  probe1 
	.probe2(handsheak), // input wire [7:0]  probe2 
	.probe3(sampling_pipeline_stage_1_mem_write), // input wire [7:0]  probe3
	.probe4(sampling_pipeline_stage_2_img2row), // input wire [7:0]  probe3
	.probe5(sampling_pipeline_stage_3_systolic), // input wire [7:0]  probe3
	.probe6(sampling_pipeline_stage_4_send2host), // input wire [7:0]  probe3
	.probe7(capture_start_fram), // input wire [7:0]  probe3
	.probe8(axi_debug) // input wire [7:0]  probe3
);


endmodule


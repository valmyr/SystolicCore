module systolicControlUnitTop#(parameter SIZE=32,WINDOW =6,WIDTH=8,BYTESIZES =256)(
    input  logic                  clock   ,
    input  logic                  rst_n_async                        ,
    input  logic                  uart_valid_rx_in                   ,
    input  logic                  uart_ready_rx                      ,
    input  logic                  u_im2row_module_ready_o            ,        
    input  logic                  u_im2row_result_rvalid_o           ,
    input  logic                  serial2mem_opa_rvalid_o            ,
    input  logic                  serial2mem_opb_rvalid_o            ,
    input  logic                  serial2mem_opa_ready_o             ,
    input  logic                  serial2mem_opb_ready_o             ,
    input  logic                  syst_rvalid_o                      ,
    input  logic                  mem2serial_rvalid_o                ,
    input  logic                  read_done                          ,
    input  logic [7:0]            uart_data_rx_out                   ,
    output logic                  serial2mem_opa_valid_i             ,    
    output logic                  serial2mem_opb_valid_i             ,    
    output logic                  serial2mem_opa_rw                  ,    
    output logic                  serial2mem_opb_rw                  ,    
    output logic                  serial2mem_opa_rready_i            ,    
    output logic                  serial2mem_opb_rready_i            ,    
    output logic                  mem2serial_valid_i                 ,    
    output logic                  mem2serial_rready_i                ,       
    output logic                  syst_valid_i                       ,    
    output logic                  syst_rready_i                      ,
    output logic                  uart_valid_tx_in                   ,
    output logic                  starting_frame_identified          ,
    output logic [31:0]           frame_start                        ,
    input  logic [SIZE*WIDTH-1:0] axi_debug                          ,
    output logic                  u_im2row_data_valid_i              ,      
    output logic                  u_im2row_downstream_ready_i        ,
    output logic                  sampling_pipeline_stage_1_mem_write,
    output logic                  sampling_pipeline_stage_2_img2row  ,
    output logic                  sampling_pipeline_stage_3_systolic ,
    output logic                  sampling_pipeline_stage_4_send2host,
    output logic [BYTESIZES-1:0]  serial2mem_ops_in_data,
    output logic                  debug_handsheak,
    output logic                  uart_ready_rx_out

);

  


localparam MAX_COUNTER_STAGES=31;
logic       s_axis_tlast;
logic ena_mem_write_counter, ena_mem_read_systolic_counter, ena_send2host_counter,ena_out_img2row;
logic clean_counter_all;
logic [MAX_COUNTER_STAGES-1:0]counter_out_opA ;
logic [MAX_COUNTER_STAGES-1:0]counter_out_systolic_read_mem;
logic [MAX_COUNTER_STAGES-1:0]counter_out_send_fpga2host;
logic [MAX_COUNTER_STAGES-1:0]counter_out_img2row;
logic [MAX_COUNTER_STAGES-1:0] counter_out_pipeline_emptying;

logic sampling_pipeline_stage_1_mem_write_reg;
logic sampling_pipeline_stage_2_img2row_reg;
logic sampling_pipeline_stage_3_systolic_reg;
logic sampling_pipeline_stage_4_send2host_reg;
logic ena_out_pipeline_emptying;



enum {IDLE,WRITE_MEM,IMG2ROW,SYSTOLIC_READ_MEM,SEND_FPGA2DMA} fsm_unit_control, fsm_unit_control_next;
enum {IDLE_W        ,    WRITE_P} fsm_pipeline_s1, fsm_pipeline_next_s1;
enum {IDLE_E        ,    EXEC_P } fsm_pipeline_s2, fsm_pipeline_next_s2;
enum {IDLE_I        ,    EXEC_I} fsm_pipeline_s4, fsm_pipeline_next_s4;
enum {IDLE_S        ,SEND2HOST_P} fsm_pipeline_s3, fsm_pipeline_next_s3;

logic handsheak;
logic start_pipeline;
logic stop_pipeline;
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

/*
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

*/

assign debug_handsheak = handsheak;
assign start_pipeline = {frame_start[15:0],uart_data_rx_out} == 16'hffff;
assign stop_pipeline =  frame_start[15:0] == 16'heaea;

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
        serial2mem_opa_rready_i       = 1;
        serial2mem_opb_rready_i       = 1;
        mem2serial_rready_i           = 1;
        syst_rready_i                 = 1;  
        u_im2row_downstream_ready_i   = 0; 
        uart_valid_tx_in              = 0;        
        syst_valid_i                  = 0; 
        mem2serial_valid_i            = 0; 
       
        starting_frame_identified     = 1;
        s_axis_tlast =0;
        if(start_pipeline) begin //Verifcado
        //if(uart_valid_rx_in && uart_ready_rx && frame_start[15:0] == 16'hffff) begin // Dump
        //if(uart_valid_rx_in && uart_ready_rx && frame_start[15:0] == 16'hffff) begin
                fsm_unit_control_next    =WRITE_MEM;
                serial2mem_opb_valid_i   =0;
                serial2mem_opa_valid_i   =0;
                s_axis_tlast             =0;
                

        end else begin
                serial2mem_opb_valid_i  =0;
                fsm_unit_control_next   =IDLE;
                serial2mem_opa_valid_i  =0;
                s_axis_tlast            =0;
        end
        ena_mem_write_counter           =0;
        ena_mem_read_systolic_counter   =0;
        ena_send2host_counter           =0;
        ena_out_img2row                 =0;

        uart_ready_rx_out   = 1;
            

        
            
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
        serial2mem_opa_valid_i        = counter_out_opA < WINDOW;
        serial2mem_opb_valid_i        = counter_out_opA  >=  WINDOW && counter_out_opA  < 2*WINDOW;
        serial2mem_opa_rw             = 0;  
        serial2mem_opb_rw             = 0; 
        serial2mem_opa_rready_i       = counter_out_opA == 3*SIZE-2+5;
        serial2mem_opb_rready_i       = counter_out_opA == 3*SIZE-2+5;    

        mem2serial_rready_i           = 0;
        u_im2row_downstream_ready_i   = 0;
        syst_rready_i                 = serial2mem_opa_rvalid_o && serial2mem_opb_rvalid_o;  


        fsm_unit_control_next         = counter_out_opA >= 3*SIZE-1+5?  IMG2ROW : WRITE_MEM;
        uart_valid_tx_in              = 0;
        starting_frame_identified     = 1;
        s_axis_tlast                  = 0;

        ena_mem_write_counter         = 1;
        ena_out_img2row               = 0;
        ena_mem_read_systolic_counter = 0;
        ena_send2host_counter         = 0;
        serial2mem_ops_in_data = axi_debug;
        uart_ready_rx_out   =  counter_out_opA < 2*WINDOW;
         
         
         
        fsm_pipeline_next_s1          = WRITE_P;
        fsm_pipeline_next_s2          = IDLE_E;
        fsm_pipeline_next_s3          = IDLE_S;
        fsm_pipeline_next_s4          = IDLE_I;


        u_im2row_data_valid_i         = 0;  



    end
    IMG2ROW:begin
        syst_valid_i                  = 0;
        u_im2row_data_valid_i         = counter_out_opA < WINDOW;
        serial2mem_opa_valid_i        =  counter_out_opA < WINDOW;
        serial2mem_opb_valid_i        =  counter_out_opA  >=  WINDOW && counter_out_opA  < 2*WINDOW;
        serial2mem_opa_rw             = 0;  
        serial2mem_opb_rw             = 0;
        serial2mem_opa_rready_i       = counter_out_opA >= 3*SIZE-1+5;
        serial2mem_opb_rready_i       = counter_out_opA >= 3*SIZE-1+5;  
        u_im2row_downstream_ready_i   = counter_out_img2row >=3*SIZE-1+5;
        syst_rready_i                 = serial2mem_opa_rvalid_o && serial2mem_opb_rvalid_o; 
        uart_ready_rx_out             = counter_out_opA < 2*WINDOW;
        mem2serial_valid_i            = 0;



        ena_mem_write_counter         = 1;
        ena_out_img2row               = 1;
        ena_mem_read_systolic_counter = 0;
        ena_send2host_counter         = 0;

        fsm_unit_control_next         = u_im2row_result_rvalid_o && counter_out_img2row >=3*SIZE-1+5?SYSTOLIC_READ_MEM : IMG2ROW;


        
         mem2serial_rready_i           = 0;
         
        fsm_pipeline_next_s1          = WRITE_P;
        fsm_pipeline_next_s2          = IDLE_E;
        fsm_pipeline_next_s3          = IDLE_S;
        fsm_pipeline_next_s4          = EXEC_I;
        serial2mem_ops_in_data = axi_debug;
        uart_valid_tx_in              = 0;
    
    end
    SYSTOLIC_READ_MEM:begin
        syst_valid_i                  = 1; 
        mem2serial_valid_i            = 0;
        serial2mem_opa_valid_i        =  counter_out_opA < WINDOW;
        serial2mem_opb_valid_i        =  counter_out_opA  >=  WINDOW && counter_out_opA  < 2*WINDOW;
        serial2mem_opa_rw             = 0;  
        serial2mem_opb_rw             = 0;  
        serial2mem_opa_rready_i       = counter_out_opA >= 3*SIZE-1+5;
        serial2mem_opb_rready_i       = counter_out_opA >= 3*SIZE-1+5;  
        u_im2row_data_valid_i         = counter_out_opA < WINDOW;
        u_im2row_downstream_ready_i   = counter_out_systolic_read_mem >= 3*SIZE-1+5;
        mem2serial_rready_i           = 0;
        syst_rready_i                 = serial2mem_opa_rvalid_o && serial2mem_opb_rvalid_o;
        uart_ready_rx_out             = counter_out_opA < 2*WINDOW;
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
        serial2mem_ops_in_data = axi_debug;
    end
    SEND_FPGA2DMA:begin
        s_axis_tlast= 0;

        serial2mem_opa_rw             = 0;  
        serial2mem_opb_rw             = 0;
          
        syst_rready_i                 = (counter_out_send_fpga2host >= 3*SIZE-1 +5);

       
        


        syst_valid_i                  = 1;
  
        uart_valid_tx_in              = 1;
        fsm_unit_control_next         = counter_out_pipeline_emptying < 3*(3*SIZE-1+5) ? SEND_FPGA2DMA : IDLE;
        starting_frame_identified     = 0;

  
        if(ena_out_pipeline_emptying)begin
            ena_mem_write_counter         = counter_out_pipeline_emptying < 0*(3*SIZE-1+5);
            ena_out_img2row               = counter_out_pipeline_emptying < 1*(3*SIZE-1+5);
            ena_mem_read_systolic_counter = counter_out_pipeline_emptying < 2*(3*SIZE-1+5);
            ena_send2host_counter         = counter_out_pipeline_emptying < 3*(3*SIZE-1+5);
            
            serial2mem_opa_valid_i        =  0;
            serial2mem_opb_valid_i        =  0;
            u_im2row_data_valid_i         = counter_out_pipeline_emptying < 1*(3*SIZE-1+5);
            uart_ready_rx_out             = 0;
            
            mem2serial_valid_i            = 1 ;
            mem2serial_rready_i           =  counter_out_pipeline_emptying == 0*(3*SIZE-1+5)||
                                             counter_out_pipeline_emptying == 1*(3*SIZE-1+5)||
                                             counter_out_pipeline_emptying == 2*(3*SIZE-1+5)||
                                             counter_out_pipeline_emptying == 3*(3*SIZE-1+5);  
                                             
            serial2mem_opa_rready_i       = 1;
            serial2mem_opb_rready_i       = 1;  
        end else begin
            ena_mem_write_counter         = 1;
            ena_out_img2row               = 1;
            ena_mem_read_systolic_counter = 1;
            ena_send2host_counter         = 1;
            serial2mem_opa_valid_i        =  (counter_out_opA < WINDOW) ;
            serial2mem_opb_valid_i        =  (counter_out_opA  >=  WINDOW && counter_out_opA  < 2*WINDOW) ;
            u_im2row_data_valid_i         = counter_out_opA < WINDOW;
            uart_ready_rx_out             = counter_out_opA < 2*WINDOW;
            mem2serial_valid_i            = counter_out_systolic_read_mem <  SIZE;
            
            mem2serial_rready_i           = (counter_out_send_fpga2host >= 3*SIZE-1 +5) ;  
            serial2mem_opa_rready_i       = counter_out_opA == 3*SIZE-1+5;
            serial2mem_opb_rready_i       = counter_out_opA == 3*SIZE-1+5;  
        end
        fsm_pipeline_next_s1          = WRITE_P;
        fsm_pipeline_next_s2          = EXEC_P;
        fsm_pipeline_next_s3          = SEND2HOST_P;
        fsm_pipeline_next_s4          = EXEC_I;
        serial2mem_ops_in_data        = stop_pipeline ? 0 : axi_debug ;
        u_im2row_downstream_ready_i   = counter_out_systolic_read_mem == (3*SIZE-1+5);

    end
    default:begin
        serial2mem_opa_rw             = 0;
        serial2mem_opb_rw             = 0;
        serial2mem_opa_rready_i       = 1;
        serial2mem_opb_rready_i       = 1;
        mem2serial_rready_i           = 1;
        syst_rready_i                 = 1;  
        u_im2row_downstream_ready_i   = 0; 
        uart_valid_tx_in              = 0;        
        syst_valid_i                  = 0; 
        mem2serial_valid_i            = 0; 
       
        starting_frame_identified     = 1;
        s_axis_tlast =0;
        if(start_pipeline) begin //Verifcado
        //if(uart_valid_rx_in && uart_ready_rx && frame_start[15:0] == 16'hffff) begin // Dump
        //if(uart_valid_rx_in && uart_ready_rx && frame_start[15:0] == 16'hffff) begin
                fsm_unit_control_next    =WRITE_MEM;
                serial2mem_opb_valid_i   =0;
                serial2mem_opa_valid_i   =0;
                s_axis_tlast             =0;
                

        end else begin
                serial2mem_opb_valid_i  =0;
                fsm_unit_control_next   =IDLE;
                serial2mem_opa_valid_i  =0;
                s_axis_tlast            =0;
        end
        ena_mem_write_counter           =0;
        ena_mem_read_systolic_counter   =0;
        ena_send2host_counter           =0;
        ena_out_img2row                 =0;

        uart_ready_rx_out   = 1;
            

        
            
        fsm_pipeline_next_s1            =IDLE_W; 
        fsm_pipeline_next_s2            =IDLE_E;
        fsm_pipeline_next_s3            =IDLE_S;
        fsm_pipeline_next_s4            =IDLE_I;


        u_im2row_data_valid_i           =0;  

        serial2mem_ops_in_data = 0;
        

    end
endcase

logic next_ena_out_pipeline_emptying;
logic [1:0] next_pipeline_empting;
logic [1:0] pipeline_empting;
always_ff@(posedge clock, negedge rst_n_async)begin

    if(!rst_n_async)begin
        pipeline_empting <=0;
        ena_out_pipeline_emptying <= 0;
    end else begin
        if(pipeline_empting ==1)begin
            ena_out_pipeline_emptying <= 1;
        end else begin
            ena_out_pipeline_emptying <= 0;
        end
        pipeline_empting <= next_pipeline_empting;
    end
end 



always_comb begin
    case(pipeline_empting)
        0: next_pipeline_empting = stop_pipeline ? 1 : 0;
        1: next_pipeline_empting = counter_out_pipeline_emptying < 3*(3*SIZE-1+5) ? 1 : 0;
    endcase
end

assign clean_counter_all = fsm_unit_control == IDLE;
counter#(.MAX_COUNTER(MAX_COUNTER_STAGES)) counter_opA(
        .clock          (clock),
        .rst_n_async    (rst_n_async),
        .ena            (ena_mem_write_counter),
        .counter        (counter_out_opA),
        .clean          (counter_out_opA >= 3*SIZE-1+5 || clean_counter_all)
);

counter#(.MAX_COUNTER(MAX_COUNTER_STAGES)) counter_read_mem(

        .clock          (clock),
        .rst_n_async    (rst_n_async),
        .ena            (ena_mem_read_systolic_counter),
        .counter        (counter_out_systolic_read_mem),
        .clean          (counter_out_systolic_read_mem >= 3*SIZE-1+5 || clean_counter_all)
);

counter#(.MAX_COUNTER(MAX_COUNTER_STAGES)) counter_write_mem(
        .clock          (clock),
        .rst_n_async    (rst_n_async),
        .ena            (ena_send2host_counter),
        .counter        (counter_out_send_fpga2host),
        .clean          (counter_out_send_fpga2host >= 3*SIZE-1+5 || clean_counter_all)
);

counter#(.MAX_COUNTER(MAX_COUNTER_STAGES)) counter_img2row(
        .clock          (clock),
        .rst_n_async    (rst_n_async),
        .ena            (ena_out_img2row),
        .counter        (counter_out_img2row),
        .clean          (counter_out_img2row >= 3*SIZE-1+5 || clean_counter_all)
);

counter#(.MAX_COUNTER(MAX_COUNTER_STAGES*4)) counter_pipeline_emptying(
        .clock          (clock),
        .rst_n_async    (rst_n_async),
        .ena            (ena_out_pipeline_emptying),
        .counter        (counter_out_pipeline_emptying),
        .clean          (counter_out_pipeline_emptying >= 3*(3*SIZE-1+5) || clean_counter_all)
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

assign sampling_pipeline_stage_1_mem_write = counter_out_opA == 3*SIZE-1+5;                  
assign sampling_pipeline_stage_2_img2row   = counter_out_img2row == 3*SIZE-1+5;              
assign sampling_pipeline_stage_3_systolic  = counter_out_systolic_read_mem == 3*SIZE-1+5;    
assign sampling_pipeline_stage_4_send2host = counter_out_send_fpga2host == 3*SIZE-1+5;       
/*
assign sampling_pipeline_stage_1_mem_write = sampling_pipeline_stage_1_mem_write_reg;
assign sampling_pipeline_stage_2_img2row = sampling_pipeline_stage_2_img2row_reg;
assign sampling_pipeline_stage_3_systolic = sampling_pipeline_stage_3_systolic_reg;
assign sampling_pipeline_stage_4_send2host = sampling_pipeline_stage_4_send2host_reg;
*/
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
	.probe8(axi_debug), // input wire [7:0]  probe3
	.probe9(perf_counter1) // input wire [7:0]  probe3
);


logic [63:0]perf_counter1;
logic [63:0]perf_counter2;
logic [63:0]perf_counter3;
logic [63:0]perf_counter4;

always_ff@(posedge clock, negedge rst_n_async)begin
    if(!rst_n_async)begin  
            perf_counter1 <= 0;
            perf_counter2 <= 0;
            perf_counter3 <= 0;
            perf_counter4 <= 0;
    end else begin
        if(ena_mem_write_counter || ena_out_img2row || ena_mem_read_systolic_counter || ena_mem_write_counter)begin
            perf_counter1 <= perf_counter1 + 1;
        end else begin
            perf_counter1 <= (perf_counter1 == perf_counter4) ?   0:perf_counter1;
        end
        
        perf_counter2 <= perf_counter1;
        perf_counter3 <= perf_counter2;
        perf_counter4 <= perf_counter3;
    end 

end


endmodule


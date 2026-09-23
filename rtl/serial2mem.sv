module serial2mem#(
    parameter WIDTH = 4,
    parameter SIZE = 128
)(
    input  logic                  clock                                      ,
    input  logic                  uart_ready_rx_out                          ,  
    input  logic                  rst_n_async                                     ,// r=1,w=0
    input  logic                  rw                                         , //Dado válido na entrada
    input  logic                  valid_i                                    , //Dado válido na entrada
    input  logic                  rready_i                                   , //Pronto para receber uma resposta
    output logic                  rvalid_o                                   , //Resposta Válida(Operação concluida)
    output logic                  ready_o                                    , //Pronto para receber um dado valido na entrada
    input  logic [WIDTH*SIZE-1:0]      in_data                                    ,//*******ATENÇÂO REPARAMETRIZE**********
    output logic [WIDTH-1:0] out_data[SIZE-1:0][SIZE-1:0]                                   ,
    output logic [WIDTH*SIZE-1:0] single_port_ram_di                        
   // output logic [(2*WIDTH-1)*SIZE*SIZE-1:0]    fifo_d                          
);
(* ram_style = "distributed" *)
logic [WIDTH-1:0] out_data_reg[SIZE-1:0][SIZE-1:0]  ;
logic [(2*SIZE)-1:0]      cnt, next_cnt                                   ;
logic [(2*SIZE)-1:0]  cnt_shift, next_cnt_shift                       ;
enum {IDLE, WRITE, READ,DONE}   mem_fsm,next_mem_fsm                            ;
//logic                           single_port_ram_clock                           ;
//logic                           single_port_ram_clockb                           ;
//logic                           single_port_ram_rst_n_async                          ;
logic                           single_port_ram_en                              ;
//logic                           single_port_ram_we                              ;
//logic [(2*SIZE)-1:0]    single_port_ram_addr                            ;
logic next_sampling_window_debug;

logic [$clog2(SIZE)-1:0] i_counter, j_counter;
logic [$clog2(SIZE)-1:0] next_i_counter, next_j_counter;


logic [WIDTH*SIZE-1:0] temp;
logic clock_sample;


always_ff@(posedge clock, negedge rst_n_async)begin
    if(!rst_n_async)begin
        clock_sample <= 0;
      //  out_data <='{default:0};
    end else begin
        clock_sample <= ~clock_sample;
       // out_data <=(cnt_shift == SIZE-1) ? out_data_reg: out_data ;
    
    end 
    
end
 
 assign out_data  =out_data_reg ;
//logic [WIDTH-1:0] data_out_lin[SIZE-1:0][SIZE-1:0];
//logic [WIDTH*SIZE-1:0] delay_1_cyclo;
   logic  [WIDTH*SIZE-1:0] single_port_ram_di_reg;
   logic  [WIDTH*SIZE-1:0] single_port_ram_di_reg_0;
    always_ff@(posedge clock, negedge rst_n_async)begin
        if(!rst_n_async)begin
            cnt                 <= 0                                                                                                           ;
            cnt_shift           <= 0                                                                                                           ;
            single_port_ram_di <= 0;

            single_port_ram_di_reg <='{default:0};
            out_data_reg <= '{default:0};
            single_port_ram_di_reg_0 <= '{default:0};
            mem_fsm <= IDLE;
            j_counter <= 0;
        end else begin        
            mem_fsm            <= next_mem_fsm                                                                                                 ;
            cnt                <= mem_fsm != DONE ? next_cnt         :    0                                                                    ;
            cnt_shift          <= mem_fsm != DONE ? next_cnt_shift   :    0                                                                    ;
            single_port_ram_di_reg_0 <= valid_i ?   in_data:single_port_ram_di_reg_0;
            {<<(WIDTH){out_data_reg[j_counter]}} <= mem_fsm != WRITE ?  temp:single_port_ram_di_reg_0;
            i_counter               <=  mem_fsm == WRITE? next_i_counter: 0;                                           ; 
            j_counter               <=  mem_fsm == WRITE? next_j_counter: 0;

        end
    end
            
assign             temp = {<<(WIDTH){out_data_reg[j_counter]}};
    always_comb case(mem_fsm)
        IDLE:begin
            ready_o         = 1                                ;
            rvalid_o        = 0                                ;
            next_sampling_window_debug =0;
            if(valid_i)begin                        
                if(rw)begin
                        next_mem_fsm             = READ        ;
                        next_cnt                 = 0           ;
                        next_cnt_shift           = 0           ;
                        single_port_ram_en       = 1           ;
                        next_j_counter = 0;


                end else  begin
                        next_mem_fsm          =  WRITE        ;
                        next_cnt              = 0             ;
                        next_cnt_shift        = 0             ;
                        single_port_ram_en    = 0             ;
                        next_j_counter = j_counter +1 ;

                end
            end else begin                          
                        next_mem_fsm         = IDLE         ;
                        next_cnt             = 0            ;
                        next_cnt_shift       = 0            ;
                        single_port_ram_en   = 0            ;

            end

         next_j_counter = 0;
         next_i_counter = 0; 
        end
        WRITE:begin
            next_sampling_window_debug =1;
            ready_o                  = 0;
            rvalid_o                 = 0;
            next_cnt                 = uart_ready_rx_out ? (cnt_shift == SIZE-1 ? cnt + 1: cnt):cnt                        ;
            next_cnt_shift           = uart_ready_rx_out ? cnt_shift + 1: cnt_shift;
            next_mem_fsm             =  cnt_shift != SIZE-1 ? WRITE: DONE;    
            single_port_ram_en       = 1                                     ;
            next_j_counter         =    (j_counter < SIZE  -1 )   ? j_counter +1 : j_counter;
            next_i_counter         =    (j_counter < SIZE -1)   ? i_counter:i_counter+1  ;
            single_port_ram_di_reg = in_data;

        end
        READ:begin
            next_sampling_window_debug =0;
            ready_o        = 0                                                                   ;
            rvalid_o       = cnt!=SIZE-1 ? 0 : 1                                               ;
            next_cnt       = cnt + 1                                                             ;
            next_mem_fsm   = cnt!=SIZE-1 ? READ: DONE                                          ;
            next_cnt_shift = cnt                                                                   ; 
            single_port_ram_en       =1;
            next_j_counter = 0;
            next_i_counter = 0; 

        end
        DONE:begin  
        next_sampling_window_debug =0;
            ready_o                  = 0                                                         ;
            rvalid_o                 = 1                                                         ;
            next_cnt                 = 0                                                         ;
            next_mem_fsm             = rready_i ? IDLE : DONE                                    ;
            next_cnt_shift           = 0                                                         ;
            single_port_ram_en       =0 ;
            next_j_counter = 0;
            next_i_counter = 0; 

        end
        default:begin
        next_sampling_window_debug =0;
            next_mem_fsm = IDLE;
            ready_o         = 1                     ;
            rvalid_o        = 0                     ;
            next_cnt        = 0                     ;
            next_cnt_shift =  0                     ;
          //  out_data       =  0                     ;
           // single_port_ram_di       = 0  ;
            single_port_ram_en       = 0;
            next_j_counter = 0;
            next_i_counter = 0; 

        end
    endcase

enum {IDLE_PIPELINE,WRITE_PIPELINE} fsm_pipeline, fsm_pipeline_next;

always_ff@(posedge clock, negedge rst_n_async)begin
    if(!rst_n_async)fsm_pipeline <= IDLE_PIPELINE;
    else fsm_pipeline <= mem_fsm == IDLE   ?   IDLE_PIPELINE: WRITE_PIPELINE;
end

endmodule
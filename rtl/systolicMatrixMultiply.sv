//============================================================
// Nome do Bloco    : SystolicMatrixMultiply + Serial + Handshake
// Versão           : 2.5
// Autor(a)         : Valmir Ferreira
// Data de Criação  : 24/10/2024
// Última Modificação: 01/02/2025
//
// Descrição:
//   Dada duas matrizes de ordem N, M1 e M2 cálcula a multplicação matricial. Serializando às matrizes de entrada;
//============================================================

module systolicMatrixMultiply#(
    parameter WIDTH = 8 , SIZE=16, WIDTHx = 4
)(
    input  logic                    clock                                  ,
    input  logic                    rst_n_async                                 ,
    input  logic                    valid_i                                , //Dado válido na entrada
    input  logic                    rready_i                               , //Pronto para receber uma resposta                                                
    input  logic [WIDTHx-1:0]       a_input [SIZE-1:0]                        	   ,
    input  logic [WIDTHx-1:0]       b_input [SIZE-1:0]                        	   ,
    output logic                    rvalid_o                               , //Resposta Válida(Operação concluida)
    output logic                    ready_o                                , //Pronto para receber um dado valido na entrada
    output logic                    read_done                              ,           
   (*dont_touch = "true"*)  output logic [WIDTH-1:0]        output_produc_a_b [SIZE-1:0][SIZE-1:0],
   output logic ena_shift_data
);

logic ena_mac;
logic [$clog2(2*SIZE) :0]       counter_mult        , next_counter_mult                 ;
logic [$clog2(2*SIZE) :0]       counter_transfer_m  , next_counter_transfer_m           ;
(* ram_style = "distributed" *)
logic [WIDTH-1:0]                       produc_a_b      [SIZE-1:0][SIZE-1:0]            ;

(* ram_style = "distributed" *) 
logic [WIDTHx-1:0]                      a_vec           [SIZE-1:0][SIZE-1:0]            ;
(* ram_style = "distributed" *) 
logic [WIDTHx-1:0]                      b_vec           [SIZE-1:0][SIZE-1:0]            ;
(* ram_style = "distributed" *) 

logic [WIDTHx-1:0]                 a_load[SIZE-1:0]                                          ;
(*dont_touch = "true"*) 
logic [WIDTHx-1:0]                 b_load[SIZE-1:0]                                          ;
logic                                    next_ena_mac,ena_shift_data_next                           ;

(*dont_touch = "true"*) 
enum {IDLE, LOAD_MULTI_MATRIX ,MULTI_MATRIX, DONE} currentStateSystolicControlUnit, nextStateSystolicControlUnit;
generate 
    genvar i,j;
        for(i =0; i < SIZE;i++)begin:CELULA_ROWS
            (*dont_touch = "true"*) 
            assign a_vec[0][i] = a_load[i];
           
            (*dont_touch = "true"*) 
            assign b_vec[0][i] = b_load[i];
            for(j =0; j < SIZE;j++)begin:CELULA_COLUMNS
               (*dont_touch = "true"*) 
                accumulator_cells #(.WIDTH(WIDTH),.WIDTHx(WIDTHx)) MAC(    
                    .clock         (     clock                                              ),
                    .rst_n_async   (     rst_n_async                                        ),
                    .ena           (     ena_mac                                            ),
                    .a             (     a_vec[i][j]                                        ),
                    .b             (     b_vec[j][i]                                        ),
                    .x             (     a_vec[i+1][j]                                      ), 
                    .y             (     b_vec[j+1][i]                                      ),
                    .z             (     produc_a_b[SIZE-j-1][SIZE-i-1]                     )
                );
            end
        end

endgenerate

always_ff@(posedge clock, negedge rst_n_async)begin
    if(!rst_n_async)begin
        currentStateSystolicControlUnit <= IDLE;
        counter_mult                    <=    0;
        counter_transfer_m              <=    0;
        ena_mac                         <=    0;
        a_load                          <= '{default:0};
        b_load                          <= '{default:0};
        output_produc_a_b               <= '{default:0};

    end else begin
        counter_transfer_m              <= next_counter_transfer_m                                               ;
        if(ena_mac)begin
            output_produc_a_b               <= produc_a_b                          ;
        end else 
            output_produc_a_b               <=   output_produc_a_b                           ;

        currentStateSystolicControlUnit <= nextStateSystolicControlUnit                                        ;
        counter_mult                    <= next_counter_mult                                                   ; 
        ena_mac                         <= next_ena_mac                                                        ;
        ena_shift_data <= ena_shift_data_next;
        a_load                          <= currentStateSystolicControlUnit == LOAD_MULTI_MATRIX ? a_input: '{default:0}   ;
        b_load                          <= currentStateSystolicControlUnit == LOAD_MULTI_MATRIX ? b_input: '{default:0}   ;
    end
end
always_comb begin
    case(currentStateSystolicControlUnit)
        IDLE:begin
            ready_o                      = 1                                                                    ;
            rvalid_o                     = 0                                                                    ;
            nextStateSystolicControlUnit = valid_i ? LOAD_MULTI_MATRIX : IDLE                                   ;
            next_counter_mult            = 0                                                                    ;
            next_ena_mac                 = 0                                                                    ;
            next_counter_transfer_m      = 0                                                                    ;
            read_done                    = 1                                                                    ;
            ena_shift_data_next  = 0;
        end
       LOAD_MULTI_MATRIX:begin
            ready_o                      = 0;
            rvalid_o                     = 0;
            nextStateSystolicControlUnit = (counter_transfer_m < 2*SIZE+1) ? LOAD_MULTI_MATRIX :MULTI_MATRIX    ;
            next_counter_transfer_m      = counter_transfer_m  +    1                                           ;                  
            next_counter_mult            = 0                                                                    ;
            next_ena_mac                 = 1                                                                    ;     
            read_done                    = 0                                                                    ;
            ena_shift_data_next               =1;
        end
        MULTI_MATRIX:begin
            ready_o                      = 0                                                                   ;
            rvalid_o                     = 0                                                                   ;
            nextStateSystolicControlUnit = (counter_mult < SIZE) ? MULTI_MATRIX : DONE                         ;
            next_counter_transfer_m      = 0                                                                   ;                  
            next_counter_mult            = counter_mult + 1'b1                                                 ;
            next_ena_mac                 = (counter_mult < SIZE) ? 1:0                                         ;
            read_done                    = 1                                                                   ;
            ena_shift_data_next = 1;
            
        end
        DONE:begin
            ready_o  = 0                                                                                       ;
            rvalid_o = 1                                                                                       ;
            nextStateSystolicControlUnit = rready_i ?  IDLE:DONE                                               ;
            next_counter_mult            = 0                                                                   ;
            next_counter_transfer_m      = 0                                                                   ;                  
            next_ena_mac                 = 0                                                                   ;
            read_done                    = 1                                                                   ;
            ena_shift_data_next = 0;
        end
        default:begin
            nextStateSystolicControlUnit = IDLE;
            ready_o                      = 1                                                                    ;
            rvalid_o                     = 0                                                                    ;
            next_counter_mult            = 0                                                                    ;
            next_ena_mac                 = 0                                                                    ;
            next_counter_transfer_m      = 0                                                                    ;
            read_done                    = 1                                                                    ;
            ena_shift_data_next = 0;
        end
    endcase
end
endmodule
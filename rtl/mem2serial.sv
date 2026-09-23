module mem2seriala#(parameter SIZE=32,WIDTH=8,BYTESIZES =256)(
    input  logic             clock                           ,
    input  logic             rst_n_async                          ,
    (*dont_touch = "true"*) 
    input  logic [WIDTH-1:0] pmatrix_in  [SIZE-1:0][SIZE-1:0]    ,
    input  logic valid_i                                     , //Dado válido na entrada
    input  logic rready_i                                    , //Pronto para receber uma resposta
    output logic rvalid_o                                    , //Resposta Válida(Operação concluida)
    output logic ready_o                                     , //Pronto para receber um dado valido na entrada
    (*dont_touch = "true"*) 
    output logic [BYTESIZES-1:0]      smatrix_out                ,
    input logic event_send_data                              ,
    output logic m_axis_tlast ,
    output logic uart_valid_tx_in
);


logic [BYTESIZES-1:0]      smatrix_out1                ;
enum {IDLE_INDEX,COUNTER_INDEX,DONE_INDEX} mem2seriala_fsm,next_mem2seriala_fsm;
logic [$clog2(SIZE)-1:0] i_counter, j_counter;
logic [$clog2(SIZE*SIZE)-1:0] k_counter_clock_base;
logic [$clog2(SIZE*SIZE)-1:0] next_k_counter_clock_base;


logic [$clog2(SIZE*SIZE)-1:0] k_counter_clock_slow;
logic [$clog2(SIZE*SIZE)-1:0] next_k_counter_clock_slow;
logic [$clog2(SIZE)-1:0] next_i_counter, next_j_counter;


/*
ref_clock #(.CLOCK_REF(500),.CLOCK_INPUT(100_000_000))clock_rate_pc(
    .in_clock     (clock                                   )                ,
    .rst_n_async       (rst_n_async                                  )                ,
    .out_clock_ref(clockk                                  )                
);
*/


wire handshake;
assign handshake = uart_valid_tx_in && event_send_data;
logic [WIDTH-1:0]      smatrix_out2                ;

/*
always @(posedge clock or negedge rst_n_async) begin
    if (!rst_n_async) begin
        //smatrix_out  <= 32'd0;
        m_axis_tlast <= 0;
    end else begin
        //m_axis_tlast <= smatrix_out1 == 254;
        if (handshake) begin
            if (smatrix_out1 == 255) begin
                //smatrix_out <=0;
                //m_axis_tlast = 1;
            end else begin
               // smatrix_out <= smatrix_out1;
                //m_axis_tlast <= next_k_counter_clock_base == 32;
            end
        end
    end
end*/
assign smatrix_out = smatrix_out1;
  
/*
ila_1 your_instance_name2 (
	.clk(clock), // input wire clk


	.probe0(smatrix_out), // input wire [7:0]  probe0  
	.probe1(k_counter_clock_base), // input wire [7:0]  probe1 
	.probe2(j_counter), // input wire [7:0]  probe2 
	.probe3(smatrix_out1), // input wire [7:0]  probe3 
	.probe4(handshake), // input wire [0:0]  probe4 
	.probe5(m_axis_tlast), // input wire [0:0]  probe5 
	.probe6(event_send_data), // input wire [0:0]  probe6 
	.probe7(uart_valid_tx_in) // input wire [0:0]  probe7

);
*/

always_ff@(posedge clock, negedge rst_n_async)begin
    if(!rst_n_async)begin
        i_counter        <=0; 
        j_counter        <=0;
        mem2seriala_fsm <= IDLE_INDEX;
        k_counter_clock_base<=0;
        // smatrix_out <= 8'hff;
         //m_axis_tlast <= 0;
        // uart_valid_tx_in <= 0;
       // m_axis_tlast <= 0;
    end else begin
        i_counter               <=  next_i_counter                                             ; 
        j_counter               <=  next_j_counter                                             ;
        k_counter_clock_base    <= next_k_counter_clock_base                                   ;
        mem2seriala_fsm         <=  next_mem2seriala_fsm                                       ;
       // m_axis_tlast <= j_counter == 0 ||j_counter == 31;
       
    end        
end
//assign m_axis_tlast =j_counter == SIZE -1;
//Experimnetal
assign m_axis_tlast =j_counter == SIZE -2 || j_counter == SIZE -1 || j_counter == SIZE;


always_comb begin
    case(mem2seriala_fsm)
        IDLE_INDEX:begin
            ready_o = 1;
            rvalid_o = 0;
            next_mem2seriala_fsm = valid_i  ? COUNTER_INDEX: IDLE_INDEX;
            next_i_counter =0;
            next_j_counter =0;
            smatrix_out1  = valid_i ?'{default:8'hff}:'{default:8'h00};
            //m_axis_tlast = valid_i;
            next_k_counter_clock_base<=0;
            uart_valid_tx_in = 0;   // já começa válido
           

           //uart_valid_tx_in =0;
        end
        COUNTER_INDEX:begin
            uart_valid_tx_in =1;
            next_k_counter_clock_base<=handshake ? k_counter_clock_base+1:k_counter_clock_base ;
            ready_o = 0;
            rvalid_o = 0;
           // m_axis_tlast = 0;
            next_j_counter         =    handshake ? ((j_counter < SIZE   )   ? j_counter +1 : 0) : j_counter;
            next_i_counter         =    (j_counter < SIZE -1)   ? i_counter:i_counter+1  ;
            next_mem2seriala_fsm   =    ( j_counter >= SIZE-1) ? DONE_INDEX: COUNTER_INDEX;
            //(*dont_touch = "true"*) 
            //test     = {>>8{pmatrix_in[j_counter]}};
            smatrix_out1     = {>>(WIDTH){pmatrix_in[j_counter]}};
            //uart_valid_tx_in =1;
          //  m_axis_tlast =1;
        

        end
        DONE_INDEX:begin
         //   m_axis_tlast =1;
            uart_valid_tx_in =0;
            smatrix_out1  = '{default:8'hff};
            //smatrix_out1 = !rready_i ?  8'hff:0;
            ready_o = 0;
            rvalid_o = 1;
            next_mem2seriala_fsm = rready_i ? IDLE_INDEX : DONE_INDEX; 
            next_i_counter = 0;
            next_j_counter = 0;
            next_k_counter_clock_base<=0;
     
           // uart_valid_tx_in = 0;
        end
        default:begin
            uart_valid_tx_in =0; 
            smatrix_out1  = '{default:8'hff};
            next_mem2seriala_fsm = IDLE_INDEX;
            ready_o = 1;
            rvalid_o = 0;
           
            next_i_counter =0;
            next_j_counter =0;next_k_counter_clock_base<=0;
            //uart_valid_tx_in = 0;
        end
    endcase
end

/*
ila_1 your_instance_name (
	.clk(clock), // input wire clk


	.probe0(smatrix_out), // input wire [7:0]  probe0  
	.probe1(i_counter), // input wire [7:0]  probe1 
	.probe2(j_counter), // input wire [7:0]  probe2 
	.probe3(mem2seriala_fsm), // input wire [7:0]  probe3 
	.probe4(k_counter_clock_base), // input wire [0:0]  probe4 
	.probe5(rvalid_o), // input wire [0:0]  probe5 
	.probe6(event_send_data), // input wire [0:0]  probe6 
	.probe7(uart_valid_tx_in) // input wire [0:0]  probe7

);*/
//assign    smatrix_out     = pmatrix_in[i_counter][j_counter];


/*
ila_0 your_instance_name (
	.clk(clock), // input wire clk


	.probe0 (pmatrix_in[0][0]), // input wire [7:0]  probe0  
	.probe1 (pmatrix_in[0][1]), // input wire [7:0]  probe1 
	.probe2 (pmatrix_in[0][2]), // input wire [7:0]  probe2 
	.probe3 (pmatrix_in[0][3]), // input wire [7:0]  probe3 
	.probe4 (pmatrix_in[0][4]), // input wire [7:0]  probe4 
	.probe5 (pmatrix_in[0][5]), // input wire [7:0]  probe5 
	.probe6 (pmatrix_in[0][6]), // input wire [7:0]  probe6 
	.probe7 (pmatrix_in[0][7]), // input wire [7:0]  probe7 
	.probe8 (pmatrix_in[0][8]), // input wire [7:0]  probe8 
	.probe9 (pmatrix_in[0][9]), // input wire [7:0]  probe9 
	.probe10(pmatrix_in[0][0]), // input wire [7:0]  probe10 
	.probe11(pmatrix_in[1][0]), // input wire [7:0]  probe11 
	.probe12(pmatrix_in[2][0]), // input wire [7:0]  probe12 
	.probe13(pmatrix_in[3][0]), // input wire [7:0]  probe13 
	.probe14(pmatrix_in[4][0]), // input wire [7:0]  probe14 
	.probe15(pmatrix_in[5][0]), // input wire [7:0]  probe15 
	.probe16(pmatrix_in[6][0]), // input wire [7:0]  probe16 
	.probe17(pmatrix_in[7][0]), // input wire [7:0]  probe17 
	.probe18(pmatrix_in[8][0]), // input wire [7:0]  probe18 
	.probe19(pmatrix_in[9][0]), // input wire [7:0]  probe19 
	.probe20(pmatrix_in[9][0]), // input wire [7:0]  probe20 
	.probe21(j_counter), // input wire [7:0]  probe21 
	.probe22(k_counter_clock_base), // input wire [7:0]  probe22 
	.probe23(mem2seriala_fsm), // input wire [7:0]  probe23 
	.probe24(smatrix_out), // input wire [255:0]  probe24 
	.probe25(m_axis_tlast), // input wire [0:0]  probe25 
	.probe26(handshake), // input wire [0:0]  probe26 
	.probe27(uart_valid_tx_in), // input wire [0:0]  probe27 
	.probe28(rready_i), // input wire [0:0]  probe28 
	.probe29(rvalid_o), // input wire [0:0]  probe29 
	.probe30(ready_o), // input wire [0:0]  probe30 
	.probe31(m_axis_tlast), // input wire [0:0]  probe31 
	.probe32(m_axis_tlast), // input wire [0:0]  probe32 
	.probe33(m_axis_tlast), // input wire [0:0]  probe33 
	.probe34(m_axis_tlast), // input wire [0:0]  probe34 
	.probe35(m_axis_tlast), // input wire [0:0]  probe35 
	.probe36(m_axis_tlast), // input wire [0:0]  probe36 
	.probe37(m_axis_tlast) // input wire [0:0]  probe37
);

*/
endmodule

module shiftdata#(parameter SIZE=16, WIDTHx=4)(
    input  logic clock,
    input  logic rst_n_async,
    input  logic ena_shift,
    input  logic [WIDTHx-1:0] opa_out_data  [SIZE-1:0][SIZE-1:0],
    input  logic [WIDTHx-1:0] opb_out_data  [SIZE-1:0][SIZE-1:0],
    output logic [WIDTHx-1:0] flow_data_time_structure_OUTA [SIZE-1:0],
    output logic [WIDTHx-1:0] flow_data_time_structure_OUTB [SIZE-1:0]
);

logic [WIDTHx-1:0] flow_data_time_structure_OPA [SIZE-1:0];
logic [WIDTHx-1:0] flow_data_time_structure_OPB [SIZE-1:0];
logic [SIZE-1:0] counter;
logic [SIZE-1:0] counter_next;


logic ena_t;
assign counter_next=counter+1;
always_ff@(posedge clock,negedge rst_n_async)begin
    if(!rst_n_async)begin
        counter <= 0;
        flow_data_time_structure_OPA <= '{default:0};
        flow_data_time_structure_OPB <= '{default:0};

        ena_t <= 0;
    end else begin

        
        ena_t <= ena_shift;
        if(ena_shift) counter <= counter_next;
        else counter <= 0;
        
        if(counter < SIZE)begin
            for(int l =0; l < SIZE; l++)begin
                flow_data_time_structure_OPA[l] <= opa_out_data[counter][l];//counter > SIZE-1 ? 0 : A1[l][counter];
                flow_data_time_structure_OPB[l] <= opb_out_data[counter][l];//counter > SIZE-1 ? 0 : A2_t[l][counter];
                /*
                                flow_data_time_structure_OPA[l] <= counter >SIZE-1 ?'{default:0}: opa_out_data_reg[l][counter];//counter > SIZE-1 ? 0 : A1[l][counter];
                flow_data_time_structure_OPB[l] <= counter >SIZE-1 ?'{default:0}: opb_out_data_reg[counter][l];//counter > SIZE-1 ? 0 : A2_t[l][counter];
                */
            end
        end
    end
end

reg_bank #(.DATA_W(WIDTHx),.N_LANES(SIZE))opa_flow_data_time_structure(
    .clock  (clock),
    .rst_n_async (rst_n_async),
    .OP     (flow_data_time_structure_OPA ),
    .OUT    (flow_data_time_structure_OUTA),
    .ena    (ena_shift)

);

reg_bank #(.DATA_W(WIDTHx),.N_LANES(SIZE))opb_flow_data_time_structure(
    .clock  (clock ),
    .rst_n_async (rst_n_async),
    .OP     (flow_data_time_structure_OPB ),
    .OUT    (flow_data_time_structure_OUTB),
    .ena    (ena_shift)
);
endmodule
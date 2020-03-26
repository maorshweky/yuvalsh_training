//////////////////////////////////////////////////////////////////
///
/// Project Name: 	avalon_enforcer
///
/// File Name: 		avalon_enforcer.sv
///
//////////////////////////////////////////////////////////////////
///
/// Author: 		Yuval shpiro
///
/// Date Created: 	25.3.2020
///
/// Company: 		B"B
///
//////////////////////////////////////////////////////////////////
///
/// Description: 	a model that fix up a avalon st type msg
///
//////////////////////////////////////////////////////////////////



module avalon_enforcer 
(
	input logic clk,
	input logic rst,
	

	avalon_st_if.master  	trusted_msg, 
	avalon_st_if.slave 		untrusted_msg,

	output logic packet_didnt_started,
	output logic packet_in_packet
	
);

import enforcer_pack::*;

enforcer_sm_t    current_state;

logic					save_data = 1'b0;
assign 	untrusted_msg.rdy = trusted_msg.rdy; // setting up the untrusted rdy for the sm


always_ff @(posedge clk or negedge rst) begin
	if(~rst) begin
		current_state <= WAIT_FOR_SOP;
	end else begin
	    unique case (current_state)
				WAIT_FOR_SOP: begin //when we got a valid sop(only sop without eop) we move on
					if (trusted_msg.rdy & untrusted_msg.valid & untrusted_msg.sop & !untrusted_msg.eop ) begin
						current_state <= WAIT_FOR_EOP;
					end
				end
				WAIT_FOR_EOP: begin // when the packet ended(got valid eop) we move back to the begining
					if (trusted_msg.rdy & untrusted_msg.eop & untrusted_msg.valid ) begin
						current_state <= WAIT_FOR_SOP;
					end
				end	
		endcase
	end
end



always_comb begin


	unique if(current_state == WAIT_FOR_SOP) begin
		packet_in_packet = 0;
		packet_didnt_started =  !untrusted_msg.sop & untrusted_msg.valid; // when we dont got valid sop it will rise up the indication of the eror
		trusted_msg.sop = untrusted_msg.sop & untrusted_msg.valid; 
		save_data = untrusted_msg.sop & untrusted_msg.valid; // to make sure we  dint save the data if it out of packet
	end
	else if(current_state == WAIT_FOR_EOP) begin
		packet_in_packet = untrusted_msg.sop & untrusted_msg.valid; // when we got a valid eop it will rise up the inidctio of the eror
		packet_didnt_started = 0;
		trusted_msg.sop = 0;
		save_data = 1;
	end
end

always_comb begin

	unique if(save_data == 0) begin // situation of throwing up the data
		trusted_msg.eop   = 1'b0;
		trusted_msg.empty = 0;
		trusted_msg.data  = '0;
		trusted_msg.valid = 1'b0;
	end
	else if(save_data == 1)begin // keeping the data
		trusted_msg.eop = untrusted_msg.eop;
		trusted_msg.empty = untrusted_msg.empty & trusted_msg.eop;
		trusted_msg.data = untrusted_msg.data;
		trusted_msg.valid = untrusted_msg.valid;
	end
 
end

endmodule
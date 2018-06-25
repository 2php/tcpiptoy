module arp_resp
  (
   input wire 	     rx_clk,
   input wire 	     ip_pkt_end,
   input wire [15:0] ip_prot_type,
   
   input wire 	     clk,
   input wire 	     rst_n,
   input wire 	     tx_busy,

   output reg 	     tx_en,
   output reg [7:0]  txd 
   );

  //sync
  reg 		     arp_req_en;
  reg [1:0] 	     expand_cnt;
  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      arp_req_en <= 1'b0;
    else if(ip_pkt_end && ip_prot_type == 16'h0806)
      arp_req_en <= 1'b1;
    else if(expand_cnt == 2'b11)
      arp_req_en <= 1'b0;

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      expand_cnt <= 2'b0;
    else if(ip_pkt_end && ip_prot_type == 16'h0806)
      expand_cnt <= expand_cnt + 1'b1;
    else if(expand_cnt != 2'b0)
      expand_cnt <= expand_cnt + 1'b1;

  reg 		     arp_req_en_dly1;
  reg 		     arp_req_en_dly2;
  wire 		     arp_req_en_rising;
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      begin
	arp_req_en_dly1 <= 1'b0;
	arp_req_en_dly2 <= 1'b0;
      end
    else
      begin
	arp_req_en_dly1 <= arp_req_en;
	arp_req_en_dly2 <= arp_req_en_dly1;
      end

  assign arp_req_en_rising = arp_req_en_dly1 & ~arp_req_en_dly2;

  //arp RESPONSE
  reg [7:0] resp [0:71] = 
  {
   8'h55, 8'h55, 8'h55, 8'h55, 8'h55, 8'h55, 8'h55, 8'hd5, //preamble
   8'h6c, 8'h62, 8'h6d, 8'h80, 8'h27, 8'h01, //des mac addr, pc
   8'h00, 8'h0a, 8'h35, 8'h02, 8'h88, 8'h46, //src mac addr, fpga
   8'h08, 8'h06, //arp
   8'h00, 8'h01, //hardware type			 
   8'h08, 8'h00, //protocol type
   8'h06, 8'h04, //size
   8'h00, 8'h02, //opcode, response			 
   8'h00, 8'h0a, 8'h35, 8'h02, 8'h88, 8'h46, //sender mac
   8'hc0, 8'ha8, 8'h00, 8'hae, //sender ip
   8'h6c, 8'h62, 8'h6d, 8'h80, 8'h27, 8'h01, //rev mac			 
   8'hc0, 8'ha8, 8'h00, 8'haf, //rev ip
   8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, //dummy zero
   8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
   8'h00, 8'h00, 
   8'h43, 8'h50, 8'h76, 8'h14 //fcs			 
   };

//   reg [7:0] udp_data [0:1013] = 
// {
// // 8'h55, 8'h55, 8'h55, 8'h55, 8'h55, 8'h55, 8'h55, 8'hd5,
// // 8'hff, 8'hff, 8'hff, 8'hff, 8'hff, 8'hff, 8'h00, 8'h0a, 8'h35, 8'h02, 8'h88, 8'h46, 8'h08, 8'h00,
// // 8'h45, 8'h00, 8'h00, 8'h26, 8'h00, 8'h01, 8'h00, 8'h00, 8'h40, 8'h11, 8'hf7, 8'hc8, 8'hc0, 8'ha8,
// // 8'h00, 8'hae, 8'hc0, 8'ha8, 8'h00, 8'hff, 8'h03, 8'he8, 8'h04, 8'hd2, 8'h00, 8'h12, 8'h00, 8'h00,
// // 8'h01, 8'h02, 8'h03, 8'h04, 8'h05, 8'h06, 8'h07, 8'h08, 8'h09, 8'h0a, 8'h00, 8'h00, 8'h00, 8'h00,
// // 8'h00, 8'h00, 8'h00, 8'h00, 
// // 8'hd5, 8'ha6, 8'h26, 8'h8e
//  
//  
// //8'h55, 8'h55, 8'h55, 8'h55, 8'h55, 8'h55, 8'h55, 8'hd5, 
// //8'hff, 8'hff, 8'hff, 8'hff, 8'hff, 8'hff, 8'h00, 8'h0a, 8'h35, 8'h02, 8'h88, 8'h46, 8'h08, 8'h00,
// ////ip start
// //8'h45, 8'h00,
// //8'h00, 8'h2e, //ip len
// //8'h00, 8'h01, 8'h00, 8'h00, 8'h40, 8'h11,
// //8'hf7, 8'hc0, //ip head checksum
// //8'hc0, 8'ha8, 8'h00, 8'hae, 8'hc0, 8'ha8, 8'h00, 8'hff,
// ////udp start
// //8'h03, 8'he8, 8'h04, 8'hd2, //port
// //8'h00, 8'h1a, //udp len
// //8'h00, 8'h00, //checksum disabled
// //8'h01, 8'h02, 8'h03, 8'h04, 8'h05, 8'h06, 8'h07, 8'h08, 8'h09, 8'h0a,
// //8'h0b, 8'h0c, 8'h0d, 8'h0e, 8'h0f, 8'h10, 8'h11, 8'h12,
// //8'h5e, 8'h89, 8'hdc, 8'h49 //fcs
//  
//  
// 8'h55, 8'h55, 8'h55, 8'h55, 8'h55, 8'h55, 8'h55, 8'hd5,
// 8'hff, 8'hff, 8'hff, 8'hff, 8'hff, 8'hff, 8'h00, 8'h0a, 8'h35, 8'h02, 8'h88, 8'h46, 8'h08, 8'h00,
// //ip start
// 8'h45, 8'h00,
// 8'h00, 8'h30, //ip len
// 8'h00, 8'h01, 8'h00, 8'h00, 8'h40, 8'h11,
// 8'hf7, 8'hbe, //ip head checksum
// 8'hc0, 8'ha8, 8'h00, 8'hae, 8'hc0, 8'ha8, 8'h00, 8'hff,
// //udp start
// 8'h03, 8'he8, 8'h04, 8'hd2, //port
// 8'h00, 8'h1c, //udp len
// 8'h00, 8'h00, //checksum disabled
// 8'h01, 8'h02, 8'h03, 8'h04, 8'h05, 8'h06, 8'h07, 8'h08, 8'h09, 8'h0a,
// 8'h0b, 8'h0c, 8'h0d, 8'h0e, 8'h0f, 8'h10, 8'h11, 8'h12, 8'h13, 8'h14,
// 8'he7, 8'hba, 8'h66, 8'ha0 //fcs
//  
// };
  
  reg [2:0] arp_cs;
  reg [2:0] arp_ns;

  parameter IDLE  = 3'd0;
  parameter START = 3'd1;
  parameter WAIT  = 3'd2;
  parameter SEND  = 3'd3;
  //parameter WAIT2 = 3'd4;
  //parameter UDP   = 3'd5;
  //parameter DONE  = 3'd6;
  parameter DONE  = 3'd4;
  
  reg [9:0] arp_send_cnt;
  //reg [9:0] wait2_cnt;
  
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      arp_cs <= IDLE;
    else
      arp_cs <= arp_ns;

  always@(*)
    case(arp_cs)
      IDLE:
	if(arp_req_en_rising)arp_ns = START;
	else arp_ns = IDLE;
      START:
	arp_ns = WAIT;
      WAIT:
	if(!tx_busy)arp_ns = SEND;
	else arp_ns = WAIT;
      SEND:
	if(arp_send_cnt == 7'd71)arp_ns = DONE;
	else arp_ns = SEND;
      //SEND:
      // 	if(arp_send_cnt == 7'd71)arp_ns = WAIT2;
      // 	else arp_ns = SEND;
      //WAIT2:
      // 	if(wait2_cnt == 1000)arp_ns = UDP;
      // 	else arp_ns = WAIT2;
      //UDP:
      // 	if(arp_send_cnt == 10'd1013)arp_ns = DONE;
      // 	else arp_ns = UDP;
      DONE:
	arp_ns = IDLE;
      default:
	arp_ns = IDLE;
    endcase

  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      arp_send_cnt <= 10'd0;
    //else if(arp_cs == SEND || arp_cs == UDP)
    else if(arp_cs == SEND)
      arp_send_cnt <= arp_send_cnt + 1'b1;
    else
      arp_send_cnt <= 10'd0;

  //always@(posedge clk, negedge rst_n)
  //  if(!rst_n)
  //    wait2_cnt <= 10'd0;
  //  else if(arp_cs == WAIT2)
  //    wait2_cnt <= wait2_cnt + 1'b1;
  //  else
  //    wait2_cnt <= 10'd0;
 
  
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      begin
	tx_en <= 1'b0;
	txd <= 8'b0;
      end
    else if(arp_cs == SEND)
      begin
	tx_en <= 1'b1;
	txd <= resp[arp_send_cnt];
      end
    //else if(arp_cs == UDP)
    //  begin
    // 	tx_en <= 1'b1;
    // 	txd <= udp_data[arp_send_cnt];
    //  end      
    else
      begin
	tx_en <= 1'b0;
	txd <= 8'b0;
      end
  
  
endmodule // arp_resp

  

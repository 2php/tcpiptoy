module udp_rx_detect
  (
   input wire 	     rx_clk,
   input wire 	     ip_pkt_end,
   input wire [15:0] ip_prot_type,
   
   input wire 	     clk,
   input wire 	     rst_n,

   output reg 	     tcpip_init_done
   );

  //sync
  reg 		     arp_req_en;
  reg [1:0] 	     expand_cnt;
  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      arp_req_en <= 1'b0;
    else if(ip_pkt_end && ip_prot_type == 16'h0800)
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

  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      tcpip_init_done <= 1'b0;
    else
      tcpip_init_done <= arp_req_en_rising;
  
  
endmodule // udp_rx_detect

  

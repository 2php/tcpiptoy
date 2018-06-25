//
//unpack udp packet and merge fragment
//
module udp_unpack
  (
   input wire 	     rx_clk, //125Mhz
   input wire 	     rst_n,

   input wire [31:0] src_ip_addr,
   input wire [31:0] des_ip_addr,
   input wire [7:0]  trans_prot_type, //tcp = 8'h06, dup = 8'h11, etc.

   input wire 	     trans_pkt_start,
   input wire 	     trans_pkt_frag_start,
   input wire 	     trans_pkt_frag_end,
   input wire 	     trans_pkt_end,

   input wire [12:0] trans_pkt_frag_sft,
   input wire 	     trans_pkt_en,
   input wire [7:0]  trans_pkt_dat,

   output reg [15:0] src_port,
   output reg [15:0] des_port,

   output reg 	     udp_pkt_start,
   output reg 	     udp_pkt_en,
   output reg [7:0]  udp_pkt_dat,
   output reg 	     udp_pkt_end
   
   );

  reg [3:0] 	     pkt_cs;
  reg [3:0] 	     pkt_ns;

  parameter IDLE  = 4'd0;
  parameter HEAD  = 4'd1;
  parameter DATA  = 4'd2;
  parameter FRAG  = 4'd3;
  parameter DONE  = 4'd4;

  wire 		     st_idle;
  wire 		     st_head;
  wire 		     st_data;
  wire               st_frag;
  wire 		     st_done;

  reg [10:0] 	     byte_cnt;
  reg [15:0] 	     udp_pkt_len;

  reg 		     frag_en;
  
  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      pkt_cs <= IDLE;
    else
      pkt_cs <= pkt_ns;

  always@(*)
    case(pkt_cs)
      IDLE:
	if(trans_pkt_start && trans_prot_type == 8'h11)pkt_ns = HEAD;
	else pkt_ns = IDLE;
      HEAD:
	if(byte_cnt == 11'd7)pkt_ns = DATA;
	else pkt_ns = HEAD;
      DATA:
	if(byte_cnt == udp_pkt_len - 1'b1)pkt_ns = FRAG;
	else pkt_ns = DATA;
      FRAG:
	if(trans_pkt_end)pkt_ns = DONE;
	else if(trans_pkt_frag_start)pkt_ns = HEAD;
        else pkt_ns = FRAG;
      DONE:
	pkt_ns = IDLE;
      default:
	pkt_ns = IDLE;
    endcase

  assign st_idle = (pkt_cs == IDLE);
  assign st_head = (pkt_cs == HEAD);
  assign st_data = (pkt_cs == DATA);
  assign st_frag = (pkt_cs == FRAG);
  assign st_done = (pkt_cs == DONE);

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      byte_cnt <= 11'd0;
    else if(st_idle || st_frag)
      byte_cnt <= 11'd0;
    else if((st_head | st_data) && trans_pkt_en)
      byte_cnt <= byte_cnt + 1'b1;

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      src_port <= 16'b0;
    else if(st_head && byte_cnt == 11'd0)
      src_port[15:8] <= trans_pkt_dat;
    else if(st_head && byte_cnt == 11'd1)
      src_port[7:0] <= trans_pkt_dat;

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      des_port <= 16'b0;
    else if(st_head && byte_cnt == 11'd2)
      des_port[15:8] <= trans_pkt_dat;
    else if(st_head && byte_cnt == 11'd3)
      des_port[7:0] <= trans_pkt_dat;  

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      udp_pkt_len <= 16'b0;
    else if(st_head && byte_cnt == 11'd4)
      udp_pkt_len[15:8] <= trans_pkt_dat;
    else if(st_head && byte_cnt == 11'd5)
      udp_pkt_len[7:0] <= trans_pkt_dat;  

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      udp_pkt_start <= 1'b0;
    else if(st_head && (byte_cnt == 11'd0) && ~frag_en)
      udp_pkt_start <= 1'b1;
    else
      udp_pkt_start <= 1'b0;

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      udp_pkt_end <= 1'b0;
    else
      udp_pkt_end <= st_done;

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      begin
	udp_pkt_en <= 1'b0;
	udp_pkt_dat <= 8'b0;
      end
    else if(st_data)
      begin
	udp_pkt_en <= trans_pkt_en;
	udp_pkt_dat <= trans_pkt_dat;
      end
    else
      begin
	udp_pkt_en <= 1'b0;
	udp_pkt_dat <= 8'b0;
      end
  
  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      frag_en <= 1'b0;
    else if(st_idle)
      frag_en <= 1'b0;
    else if(st_frag && trans_pkt_frag_start)
      frag_en <= 1'b1;
  
endmodule // udp_unpack


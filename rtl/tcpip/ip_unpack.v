//
//unpack ip pkt and merge fragment
//
module ip_unpack
  (
   input wire 	     rx_clk, //125Mhz
   input wire 	     rst_n,

   //from mac
   input wire 	     ip_pkt_start,
   input wire 	     ip_pkt_en,
   input wire [7:0]  ip_pkt_dat,
   input wire 	     ip_pkt_end,

   input wire [47:0] des_mac_addr,
   input wire [47:0] src_mac_addr,
   input wire [15:0] ip_prot_type,

   //to tcp/udp
   output reg [31:0] src_ip_addr,
   output reg [31:0] des_ip_addr,
   output reg [7:0]  trans_prot_type, //tcp, dup, etc.
   
   output reg 	     trans_pkt_start,
   output reg 	     trans_pkt_frag_start,
   output reg [12:0] trans_pkt_frag_sft,
   output reg 	     trans_pkt_en,
   output reg [7:0]  trans_pkt_dat,
   output reg 	     trans_pkt_frag_end,
   output reg 	     trans_pkt_end
   
   );

  reg 		     ipv4;
  reg [3:0] 	     head_len;
  reg [15:0] 	     ip_pkt_len;

  reg [15:0] 	     mark;
  reg 		     mf; //more fragment
  reg 		     df; //dont fragment
  
  reg [7:0] 	     time_of_life;
  
  reg [3:0] 	     pkt_cs;
  reg [3:0] 	     pkt_ns;

  reg [11:0] 	     byte_cnt;
  reg 		     frag_sync;
  reg            is_bmp_pkt;
	 
  parameter IDLE  = 4'd0;
  parameter START = 4'd1;
  parameter HEAD  = 4'd2;
  parameter DATA  = 4'd3;
  parameter DONE  = 4'd4;

  wire 		     st_idle;
  wire 		     st_start;
  wire 		     st_head;
  wire 		     st_data;
  wire 		     st_done;
  
  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      pkt_cs <= IDLE;
    else
      pkt_cs <= pkt_ns;

  always@(*)
    case(pkt_cs)
      IDLE:
	if(ip_pkt_start && ip_prot_type == 16'h0800)
	  pkt_ns = START;
	else
	  pkt_ns = IDLE;
      START:
	pkt_ns = HEAD;
      HEAD:
	if(byte_cnt == ((head_len << 2) - 1))
	  pkt_ns = DATA;
	else
	  pkt_ns = HEAD;
      DATA:
        if(!is_bmp_pkt)pkt_ns = IDLE;
	else if(byte_cnt == ip_pkt_len - 1)
	  pkt_ns = DONE;
	else
	  pkt_ns = DATA;
      DONE:
	pkt_ns = IDLE;
      default:
	pkt_ns = IDLE;
    endcase

  assign st_idle  = (pkt_cs == IDLE ); 
  assign st_start = (pkt_cs == START); 
  assign st_head  = (pkt_cs == HEAD ); 
  assign st_data  = (pkt_cs == DATA ); 
  assign st_done  = (pkt_cs == DONE ); 

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      byte_cnt <= 11'd0;
    else if(st_idle)
      byte_cnt <= 11'd0;
    else if(ip_pkt_en)
      byte_cnt <= byte_cnt + 1'b1;

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      begin
	ipv4 <= 1'b0;
	head_len <= 4'd0;
      end
    else if(ip_pkt_en && byte_cnt == 11'd0)
      begin
	if(ip_pkt_dat[7:4] == 8'h4)ipv4 <= 1'b1;
	else ipv4 <= 1'b0;
	head_len <= ip_pkt_dat[3:0];
      end

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      ip_pkt_len <= 16'b0;
    else if(ip_pkt_en && byte_cnt == 11'd2)
      ip_pkt_len[15:8] <= ip_pkt_dat;
    else if(ip_pkt_en && byte_cnt == 11'd3)
      ip_pkt_len[7:0] <= ip_pkt_dat;


  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
	   is_bmp_pkt <= 1'b0;
	 else if(ip_pkt_len > 1024)
	   is_bmp_pkt <= 1'b1;
	 else 
	   is_bmp_pkt <= 1'b0;

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      mark <= 16'b0;
    else if(ip_pkt_en && byte_cnt == 11'd4)
      mark[15:8] <= ip_pkt_dat;
    else if(ip_pkt_en && byte_cnt == 11'd5)
      mark[7:0] <= ip_pkt_dat;

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      begin
	mf <= 1'b0;
	df <= 1'b0;
      end
    else if(ip_pkt_en && byte_cnt == 11'd6)
      begin
	mf <= ip_pkt_dat[7];
	df <= ip_pkt_dat[6];
      end

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)  
      trans_pkt_frag_sft <= 13'b0;
    else if(ip_pkt_en && byte_cnt == 11'd6)
      trans_pkt_frag_sft[12:8] <= ip_pkt_dat[4:0];
    else if(ip_pkt_en && byte_cnt == 11'd7)
      trans_pkt_frag_sft[7:0] <= ip_pkt_dat;

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)   
      time_of_life <= 8'b0;
    else if(ip_pkt_en && byte_cnt == 11'd8)
      time_of_life <= ip_pkt_dat;

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)     
      trans_prot_type <= 8'b0;
    else if(ip_pkt_en && byte_cnt == 11'd9)
      trans_prot_type <= ip_pkt_dat;

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      src_ip_addr <= 32'b0;
    else if(ip_pkt_en && byte_cnt == 11'd12)
      src_ip_addr[31:24] <= ip_pkt_dat;
    else if(ip_pkt_en && byte_cnt == 11'd13)
      src_ip_addr[23:16] <= ip_pkt_dat;
    else if(ip_pkt_en && byte_cnt == 11'd14)
      src_ip_addr[15:8] <= ip_pkt_dat;
    else if(ip_pkt_en && byte_cnt == 11'd15)
      src_ip_addr[7:0] <= ip_pkt_dat;

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      des_ip_addr <= 32'b0;
    else if(ip_pkt_en && byte_cnt == 11'd16)
      des_ip_addr[31:24] <= ip_pkt_dat;
    else if(ip_pkt_en && byte_cnt == 11'd17)
      des_ip_addr[23:16] <= ip_pkt_dat;
    else if(ip_pkt_en && byte_cnt == 11'd18)
      des_ip_addr[15:8] <= ip_pkt_dat;
    else if(ip_pkt_en && byte_cnt == 11'd19)
      des_ip_addr[7:0] <= ip_pkt_dat;

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      frag_sync <= 1'b0;
    else if(st_data && byte_cnt == (head_len << 2))
      frag_sync <= (~df & mf);
  
  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      begin
	trans_pkt_start <= 1'b0;
	trans_pkt_frag_start <= 1'b0;
	trans_pkt_en <= 1'b0;
	trans_pkt_dat <= 8'b0;
	trans_pkt_frag_end <= 1'b0;
	trans_pkt_end <= 1'b0;
      end
    else
      begin
	if(st_head && is_bmp_pkt && byte_cnt == ((head_len << 2) - 1) && ~frag_sync)
	  trans_pkt_start <= 1'b1;
	else
	  trans_pkt_start <= 1'b0;

	if(st_head && is_bmp_pkt && byte_cnt == ((head_len << 2) - 1) && frag_sync)
	  trans_pkt_frag_start <= 1'b1;
	else
	  trans_pkt_frag_start <= 1'b0;
	
	trans_pkt_en <= st_data;
	if(st_data)trans_pkt_dat <= ip_pkt_dat;
	if(frag_sync)trans_pkt_frag_end <= st_done;
	else trans_pkt_end <= st_done;
      end
  
endmodule // ip_unpack

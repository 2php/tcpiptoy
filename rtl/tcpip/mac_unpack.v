// data link layer
module mac_unpack
  (
   input wire 	     rst_n, //from sys
        
   //GMII/MII rx
   input wire 	     rx_clk, //125Mhz
   input wire 	     rx_dv, //receive data valid
   input wire 	     rx_er, //receive error
   input wire [7:0]  rxd, //receive data

   output reg 	     ip_pkt_start,
   output reg 	     ip_pkt_en,
   output reg [7:0]  ip_pkt_dat,
   output reg 	     ip_pkt_end,

   output reg [47:0] des_mac_addr,
   output reg [47:0] src_mac_addr,
   output reg [15:0] prot_type
   );

  //receive from physical layer & unpack
  reg [3:0]          unpack_cs;
  reg [3:0]          unpack_ns;

  parameter IDLE      = 4'd0;
  parameter DES_PHY_A = 4'd1;
  parameter SRC_PHY_A = 4'd2;
  parameter PROT_TYPE = 4'd3;
  parameter IP_LEN    = 4'd4;
  parameter IP_DAT    = 4'd5;
  parameter IP_DONE   = 4'd6;

  wire               st_idle;
  wire               st_des_phy_a;
  wire               st_src_phy_a;
  wire               st_prot_type;
  wire               st_ip_len;
  wire               st_ip_dat;
  wire               st_ip_done;
  
  reg                rx_dv_buf;
  reg [7:0]          rxd_buf;
  reg [3:0]          head_55_cnt;
  
  reg [10:0]         byte_cnt; //0~2047
  reg [10:0]         ip_pkt_len;
  

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      begin
        //rx_dv_buf <= 1'b0;
        rxd_buf <= 8'b0;
      end
    else if(rx_dv)
      begin
        //rx_dv_buf <= rx_dv;
        rxd_buf <= rxd;
      end

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      unpack_cs <= IDLE;
    else
      unpack_cs <= unpack_ns;

  always@(*)
    case(unpack_cs)
      IDLE:
        if(head_55_cnt == 4'd7 && rxd_buf == 8'hd5)
          unpack_ns = DES_PHY_A;
        else
          unpack_ns = IDLE;
      DES_PHY_A:
        if(byte_cnt == 11'd5)unpack_ns = SRC_PHY_A;
        else unpack_ns = DES_PHY_A;
      SRC_PHY_A:
        if(byte_cnt == 11'd5)unpack_ns = PROT_TYPE;
        else unpack_ns = SRC_PHY_A;
      PROT_TYPE:
        if(byte_cnt == 11'd1)unpack_ns = IP_LEN;
        else unpack_ns = PROT_TYPE;
      IP_LEN:
        if(byte_cnt == 11'd3)unpack_ns = IP_DAT;
        else unpack_ns = IP_LEN;
      IP_DAT:
	if(prot_type == 16'h0806)unpack_ns = IP_DONE;
	else if(byte_cnt == ip_pkt_len - 1)unpack_ns = IP_DONE;
        else unpack_ns = IP_DAT;
      IP_DONE:
        unpack_ns = IDLE;
      default:
        unpack_ns = IDLE;
    endcase

  assign st_idle      = (unpack_cs == IDLE     );
  assign st_des_phy_a = (unpack_cs == DES_PHY_A);
  assign st_src_phy_a = (unpack_cs == SRC_PHY_A);
  assign st_prot_type = (unpack_cs == PROT_TYPE);
  assign st_ip_len    = (unpack_cs == IP_LEN   );
  assign st_ip_dat    = (unpack_cs == IP_DAT   );
  assign st_ip_done   = (unpack_cs == IP_DONE  );

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      head_55_cnt <= 4'd0;
    else if(st_idle && rxd_buf == 8'h55)
      head_55_cnt <= head_55_cnt + 1'b1;
    else
      head_55_cnt <= 4'd0;

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      byte_cnt <= 11'd0;
    else if(st_idle || 
            (st_des_phy_a && byte_cnt == 11'd5) ||
            (st_src_phy_a && byte_cnt == 11'd5) ||
            (st_prot_type && byte_cnt == 11'd1) ||
	    st_ip_done)
      byte_cnt <= 11'd0;
    else
      byte_cnt <= byte_cnt + 1'b1;

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      ip_pkt_len <= 11'd0;
    else if(st_ip_len && byte_cnt == 11'd2)
      ip_pkt_len[10:8] <= rxd_buf;
    else if(st_ip_len && byte_cnt == 11'd3)
      ip_pkt_len[7:0] <= rxd_buf;

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      des_mac_addr <= 48'b0;
    else if(st_des_phy_a)
      begin
	if(byte_cnt == 11'd0)     des_mac_addr[47:40] <= rxd_buf;
	else if(byte_cnt == 11'd1)des_mac_addr[39:32] <= rxd_buf;
	else if(byte_cnt == 11'd2)des_mac_addr[31:24] <= rxd_buf;
	else if(byte_cnt == 11'd3)des_mac_addr[23:16] <= rxd_buf;
	else if(byte_cnt == 11'd4)des_mac_addr[15:8]  <= rxd_buf;
	else if(byte_cnt == 11'd5)des_mac_addr[7:0]   <= rxd_buf;
      end

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      src_mac_addr <= 48'b0;
    else if(st_src_phy_a)
      begin
	if(byte_cnt == 11'd0)     src_mac_addr[47:40] <= rxd_buf;
	else if(byte_cnt == 11'd1)src_mac_addr[39:32] <= rxd_buf;
	else if(byte_cnt == 11'd2)src_mac_addr[31:24] <= rxd_buf;
	else if(byte_cnt == 11'd3)src_mac_addr[23:16] <= rxd_buf;
	else if(byte_cnt == 11'd4)src_mac_addr[15:8]  <= rxd_buf;
	else if(byte_cnt == 11'd5)src_mac_addr[7:0]   <= rxd_buf;
      end

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      prot_type <= 16'b0;
    else if(st_prot_type)
      begin
	if(byte_cnt == 11'd0)     prot_type[15:8] <= rxd_buf;
	else if(byte_cnt == 11'd1)prot_type[7:0]  <= rxd_buf;
      end
  
  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      ip_pkt_start <= 1'b0;
    else if(st_prot_type && byte_cnt == 11'd1)
      ip_pkt_start <= 1'b1;
    else
      ip_pkt_start <= 1'b0;
  
  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      ip_pkt_en <= 1'b0;
    else if(st_ip_len || st_ip_dat)
      ip_pkt_en <= 1'b1;
    else
      ip_pkt_en <= 1'b0;

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      ip_pkt_dat <= 8'b0;
    else if(st_ip_len || st_ip_dat)
      ip_pkt_dat <= rxd_buf;
    else
      ip_pkt_dat <= 8'b0;

  always@(posedge rx_clk, negedge rst_n)
    if(!rst_n)
      ip_pkt_end <= 1'b0;
    else
      ip_pkt_end <= st_ip_done;
  
        
endmodule // mac_layer



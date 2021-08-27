library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity neopixel_v1_0 is
	generic (
		-- Users to add parameters here
        NUM_OF_LEDS	: natural	:= 4;
		DELAY_TIME	: natural	:= 5000;
		--COLOR_MODE  : string    := "RGB";
		
		-- User parameters ends
		-- Do not modify the parameters beyond this line


		-- Parameters of Axi Slave Bus Interface S00_AXI
		C_S00_AXI_DATA_WIDTH	: integer	:= 32;
		C_S00_AXI_ADDR_WIDTH	: integer	:= 4
	);
	port (
		-- Users to add ports here
        bitstream : out std_logic;
		-- User ports ends
		-- Do not modify the ports beyond this line


		-- Ports of Axi Slave Bus Interface S00_AXI
		s00_axi_aclk	: in std_logic;
		s00_axi_aresetn	: in std_logic;
		s00_axi_awaddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_awprot	: in std_logic_vector(2 downto 0);
		s00_axi_awvalid	: in std_logic;
		s00_axi_awready	: out std_logic;
		s00_axi_wdata	: in std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_wstrb	: in std_logic_vector((C_S00_AXI_DATA_WIDTH/8)-1 downto 0);
		s00_axi_wvalid	: in std_logic;
		s00_axi_wready	: out std_logic;
		s00_axi_bresp	: out std_logic_vector(1 downto 0);
		s00_axi_bvalid	: out std_logic;
		s00_axi_bready	: in std_logic;
		s00_axi_araddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_arprot	: in std_logic_vector(2 downto 0);
		s00_axi_arvalid	: in std_logic;
		s00_axi_arready	: out std_logic;
		s00_axi_rdata	: out std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_rresp	: out std_logic_vector(1 downto 0);
		s00_axi_rvalid	: out std_logic;
		s00_axi_rready	: in std_logic
	);
end neopixel_v1_0;

architecture arch_imp of neopixel_v1_0 is
    
    signal clock : std_logic;
    signal reset : std_logic;
    signal internal_enable : std_logic;
    
    signal led_idx   : unsigned(7 downto 0);
    signal led_color : std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
    
    type LED_VECT is array (0 to (NUM_OF_LEDS-1)) of std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
    signal led_reg : LED_VECT := ((others => (others =>'0')));
    
        ---- WRITE SIGNALS ----
    signal aw_transfer : std_logic;
    signal aw_ready : std_logic;

    signal w_transfer : std_logic;
    signal w_ready : std_logic;

    signal b_transfer : std_logic;
    signal b_valid : std_logic;
    
    ---- Write Register Address ----
    signal Write_RegAddress : std_logic_vector(1 downto 0);
    signal WriteEnable0         : std_logic;
    signal WriteEnable1        : std_logic;
    signal WriteEnable2        : std_logic;
    signal WriteEnable3        : std_logic;
    
    ---- READ SIGNALS ---- 
    signal ar_transfer : std_logic;
    signal ar_ready : std_logic;

    signal r_transfer : std_logic;
    signal r_valid : std_logic;
    
    ---- Read Register Address ----
    signal Read_RegAddress : std_logic_vector(1 downto 0);
    signal ReadEnable0     : std_logic;
    signal ReadEnable1     : std_logic;
    signal ReadEnable2     : std_logic;
    signal ReadEnable3     : std_logic;
    
    ---- REGISTER SIGNALS ----
    signal Register0    : std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);    -- register  00
    signal RegisterINDEX: std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);    -- register  01
    signal RegisterDATA : std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);    -- register  10
    signal Register3    : std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);    -- register  11 
    
	-- component declaration
	component npix_driver is
        generic ( NUM_OF_LEDS: natural := 4;
                  DELAY_TIME:  natural := 10000 ); 
        port ( data_in:     in std_logic_vector(23 downto 0);           -- data in RGB 
               clock:       in std_logic;                               -- expecting 100MHz clock
               enable:      in std_logic;
               --rdata_end:   out std_logic;                              -- read data finished
               led_idx:     out unsigned(7 downto 0);   -- return led index
               bitstream:   out std_logic );
    end component;
    
begin

    -- Add user logic here
    clock <= s00_axi_aclk;
    reset <= not s00_axi_aresetn;
    
    ---- WRITE ACCESS (control flow) ----
    s00_axi_awready <= aw_ready;
    s00_axi_wready  <= w_ready;
    s00_axi_bvalid  <= b_valid;
    s00_axi_bresp   <= "00"; -- always OK

    aw_transfer <= s00_axi_awvalid and aw_ready;
    w_transfer  <= s00_axi_wvalid  and w_ready;
    b_transfer  <= s00_axi_bready  and b_valid;

    aw_ready <= '1';  -- can always accept write address
    
    process(clock)  -- get register address from master
    begin
        if (rising_edge(clock)) then
            if (reset='1') then
                Write_RegAddress <= (others => '0');
            elsif (aw_transfer='1') then
                Write_RegAddress <= s00_axi_awaddr(3 downto 2); -- 4 registers; lower two bits are for byte-addressing and not used for 32-bit registers;
            end if;
        end if;
    end process;
    
    process(clock)  -- write transfer signals
    begin
        if (rising_edge(clock)) then
            if (reset='1') then
                w_ready <= '0';
            elsif (aw_transfer='1') then -- can accept data one cycle after address transfer
                w_ready <= '1';
            elsif (w_transfer='1') then
                w_ready <= '0';               
            end if;
        end if;
    end process;

    process(clock)  -- b_valid signal 
    begin
        if (rising_edge(clock)) then
            if (reset='1') then
                b_valid <= '0';
            elsif (w_transfer='1') then -- can acknowledge right after write transfer
                b_valid <= '1';
            elsif (b_transfer='1') then
                b_valid <= '0';
            end if;
        end if;
    end process;
    
    -- Write De-multiplexer
    WriteEnable0  <= '1' when (w_transfer='1' and Write_RegAddress="00") else '0';
    WriteEnable1  <= '1' when (w_transfer='1' and Write_RegAddress="01") else '0';
    WriteEnable2  <= '1' when (w_transfer='1' and Write_RegAddress="10") else '0';
    WriteEnable3  <= '1' when (w_transfer='1' and Write_RegAddress="11") else '0';
    
-- #########################################################################################################
    ---- READ ACCESS (control flow) ----
    s00_axi_arready <= ar_ready;
    s00_axi_rvalid  <= r_valid;
    s00_axi_rresp   <= "00"; -- always OK
    
    ar_transfer <= s00_axi_arvalid and ar_ready;
    r_transfer  <= s00_axi_rready  and r_valid;
    
    ar_ready <= '1';  -- can always accept read address

    process(clock)
    begin
        if (rising_edge(clock)) then
            if (reset='1') then
                Read_RegAddress <= (others => '0');
            elsif (ar_transfer='1') then
                Read_RegAddress <= s00_axi_araddr(3 downto 2); -- 4 registers; lower two bits are for byte-addressing and not used for 32-bit registers;
            end if;
        end if;
    end process;

    process(clock)
    begin
        if (rising_edge(clock)) then
            if (reset='1') then
                r_valid <= '0';
            elsif (ar_transfer='1') then -- can offer data one cycle after address transfer
                r_valid <= '1';
            elsif (r_transfer='1') then
                r_valid <= '0';
            end if;
        end if;
    end process;

    -- Read De-multiplexer
    ReadEnable0 <= '1' when (r_transfer='1' and Read_RegAddress="00") else '0';
    ReadEnable1 <= '1' when (r_transfer='1' and Read_RegAddress="01") else '0';
    ReadEnable2 <= '1' when (r_transfer='1' and Read_RegAddress="10") else '0';
    ReadEnable3 <= '1' when (r_transfer='1' and Read_RegAddress="11") else '0';
    
    -- Read Multiplexer - picks which register value to return
    with Read_RegAddress select
        s00_axi_rdata <= Register0(31 downto 1) & internal_enable when "00",
                         x"000000" & RegisterINDEX(7 downto 0) when "01",
                         led_reg(to_integer(unsigned(RegisterINDEX(7 downto 0)))) when "10",
                         Register3 when others;
-- #########################################################################################################
    -- Get data from AXI-bus and write to register
    ---- REGISTERS (data flow) ----
    -- Register enable
    process(clock)
    begin
        if (rising_edge(clock)) then
            if (reset='1') then
                internal_enable <= '0';
            elsif (WriteEnable0='1') then
                internal_enable <= s00_axi_wdata(0);
            else
                internal_enable <= internal_enable;
            end if;
        end if;
    end process;
    
    -- led index
    process(clock)
    begin
        if (rising_edge(clock)) then
            if (reset='1') then
                RegisterINDEX <= (others => '0');
            elsif (WriteEnable1='1') then
                RegisterINDEX <= s00_axi_wdata;
            end if;
        end if;
    end process;
    
    -- color data
    process(clock)
    begin
        if (rising_edge(clock)) then
            if (reset='1') then
                led_reg <= ((others => (others =>'0')));
            elsif (WriteEnable2='1') then
                led_reg(to_integer(unsigned(RegisterINDEX(7 downto 0)))) <= s00_axi_wdata;
            end if;
        end if;
    end process;
-- #########################################################################################################
    -- concurrent_statements;
    process(clock)
    begin
        if (rising_edge(clock)) then
            if reset = '1' then
                led_color <= (others => '0');
            else
                led_color <= led_reg(to_integer(led_idx(7 downto 0)));
            end if;
        end if;
    end process;

    DRIVER : npix_driver generic map (NUM_OF_LEDS => NUM_OF_LEDS,
                                      DELAY_TIME => DELAY_TIME)
                         port map (data_in => led_color(23 downto 0),
                                   clock => clock,
                                   enable => internal_enable,
                                   --rdata_end => open,
                                   led_idx => led_idx,
                                   bitstream => bitstream);
    -- User logic ends

end arch_imp;

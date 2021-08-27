-- original code: https://reference.digilentinc.com/lib/exe/fetch.php?tok=53d927&media=https%3A%2F%2Fgithub.com%2Fmwingerson%2FDigiLED%2Farchive%2Fmaster.zip

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity npix_driver is
    generic ( NUM_OF_LEDS: natural := 4;
              DELAY_TIME:  natural := 5000 ); 
    port ( data_in:     in std_logic_vector(23 downto 0); -- data in RGB 
           clock:       in std_logic;                     -- expecting 100MHz clock
           enable:      in std_logic;
           --rdata_end:   out std_logic;                    -- read data finished
           led_idx:     out unsigned(7 downto 0);   -- return led index
           bitstream:   out std_logic );
end npix_driver;

architecture Behavioral of npix_driver is
    signal color_reg: std_logic_vector(23 downto 0);    -- 24 bit register stored in GRB
    signal internal_reset: std_logic := '0';
    
    signal led_counter: unsigned(7 downto 0) := (others => '0');
    signal pwm_out_0: std_logic;
    signal pwm_out_1: std_logic;
    
    -- bit counter signal
    constant BIT_COUNTER_MAX: integer := 24 - 1; -- 24 bit
    signal bit_counter: integer := 0;
    
    -- bit divider signals
    constant BIT_COUNTER_DIV_MAX: integer := 125 - 1;   -- 100Mhz / 800kHz pulse per frame
    signal neopix_clock_counter: integer := 0;          --bit_counter_div
    signal neopix_clock: std_logic;
    
    -- pwm counter signals
    constant PWM_0_TIME: integer := 40;   -- 40 dec = 0.4046us * 100MHz
    constant PWM_1_TIME: integer := 80;   -- 80 dec = 0.8092us * 100MHz

    -- delay counter signal
    signal delay_counter: integer range DELAY_TIME-1 downto 0 := 0;
    signal delay_done_flag: std_logic := '0';
    
    -- state machine variables
    type STATE_TYPE is (GET_COLOR, GET_LED, TRANSFER_BIT, WAITING);
    signal STATE: STATE_TYPE := GET_COLOR;
begin
    -- state machine reset 
    internal_reset <= not enable;
    
    -- #### bit counter divider ####
    BIT_CNT_DIV_PROC: process(clock)
    begin
        if rising_edge(clock) then
            if (neopix_clock_counter < BIT_COUNTER_DIV_MAX) and 
               (internal_reset = '0' and ((STATE = GET_COLOR) or (STATE = GET_LED) or (STATE = TRANSFER_BIT))) then
               
                neopix_clock_counter <= neopix_clock_counter + 1;
            else
                neopix_clock_counter <= 0;
            end if;
        end if;
    end process;
    neopix_clock <= '1' when neopix_clock_counter = BIT_COUNTER_DIV_MAX else '0'; -- 1 bit needs 125 pulse
    
    --##### bit counter ####
    BIT_CNT_PROC: process(clock)
    begin
        if rising_edge(clock) then
            -- count bits
            if ((neopix_clock = '1') and
                (bit_counter < BIT_COUNTER_MAX) and -- if we still have bits left
                (STATE = GET_COLOR or STATE = GET_LED or STATE = TRANSFER_BIT)) then
                
                bit_counter <= bit_counter + 1;
                
            elsif neopix_clock = '1' then   -- if all frames was sent
                bit_counter <= 0;     
            else                            -- if something goes wrong
                bit_counter <= bit_counter;
            end if;
        end if;
    end process;
    
    -- #### pwm ####
    pwm_out_0 <= '1' when neopix_clock_counter < PWM_0_TIME and internal_reset = '0' and ((STATE = GET_COLOR) or (STATE = GET_LED) or (STATE = TRANSFER_BIT)) else '0';
    pwm_out_1 <= '1' when neopix_clock_counter < PWM_1_TIME and internal_reset = '0' and ((STATE = GET_COLOR) or (STATE = GET_LED) or (STATE = TRANSFER_BIT)) else '0';
    
    -- FSM data transfer
    FSM_PROC: process(clock, internal_reset)
    begin
        if rising_edge(clock) then
            if internal_reset = '1' then
                STATE <= GET_COLOR;
                led_counter <= (others => '0');
            else
                case STATE is
                    when GET_COLOR => -- get color from register
                        color_reg <= data_in(15 downto 8) & data_in(23 downto 16) & data_in(7 downto 0); -- convert to GRB
                        STATE <= GET_LED;
                        
                    when GET_LED =>   -- get led idx
                        if neopix_clock = '1' then
                            led_counter <= led_counter + 1; -- increase led counter   
                            STATE <= TRANSFER_BIT;          -- change state to transfer bits
                        else 
                            STATE <= STATE; 
                        end if;
                        
                    when TRANSFER_BIT => 
                        if neopix_clock = '1' and bit_counter /= BIT_COUNTER_MAX then
                            STATE <= TRANSFER_BIT;      -- transfer again
                        elsif neopix_clock = '1' and led_counter < NUM_OF_LEDS then   -- if we still have LEDs left
                            STATE <= GET_COLOR;                                       -- go back and get led data
                        elsif neopix_clock = '1' then                                 -- if the transfer is finished
                            led_counter <= (others => '0');
                            STATE <= WAITING;
                        else 
                            STATE <= STATE; 
                        end if;
                        
                    when WAITING => 
                        if delay_done_flag = '1' then
                            STATE <= GET_COLOR;
                        end if;
                    when others => null;
                end case;
            end if;
        end if;
    end process FSM_PROC;
    
    -- #### delay counter for color ####
    DELAY_CNT_PROC: process(clock)
    begin
        if rising_edge(clock) then
            if STATE = WAITING then
                if delay_counter < DELAY_TIME then
                    delay_counter <= delay_counter + 1;
                else
                    delay_counter <= 0;
                end if;
            end if;
        end if;
    end process;
    
    -- set delay flag
    DELAY_FLAG_PROC: process(clock)
    begin
        if rising_edge(clock) then
            if STATE = WAITING then
                if delay_counter = DELAY_TIME then
                    delay_done_flag <= '1';
                else
                    delay_done_flag <= '0';
                end if;
            elsif STATE = GET_COLOR then
                delay_done_flag <= '0';
            end if;
        end if;
    end process;
    
    led_idx <= led_counter when (led_counter < NUM_OF_LEDS) else (others => '0');
    --rdata_end <= '1' when (bit_counter = BIT_COUNTER_MAX-1) and (neopix_clock = '1') else '0';
    
    -- assign the PWM signal from PWM1 or PWM0 dependent on the whether current indexed bit is a 1 or 0
    bitstream <= pwm_out_1 when enable = '1' and (color_reg(23 - bit_counter) = '1') else pwm_out_0;
end Behavioral;

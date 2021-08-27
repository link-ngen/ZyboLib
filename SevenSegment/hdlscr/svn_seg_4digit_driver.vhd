-- fpga4student.com: FPGA projects, Verilog projects, VHDL projects
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity svn_seg_4digit_driver is
    Port ( clock:   in std_logic;     -- 100 Mhz clock source
           enable:  in std_logic;
           number:  in unsigned(15 downto 0);
           jc_anode:   out std_logic_vector(3 downto 0);  -- LED4, LED3, LED2, LED1
           jd_cathode: out std_logic_vector(6 downto 0)); -- p, a, b, c, d, e, f, g
                                                          -- 7, 6, 5, 4, 3, 2, 1, 0
end svn_seg_4digit_driver;

architecture Behavioral of svn_seg_4digit_driver is
    signal freq_div_reg : unsigned(20 downto 0); -- the first 19-bit for creating 190Hz refresh rate 2^19 -1 = 524287 => 100MHz/524287 = 190 Hz.
                                                 -- the other 2-bit for creating 4 LED-activating signals
    signal activate_digit_led: unsigned(1 downto 0);
    signal digit_register : std_logic_vector(15 downto 0);
    signal bcd : std_logic_vector(3 downto 0);
    --signal decimal_point : std_logic;
begin
   
    REFRESH_COUNT_PROC : process(clock)
    begin
        if rising_edge(clock) then
            if enable = '0' then
                freq_div_reg <= (others => '0');
            else
                freq_div_reg <= freq_div_reg + 1;
            end if;
        end if;
    end process;
    activate_digit_led <= freq_div_reg(20 downto 19);
    
    process(activate_digit_led, number)
    begin
        case activate_digit_led is
            when "00" => -- activate LED1 and Deactivate LED2, LED3, LED4
                jc_anode <= "1110";
                -- the first digit of the 16-bit number digit_register
                digit_register <= std_logic_vector(number / 1000);
                --decimal_point <= '0';
            when "01" => -- activate LED2 and Deactivate LED1, LED3, LED4
                jc_anode <= "1101";
                -- the second digit of the 16-bit number
                digit_register <= std_logic_vector((number mod 1000) / 100);
                --decimal_point <= '1';
            when "10" => -- activate LED3 and Deactivate LED2, LED1, LED4
                jc_anode <= "1011";
                -- the third digit of the 16-bit number
                digit_register <= std_logic_vector(((number mod 1000) mod 100) / 10);
                --decimal_point <= '0';
            when "11" => -- activate LED4 and Deactivate LED2, LED3, LED1
                jc_anode <= "0111";
                -- the fourth digit of the 16-bit number
                digit_register <= std_logic_vector(((number mod 1000) mod 100) mod 10);
                --decimal_point <= '0';
            when others => null;
        end case;
    end process;
    
    bcd <= digit_register(3 downto 0);
    jd_cathode <= "1111110" when bcd = "0000" else  -- 0
                  "0110000" when bcd = "0001" else  -- 1
                  "1101101" when bcd = "0010" else  -- 2
                  "1111001" when bcd = "0011" else  -- 3
                  "0110011" when bcd = "0100" else  -- 4
                  "1011011" when bcd = "0101" else  -- 5
                  "1011111" when bcd = "0110" else  -- 6
                  "1110000" when bcd = "0111" else  -- 7
                  "1111111" when bcd = "1000" else  -- 8
                  "1111011" when bcd = "1001";      -- 9
end Behavioral;

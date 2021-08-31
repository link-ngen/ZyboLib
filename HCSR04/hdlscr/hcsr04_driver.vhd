library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;
USE ieee.math_real.ceil;

entity hcsr04_driver is
    generic (FREQ: natural := 100); --in MHz
    Port ( clock:           in  std_logic; -- expecting 100MHz clock
           enable:          in  std_logic;
           trigger:         out std_logic;
           echo:            in  std_logic;
           distance:        out unsigned(15 downto 0) ); -- in mm
end hcsr04_driver;

architecture Behavioral of hcsr04_driver is
    constant MAX_ECHO_TIME : natural := 34; -- Maximum echo pulse width when no obstructions (ms).   
    constant TRIGGER_FREQ_DIV: natural := 1000000 - 1; --integer(ceil((FREQ * 1.0E6) / TRIGGER_FREQ)) - 1; --(2000000 - 1)
       
    signal trigger_counter : natural range 0 to TRIGGER_FREQ_DIV;
    signal echo_counter : unsigned(23 downto 0); --natural range 0 to 3400000 - 1;--integer(MAX_ECHO_TIME * FREQ * 1000) - 1;
    
    signal internal_trigger: std_logic;
    signal echo_flag : std_logic;
begin
    
    TRIGGER_COUNT_PROC: process(clock)
    begin
        if rising_edge(clock) then
            if (enable = '1' and trigger_counter < TRIGGER_FREQ_DIV) then
                trigger_counter <= trigger_counter + 1;
            else
                trigger_counter <= 0;
            end if;
        end if;
    end process;
    
    TRIGGER_CLK_PROC: process(clock)
    begin
        if rising_edge(clock) then
            if enable = '0' then
                internal_trigger <= '0';
            elsif trigger_counter = TRIGGER_FREQ_DIV then
                internal_trigger <= not internal_trigger;
            else
                internal_trigger <= internal_trigger;
            end if;
        end if;
    end process;
    
    trigger <= not internal_trigger;
    
    COUNT_ECHO_PROC: process(clock)
    begin
        if rising_edge(clock) then
            if enable = '0' or echo = '0' then
                echo_counter <= x"000000";
            elsif echo = '1' then
                echo_counter <= echo_counter + 1;
            end if;
        end if;
    end process;

    process(clock)
        variable result_temp : unsigned(47 downto 0);
    begin
        if rising_edge(clock) then
            if enable = '0' then
                distance <= (others => '0');
                echo_flag <= '0';
            else 
                echo_flag <= echo;
                if echo_flag = '1' and echo = '0' then
                    result_temp := echo_counter * 172 / 100_000;
                    distance <= result_temp(15 downto 0);
                end if;
            end if;
        end if;
    end process;
end Behavioral;

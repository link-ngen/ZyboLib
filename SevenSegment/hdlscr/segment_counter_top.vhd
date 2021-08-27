library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity segment_counter_top is
    port ( clock:       in std_logic;
           enable:      in std_logic;
           jc_anode:    out std_logic_vector(3 downto 0);
           jd_cathode:  out std_logic_vector(6 downto 0) );
end segment_counter_top;

architecture Behavioral of segment_counter_top is
    signal one_sec_flag: std_logic;
    signal one_sec_counter: unsigned(26 downto 0);
    signal number : unsigned(15 downto 0);
    
    component svn_seg_4digit_driver
        Port ( clock:   in std_logic;     -- 100 Mhz clock source
               enable:  in std_logic;
               number:  in unsigned(15 downto 0);
               jc_anode:   out std_logic_vector(3 downto 0);
               jd_cathode: out std_logic_vector(6 downto 0));                                        
    end component;
begin
    process(clock)
    begin
        if rising_edge(clock) then
            if enable = '0' or number >= 9999 then
                number <= (others => '0');
            elsif (one_sec_flag = '1') then
                number <= number + 1;
            end if;
        end if;
    end process;
    
    process(clock)
    begin
        if rising_edge(clock) then
            if enable = '0' then
                one_sec_counter <= (others => '0');
            else 
                if one_sec_counter >= 99999999 then
                    one_sec_counter <= (others => '0');
                else
                    one_sec_counter <= one_sec_counter + 1;
                end if;
            end if;
        end if;
    end process;
    one_sec_flag <= '1' when (one_sec_counter = 99999999) else '0';
    
    SEVEN_SEGMENT: svn_seg_4digit_driver 
                        port map (clock => clock,
                                  enable => enable,
                                  number => number,
                                  jc_anode => jc_anode,
                                  jd_cathode => jd_cathode);

end Behavioral;

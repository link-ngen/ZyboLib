#include "neopixel_driver.h"

static volatile Xuint32 *pRegister;

/**
 * 	@brief	Initialize Neopixel driver.
 */
void neopixel_init(Xuint32 base_addr, rgb_t leds[])
{
	pRegister = (volatile Xuint32*) base_addr;
	for (Xuint8 ledIdx = 0; ledIdx < NUM_OF_LEDS; ++ledIdx)
	{
		neopixel_set_color(ledIdx, leds[ledIdx]);
	}
}

/**
 * 	@brief	Start NeoPixel driver on FPGA.
 */
void neopixel_enable_leds()
{
	pRegister[REGISTER0] = 0x01;
}

/**
 * 	@brief	Stop NeoPixel driver on FPGA.
 */
void neopixel_disable_leds()
{
	pRegister[REGISTER0] = 0x00;
}

/**
 * 	@brief	Read led color by giving index.
 * 	@param	led_idx led index, starting from 0.
 *	@return	32-bit color code.
 */
Xuint32 neopixel_read_led(Xuint8 led_idx)
{
	if (led_idx < NUM_OF_LEDS) // guard
	{
		pRegister[REGISTER1] = led_idx;
		return pRegister[REGISTER2];
	}
	return 0;
}

/**
 * @brief   Set a led's color using color structure components.
 * @param   led_idx led index, starting from 0.
 * @param	color	color structure red, green, blue.
 */
void neopixel_set_color(Xuint8 led_idx, rgb_t color)
{
	if (led_idx < NUM_OF_LEDS) // guard
	{
		color.r = (color.r * BRIGHTNESS) >> 8;
		color.g = (color.g * BRIGHTNESS) >> 8;
		color.b = (color.b * BRIGHTNESS) >> 8;

		pRegister[REGISTER1] = led_idx;
		pRegister[REGISTER2] = ((Xuint32)color.r << 16) | ((Xuint32) color.g << 8) | color.b;
	}
}

/**
 * 	@brief   Fill the led with 0 / black / off.
 * 	@param   led_idx led index, starting from 0.
 */
void neopixel_clear_led(Xuint8 led_idx)
{
	if (led_idx < NUM_OF_LEDS) // guard
	{
		pRegister[REGISTER1] = led_idx;
		pRegister[REGISTER2] = 0;
	}
}

Xuint32 neopixel_readRegister(Xuint8 regIdx)
{
	return (regIdx > REGISTER2) ? 0 : pRegister[regIdx];
}

void neopixel_clear(void)
{
	neopixel_disable_leds();
	for (Xuint8 ledIdx = 0; ledIdx < NUM_OF_LEDS; ++ledIdx)
	{
		neopixel_clear_led(ledIdx);
	}
	neopixel_enable_leds();
}

/*
 * @brief Fill strip pixels one after another with a color.
 * @param color 24-bit color value.
 * @param wait Delay time in milliseconds.
 */
void neopixel_color_wipe(rgb_t color, Xuint16 wait)
{
	for (Xuint8 ledIdx = 0; ledIdx < NUM_OF_LEDS; ++ledIdx)	// For each pixel in strip...
	{
		neopixel_disable_leds();		// disable pixel color
		neopixel_set_color(ledIdx, color);
		neopixel_enable_leds();
		usleep(wait * 1000); 	// pause for a moment
	}
}

static rgb_t neopixel_wheel(Xuint8 wheel_pos)
{
	static rgb_t c;
	if (wheel_pos < 85)
	{
		c.r = wheel_pos * 3;
		c.g = 255 - wheel_pos * 3;
		c.b = 0;
	}
	else if (wheel_pos < 170)
	{
		wheel_pos -= 85;
		c.r = 255 - wheel_pos * 3;
		c.g = 0;
		c.b = wheel_pos * 3;
	}
	else
	{
		wheel_pos -= 170;
		c.r = 0;
		c.g = wheel_pos * 3;
		c.b = 255 - wheel_pos * 3;
	}
	return c;
}

void neopixel_rainbow_cycle(Xuint16 wait)
{
	rgb_t c;
	for (Xuint16 j = 0; j < 256 * 5; ++j) // 5 cycles of all colors on wheel
	{
		neopixel_disable_leds();
		for (Xuint16 i = 0; i < NUM_OF_LEDS; ++i)
		{
			c = neopixel_wheel(((i * 256 / NUM_OF_LEDS) + j) & 255);
			neopixel_set_color(i, c);
		}
		neopixel_enable_leds();
		usleep(wait * 1000);
	}
}

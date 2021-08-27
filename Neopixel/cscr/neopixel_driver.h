#ifndef SRC_NEOPIXEL_DRIVER_H_
#define SRC_NEOPIXEL_DRIVER_H_

#include "xbasic_types.h"
#include "sleep.h"

#define REGISTER0 	(0)
#define REGISTER1 	(1)
#define REGISTER2 	(2)

#define NUM_OF_LEDS (8)
#define BRIGHTNESS 	(50)	// Set BRIGHTNESS to about 1/5 (max = 255)

typedef struct rgb_t {
	Xuint8 r;
	Xuint8 g;
	Xuint8 b;
} rgb_t;

// TODO: in process...
typedef struct hsv_t {
	Xuint16 hue;
	Xuint8 sat;
	Xuint8 val;
} hsv_t;

void neopixel_init(Xuint32 base_addr, rgb_t leds[]);
void neopixel_enable_leds(void);
void neopixel_disable_leds(void);
Xuint32 neopixel_read_led(Xuint8 led_idx);
void neopixel_set_color(Xuint8 led_idx, rgb_t color);
void neopixel_clear_led(Xuint8 led_idx);
void neopixel_clear(void);
Xuint32 neopixel_readRegister(Xuint8 regIdx);

// color features
void neopixel_color_wipe(rgb_t color, Xuint16 wait);
static rgb_t neopixel_wheel(Xuint8 wheel_pos);
void neopixel_rainbow_cycle(Xuint16 wait);

#endif /* SRC_NEOPIXEL_DRIVER_H_ */

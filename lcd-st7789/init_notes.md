# Init and reset sequence
Based on the example from [Sipeed LCD
top.v](https://github.com/sipeed/TangNano-9K-example/blob/main/spi_lcd/src/top.v)
I will walk through the sequence of events, and cross check that with the
datasheet.

This will proberly only work for a basic implementation, and further research
is probable.
I will want to print text and colors at a later date, but will start by init

# Commands
There are 19 commands in the example, 18 in the array, and first
0x11 - Sleep out, no parameter

 then all of the commands in the array in this order with the parameters

- 0x36 - Memory data access control
- 0x3A - Interface pixel format
- 0xB2 - Porch control
- 0xB7 - Gate Control
- 0xBB - VCOMS setting
- 0xC0 - LCM control
- 0xC2 - VDV and VRH Command Enable
- 0xC3 - VRH Set
- 0xC4 - VDV Setting
- 0xC6 - FR Control
- 0xD0 - Power Control 1
- 0xE0 - Positive Voltage Gamma Control
- 0xE1 - Negative Voltage Gamma Control
- 0x21 - Display inversion on
- 0x29 - Display on    (0x28 is display off for future reference)
- 0x2A - Column address set
- 0x2B - Row address set
- 0x2C - Memory write

And then we write all the pixels to the screen by setting cs to 0 and rs to 1
and then just giving the output
Since the screen is 240x135 the pixel count is 32400 total

Each of these commands has parameters, some more than others.
The first bit, or dc, is high when sending parameters. Then the rest is the data

# Powering on and reset
First of all: Power on/off sequence, if powering off from awake (sleep out),
wait 120ms after RESX has been released. If sleep, just shutdown.
Powering on requires no waiting, unless in CABC function, then 5ms.

Software reset also has a 5ms wait period, if reset while sleeping 120ms wait
Cannot send this during sleep out sequence

So powering on, or pressing reset (reset needs a minimum of 10us to work)
we wait a minimum of 5ms to send commands, but 120ms to send the sleep out
command.

*0x11* has no parameters, it turns off sleep mode, but you have to wait
the normal 5ms before sending a new command, but 120ms to send a sleep in

*0x36* sets the scanning direction of frame memory. Takes on byte as a
parameter. The dc bit is high, since its a parameter dont care about bit 0 and
1, there its 6 bits of information, each 2 options.
    Pages address order,
    Colums address order,
    Page/Column order,
    Line address order,
    RGB/BGR
    display daya latch order

Example had 170, meaning 01110000.
Top to bottom, right to left, reverse mode, Section 8.12
and then LCD refrech bottom to top, RGB, and refresh left to right
Makes sense, and i will have the same configuration

_Note_: Power on sequene and HW reset sets this to 0h, but software reset does
not change the settings

*0x3A* defines the format of RGB pictura data, which is to be transferred
to the screen. dc bit high and rdx high as always
bit 3 and 7 are always 0.

Both groups set color format, but the difference is where.
bits 0,1 and 2 set the Control interface, which is SPI <= us
bits 4,5 and 6 set the RBG interface, which we dont have

Example had 0x05 meaning 16 bit per pixel. Default is 18.


*0xB2* describes the porch setting. This is a short non visible interval after
the active image is scanned, before the next synch pulse.

Takes 5 parameters, whereas the command it self has dc low, then 5 paramester
with dc high
The power on sequence, and reset, has this defaulted to 0xc,0xc,0x0,0x33,0x33,
and that is what the example sends as well

*0xB7*, gate control, is also not needed, its default setting is excactly what
the example sends, which is 0x35 with the dc bit high. This can also be skipped

*0xBB* is interesting. VCOMS setting, which default to 0x20 (0.9V), but the
example sets it to 0x19 (0.725V). Why i dont know, but another we could  skip
if we just use the defaul setting, but i think this is for a reason, and I will
keep it

*0xC0* is LCM control, which is Liquid Crystam Module control and it configures
some controller settings mapped to the physical panel. But the example and the
default values are the same, so we can skip this too

*0xC2* adjust the internal voltages used to drive the LCD pixels, here again the
default and the example matches, even though the example skipped the 2nd param.

*0xC3* adjust the VRH (base reference voltage magnitude) positive and negative
drive voltage references. This command take on parameter selecting from a table
The default is 0x0b, but the example sets 0x12. This is a substantial change,
and it is probably a reason for it. Default is +/-4.1 and 0x12 is 4.45

*0xC4* follows this up with the default value, 0x020, so we skip it. Its 0V.

*0xC6* is the frame rate control in normal mode, default value is 0f, which is
60hz, this is also default value, so another we can skip.

=====

*0xD0* is power control 1 which set three internal analog supply coltages.
The first parameter is always 0xa4, and the second parameter sets the actual
voltages. Default is 0x81, but the example has 0xA1, meaning avcl is changed
from -4.4V to -4.8V, while leaving the avdd to 6.8 (first to bits are still 10,
which is 0x2, and the last is 0x1, which is vdds of 2.3.

And then next up is a doozy, both 0xe0 and 0xe1 takes 14 parameters

*0xE0* is the positive voltage gamma control and this is where is gets really
spicy. The controller chip can drive many different screens, and the default
are not chosen, meaning that the screen here might need different values.
This is probably a manufactur spec thing, that i can check later.
Keep them for now. Sequence of parameter is:
    D0, 04, 0D, 11, 13, 2B, 3F, 54, 4C, 18, 0D, 0B, 1F, 23

*0xE1* is the same story and almost the same parameters:
    D0, 04, 0C, 11, 13, 2C, 3F, 44, 51, 2F, 1F, 1F, 20, 23

And then we get to the end of the power up sequence with two commands, first

*0x21* Display inversion on, which recover from inversion mode. The default is
being off, and after this we turn the screen actually on

*0x29* Display on!

All that is left to do now is knowing that reset or a new power on sequence,
will need to do everything here over again, and that in the on state we can
turn it off, write to the screen or just keep it on

## Writing to the screen

Here we need three commands, and the example shows us how its done
first we say which column, then row and then we say start. 
That is it!

row and column takes 4 parameter, and start is a single command

*0x2A* Column address set. this is the position across the image, basicly
starting column and ending column. So we give it a width in other words.
two bytes for the start, two bytes for the end. Basicly the x positions

*0x2B* is the row address set, this is the height, basicly y positions.

What we need to know is that the framebuffer is 320x240 since the chip supports
screens up to that size. Our screen is only 240x135, and is in the middle.
it has 80 extra columns, but places with 40 extra before and after our rect.
the rows are 105 extra, but its 53 before and 52 after our rect. therefore we
have a fixed offset of 40 on the cols and 53 on the rows.
0,0 on our screen is in other words 40,53 on the framebuffer.

we then call the command

*0x2c* memory write! This command takes what we entered above and writes bytes
to the framebuffer, effectivly displaying the image. We do not need to refresh
the screen. Write to it once, and let it be.

We have to calculate a rectangle in order to send bytes, this is also the size
and amount of bytes. its width x height x 2. The command will expect bytes to
fill the rect. This command as always has dc low for the command, and dc high
for each byte.

_note_ sending any other command can stop frame write.

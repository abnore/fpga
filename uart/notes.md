# UART connection using screen

First install screen or putty.
Second, find the device. The Tang nano on mac will be on

- `/dev/cu.usbserial2100` is JTAG
- `/dev/cu.usbserial2101` is UART

This may change, but higher number is uart, normally (channel B).

then do
```bash
screen /dev/cu.usbserial2101 115200
```

Now we can read the data


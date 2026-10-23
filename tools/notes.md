# FPGA tools – Mac / Tang Nano 9K

OSS CAD Suite gives me an open-source toolchain to simulate, build, and program
FPGA designs from the terminal.

## Activate

```bash
fpga
```

This selects the suite’s tools, including GHDL 7.0.0-dev,
instead of my standalone GHDL 6.0.0.

Check which GHDL is selected:

```bash
command -v ghdl
ghdl --version
```

## Deactivate

```bash
deactivate
```

This restores the previous environment, including
`/opt/homebrew/bin/ghdl`.

## Notes

- `fpga` is an alias for: `source ~/dev/FPGA/tools/oss-cad-suite/environment`
- Sourcing `.bashrc` may remove the prompt label without deactivating the
  environment.

## GHDL bug ([Issue #176](https://github.com/YosysHQ/oss-cad-suite-build/issues/176))
- The bundled GHDL was repaired by removing duplicate `LC_RPATH` entries and
  re-signing it locally.
- Replacing/updating the suite may require that repair again.

## Detecting the Tang Nano 9K

Activate the OSS CAD Suite environment:

```bash
fpga
```

Check that the board is connected and detected:

```bash
openFPGALoader -b tangnano9k --detect
```

A successful detection looks like this:

```text
Jtag frequency : requested 6.00MHz -> real 6.00MHz
index 0:
    idcode 0x100481b
    manufacturer Gowin
    family GW1N
    model GW1N(R)-9C
    irlength 8
```

## Building and programming
The first project, that can serve as an example now, is `tang-blink`.
It contains:

- `blink.vhdl` - a VHDL design that blinks one onboard LED.
- `tangnano9k.cst` - pin and electrical constraints for the clock and LED.
- `Makefile` - builds the design through synthesis, place and route, and bitstream generation.

This is the inital state which had the first makefile, before it became common,
simple .cst and simply enough to make it work.

From the project directory, run:

```bash
make
```

This generates `build/blink.fs`.

Load the bitstream into the FPGA temporarily:

```bash
make program
```

Write it to the Tang Nano 9K’s onboard flash so it persists after power-off:

```bash
make flash
```


## Shared Makefile

Common build rules are stored in `tools/tangnano9k.mk` in this repository.

Add the following to your `~/.bashrc` or `~/.bash_profile`, replacing
`/path/to/fpga` with the absolute path to your clone:

```bash
export MAKEFLAGS="$MAKEFLAGS -I/path/to/fpga/tools"
```

Reload your shell configuration after saving.

Each project only needs a small Makefile:

```makefile
TOP := ex_top
SRC := some_pkg.vhdl example.vhdl foo.vhdl

include tangnano9k.mk
```

Available commands:

- `make` – Build bitstream
- `make program` – Program SRAM
- `make flash` – Program flash
- `make timing` – Show timing and resource utilization
- `make clean` – Remove build files

## Apicula performance

OSS CAD Suite uses its own Python environment.

Initially, NumPy, msgspec and fastcrc were missing, slowing down
bitstream generation.

Fixed with:

```bash
fpga # Do enter the virtual enviroment explained above
python3 -m pip install numpy msgspec fastcrc
```

Bitstream generation is significantly faster after installation.

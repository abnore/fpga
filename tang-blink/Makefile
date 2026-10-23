.DEFAULT_GOAL := all
.DELETE_ON_ERROR:

.PHONY: all program flash clean

all: build/blink.fs

build:
	mkdir -p build

build/blink.v: blink.vhdl | build
	ghdl --synth --std=19 --out=verilog $< -e blink > $@

build/blink.json: build/blink.v
	yosys -p 'read_verilog $<; synth_gowin -top blink -json $@'

build/routed.json: build/blink.json tangnano9k.cst
	nextpnr-himbaechel \
		--device GW1NR-LV9QN88PC6/I5 \
		--vopt family=GW1N-9C \
		--vopt cst=tangnano9k.cst \
		--freq 27 \
		--json $< \
		--write $@

build/blink.fs: build/routed.json
	gowin_pack -d GW1N-9C -o $@ $<

program: build/blink.fs
	openFPGALoader -b tangnano9k $<

flash: build/blink.fs
	openFPGALoader -b tangnano9k -f $<

clean:
	rm -rf build

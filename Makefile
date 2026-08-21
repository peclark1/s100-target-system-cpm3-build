.PHONY: all build verify image clean

all: build verify

build:
	./scripts/build.sh

verify:
	./scripts/verify.sh

image: build
	./scripts/make_image.sh
	./scripts/verify.sh

clean:
	rm -rf build dist/CPM3.SYS dist/BIOS3.SPR dist/BIOS3.SYM \
	       dist/S100-cpm3-nonbanked-prop-dualcf-dsi-v3.0.img tools/cpmrun

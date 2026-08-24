.PHONY: all build verify image loader loader-image clean

all: build verify

build:
	./scripts/build.sh

verify:
	./scripts/verify.sh

image: build
	./scripts/make_image.sh
	./scripts/verify.sh

# Experimental front-panel-aware CP/M 3 loader.  This deliberately remains
# separate from the hardware-tested normal image path until physical testing
# is complete.  CPMLDR.REL must be supplied in tools/cpm or via CPMLDR_REL.
loader:
	bash ./scripts/build_loader.sh

loader-image: build loader
	bash ./scripts/make_loader_image.sh
	./scripts/verify.sh

clean:
	rm -rf build build-loader \
	       dist/CPM3.SYS dist/BIOS3.SPR dist/BIOS3.SYM \
	       dist/CPMLDR.COM dist/CPMLDR.SYM dist/LDRBIOS.PRN \
	       dist/S100-cpm3-nonbanked-prop-dualcf-fdc3712-candidate.img \
	       dist/S100-cpm3-nonbanked-prop-dualcf-fdc3712-front-panel-loader.img \
	       tools/cpmrun

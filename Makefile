.PHONY: all build verify image fdcplus fdcplus-image clean

all: build verify

build:
	./scripts/build.sh

verify:
	./scripts/verify.sh

image: build
	./scripts/make_image.sh
	./scripts/verify.sh

fdcplus:
	./scripts/build-fdcplus.sh

fdcplus-image: fdcplus
	./scripts/make_image_fdcplus.sh

clean:
	rm -rf build build-fdcplus \
	       dist/CPM3.SYS dist/BIOS3.SPR dist/BIOS3.SYM \
	       dist/S100-cpm3-nonbanked-prop-dualcf-dsi-v3.0.img \
	       dist/CPM3-FDCPLUS.SYS dist/BIOS3-FDCPLUS.SPR \
	       dist/BIOS3-FDCPLUS.SYM \
	       dist/S100-cpm3-nonbanked-prop-dualcf-fdcplus-test.img \
	       tools/cpmrun

.PHONY: all build verify image fdcplus fdcplus-image abonly abonly-image clean

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

abonly:
	bash ./scripts/build-abonly.sh

abonly-image: abonly
	bash ./scripts/make_image_abonly.sh

clean:
	rm -rf build build-fdcplus build-abonly \
	       dist/CPM3.SYS dist/BIOS3.SPR dist/BIOS3.SYM \
	       dist/S100-cpm3-nonbanked-prop-dualcf-dsi-v3.0.img \
	       dist/CPM3-FDCPLUS.SYS dist/BIOS3-FDCPLUS.SPR \
	       dist/BIOS3-FDCPLUS.SYM \
	       dist/S100-cpm3-nonbanked-prop-dualcf-fdcplus-test.img \
	       dist/CPM3-ABONLY.SYS dist/BIOS3-ABONLY.SPR \
	       dist/BIOS3-ABONLY.SYM \
	       dist/S100-cpm3-nonbanked-prop-dualcf-abonly-test.img \
	       tools/cpmrun

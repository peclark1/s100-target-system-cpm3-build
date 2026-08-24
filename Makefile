.PHONY: all build verify image loader-image ldrpatch clean

all: build verify

build:
	./scripts/build.sh

verify:
	./scripts/verify.sh

image: build
	./scripts/make_image.sh
	./scripts/verify.sh

# Experimental loader path: keep the proven CPMLDR and patch only its
# loader-BIOS CONOUT entry to tail-jump through the 4K ROM at F006H.
loader-image: image
	bash ./scripts/make_loader_image.sh

# Tiny CP/M-side utility that applies the same four-byte patch directly to
# raw A: LBA 6, with signature checks and full-sector read-back verification.
ldrpatch:
	bash ./scripts/build_ldrpatch.sh

clean:
	rm -rf build build-ldrpatch \
	       dist/CPM3.SYS dist/BIOS3.SPR dist/BIOS3.SYM \
	       dist/LDRPATCH.COM dist/LDRPATCH.SYM \
	       dist/S100-cpm3-nonbanked-prop-dualcf-fdc3712-candidate.img \
	       dist/S100-cpm3-nonbanked-prop-dualcf-fdc3712-front-panel-loader.img \
	       tools/cpmrun

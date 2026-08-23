# FDC+3712 Hardware Acceptance Test

Do not promote the candidate hash to gold until this test passes on the physical IMSAI/S-100 target system.

Use expendable floppy media for every write test.

## 1. Build and install

```bash
make clean
make
make image
```

Install the resulting candidate CF image on a test CF card.

## 2. IDE/CF regression and no-floppy boot

1. Power off or disconnect the 8-inch drive subsystem.
2. Boot CP/M 3 from CF #0.
3. Confirm the A> prompt appears without an FDC+ wait or hang.
4. Run `DIR A:` and `DIR B:`.
5. Read and write a small expendable file on B:.
6. Run `DIR C:` and confirm an error returns within a bounded time rather than hanging.
7. Reconnect/power the floppy subsystem before continuing.

## 3. Known-media read test

Use the physical disk written from `CPM22v1.0-FDC+3712-48K.dsk`.

1. Insert it in physical drive 0.
2. Run `DIR C:`.
3. Confirm expected files such as ASM.COM, DDT.COM, FORMAT.COM, MOVCPM.COM, PIP.COM, STAT.COM, and SYSGEN.COM are visible.
4. Copy a small file from C: to A: and compare or execute it.
5. Repeat the read test on physical drive 1 as D:.

## 4. Scratch-media write test

Use scratch IBM-3740/CP/M media.

1. Copy a small file A: to C: with PIP verify enabled.
2. Read the file back and compare it.
3. Delete it and confirm the directory update.
4. Repeat on D:.
5. Copy a file directly C: to D: and then D: to C:.
6. Write-protect a disk, attempt a copy, and confirm CP/M reports write protection without corrupting the disk.

## 5. Track and drive-switching test

1. Read files spanning several tracks on C:.
2. Alternate `DIR C:` and `DIR D:` repeatedly.
3. Copy files in both directions between C: and D:.
4. Warm boot CP/M and repeat directory reads.
5. Reset and cold boot from IDE/CF, then repeat.

## 6. Promotion

After every step passes:

1. Record the tested `CPM3.SYS` SHA-256.
2. Record the complete candidate CF-image SHA-256.
3. Change candidate wording to hardware-tested gold.
4. Preserve the tested system and image under `reference/`.
5. Tag/release the repository.

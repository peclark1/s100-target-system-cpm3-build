# Hardware Acceptance Test

After any source change, do not promote a new gold hash until the following has been run on the physical IMSAI/S-100 system.

## Boot

1. Boot from CF #0.
2. Confirm CP/M 3 reaches the `A>` prompt.
3. Confirm no unexpected DSI bootstrap/access occurs during CP/M startup.

## Read test

```text
DIR A:
DIR B:
DIR C:
DIR D:
```

All four directories must return normally.

## Write test

Use expendable files/media where appropriate.

1. Copy a small file to B: and read it back.
2. Copy a small file from A: to C: and verify it.
3. Copy a small file from A: to D: and verify it.
4. Copy a file D: -> C: and verify the resulting file.
5. Delete test files and confirm directory updates succeed.

## User-area test

Example copying from A: user 1 to C: user 0:

```text
PIP C:[G0]=A:FILE.EXT[G1]
```

## Promotion rule

Only after the physical tests pass:

1. Record the new `CPM3.SYS` SHA-256.
2. Record the complete CF-image SHA-256.
3. Update the gold references and changelog.
4. Tag/release the repository.

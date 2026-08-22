        TITLE   'CP/M 3.0 A/B-ONLY DIAGNOSTIC DRIVE TABLE'
        PUBLIC  @DTBL
        EXTRN   DPH0,DPH1
        MACLIB  CPM3
        CSEG

; Diagnostic table: expose only the two known-good IDE/CF drives.
; C: through P: are deliberately absent so CP/M never sees an FDC+ DPH.
@DTBL:  DTBL    <DPH0,DPH1,0,0,0,0,0,0,0,0,0,0,0,0,0,0>

        END

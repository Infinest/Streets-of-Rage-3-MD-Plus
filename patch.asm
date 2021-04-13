; Build params: ------------------------------------------------------------------------------

JPROM	set 0

	if	JPROM
TRACK_ID_TABLE	set $00000C14
	else
TRACK_ID_TABLE	set $0004AD70
	endif

; Constants: ---------------------------------------------------------------------------------
	MD_PLUS_OVERLAY_PORT:				equ $0003F7FA
	MD_PLUS_CMD_PORT:					equ $0003F7FE
	MD_PLUS_RESPONSE_PORT:				equ $0003F7FC
	
	TRACK_TABLE_LENGTH:					equ $0000001C
	INVALID_TRACK_INDEX:				equ $000000FF

	MUSIC_PLAY_FUNCTION:				equ $001A84F8
	SND_DRIVER_DO_NOTHING:				equ	$001A88EC

	SND_DRIVER_PROCESS_CMD_FUNCTION:	equ $001A826E

	STOP_PAUSE_MUSIC_FUNCTION:			equ $001A8312
	RESUME_MUSIC_FUNCTION:				equ	$001A8466
	FADE_OUT_MUSIC_FUNCTION:			equ $001A8336

	CURRENT_CD_TRACK:					equ $FFFFFD00

; Overrides: ---------------------------------------------------------------------------------

	org SND_DRIVER_PROCESS_CMD_FUNCTION+$1C
	jmp PROCESS_NON_PLAY_COMMANDS_DETOUR

	org MUSIC_PLAY_FUNCTION+$4
	jmp		MUSIC_PLAY_DETOUR
MUSIC_PLAY_FUNCTION_RETURN

; Detours: -----------------------------------------------------------------------------------
	org $2EE000
PROCESS_NON_PLAY_COMMANDS_DETOUR
	tst.b	D0
	bne		NOT_STOP_CMD
	move.w	#$1300,D1						; Move stop command into D1
	jsr		WRITE_MD_PLUS_FUNCTION
	jmp		STOP_PAUSE_MUSIC_FUNCTION
NOT_STOP_CMD
	cmpi.b	#$1,D0
	bne		NOT_FADE_OUT_CMD
	move	#$13FF,D1						; Move stop command with fadeout into D1
	jsr		WRITE_MD_PLUS_FUNCTION
	jmp		FADE_OUT_MUSIC_FUNCTION
NOT_FADE_OUT_CMD
	cmpi.b	#$2,D0
	bne		NOT_RESUME_CMD
	move.b	(CURRENT_CD_TRACK),D1			; Retrieve the last played track from RAM
	cmpi.b	#INVALID_TRACK_INDEX,D1			; Check if it is a valid cd audio track
	beq		RESUME_FM_MUSIC					; If not, we instead try to resume FM music
	move.w	#$1400,D1						; Move resume command into D1
	jsr		WRITE_MD_PLUS_FUNCTION
	jmp		SND_DRIVER_DO_NOTHING			; Make sure the fm sound driver does nothing
RESUME_FM_MUSIC
	jmp		RESUME_MUSIC_FUNCTION
NOT_RESUME_CMD
	jmp		SND_DRIVER_DO_NOTHING			; Make sure the fm sound driver does nothing

MUSIC_PLAY_DETOUR
	move.w	#$1300,D1						; Move stop command into D1
	jsr		WRITE_MD_PLUS_FUNCTION
	andi.w	#$00FF,D0						; Make sure D0 contains just the track pointer
	jsr		GET_TRACK_INDEX_FUNCTION		; Get the track index via D0
	move.b	D1,CURRENT_CD_TRACK				; Always back the last played track up into RAM
	cmpi.b	#INVALID_TRACK_INDEX,D1			; Check if D1 contains a valid cd audio track index
	beq		DO_NOT_PLAY_VIA_MD_PLUS			; If not, play normal FM music
	ori.w	#$1200,D1						; Or play command into D1
	jsr		WRITE_MD_PLUS_FUNCTION
	jmp		STOP_PAUSE_MUSIC_FUNCTION		; Make sure any previously played FM music is silenced
DO_NOT_PLAY_VIA_MD_PLUS
	lsl.w	#$2,D0							; Left shift D0 to get the full track pointer
	jmp		MUSIC_PLAY_FUNCTION_RETURN		; Resume routine for playing FM music

; Helper Functions: --------------------------------------------------------------------------

WRITE_MD_PLUS_FUNCTION:
	move.w  #$CD54,(MD_PLUS_OVERLAY_PORT)	; Open interface
	move.w  D1,(MD_PLUS_CMD_PORT)			; Send command to interface
	move.w  #$0000,(MD_PLUS_OVERLAY_PORT)	; Close interface
	rts

GET_TRACK_INDEX_FUNCTION:
	move	#$FF,D1							; Move $FF into D1 to make sure D1 is 0 on the first loop
	movea.l	#TRACK_ID_TABLE,A1
GET_TRACK_INDEX_LOOP						; Loop until A1+D1 reaches the address of the input track pointer
	addq.b	#$1,D1
	cmpi.b	#TRACK_TABLE_LENGTH,D1
	bhi		GET_TRACK_INDEX_END_REACHED		; If D1 is higher than TRACK_TABLE_LENGTH there are no more valid tracks in the track table
	cmp.b	(A1,D1),D0						; If the value at address A1+D1 match D0 we have found the matching index
	bne		GET_TRACK_INDEX_LOOP
	addi.b	#$1,D1							; Increase D1 by $1 to make sure our track list starts at $1
	rts
GET_TRACK_INDEX_END_REACHED
	move.b	#INVALID_TRACK_INDEX,D1			; Write $FF to D1 and return
	rts
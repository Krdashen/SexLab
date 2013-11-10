scriptname sslActorAlias extends ReferenceAlias

sslActorLibrary property Lib auto

actor property ActorRef auto hidden

ObjectReference MarkerObj
ObjectReference property MarkerRef hidden
	ObjectReference function get()
		if MarkerObj == none && ActorRef != none
			MarkerObj = ActorRef.PlaceAtMe(Lib.BaseMarker)
		endIf
		return MarkerObj
	endFunction
endProperty

bool Active
sslThreadController Controller
sslBaseExpression Expression
sslBaseAnimation Animation
sslBaseVoice Voice

; Voice
float VoiceDelay
bool IsSilent
int VoiceInstance

; Info
bool IsPlayer
bool IsVictim
bool IsFemale
bool IsCreature

; Storage
int strength
int position
int stage
form[] EquipmentStorage
bool[] StripOverride
form strapon
float scale
float[] loc

; Switches
bool disableRagdoll
bool property DoRagdoll hidden
	bool function get()
		if disableRagdoll
			return false
		endIf
		return Lib.bRagDollEnd
	endFunction
endProperty

bool disableundress
bool property DoUndress hidden
	bool function get()
		if disableundress
			return false
		endIf
		return Lib.bUndressAnimation
	endFunction
	function set(bool value)
		disableundress = !value
	endFunction
endProperty

;/-----------------------------------------------\;
;|	Alias Functions                              |;
;\-----------------------------------------------/;

function SetAlias(sslThreadController ThreadView)
	if GetReference() != none
		Initialize()
		TryToStopCombat()
		Controller = ThreadView
		ActorRef = GetReference() as actor
		int gender = Lib.GetGender(ActorRef)
		IsFemale = gender == 1
		IsCreature = gender == 2
		IsPlayer = ActorRef == Lib.PlayerRef
		IsVictim = ActorRef == ThreadView.GetVictim()
	endIf
endFunction

function ClearAlias()
	if GetReference() != none
		TryToClear()
		TryToReset()
		Debug.Trace("SexLab: Clearing Actor Slot of "+ActorRef.GetLeveledActorBase().GetName())
		ActorRef.EvaluatePackage()
		Initialize()
	endIf
endFunction

bool function IsCreature()
	return IsCreature
endFunction

;/-----------------------------------------------\;
;|	Preparation Functions                        |;
;\-----------------------------------------------/;

function LockActor()
	; Start DoNothing package
	ActorRef.AddToFaction(Lib.AnimatingFaction)
	ActorRef.SetFactionRank(Lib.AnimatingFaction, 1)
	ActorRef.EvaluatePackage()
	; Attach positioning marker
	ActorRef.SetVehicle(MarkerRef)
	; Disable movement
	if IsPlayer
		Game.DisablePlayerControls(false, false, false, false, false, false, true, false, 0)
		Game.ForceThirdPerson()
		Game.SetPlayerAIDriven()
		; Game.SetInChargen(true, true, true)
		; Enable hotkeys, if needed
		if IsVictim && Lib.bDisablePlayer
			Controller.AutoAdvance = true
		else
			Lib._HKStart(Controller)
		endIf
	else
		ActorRef.SetRestrained(true)
		ActorRef.SetDontMove(true)
		; ActorRef.SetAnimationVariableBool("bHumanoidFootIKDisable", true)
	endIf
endFunction

function UnlockActor()
	; Enable movement
	if IsPlayer
		Lib._HKClear()
		Game.EnablePlayerControls(false, false, false, false, false, false, true, false, 0)
		Game.SetPlayerAIDriven(false)
		; Game.SetInChargen(false, false, false)
	else
		ActorRef.SetRestrained(false)
		ActorRef.SetDontMove(false)
		; ActorRef.SetAnimationVariableBool("bHumanoidFootIKEnable", true)
	endIf
	; Remove from animation faction
	ActorRef.RemoveFromFaction(Lib.AnimatingFaction)
	ActorRef.EvaluatePackage()
	; Detach positioning marker
	ActorRef.StopTranslation()
	ActorRef.SetVehicle(none)
endFunction

function PrepareActor()
	if IsCreature
		GoToState("Ready")
		return ; Creatures need none of this
	endIf
	; Cleanup
	if ActorRef.IsWeaponDrawn()
		ActorRef.SheatheWeapon()
	endIf
	; Sexual animations only
	if Controller.Animation.IsSexual()
		Strip(DoUndress)
	endIf
	; Scale actor is enabled
	if Controller.ActorCount > 1 && Lib.bScaleActors
		float display = ActorRef.GetScale()
		ActorRef.SetScale(1.0)
		float base = ActorRef.GetScale()
		scale = ( display / base )
		ActorRef.SetScale(1.0 / base)
	endIf
	; Make erect for SOS
	Debug.SendAnimationEvent(ActorRef, "SOSFastErect")
	GoToState("Ready")
endFunction

function ResetActor()
	UnregisterForUpdate()
	if IsCreature
		return ; Creatures need none of this
	endIf
	; Cleanup Actors
	RemoveStrapon()
	; Reset openmouth
	ActorRef.ClearExpressionOverride()
	MfgConsoleFunc.ResetPhonemeModifier(ActorRef)
	; Reset to starting scale
	if Controller.ActorCount > 1 && Lib.bScaleActors && scale > 0.0
		ActorRef.SetScale(scale)
	endIf
	; Make flaccid for SOS
	Debug.SendAnimationEvent(ActorRef, "SOSFlaccid")
	; Unstrip
	if !ActorRef.IsDead()
		Lib.UnstripActor(ActorRef, EquipmentStorage, Controller.GetVictim())
	endIf
endFunction

function EquipStrapon()
	if strapon == none && Lib.HasStrapon(ActorRef)
		return
	elseIf strapon == none
		strapon = Lib.PickStrapon(ActorRef)
	endIf
	if strapon != none && !ActorRef.IsEquipped(strapon)
		;ActorRef.AddItem(strapon, 1, true)
		ActorRef.EquipItem(strapon, false, true)
	endIf
endFunction

function RemoveStrapon()
	if strapon == none || (strapon != none && !ActorRef.IsEquipped(strapon))
		return ; Nothing to remove
	endIf
	ActorRef.UnequipItem(strapon, false, true)
	ActorRef.RemoveItem(strapon, 1, true)
endFunction

;/-----------------------------------------------\;
;|	Manipulation Functions                       |;
;\-----------------------------------------------/;

function StopAnimating(bool quick = false)
	; Reset Idle
	if IsCreature
		; Reset Creature Idle
		Debug.SendAnimationEvent(ActorRef, "Reset")
		Debug.SendAnimationEvent(ActorRef, "ReturnToDefault")
		Debug.SendAnimationEvent(ActorRef, "FNISDefault")
		Debug.SendAnimationEvent(ActorRef, "IdleReturnToDefault")
		Debug.SendAnimationEvent(ActorRef, "ForceFurnExit")
		ActorRef.PushActorAway(ActorRef, 1.0)
	else
		; Reset NPC/PC Idle Quickly
		Debug.SendAnimationEvent(ActorRef, "JumpLand")
		Debug.SendAnimationEvent(ActorRef, "IdleForceDefaultState")
		; Ragdoll NPC/PC if enabled and not in TFC
		if !quick && DoRagdoll && (!IsPlayer || (IsPlayer && Game.GetCameraState() != 3))
			ActorRef.PushActorAway(ActorRef, 1.0)
		endIf
	endIf
endFunction

function AlignTo(float[] offsets)
	float[] centerLoc = Controller.CenterLocation
	loc = new float[6]
	; Determine offsets coordinates from center
	loc[0] = centerLoc[0] + ( Math.sin(centerLoc[5]) * offsets[0] ) + ( Math.cos(centerLoc[5]) * offsets[1] )
	loc[1] = centerLoc[1] + ( Math.cos(centerLoc[5]) * offsets[0] ) + ( Math.sin(centerLoc[5]) * offsets[1] )
	loc[2] = centerLoc[2] + offsets[2]
	loc[3] = centerLoc[3]
	loc[4] = centerLoc[4]
	loc[5] = centerLoc[5] + offsets[3]
	if loc[5] >= 360.0
		loc[5] = loc[5] - 360.0
	elseIf loc[5] < 0.0
		loc[5] = loc[5] + 360.0
	endIf
	MarkerRef.SetPosition(loc[0], loc[1], loc[2])
	MarkerRef.SetAngle(loc[3], loc[4], loc[5])
	ActorRef.SetVehicle(MarkerRef)
	Snap()
endfunction

function Snap()
	if ActorRef == none || MarkerObj == none
		return
	endIf
	; Quickly move into place if actor isn't positioned right
	if ActorRef.GetDistance(MarkerRef) > 0.5
		ActorRef.SplineTranslateTo(loc[0], loc[1], loc[2], loc[3], loc[4], loc[5], 1.0, 50000, 0)
		ActorRef.SetVehicle(MarkerRef)
		Utility.Wait(0.1)
	endIf
	; Force position if translation didn't move them properly
	if ActorRef.GetDistance(MarkerRef) > 1.0
		ActorRef.StopTranslation()
		ActorRef.SetPosition(loc[0], loc[1], loc[2])
		ActorRef.SetVehicle(MarkerRef)
	endIf
	; Force angle if translation didn't rotate them properly
	if Math.Abs(ActorRef.GetAngleZ() - MarkerRef.GetAngleZ()) > 0.5
		ActorRef.StopTranslation()
		ActorRef.SetAngle(loc[3], loc[4], loc[5])
		ActorRef.SetVehicle(MarkerRef)
	endIf
	; Begin very slowly rotating a small amount to hold position
	ActorRef.SplineTranslateTo(loc[0], loc[1], loc[2], loc[3], loc[4], loc[5]+0.1, 1.0, 10000, 0.0001)
endFunction

event OnTranslationComplete()
	Utility.Wait(0.25)
	Snap()
endEvent

function Strip(bool animate = true)
	if IsCreature
		return
	endIf
	bool[] strip
	; Get Strip settings or override
	if StripOverride.Length != 33
		strip = Lib.GetStrip(ActorRef, Controller.GetVictim(), Controller.LeadIn)
	else
		strip = StripOverride
	endIf
	; Strip slots and store removed equipment
	form[] equipment = Lib.StripSlots(ActorRef, strip, animate)
	StoreEquipment(equipment)
endFunction

;/-----------------------------------------------\;
;|	Storage Functions                            |;
;\-----------------------------------------------/;

function DisableRagdollEnd(bool disableIt = true)
	disableragdoll = disableIt
endFunction

function DisableUndressAnim(bool disableIt = true)
	disableundress = disableIt
endFunction

function StoreEquipment(form[] equipment)
	if equipment.Length < 1
		return
	endIf
	; Addon existing storage
	int i
	while i < EquipmentStorage.Length
		equipment = sslUtility.PushForm(EquipmentStorage[i], equipment)
		i += 1
	endWhile
	; Save new storage
	EquipmentStorage = equipment
endFunction

function SyncThread()
	if !Active || Controller == none || ActorRef == none
		return
	endIf
	; Sync from thread
	int toPosition = Controller.GetPosition(ActorRef)
	int toStage = Controller.Stage
	sslBaseAnimation toAnimation = Controller.Animation
	; Update marker postioning
	AlignTo(toAnimation.GetPositionOffsets(toPosition, toStage))
	; Update if needed
	if toPosition != position || toStage != stage || toAnimation != Animation
		; Update thread info
		position = toPosition
		stage = toStage
		Animation = toAnimation
		; Update Strength for voice & expression
		strength = ((stage as float) / (Animation.StageCount() as float) * 100) as int
		if Controller.LeadIn
			strength = ((strength as float) * 0.70) as int
		endIf
		if stage == 1 && Animation.StageCount() == 1
			strength = 70
		endIf
		; Update Silence
		IsSilent = Animation.IsSilent(position, stage)
		if IsSilent || IsCreature
			; VoiceDelay is used as loop timer, must be set even if silent.
			VoiceDelay = 2.5
		else
			; Base Delay
			if !IsFemale
				VoiceDelay = Lib.fMaleVoiceDelay
			else
				VoiceDelay = Lib.fFemaleVoiceDelay
			endIf
			; Stage Delay
			if stage > 1
				VoiceDelay = (VoiceDelay - (stage * 0.8)) + Utility.RandomFloat(-0.3, 0.3)
			endIf
			; Min 1.3 delay
			if VoiceDelay < 1.3
				VoiceDelay = 1.3
			endIf
		endIf
		; Animation related stuffs
		if !IsCreature
			; Send expression
			Expression.ApplyTo(ActorRef, strength, Animation.UseOpenMouth(position, stage))
			; Send SOS event
			if Lib.SOSEnabled && Animation.GetGender(position) == 0
				Debug.SendAnimationEvent(ActorRef, "SOSFastErect")
				int offset = Animation.GetSchlong(position, stage)
				string bend
				if offset < 0
					bend = "SOSBendDown0"+((Math.Abs(offset) / 2) as int)
				elseif offset > 0
					bend = "SOSBendUp0"+((Math.Abs(offset) / 2) as int)
				else
					bend = "SOSNoBend"
				endIf
				Debug.SendAnimationEvent(ActorRef, bend)
				string name = ActorRef.GetLeveledActorBase().GetName()
				;Debug.Notification(name+" Offset["+offset+"]: "+bend)
				;Debug.Trace(name+" Offset: SOSBend"+offset+ ": Sent -> "+bend)
				; Debug.SendAnimationEvent(ActorRef, "SOSBend"+offset)
			endif
			; Equip Strapon if needed
			if IsFemale && Lib.bUseStrapons && Animation.UseStrapon(position, stage)
				EquipStrapon()
			; Remove strapon if there is one
			elseIf strapon != none
				RemoveStrapon()
			endIf
		endIf
	endIf
endFunction

function OverrideStrip(bool[] setStrip)
	if setStrip.Length != 33
		return
	endIf
	StripOverride = setStrip
endFunction

function SetVoice(sslBaseVoice toVoice)
	Voice = toVoice
endFunction
sslBaseVoice function GetVoice()
	return Voice
endFunction

function SetExpression(sslBaseExpression toExpression)
	Expression = toExpression
endFunction
sslBaseExpression function GetExpression()
	return Expression
endFunction

;/-----------------------------------------------\;
;|	Animation/Voice Loop                         |;
;\-----------------------------------------------/;

state Ready
	event OnBeginState()
		UnregisterForUpdate()
	endEvent
	function StartAnimating()
		Active = true
		SyncThread()
		GoToState("Animating")
		RegisterForSingleUpdate(Utility.RandomFloat(0.0, 0.8))
	endFunction
endState

state Animating
	event OnUpdate()
		if ActorRef.IsDead() || ActorRef.IsDisabled()
			Controller.EndAnimation(true)
			return
		endIf
		RegisterForSingleUpdate(VoiceDelay)
		if IsCreature || IsSilent || Voice == none
			return
		endIf
		if VoiceInstance > 0
			Sound.StopInstance(VoiceInstance)
		endIf
		Expression.ClearMFG(ActorRef)
		VoiceInstance = Voice.Moan(ActorRef, strength, IsVictim)
		Sound.SetInstanceVolume(VoiceInstance, Lib.fVoiceVolume)
		Expression.ApplyTo(ActorRef, strength)
	endEvent
endState

;/-----------------------------------------------\;
;|	Actor Callbacks                              |;
;\-----------------------------------------------/;

event OnStartThread(string eventName, string argString, float argNum, form sender)
	UnregisterForModEvent("StartThread")
	LockActor()
	PrepareActor()
endEvent

event OnEndThread(string eventName, string argString, float argNum, form sender)
	UnregisterForModEvent("EndThread")
	UnregisterForUpdate()
	; Update diary/journal stats for player
	if IsPlayer
		int[] genders = Lib.GenderCount(Controller.Positions)
		Lib.Stats.UpdatePlayerStats(genders[0], genders[1], genders[2], Animation, Controller.GetVictim(), Controller.GetTime())
	elseIf Controller.HasPlayer
		Lib.Stats.SexWithPlayer(ActorRef)
	endIf
	; Reset actor
	bool quick = (argNum as bool)
	UnlockActor()
	StopAnimating(quick)
	ResetActor()
	; Apply cum
	int cum = Animation.GetCum(position)
	if !quick && cum > 0 && Lib.bUseCum && (Lib.bAllowFFCum || Controller.HasCreature || Lib.MaleCount(Controller.Positions) > 0)
		Lib.ApplyCum(ActorRef, cum)
	endIf
	; Free up alias slot
	ClearAlias()
	Utility.Wait(0.5)
	Initialize()
endEvent

;/-----------------------------------------------\;
;|	Misc Functions                               |;
;\-----------------------------------------------/;

function Initialize()
	; Clear events
	UnregisterForUpdate()
	UnregisterForAllModEvents()
	GoToState("")
	; Clear marker snapping
	if ActorRef != none
		ActorRef.StopTranslation()
		ActorRef.SetVehicle(none)
	endIf
	if MarkerObj != none
		MarkerObj.Disable()
		MarkerObj.Delete()
	endIf
	; Clear storage
	MarkerObj = none
	ActorRef = none
	Active = false
	Controller = none
	Voice = none
	Animation = none
	Expression = none
	strapon = none
	scale = 0.0
	position = 0
	stage = 0
	form[] formDel
	EquipmentStorage = formDel
	bool[] boolDel
	StripOverride = boolDel
endFunction


function StartAnimating()
	;Debug.TraceAndbox("Null start: "+ActorRef)
endFunction

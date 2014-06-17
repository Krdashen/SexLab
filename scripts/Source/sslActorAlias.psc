scriptname sslActorAlias extends ReferenceAlias

import sslUtility

; Settings access
sslSystemConfig Config

; Framework access
Actor PlayerRef
sslActorStats Stats
sslActorLibrary ActorLib
sslVoiceSlots VoiceSlots
sslExpressionSlots ExpressionSlots

; Actor Info
Actor property ActorRef auto hidden
ActorBase BaseRef
string ActorName
int BaseSex
int Gender
bool IsMale
bool IsFemale
bool IsCreature
bool IsVictim
bool IsPlayer
bool IsTracked

; Current Thread state
sslThreadController Thread
int Position
int Stage

; Animation
sslBaseAnimation Animation
string AdjustKey

; Voice
sslBaseVoice Voice
VoiceType ActorVoice
bool IsForcedSilent
float VoiceDelay

; Expression
sslBaseExpression Expression

; Positioning
ObjectReference MarkerRef
; float[] Offsets
float[] Loc

; Storage
int[] Flags
bool[] StripOverride
form[] Equipment
float ActorScale
float AnimScale
form Strapon
int HighestRelation
; Stats
float[] Skills
int Enjoyment

; Animation Position/Stage flags
bool property OpenMouth hidden
	bool function get()
		return Flags[1] == 1
	endFunction
endProperty
bool property IsSilent hidden
	bool function get()
		return Voice == none || IsForcedSilent || IsCreature || Flags[0] == 1 || Flags[1] == 1
	endFunction
endProperty
bool property UseStrapon hidden
	bool function get()
		return Flags[2] == 1 && Flags[4] == 0
	endFunction
endProperty
int property Schlong hidden
	int function get()
		return Flags[3]
	endFunction
endProperty
bool property MalePosition hidden
	bool function get()
		return Flags[4] == 0
	endFunction
endProperty

; ------------------------------------------------------- ;
; --- Load/Clear Alias For Use                        --- ;
; ------------------------------------------------------- ;

bool function SetActor(Actor ProspectRef, bool Victimize = false, sslBaseVoice UseVoice = none, bool ForceSilent = false)
	if ProspectRef == none || ProspectRef != GetReference()
		return false ; Failed to set prospective actor into alias
	endIf
	; Init actor alias information
	ActorRef   = ProspectRef
	BaseRef    = ActorRef.GetLeveledActorBase()
	ActorName  = BaseRef.GetName()
	BaseSex    = BaseRef.GetSex()
	Gender     = ActorLib.GetGender(ActorRef)
	IsMale     = Gender == 0
	IsFemale   = Gender == 1
	IsCreature = Gender == 2
	IsVictim   = Victimize
	IsPlayer   = ActorRef == PlayerRef
	IsTracked  = Config.ThreadLib.IsActorTracked(ActorRef)
	ActorVoice = BaseRef.GetVoiceType()
	if !IsCreature
		SetVoice(UseVoice, ForceSilent)
		if !IsPlayer
			Stats.SeedActor(ActorRef)
		endIf
	else
		Thread.CreatureRef = BaseRef.GetRace()
	endIf
	if IsTracked
		Thread.SendTrackedEvent(ActorRef, "Added", Thread.tid)
	endif
	; Update threads gender
	Thread.Genders[Gender] = Thread.Genders[Gender] + 1
	; Get ready for mod events
	RegisterEvents()
	; Ready
	Log("Slotted '"+ActorName+"'", self)
	GoToState("Ready")
	return true
endFunction

function ClearAlias()
	; Maybe got here prematurely, give it 10 seconds before forcing the clear
	if GetState() == "Resetting"
		float Failsafe = Utility.GetCurrentRealTime() + 10.0
		while GetState() == "Resetting" && Utility.GetCurrentRealTime() < Failsafe
			Utility.WaitMenuMode(0.2)
		endWhile
	endIf
	; Make sure actor is reset
	if GetReference() != none
		; Init variables needed for reset
		ActorRef   = GetReference() as Actor
		BaseRef    = ActorRef.GetLeveledActorBase()
		ActorName  = BaseRef.GetName()
		BaseSex    = BaseRef.GetSex()
		Gender     = ActorLib.GetGender(ActorRef)
		IsMale     = Gender == 0
		IsFemale   = Gender == 1
		IsCreature = Gender == 2
		IsPlayer   = ActorRef == PlayerRef
		Log("'"+ActorName+"' / '"+ActorRef+"' present during alias clear! This is usually harmless as the alias and actor will correct itself, but is usually a sign that a thread did not close cleanly.", self)
		; Reset actor back to default
		RestoreActorDefaults()
		StopAnimating(true)
		UnlockActor()
		Unstrip()
	endIf
	Initialize()
endFunction

; ------------------------------------------------------- ;
; --- Actor Prepartion                                --- ;
; ------------------------------------------------------- ;

state Ready

	bool function SetActor(Actor ProspectRef, bool MakeVictim = false, sslBaseVoice UseVoice = none, bool ForceSilent = false)
		return false
	endFunction

	function PrepareActor()
		; Thread.Log("Preparing", ActorName)
		; Remove any unwanted combat effects
		ActorRef.StopCombat()
		if ActorRef.IsWeaponDrawn()
			ActorRef.SheatheWeapon()
		endIf
		; Calculate scales
		float display = ActorRef.GetScale()
		ActorRef.SetScale(1.0)
		float base = ActorRef.GetScale()
		ActorScale = ( display / base )
		AnimScale = ActorScale
		ActorRef.SetScale(ActorScale)
		if Thread.ActorCount > 1 && Config.ScaleActors
			AnimScale = (1.0 / base)
		endIf
		; Stop movement
		LockActor()
		; Strip non creatures
		if !IsCreature
			; Pick a strapon on females to use
			if IsFemale && Config.UseStrapons && Config.Strapons.Length > 0
				Strapon = Config.GetStrapon()
				; ActorRef.AddItem(Strapon, 1, true)
			endIf
			; Strip actor
			Strip()
			; Pick a voice if needed
			if Voice == none && !IsForcedSilent
				SetVoice(VoiceSlots.PickVoice(ActorRef), IsForcedSilent)
			endIf
			; Pick an expression if needed
			if Expression == none && Config.UseExpressions
				Expression = ExpressionSlots.PickExpression(ActorRef, Thread.VictimRef)
			endIf
			; Always use players stats if present, so players stats mean something more for npcs
			Actor SkilledActor = ActorRef
			if !IsPlayer && Thread.HasPlayer
				SkilledActor = PlayerRef
			; If a non-creature couple, base skills off partner
			elseIf Thread.ActorCount == 2 && !Thread.HasCreature
				SkilledActor = Thread.Positions[IndexTravel(Thread.Positions.Find(ActorRef), Thread.ActorCount)]
			endIf
			Skills = Stats.GetSkillLevels(SkilledActor)
			; Thread.Log(SkilledActor.GetLeveledActorBase().GetName()+" Skills: "+Skills, ActorName)
			; Get highest relationship ahead of time
			HighestRelation = Thread.GetHighestPresentRelationshipRank(ActorRef)
			; Start Auto TFC if enabled
			if IsPlayer && Config.AutoTFC && Game.GetCameraState() != 3
				Config.ToggleFreeCamera()
			endIf
		endIf
		; Enter animatable state - rest is non vital and can finish as queued
		Debug.SendAnimationEvent(ActorRef, "IdleForceDefaultState")
		Debug.SendAnimationEvent(ActorRef, "SOSFastErect")
		GoToState("Animating")
		Thread.AliasEventDone("Prepare")
	endFunction
endState

; ------------------------------------------------------- ;
; --- Animation Loop                                  --- ;
; ------------------------------------------------------- ;

state Animating

	function StartAnimating()
		; Position / fix SOS side bend
		Utility.Wait(0.2)
		SyncThread()
		SyncLocation(true)
		ActorRef.StopTranslation()
		ActorRef.SplineTranslateTo(Loc[0], Loc[1], Loc[2], Loc[3], Loc[4], Loc[5], 1.0, 50000, 0)
		if IsTracked
			Thread.SendTrackedEvent(ActorRef, "Start", Thread.tid)
		endif
		; Start update loop
		RegisterForSingleUpdate(Utility.RandomFloat(1.5, 3.0))
	endFunction

	event OnUpdate()
		; Check if still amonst the living and able.
		if ActorRef.GetActorValue("Health") < 1.0 || ActorRef.IsDisabled() ;|| !ActorRef.Is3DLoaded()
			Log("Actor is disabled or has no health, unable to continue animating", ActorName)
			Thread.EndAnimation(true)
			return
		endIf
		; Ping thread to update skill xp
		if Position == 0
			Thread.RecordSkills()
			Thread.SetBonuses()
		endIf
		; Sync enjoyment level
		GetEnjoyment()
		; Apply Expression / sync enjoyment
		if !IsCreature && Expression != none && !OpenMouth
			Expression.Apply(ActorRef, Enjoyment, BaseSex)
		endIf
		; Moan if not silent
		if !IsSilent
			Voice.Moan(ActorRef, Enjoyment, IsVictim)
		endIf
		; Loop
		RegisterForSingleUpdate(VoiceDelay)
	endEvent

	function SyncActor()
		SyncThread()
		SyncLocation(false)
		Thread.AliasEventDone("Sync")
	endFunction

	function SyncThread()
		; Sync thread information
		Animation  = Thread.Animation
		Stage      = Thread.Stage
		Position   = Thread.Positions.Find(ActorRef)
		AdjustKey  = Thread.AdjustKey
		Flags      = Animation.GetPositionFlags(AdjustKey, Position, Stage)
		VoiceDelay = Config.GetVoiceDelay(IsFemale, Stage, IsSilent)
		; Creature skipped
		if !IsCreature
			; Sync enjoyment level
			GetEnjoyment()
			; Equip Strapon if needed and enabled
			if Strapon != none
				if UseStrapon && !ActorRef.IsEquipped(Strapon)
					ActorRef.EquipItem(Strapon, true, true)
				elseif !UseStrapon && ActorRef.IsEquipped(Strapon)
					ActorRef.UnequipItem(Strapon, true, true)
				endIf
			endIf
			; Clear any existing expression as a default - to remove open mouth
			ActorRef.ClearExpressionOverride()
			if OpenMouth
				; Open mouth if needed
				sslBaseExpression.OpenMouth(ActorRef)
			elseIf Expression != none
				; Apply expression otherwise - overrides open mouth
				Expression.Apply(ActorRef, Enjoyment, BaseSex)
			else
				; No expression to override but mouth might be open - close it
				sslBaseExpression.CloseMouth(ActorRef)
			endIf
		endIf
		; Send schlong offset
		if MalePosition
			Debug.SendAnimationEvent(ActorRef, "SOSBend"+Schlong)
		endIf
	endFunction

	function UpdateOffsets()
		SyncLocation(true)
	endFunction

	function RefreshLoc()
		ActorRef.SplineTranslateTo(Loc[0], Loc[1], Loc[2], Loc[3], Loc[4], Loc[5], 1.0, 10000, 0)
	endFunction

	function SyncLocation(bool Force = false)
		; Set Loc Array to offset coordinates
		OffsetCoords(Loc, Thread.CenterLocation, Animation.GetPositionOffsets(AdjustKey, Position, Stage))
		; Set marker/actor to Loc
		MarkerRef.SetPosition(Loc[0], Loc[1], Loc[2])
		MarkerRef.SetAngle(Loc[3], Loc[4], Loc[5])
		if Force
			ActorRef.SetPosition(Loc[0], Loc[1], Loc[2])
			ActorRef.SetAngle(Loc[3], Loc[4], Loc[5])
		endIf
		ActorRef.SetVehicle(MarkerRef)
		ActorRef.SetScale(AnimScale)
		Snap()
	endFunction

	function Snap()
		; Quickly move into place and angle if actor is off by a lot
		float distance = ActorRef.GetDistance(MarkerRef)
		if distance > 50.0 || ((Math.Abs(ActorRef.GetAngleZ() - MarkerRef.GetAngleZ())) > 1.0)
			ActorRef.SetPosition(Loc[0], Loc[1], Loc[2])
			ActorRef.SetAngle(Loc[3], Loc[4], Loc[5])
			ActorRef.SetVehicle(MarkerRef)
			ActorRef.SetScale(AnimScale)
		elseIf distance > 0.3
			ActorRef.SplineTranslateTo(Loc[0], Loc[1], Loc[2], Loc[3], Loc[4], Loc[5], 1.0, 50000, 0)
			return ; OnTranslationComplete() will take over when in place
		endIf
		; Begin very slowly rotating a small amount to hold position
		ActorRef.SplineTranslateTo(Loc[0], Loc[1], Loc[2], Loc[3], Loc[4], Loc[5]+0.01, 1.0, 10000, 0.001)
	endFunction

	event OnTranslationComplete()
		Utility.Wait(0.5)
		Snap()
	endEvent

	function OrgasmEffect()
		; Apply cum
		int CumID = Animation.GetCum(Position)
		if CumID > 0 && Config.UseCum && (Thread.Males > 0 || Config.AllowFFCum || Thread.HasCreature)
			ActorLib.ApplyCum(ActorRef, CumID)
		endIf
		; Shake camera for player
		if IsPlayer && Game.GetCameraState() != 3
			Game.ShakeCamera(none, 0.75, 1.5)
		endIf
		; Play
		Config.OrgasmFX.Play(ActorRef)
		VoiceDelay = 0.8
		; Notify thread of finish
		Thread.AliasEventDone("Orgasm")
		RegisterForSingleUpdate(VoiceDelay)
	endFunction

	event ResetActor()
		GoToState("Resetting")
		UnregisterForUpdate()
		ClearEvents()
		; Update stats
		if !IsCreature
			Stats.RecordThread(ActorRef, Thread.HasPlayer, Thread.ActorCount, HighestRelation, Thread.TotalTime, Thread.VictimRef, Thread.SkillXP, Thread.Genders)
			; Stats.AddSkillXP(ActorRef, SkillXP[0], SkillXP[1], SkillXP[2], SkillXP[3])
			; Stats.AddPurityXP(ActorRef, Skills[4], SkillXP[5], Thread.IsAggressive, IsVictim, Genders[2] > 0, Thread.ActorCount, Thread.GetHighestPresentRelationshipRank(ActorRef))
			; Stats.AddSex(ActorRef, Thread.TotalTime, Thread.HasPlayer, Thread.IsAggressive, Genders[0], Genders[1], Genders[2])
		endIf
		; Clear TFC
		if IsPlayer && Game.GetCameraState() == 3
			Config.ToggleFreeCamera()
		endIf
		; Apply cum
		int CumID = Animation.GetCum(Position)
		if !Thread.FastEnd && CumID > 0 && Config.UseCum && (Thread.Males > 0 || Config.AllowFFCum || Thread.HasCreature)
			ActorLib.ApplyCum(ActorRef, CumID)
		endIf
		; Tracked events
		if IsTracked
			Thread.SendTrackedEvent(ActorRef, "End", Thread.tid)
		endif
		; Restore actor to starting point
		RestoreActorDefaults()
		StopAnimating(Thread.FastEnd)
		UnlockActor()
		; Unstrip items in storage, if any
		if !ActorRef.IsDead()
			Unstrip()
		endIf
		; Reset alias
		TryToClear()
		Initialize()
		Thread.AliasEventDone("Reset")
	endEvent

	int function GetEnjoyment()
		if IsCreature
			Enjoyment = (ClampFloat(Thread.TotalTime / 6.0, 0.0, 40.0) + ((Stage as float / Animation.StageCount as float) * 60.0)) as int
			return Enjoyment
		endIf
		Enjoyment = CalcEnjoyment(Thread.SkillBonus, Skills, Thread.LeadIn, IsFemale, Thread.TotalTime, Stage, Animation.StageCount)
		return Enjoyment
	endFunction

	int function GetPain()
		float Pain = Math.Abs(100.0 - ClampFloat(GetEnjoyment() as float, 1.0, 99.0))
		if IsVictim
			return (Pain * 1.5) as int
		endIf
		return (Pain * 0.5) as int
	endFunction

endState

state Resetting
	event OnUpdate()
	endEvent
endState

; ------------------------------------------------------- ;
; --- Actor Manipulation                              --- ;
; ------------------------------------------------------- ;

function StopAnimating(bool Quick = false)
	if ActorRef == none
		return
	endIf
	; Disable free camera, if in it
	if IsPlayer && Game.GetCameraState() == 3
		Config.ToggleFreeCamera()
	endIf
	if IsCreature
		; Reset creature idle
		Debug.SendAnimationEvent(ActorRef, "Reset")
		Debug.SendAnimationEvent(ActorRef, "ReturnToDefault")
		Debug.SendAnimationEvent(ActorRef, "FNISDefault")
		Debug.SendAnimationEvent(ActorRef, "IdleReturnToDefault")
		Debug.SendAnimationEvent(ActorRef, "ForceFurnExit")
		ActorRef.PushActorAway(ActorRef, 0.75)
	else
		; Reset NPC/PC Idle Quickly
		Debug.SendAnimationEvent(ActorRef, "IdleForceDefaultState")
		; Ragdoll NPC/PC if enabled and not in TFC
		if !Quick && DoRagdoll && (!IsPlayer || (IsPlayer && Game.GetCameraState() != 3))
			ActorRef.StopTranslation()
			ActorRef.SetPosition(Loc[0], Loc[1], Loc[2])
			ActorRef.SetAngle(Loc[3], Loc[4], Loc[5])
			ActorRef.PushActorAway(ActorRef, 0.1)
		endIf
	endIf
endFunction

function LockActor()
	if ActorRef == none
		return
	endIf
	; Stop whatever they are doing
	Debug.SendAnimationEvent(ActorRef, "IdleForceDefaultState")
	; Start DoNothing package
	ActorRef.SetFactionRank(Config.AnimatingFaction, 1)
	; ActorUtil.AddPackageOverride(ActorRef, Config.DoNothing, 100, 1)
	ActorRef.EvaluatePackage()
	; Disable movement
	if IsPlayer
		Game.ForceThirdPerson()
		; Game.DisablePlayerControls(false, false, false, false, false, false, true, false, 0)
		Game.SetPlayerAIDriven()
		; Enable hotkeys, if needed
		if !(IsVictim && Config.DisablePlayer)
			Thread.EnableHotkeys()
		endIf
	else
		ActorRef.SetDontMove(true)
	endIf
	; Attach positioning marker
	if !MarkerRef
		MarkerRef = ActorRef.PlaceAtMe(Config.BaseMarker)
	endIf
	MarkerRef.Enable()
	MarkerRef.MoveTo(ActorRef)
	ActorRef.StopTranslation()
	ActorRef.SetVehicle(MarkerRef)
endFunction

function UnlockActor()
	if ActorRef == none
		return
	endIf
	; Detach positioning marker
	ActorRef.StopTranslation()
	ActorRef.SetVehicle(none)
	; Remove from animation faction
	ActorRef.RemoveFromFaction(Config.AnimatingFaction)
	ActorUtil.RemovePackageOverride(ActorRef, Config.DoNothing)
	ActorRef.EvaluatePackage()
	; Enable movement
	if IsPlayer
		; Disable free camera, if in it
		if Game.GetCameraState() == 3
			Config.ToggleFreeCamera()
		endIf
		Thread.DisableHotkeys()
		Game.EnablePlayerControls()
		Game.SetPlayerAIDriven(false)
	else
		ActorRef.SetDontMove(false)
	endIf
endFunction

function RestoreActorDefaults()
	if GetReference() == none && ActorRef == none
		return
	endIf
	; Make sure we have actor, can't afford to miss this block
	ActorRef = GetReference() as Actor
	; Reset to starting scale
	if ActorScale != 0.0
		ActorRef.SetScale(ActorScale)
	endIf
	if !IsCreature
		; Reset expression
		ActorRef.ClearExpressionOverride()
		MfgConsoleFunc.ResetPhonemeModifier(ActorRef)
		if ActorVoice != none && ActorVoice != BaseRef.GetVoiceType()
			BaseRef.SetVoiceType(ActorVoice)
		endIf
		; Remove strapon
		if Strapon != none
			ActorRef.UnequipItem(Strapon, true, true)
			ActorRef.RemoveItem(Strapon, 1, true)
		endIf
	endIf
	; Remove SOS erection
	Debug.SendAnimationEvent(ActorRef, "SOSFlaccid")
endFunction

; ------------------------------------------------------- ;
; --- Data Accessors                                  --- ;
; ------------------------------------------------------- ;

function SetVoice(sslBaseVoice ToVoice = none, bool ForceSilence = false)
	IsForcedSilent = ForceSilence
	if ToVoice != none
		Voice = ToVoice
		; Set voicetype if unreconized
		if Config.UseLipSync && !Config.SexLabVoices.HasForm(ActorVoice)
			if BaseSex == 1
				BaseRef.SetVoiceType(Config.SexLabVoiceF)
			else
				BaseRef.SetVoiceType(Config.SexLabVoiceM)
			endIf
		endIf
	endIf
endFunction

sslBaseVoice function GetVoice()
	return Voice
endFunction

function SetExpression(sslBaseExpression ToExpression)
	if ToExpression != none
		Expression = ToExpression
	endIf
endFunction

sslBaseExpression function GetExpression()
	return Expression
endFunction

function EquipStrapon()
	if Strapon != none && !ActorRef.IsEquipped(Strapon)
		ActorRef.EquipItem(Strapon, true, true)
	endIf
endFunction

function UnequipStrapon()
	if Strapon != none && ActorRef.IsEquipped(Strapon)
		ActorRef.UnequipItem(Strapon, true, true)
	endIf
endFunction

function OverrideStrip(bool[] SetStrip)
	if SetStrip.Length != 33
		Thread.Log(ActorName+" -- Invalid strip bool override array given. Must be length 33; was given "+SetStrip.Length, "ERROR")
	else
		StripOverride = SetStrip
	endIf
endFunction

function Strip()
	if ActorRef == none || IsCreature
		return
	endIf
	; Start stripping animation
	if DoUndress
		Debug.SendAnimationEvent(ActorRef, "Arrok_Undress_G"+BaseSex)
		NoUndress = true
	endIf
	; Select stripping array
	bool[] Strip
	if StripOverride.Length == 33
		Strip = StripOverride
	else
		Strip = Config.GetStrip(IsFemale, Thread.LeadIn, Thread.IsAggressive, IsVictim)
	endIf
	; Get Nudesuit
	bool UseNudeSuit = Strip[2] && ((Gender == 0 && Config.UseMaleNudeSuit) || (Gender == 1 && Config.UseFemaleNudeSuit))
	if UseNudeSuit && ActorRef.GetItemCount(Config.NudeSuit) < 1
		; ActorRef.AddItem(Config.NudeSuit, 1, true)
	endIf
	; Stripped storage
	Form[] Stripped = new Form[34]
	Form ItemRef
	; Strip Weapon
	if Strip[32]
		; Right hand
		ItemRef = ActorRef.GetEquippedWeapon(false)
		if ItemRef && !SexLabUtil.HasKeywordSub(ItemRef, "NoStrip")
			ActorRef.UnequipItemEX(ItemRef, 1, false)
			Stripped[33] = ItemRef
		endIf
		; Left hand
		ItemRef = ActorRef.GetEquippedWeapon(true)
		if ItemRef && !SexLabUtil.HasKeywordSub(ItemRef, "NoStrip")
			ActorRef.UnequipItemEX(ItemRef, 2, false)
			Stripped[32] = ItemRef
		endIf
	endIf
	; Strip armor slots
	int i = Strip.RFind(true, 31)
	while i >= 0
		if Strip[i]
			; Grab item in slot
			ItemRef = ActorRef.GetWornForm(Armor.GetMaskForSlot(i + 30))
			if ItemRef && !SexLabUtil.HasKeywordSub(ItemRef, "NoStrip")
				ActorRef.UnequipItem(ItemRef, false, true)
				Stripped[i] = ItemRef
			endIf
		endIf
		; Move to next slot
		i -= 1
	endWhile
	; Equip the nudesuit
	if UseNudeSuit
		ActorRef.EquipItem(Config.NudeSuit, true, true)
	endIf
	; Store stripped items
	Equipment = MergeFormArray(ClearNone(Stripped), Equipment)
endFunction

function UnStrip()
 	if ActorRef == none || IsCreature || Equipment.Length == 0
 		return
 	endIf
	; Remove nudesuit if present
	if ActorRef.GetItemCount(Config.NudeSuit) > 0
		ActorRef.UnequipItem(Config.NudeSuit, true, true)
		ActorRef.RemoveItem(Config.NudeSuit, ActorRef.GetItemCount(Config.NudeSuit), true)
	endIf
	; Continue with undress, or am I disabled?
 	if !DoRedress
 		return ; Fuck clothes, bitch.
 	endIf
 	; Equip Stripped
 	int hand = 1
 	int i = Equipment.Length
 	while i
 		i -= 1
 		if Equipment[i] != none
 			int type = Equipment[i].GetType()
 			if type == 22 || type == 82
 				ActorRef.EquipSpell((Equipment[i] as Spell), hand)
 			else
 				ActorRef.EquipItem(Equipment[i], false, true)
 			endIf
 			; Move to other hand if weapon, light, spell, or leveledspell
 			hand -= ((hand == 1 && (type == 41 || type == 31 || type == 22 || type == 82)) as int)
  		endIf
 	endWhile
endFunction

bool NoRagdoll
bool property DoRagdoll hidden
	bool function get()
		if NoRagdoll
			return false
		endIf
		return !NoRagdoll && Config.RagdollEnd
	endFunction
	function set(bool value)
		NoRagdoll = !value
	endFunction
endProperty

bool NoUndress
bool property DoUndress hidden
	bool function get()
		if NoUndress
			return false
		endIf
		return Config.UndressAnimation
	endFunction
	function set(bool value)
		NoUndress = !value
	endFunction
endProperty

bool NoRedress
bool property DoRedress hidden
	bool function get()
		if NoRedress || (IsVictim && !Config.RedressVictim)
			return false
		endIf
		return !IsVictim || (IsVictim && Config.RedressVictim)
	endFunction
	function set(bool value)
		NoRedress = !value
	endFunction
endProperty

; ------------------------------------------------------- ;
; --- System Use                                      --- ;
; ------------------------------------------------------- ;

function RegisterEvents()
	string e = Thread.Key("")
	RegisterForModEvent(e+"Prepare", "PrepareActor")
	RegisterForModEvent(e+"Reset", "ResetActor")
	RegisterForModEvent(e+"Sync", "SyncActor")
	RegisterForModEvent(e+"Orgasm", "OrgasmEffect")
	RegisterForModEvent(e+"Strip", "Strip")
endFunction

function ClearEvents()
	GoToState("")
	UnregisterForUpdate()
	string e = Thread.Key("")
	UnregisterForModEvent(e+"Prepare")
	UnregisterForModEvent(e+"Reset")
	UnregisterForModEvent(e+"Sync")
	UnregisterForModEvent(e+"Orgasm")
	UnregisterForModEvent(e+"Strip")
endFunction

function Initialize()
	; Stop events
	ClearEvents()
	; Clear actor
	if ActorRef != none
		; Remove nudesuit if present
		if ActorRef.GetItemCount(Config.NudeSuit) > 0
			ActorRef.UnequipItem(Config.NudeSuit, true, true)
			ActorRef.RemoveItem(Config.NudeSuit, ActorRef.GetItemCount(Config.NudeSuit), true)
		endIf
	endIf
	; Delete positioning marker
	if MarkerRef != none
		MarkerRef.Disable()
		MarkerRef.Delete()
	endIf
	; Forms
	ActorRef       = none
	MarkerRef      = none
	Strapon        = none
	; Voice
	Voice          = none
	ActorVoice     = none
	IsForcedSilent = false
	; Expression
	Expression     = none
	; Flags
	NoRagdoll      = false
	NoUndress      = false
	NoRedress      = false
	; Floats
	ActorScale     = 0.0
	AnimScale      = 0.0
	; Storage
	StripOverride  = BoolArray(0)
	Equipment      = FormArray(0)
	Loc            = new float[6]
	; Make sure alias is emptied
	TryToClear()
endFunction

function Setup()
	; init libraries
	SexLabFramework SexLab = Game.GetFormFromFile(0xD62, "SexLab.esm") as SexLabFramework
	PlayerRef       = SexLab.PlayerRef
	Config          = SexLab.Config
	ActorLib        = SexLab.ActorLib
	Stats           = SexLab.Stats
	VoiceSlots      = SexLab.VoiceSlots
	ExpressionSlots = SexLab.ExpressionSlots
	; init alias settings
	Thread = GetOwningQuest() as sslThreadController
	Initialize()
endFunction

function Log(string Log, string Type = "NOTICE")
	SexLabUtil.DebugLog(Log, Type, Config.DebugMode)
endFunction

bool function TestAlias()
	return PlayerRef && Config && ActorLib && Stats && VoiceSlots && ExpressionSlots && Thread
endFunction

; ------------------------------------------------------- ;
; --- State Restricted                                --- ;
; ------------------------------------------------------- ;

; Ready
function PrepareActor()
endFunction
; Animating
function StartAnimating()
endFunction
function SyncActor()
endFunction
function SyncThread()
endFunction
function UpdateOffsets()
endFunction
function SyncLocation(bool Force = false)
endFunction
function RefreshLoc()
endFunction
function Snap()
endFunction
event OnTranslationComplete()
endEvent
function OrgasmEffect()
endFunction
event ResetActor()
endEvent
event OnOrgasm()
endEvent
int function GetEnjoyment()
	return 0
endFunction
int function GetPain()
	return 0
endFunction


int function CalcEnjoyment(float[] XP, float[] SkillsAmounts, bool IsLeadin, bool IsFemaleActor, float Timer, int OnStage, int MaxStage) global native
function OffsetCoords(float[] Output, float[] CenterCoords, float[] OffsetBy) global native

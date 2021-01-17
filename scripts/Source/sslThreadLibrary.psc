scriptname sslThreadLibrary extends sslSystemLibrary

import StorageUtil

; Data
FormList property BedsList auto hidden
FormList property DoubleBedsList auto hidden
FormList property BedRollsList auto hidden
Keyword property FurnitureBedRoll auto hidden

; ------------------------------------------------------- ;
; --- Object Locators                                 --- ;
; ------------------------------------------------------- ;

bool function CheckActor(Actor CheckRef, int CheckGender = -1)
	if !CheckRef
		return false ; Invalid args
	endIf
	int IsGender = ActorLib.GetGender(CheckRef)
	return ((CheckGender < 2 && IsGender < 2) || (CheckGender >= 2 && IsGender >= 2)) && (CheckGender == -1 || IsGender == CheckGender) && ActorLib.IsValidActor(CheckRef)
endFunction

Actor function FindAvailableActor(ObjectReference CenterRef, float Radius = 5000.0, int FindGender = -1, Actor IgnoreRef1 = none, Actor IgnoreRef2 = none, Actor IgnoreRef3 = none, Actor IgnoreRef4 = none, string RaceKey = "")
	if !CenterRef || FindGender > 3 || FindGender < -1 || Radius < 0.1
		return none ; Invalid args
	endIf
	; Normalize creature genders search
	if RaceKey != "" || FindGender >= 2
		if FindGender == 0 || !Config.UseCreatureGender
			FindGender = 2
		elseIf FindGender == 1
			FindGender = 3
		endIf
	endIf
	; Create supression list
	Form[] Suppressed = new Form[25]
	Suppressed[24] = CenterRef
	Suppressed[23] = IgnoreRef1
	Suppressed[22] = IgnoreRef2
	Suppressed[21] = IgnoreRef3
	Suppressed[20] = IgnoreRef4
	; Attempt 20 times before giving up.
	int i = Suppressed.Length - 5
	while i > 0
		i -= 1
		Actor FoundRef = Game.FindRandomActorFromRef(CenterRef, Radius)
		if !FoundRef || (Suppressed.Find(FoundRef) == -1 && CheckActor(FoundRef, FindGender) && (RaceKey == "" || sslCreatureAnimationSlots.GetAllRaceKeys(FoundRef.GetLeveledActorBase().GetRace()).Find(RaceKey) != -1))
			return FoundRef ; None means no actor in radius, give up now
		endIf
		Suppressed[i] = FoundRef
	endWhile
	; No actor found in attempts
	return none
endFunction

; TODO: probably needs some love
Actor[] function FindAvailablePartners(actor[] Positions, int total, int males = -1, int females = -1, float radius = 10000.0)
	int needed = (total - Positions.Length)
	if needed <= 0
		return Positions ; Nothing to do
	endIf
	; Get needed gender counts based on current counts
	int[] genders = ActorLib.GenderCount(Positions)
	males -= genders[0]
	females -= genders[1]
	; Loop through until filled or we give up
	int attempts = 30
	while needed && attempts
		; Determine needed gender
		int findGender = -1
		if males > 0 && females < 1
			findGender = 0
		elseif females > 0 && males < 1
			findGender = 1
		endIf
		; Locate actor
		int have = Positions.Length
		actor FoundRef
		if have == 2
			FoundRef = FindAvailableActor(Positions[0], radius, findGender, Positions[1])
		elseif have == 3
			FoundRef = FindAvailableActor(Positions[0], radius, findGender, Positions[1], Positions[2])
		elseif have == 4
			FoundRef = FindAvailableActor(Positions[0], radius, findGender, Positions[1], Positions[2], Positions[3])
		else
			FoundRef = FindAvailableActor(Positions[0], radius, findGender)
		endIf
		; Validate/Add them
		if !FoundRef
			return Positions ; None means no actor in radius, give up now
		elseIf Positions.Find(FoundRef) == -1
			; Add actor
			Positions = PapyrusUtil.PushActor(Positions, FoundRef)
			; Update search counts
			int gender = ActorLib.GetGender(FoundRef)
			males   -= (gender == 0) as int
			females -= (gender == 1) as int
			needed  -= 1
		endIf
		attempts -= 1
	endWhile
	; Output whatever we have at this point
	return Positions
endFunction

Actor[] function SortActors(Actor[] Positions, bool FemaleFirst = true)
	int ActorCount = Positions.Length
	int Priority   = FemaleFirst as int
	if ActorCount < 2 || (ActorCount == 2 && ActorLib.GetGender(Positions[0]) == Priority)
		return Positions ; No need to sort actors.
	endIf
	; Check first occurance of priority gender.
	int[] GendersAll = ActorLib.GetGendersAll(Positions)
	int i = GendersAll.Find(Priority)
	if i == -1 ;|| (i == 0 && GendersAll.RFind(Priority) == 0)
		return Positions ; Prefered gender not present
	endIf
	; Sort actors of priority gender into start of array
	Actor[] Sorted
	while i < ActorCount
		; Priority gender or last actor, just add them.
		if GendersAll[i] == Priority
			GendersAll[i] = -1
			Sorted = PapyrusUtil.PushActor(Sorted, Positions[i])
		endIf
		i += 1
	endwhile
	; Insert remaining actors
	i = 0
	while i < ActorCount
		if GendersAll[i] != -1
			Sorted = PapyrusUtil.PushActor(Sorted, Positions[i])
		endIf
		i += 1
	endWhile
	; Return sorted actor array
	Log("SortActors("+Positions+") -- Return:"+Sorted)
	return Sorted
endFunction

Actor[] function SortActorsByAnimation(actor[] Positions, sslBaseAnimation Animation = none)
	int ActorCount = Positions.Length
	if ActorCount < 2
		return Positions ; Nothing to sort
	endIf
	int[] Genders = ActorLib.GenderCount(Positions)
	int[] Futas = TransCount(Positions)
	int Creatures = Genders[2] + Genders[3]
	if Creatures < 1
		if (Futas[0] + Futas[1]) < 1 && (Genders[0] == ActorCount || Genders[1] == ActorCount)
			return Positions ; Nothing to sort
		elseIf Animation && Animation != none && !Animation.HasTag("Futa")
			if Animation.Males == Animation.PositionCount || Animation.Females == Animation.PositionCount || Genders == Animation.Genders
				return Positions ; Nothing to sort
			endIf
		endIf
	else
		return SortCreatures(Positions, Animation)
	endIf
	Actor[] Sorted = PapyrusUtil.ActorArray(ActorCount)
	int pos
	int i
	if !Animation || Animation == none || !Config.RestrictGenderTag
		return SortActors(Positions)
	elseIf !(Animation.HasTag("NoSwap") || Animation.HasTag("Vaginal") || Animation.HasTag("Pussy") || Animation.HasTag("Cunnilingus") || Animation.HasTag("Futa"))
		return SortActors(Positions)
	elseIf ActorCount != Animation.PositionCount || Creatures != Animation.Creatures
		Sorted = Positions
		while i < Sorted.Length
			; Put non creatures first
			if !Animation.HasRace(Sorted[i].GetLeveledActorBase().GetRace()) && i > pos
				Actor moved = Sorted[pos]
				Sorted[pos] = Sorted[i]
				Sorted[i] = moved
				pos += 1
			endIf
			i += 1
		endWhile
	else
		int[] GendersAll = ActorLib.GetGendersAll(Positions)
		int[] FutasAll = GetTransAll(Positions)
		
		i = 0
		while i < Animation.PositionCount
			int futa = -1
			int better = -1
			int first = -1
			pos = 0
			while pos < ActorCount
				if (!Sorted[i] || Sorted[i] == none) 
					if Sorted.Find(Positions[pos]) < 0
						if !(Animation.HasTag("Futa") && (Futas[0] + Futas[1]) >= 1) && (Animation.Females < 1 || Genders[1] < 1 || Animation.Males < 1 || Genders[0] < 1 || (Animation.Females == Genders[1] && !(Animation.HasTag("NoSwap") || !Config.RestrictGenderTag || Animation.HasTag("Vaginal") || Animation.HasTag("Pussy") || Animation.HasTag("Cunnilingus"))))
							Sorted[i] = Positions[pos]
						else
							if Animation.GetGender(i) == GendersAll[pos] && (Futas[0] + Futas[1]) < 1
								Sorted[i] = Positions[pos]
							elseIf futa < 0 && GendersAll[pos] == FutasAll[pos]
								if (pos + 1) >= ActorCount
									Sorted[i] = Positions[pos]
								else
									futa = pos
								endIf
							elseIf better < 0 && Animation.GetGender(i) == GendersAll[pos]
								if (pos + 1) >= ActorCount
									Sorted[i] = Positions[pos]
								else
									better = pos
								endIf
							elseIf first < 0
								if (pos + 1) >= ActorCount
									Sorted[i] = Positions[pos]
								else
									first = pos
								endIf
							elseIf (pos + 1) >= ActorCount
								if futa >= 0
									Sorted[i] = Positions[futa]
								elseIf better >= 0
									Sorted[i] = Positions[better]
								else
									Sorted[i] = Positions[first]
								endIf
							endIf
						endIf
					elseIf (pos + 1) >= ActorCount 
						if futa >= 0
							Sorted[i] = Positions[futa]
						elseIf better >= 0
							Sorted[i] = Positions[better]
						elseIf first >= 0
							Sorted[i] = Positions[first]
						endIf
					endIf
				endIf
				pos += 1
			endWhile
			i += 1
		endWhile
	endIf
	if Sorted.Find(none) < 0
		Log("SortActorsByAnimation("+Positions+", "+Animation+") -- Return:"+Sorted)
		return Sorted
	else
		Log("SortActorsByAnimation("+Positions+", "+Animation+") -- Failed to sort actors '"+Sorted+"' -- They were unable to fill an actor position","FATAL")
		return Positions
	endIf
endFunction

; TODO: Move the Trans functions to the sslActorLibrary
int function GetTrans(Actor ActorRef)
	if ActorRef && ActorRef != none && ActorRef.IsInFaction(Config.GenderFaction)
		if sslCreatureAnimationSlots.HasRaceType(ActorRef.GetLeveledActorBase().GetRace())
			return 2 + ActorRef.GetFactionRank(Config.GenderFaction)
		else
			return ActorRef.GetFactionRank(Config.GenderFaction)
		endIf
	endIf
	return -1
endFunction

int[] function GetTransAll(Actor[] Positions)
	int i = Positions.Length
	int[] Trans = Utility.CreateIntArray(i)
	while i > 0
		i -= 1
		Trans[i] = GetTrans(Positions[i])
	endWhile
	return Trans
endFunction

int[] function TransCount(Actor[] Positions)
	int[] Trans = new int[4]
	int i = Positions.Length
	while i > 0
		i -= 1
		int g = GetTrans(Positions[i])
		if g >= 0 && g < 4
			Trans[g] = Trans[g] + 1
		endIf
	endWhile
	return Trans
endFunction

int function FindNext(Actor[] Positions, sslBaseAnimation Animation, int offset, bool FindCreature)
	while offset
		offset -= 1
		if Animation.HasRace(Positions[offset].GetLeveledActorBase().GetRace()) == FindCreature
			return offset
		endIf
	endwhile
	return -1
endFunction

Actor[] function SortCreatures(actor[] Positions, sslBaseAnimation Animation = none)
	int ActorCount = Positions.Length
	if ActorCount < 2
		return Positions ; Nothing to sort
	endIf
	int[] Genders = ActorLib.GenderCount(Positions)
	int Creatures = Genders[2] + Genders[3]
	if Creatures < 1
		return Positions ; Nothing to sort
	endIf
	Actor[] Sorted = PapyrusUtil.ActorArray(ActorCount)
	int pos
	int i
	if !Animation || Animation == none
		i = ActorCount
		while i > 0
			i -= 1
			pos = ActorCount
			while pos > 0
				pos -= 1
				if (!Sorted[i] || Sorted[i] == none) && Sorted.Find(Positions[pos]) < 0
					; Put creatures last
					if Creatures > ActorLib.CreatureCount(Sorted)
						if ActorLib.IsCreature(Positions[i])
							Sorted[i] = Positions[pos]
						endIf
					else
						if !ActorLib.IsCreature(Positions[i])
							Sorted[i] = Positions[pos]
						endIf
					endIf
				endIf
			endWhile
		endWhile
	elseIf ActorCount != Animation.PositionCount || Creatures != Animation.Creatures
		Sorted = Positions
		while i < Sorted.Length
			; Put non creatures first
			if !Animation.HasRace(Sorted[i].GetLeveledActorBase().GetRace()) && i > pos
				Actor moved = Sorted[pos]
				Sorted[pos] = Sorted[i]
				Sorted[i] = moved
				pos += 1
			endIf
			i += 1
		endWhile
	else
		int[] GendersAll = ActorLib.GetGendersAll(Positions)
		int[] Futas = TransCount(Positions)
		int[] FutasAll = GetTransAll(Positions)

		i = Animation.PositionCount
		while i > 0
			i -= 1
			int futa = -1
			int better = -1
			int first = -1
			pos = ActorCount
			while pos > 0
				pos -= 1
				if (!Sorted[i] || Sorted[i] == none)
					if Sorted.Find(Positions[pos]) < 0 ; Sorted[i] != Positions[pos]
						if Animation.CreaturePosition(i)
							if ActorLib.IsCreature(Positions[pos])
								if Animation.HasPostionRace(i,sslCreatureAnimationSlots.GetAllRaceKeys(Positions[pos].GetLeveledActorBase().GetRace()))
									if !Config.UseCreatureGender
										Sorted[i] = Positions[pos]
									else
										if (Futas[2] + Futas[3]) < 1 && Animation.GetGender(i) == GendersAll[pos]
											Sorted[i] = Positions[pos]
										elseIf futa < 0 && GendersAll[pos] == FutasAll[pos]
											if pos < 1
												Sorted[i] = Positions[pos]
											else
												futa = pos
											endIf
										elseIf better < 0 && Animation.GetGender(i) == GendersAll[pos]
											if pos < 1
												Sorted[i] = Positions[pos]
											else
												better = pos
											endIf
										elseIf first < 0
											if pos < 1
												Sorted[i] = Positions[pos]
											else
												first = pos
											endIf
										elseIf pos < 1
											if futa >= 0
												Sorted[i] = Positions[futa]
											elseIf better >= 0
												Sorted[i] = Positions[better]
											else
												Sorted[i] = Positions[first]
											endIf
										endIf
									endIf
								elseIf pos < 1
									if futa >= 0
										Sorted[i] = Positions[futa]
									elseIf better >= 0
										Sorted[i] = Positions[better]
									elseIf first >= 0
										Sorted[i] = Positions[first]
									endIf
								endIf
							elseIf pos < 1
								if futa >= 0
									Sorted[i] = Positions[futa]
								elseIf better >= 0
									Sorted[i] = Positions[better]
								elseIf first >= 0
									Sorted[i] = Positions[first]
								endIf
							endIf
						else
							if !ActorLib.IsCreature(Positions[pos])
								if !(Animation.HasTag("Futa") && (Futas[0] + Futas[1]) >= 1) && (Animation.Females < 1 || Genders[1] < 1 || Animation.Males < 1 || Genders[0] < 1 || (Animation.Females == Genders[1] && !(Animation.HasTag("NoSwap") || !Config.RestrictGenderTag || Animation.HasTag("Vaginal") || Animation.HasTag("Pussy") || Animation.HasTag("Cunnilingus"))))
									Sorted[i] = Positions[pos]
								else
									if (Futas[0] + Futas[1]) < 1 && Animation.GetGender(i) == GendersAll[pos]
										Sorted[i] = Positions[pos]
									elseIf futa < 0 && GendersAll[pos] == FutasAll[pos]
										if pos < 1
											Sorted[i] = Positions[pos]
										else
											futa = pos
										endIf
									elseIf better < 0 && Animation.GetGender(i) == GendersAll[pos]
										if pos < 1
											Sorted[i] = Positions[pos]
										else
											better = pos
										endIf
									elseIf first < 0
										if pos < 1
											Sorted[i] = Positions[pos]
										else
											first = pos
										endIf
									elseIf pos < 1
										if futa >= 0
											Sorted[i] = Positions[futa]
										elseIf better >= 0
											Sorted[i] = Positions[better]
										else
											Sorted[i] = Positions[first]
										endIf
									endIf
								endIf
							elseIf pos < 1
								if futa >= 0
									Sorted[i] = Positions[futa]
								elseIf better >= 0
									Sorted[i] = Positions[better]
								elseIf first >= 0
									Sorted[i] = Positions[first]
								endIf
							endIf
						endIf
					elseIf pos < 1
						if futa >= 0
							Sorted[i] = Positions[futa]
						elseIf better >= 0
							Sorted[i] = Positions[better]
						elseIf first >= 0
							Sorted[i] = Positions[first]
						endIf
					endIf
				endIf
			endWhile
		endWhile
	endIf
	if Sorted.Find(none) < 0
		Log("SortCreatures("+Positions+", "+Animation+") -- Return:"+Sorted)
		return Sorted
	else
		Log("SortCreatures("+Positions+", "+Animation+") -- Failed to sort actors '"+Sorted+"' -- They were unable to fill an actor position","FATAL")
		return Positions
	endIf
endFunction

bool function IsBedRoll(ObjectReference BedRef)
	if BedRef 
		return BedRef.HasKeyword(FurnitureBedRoll) || BedRollsList.HasForm(BedRef.GetBaseObject()) \
			|| StringUtil.Find(BedRef.GetDisplayName(), "roll") != -1 || StringUtil.Find(BedRef.GetDisplayName(), "pile") != -1
	endIf
	return false
endFunction

bool function IsDoubleBed(ObjectReference BedRef)
	return BedRef && DoubleBedsList.HasForm(BedRef.GetBaseObject())
endFunction

bool function IsSingleBed(ObjectReference BedRef)
	return BedRef && BedsList.HasForm(BedRef.GetBaseObject()) && !BedRollsList.HasForm(BedRef.GetBaseObject()) && !DoubleBedsList.HasForm(BedRef.GetBaseObject())
endFunction

int function GetBedType(ObjectReference BedRef)
	if BedRef
		Form BaseRef = BedRef.GetBaseObject()
		if !BedsList.HasForm(BaseRef)
			return 0
		elseIf IsBedRoll(Bedref);BedRollsList.HasForm(BedRef.GetBaseObject()) || BedRef.HasKeyword(FurnitureBedRoll)
			return 1
		elseIf DoubleBedsList.HasForm(BaseRef)
			return 3
		else
			return 2
		endIf
	endIf
	return 0
endFunction

bool function IsBedAvailable(ObjectReference BedRef)
	; Check furniture use
	if !BedRef || BedRef.IsFurnitureInUse(true)
		return false
	endIf
	; Check if used by a current thread
	sslThreadController[] Threads = ThreadSlots.Threads
	int i
	while i < 15
		if Threads[i].BedRef == BedRef
			return false
		endIf
		i += 1
	endwhile
	; Bed is free for use
	return true
endFunction

bool function CheckBed(ObjectReference BedRef, bool IgnoreUsed = true)
	return BedRef && BedRef.IsEnabled() && BedRef.Is3DLoaded() && (!IgnoreUsed || (IgnoreUsed && IsBedAvailable(BedRef)))
endFunction

bool function LeveledAngle(ObjectReference ObjectRef, float Tolerance = 5.0)
	return ObjectRef && Math.Abs(ObjectRef.GetAngleX()) <= Tolerance && Math.Abs(ObjectRef.GetAngleY()) <= Tolerance
endFunction

bool function SameFloor(ObjectReference BedRef, float Z, float Tolerance = 15.0)
	return BedRef && Math.Abs(Z - BedRef.GetPositionZ()) <= Tolerance
endFunction

ObjectReference function FindBed(ObjectReference CenterRef, float Radius = 1000.0, bool IgnoreUsed = true, ObjectReference IgnoreRef1 = none, ObjectReference IgnoreRef2 = none)
	if !CenterRef || Radius < 1.0
		return none ; Invalid args
	endIf
	; Current elevation to determine bed being on same floor
	float Z = CenterRef.GetPositionZ()
	; Search a couple times for a nearby bed on the same elevation first before looking for random
	ObjectReference NearRef = Game.FindClosestReferenceOfAnyTypeInListFromRef(BedsList, CenterRef, Radius)
	if !NearRef || (NearRef != IgnoreRef1 && NearRef != IgnoreRef2 && SameFloor(NearRef, Z) && LeveledAngle(NearRef) && CheckBed(NearRef, IgnoreUsed))
		return NearRef
	endIf
	NearRef = Game.FindRandomReferenceOfAnyTypeInListFromRef(BedsList, CenterRef, Radius)
	if !NearRef || (NearRef != IgnoreRef1 && NearRef != IgnoreRef2 && SameFloor(NearRef, Z) && LeveledAngle(NearRef) && CheckBed(NearRef, IgnoreUsed))
		return NearRef
	endIf
	NearRef = Game.FindRandomReferenceOfAnyTypeInListFromRef(BedsList, CenterRef, Radius)
	if !NearRef || (NearRef != IgnoreRef1 && NearRef != IgnoreRef2 && SameFloor(NearRef, Z) && LeveledAngle(NearRef) && CheckBed(NearRef, IgnoreUsed))
		return NearRef
	endIf
	NearRef = Game.FindClosestReferenceOfAnyTypeInListFromRef(BedsList, CenterRef, Radius)
	if !NearRef || (NearRef != IgnoreRef1 && NearRef != IgnoreRef2 && SameFloor(NearRef, Z, Radius * 0.5) && LeveledAngle(NearRef) && CheckBed(NearRef, IgnoreUsed))
		return NearRef
	endIf
	; Failover to any random useable bed
	form[] Suppressed = new Form[10]
	Suppressed[9] = NearRef
	Suppressed[8] = IgnoreRef1
	Suppressed[7] = IgnoreRef2
	int i = 7
	while i
		i -= 1
		ObjectReference BedRef = Game.FindRandomReferenceOfAnyTypeInListFromRef(BedsList, CenterRef, Radius)
		if !BedRef || (Suppressed.Find(BedRef) == -1 && SameFloor(NearRef, Z, Radius * 0.5) && LeveledAngle(BedRef) && CheckBed(BedRef, IgnoreUsed))
			return BedRef ; Found valid bed or none nearby and we should give up
		else
			Suppressed[i] = BedRef ; Add to suppression list
		endIf
	endWhile
	return none ; Nothing found in search loop
endFunction

; ------------------------------------------------------- ;
; --- Actor Tracking                                  --- ;
; ------------------------------------------------------- ;

function TrackActor(Actor ActorRef, string Callback)
	FormListAdd(Config, "TrackedActors", ActorRef, false)
	StringListAdd(ActorRef, "SexLabEvents", Callback, false)
endFunction

function TrackFaction(Faction FactionRef, string Callback)
	FormListAdd(Config, "TrackedFactions", FactionRef, false)
	StringListAdd(FactionRef, "SexLabEvents", Callback, false)
endFunction

function UntrackActor(Actor ActorRef, string Callback)
	StringListRemove(ActorRef, "SexLabEvents", Callback, true)
	if StringListCount(ActorRef, "SexLabEvents") < 1
		FormListRemove(Config, "TrackedActors", ActorRef, true)
	endif
endFunction

function UntrackFaction(Faction FactionRef, string Callback)
	StringListRemove(FactionRef, "SexLabEvents", Callback, true)
	if StringListCount(FactionRef, "SexLabEvents") < 1
		FormListRemove(Config, "TrackedFactions", FactionRef, true)
	endif
endFunction

bool function IsActorTracked(Actor ActorRef)
	if ActorRef == PlayerRef || StringListCount(ActorRef, "SexLabEvents") > 0
		return true
	endIf
	int i = FormListCount(Config, "TrackedFactions")
	while i
		i -= 1
		Faction FactionRef = FormListGet(Config, "TrackedFactions", i) as Faction
		if FactionRef && ActorRef.IsInFaction(FactionRef)
			return true
		endIf
	endWhile
	return false
endFunction

function SendTrackedEvent(Actor ActorRef, string Hook = "", int id = -1)
	; Append hook type, global if empty
	if Hook != ""
		Hook = "_"+Hook
	endIf
	; Send generic player callback event
	if ActorRef == PlayerRef
		SetupActorEvent(PlayerRef, "PlayerTrack"+Hook, id)
	endIf
	; Send actor callback events
	int i = StringListCount(ActorRef, "SexLabEvents")
	while i
		i -= 1
		SetupActorEvent(ActorRef, StringListGet(ActorRef, "SexLabEvents", i)+Hook, id)
	endWhile
	; Send faction callback events
	i = FormListCount(Config, "TrackedFactions")
	while i
		i -= 1
		Faction FactionRef = FormListGet(Config, "TrackedFactions", i) as Faction
		if FactionRef && ActorRef.IsInFaction(FactionRef)
			int n = StringListCount(FactionRef, "SexLabEvents")
			while n
				n -= 1
				SetupActorEvent(ActorRef, StringListGet(FactionRef, "SexLabEvents", n)+Hook, id)
			endwhile
		endIf
	endWhile
endFunction

function SetupActorEvent(Actor ActorRef, string Callback, int id = -1)
	int eid = ModEvent.Create(Callback)
	ModEvent.PushForm(eid, ActorRef)
	ModEvent.PushInt(eid, id)
	ModEvent.Send(eid)
endFunction

; ------------------------------------------------------- ;
; --- System use only                                 --- ;
; ------------------------------------------------------- ;

function Setup()
	parent.Setup()
	BedsList       = Config.BedsList
	DoubleBedsList = Config.DoubleBedsList
	BedRollsList   = Config.BedRollsList
	FurnitureBedRoll = Config.FurnitureBedRoll
endFunction

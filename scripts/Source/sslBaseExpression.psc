scriptname sslBaseExpression extends sslBaseObject

import PapyrusUtil

; Gender Types
int property Male       = 0 autoreadonly
int property Female     = 1 autoreadonly
int property MaleFemale = -1 autoreadonly
; MFG Types
int property Phoneme  = 0 autoreadonly
int property Modifier = 16 autoreadonly
int property Mood     = 30 autoreadonly
; ID loop ranges
int property PhonemeIDs  = 15 autoreadonly
int property ModifierIDs = 13 autoreadonly
int property MoodIDs     = 16 autoreadonly

string property File hidden
	string function get()
		return "../SexLab/Expression_"+Registry+".json"
	endFunction
endProperty

int[] Phases
int[] property PhaseCounts hidden
	int[] function get()
		return Phases
	endFunction
endProperty
int property PhasesMale hidden
	int function get()
		return Phases[Male]
	endFunction
endProperty
int property PhasesFemale hidden
	int function get()
		return Phases[Female]
	endFunction
endProperty

float[] Male1
float[] Male2
float[] Male3
float[] Male4
float[] Male5

float[] Female1
float[] Female2
float[] Female3
float[] Female4
float[] Female5

; ------------------------------------------------------- ;
; --- Application Functions                           --- ;
; ------------------------------------------------------- ;

function Apply(Actor ActorRef, int Strength, int Gender)
	ApplyPhase(ActorRef, PickPhase(Strength, Gender), Gender)
endFunction

function ApplyPhase(Actor ActorRef, int Phase, int Gender)
	if Phase <= Phases[Gender]
		ApplyPresetFloats(ActorRef, GetPhase(Phase, Gender))
	endIf
endFunction

int function PickPhase(int Strength, int Gender)
	return ClampInt(((ClampInt(Strength, 1, 100) * Phases[Gender]) / 100), 1, Phases[Gender])
endFunction

float[] function SelectPhase(int Strength, int Gender)
	return GetPhase(PickPhase(Strength, Gender), Gender)
endFunction

; ------------------------------------------------------- ;
; --- Global Utilities                                --- ;
; ------------------------------------------------------- ;

function ClearPhoneme(Actor ActorRef) global native
function ClearModifier(Actor ActorRef) global native

function OpenMouth(Actor ActorRef) global
	ClearPhoneme(ActorRef)
	ActorRef.SetExpressionOverride(16, 100)
	ActorRef.SetExpressionPhoneme(1, 0.4)
endFunction

function CloseMouth(Actor ActorRef) global
	ActorRef.ClearExpressionOverride()
	ActorRef.SetExpressionPhoneme(1, 0.0)
endFunction

bool function IsMouthOpen(Actor ActorRef) global
	return GetPhoneme(ActorRef, 1) >= 40
endFunction

function ClearMFG(Actor ActorRef) global
	ClearPhoneme(ActorRef)
	ClearModifier(ActorRef)
	ActorRef.ResetExpressionOverrides()
	ActorRef.ClearExpressionOverride()
endFunction

function ApplyPresetFloats(Actor ActorRef, float[] Preset) global
	ApplyPresetArray(ActorRef, Preset)
	; ActorRef.SetExpressionOverride(Preset[30] as int, Preset[31] as int)
endFunction

function ApplyPreset(Actor ActorRef, int[] Preset) global
	int i
	; Set Phoneme
	int p
	while p <= 15
		ActorRef.SetExpressionPhoneme(p, Preset[i] as float / 100.0)
		i += 1
		p += 1
	endWhile
	; Set Modifers
	int m
	while m <= 13
		ActorRef.SetExpressionModifier(m, Preset[i] as float / 100.0)
		i += 1
		m += 1
	endWhile
	; Set expression
	ActorRef.SetExpressionOverride(Preset[30], Preset[31])
endFunction

; ------------------------------------------------------- ;
; --- Editing Functions                               --- ;
; ------------------------------------------------------- ;

function SetIndex(int Phase, int Gender, int Mode, int id, int value)
	float[] Preset = GetPhase(Phase, Gender)
	int i = Mode+id
	if value > 100
		value = 100
	elseIf value < 0
		value = 0
	endIf
	Preset[i] = value as float
	if i < 30
		Preset[i] = Preset[i] / 100.0
	endIf
	SetPhase(Phase, Gender, Preset)
endFunction

function SetPreset(int Phase, int Gender, int Mode, int id, int value)
	if Mode == Mood
		SetMood(Phase, Gender, id, value)
	elseif Mode == Modifier
		SetModifier(Phase, Gender, id, value)
	elseif Mode == Phoneme
		SetPhoneme(Phase, Gender, id, value)
	endIf
endFunction

function SetMood(int Phase, int Gender, int id, int value)
	if Gender == Female || Gender == MaleFemale
		SetIndex(Phase, Female, Mood, 0, id)
		SetIndex(Phase, Female, Mood, 1, value)
	endIf
	if Gender == Male || Gender == MaleFemale
		SetIndex(Phase, Male, Mood, 0, id)
		SetIndex(Phase, Male, Mood, 1, value)
	endIf
endFunction

function SetModifier(int Phase, int Gender, int id, int value)
	if Gender == Female || Gender == MaleFemale
		SetIndex(Phase, Female, Modifier, id, value)
	endIf
	if Gender == Male || Gender == MaleFemale
		SetIndex(Phase, Male, Modifier, id, value)
	endIf
endFunction

function SetPhoneme(int Phase, int Gender, int id, int value)
	if Gender == Female || Gender == MaleFemale
		SetIndex(Phase, Female, Phoneme, id, value)
	endIf
	if Gender == Male || Gender == MaleFemale
		SetIndex(Phase, Male, Phoneme, id, value)
	endIf
endFunction

function EmptyPhase(int Phase, int Gender)
	float[] Preset = new float[32]
	SetPhase(Phase, Gender, Preset)
	Phases[Gender] = ClampInt((Phases[Gender] - 1), 0, 5)
	CountPhases()
	if Phases[0] == 0 && Phases[1] == 0
		Enabled = false
	endIf
endFunction

function AddPhase(int Phase, int Gender)
	float[] Preset = GetPhase(Phase, Gender)
	if Preset[30] == 0.0 || Preset[31] == 0.0
		Preset[30] = 7.0
		Preset[31] = 0.5
	endIf
	SetPhase(Phase, Gender, Preset)
	Phases[Gender] = ClampInt((Phases[Gender] + 1), 0, 5)
	Enabled = true
endFunction

; ------------------------------------------------------- ;
; --- Phase Accessors                                 --- ;
; ------------------------------------------------------- ;

bool function HasPhase(int Phase, Actor ActorRef)
	if !ActorRef || Phase < 1
		return false
	endIf
	int Gender = ActorRef.GetLeveledActorBase().GetSex()
	return (Gender == 1 && Phase <= PhasesFemale) || (Gender == 0 && Phase <= PhasesMale)
endFunction

float[] function GetPhase(int Phase, int Gender)
	float[] Preset
	if Gender == Male
		if Phase == 1
			Preset = Male1
		elseIf Phase == 2
			Preset = Male2
		elseIf Phase == 3
			Preset = Male3
		elseIf Phase == 4
			Preset = Male4
		elseIf Phase == 5
			Preset = Male5
		endIf
	else
		if Phase == 1
			Preset = Female1
		elseIf Phase == 2
			Preset = Female2
		elseIf Phase == 3
			Preset = Female3
		elseIf Phase == 4
			Preset = Female4
		elseIf Phase == 5
			Preset = Female5
		endIf
	endIf
	if Preset.Length != 32
		return new float[32]
	endIf
	return Preset
endFunction

function SetPhase(int Phase, int Gender, float[] Preset)
	if Gender == Male
		if Phase == 1
			Male1 = Preset
		elseIf Phase == 2
			Male2 = Preset
		elseIf Phase == 3
			Male3 = Preset
		elseIf Phase == 4
			Male4 = Preset
		elseIf Phase == 5
			Male5 = Preset
		endIf
	else
		if Phase == 1
			Female1 = Preset
		elseIf Phase == 2
			Female2 = Preset
		elseIf Phase == 3
			Female3 = Preset
		elseIf Phase == 4
			Female4 = Preset
		elseIf Phase == 5
			Female5 = Preset
		endIf
	endIf
endFunction

float[] function GetPhonemes(int Phase, int Gender)
	float[] Output = new float[16]
	float[] Preset = GetPhase(Phase, Gender)
	int i
	while i < 16
		Output[i] = Preset[Phoneme + i]
		i += 1
	endWhile
	return Output
endFunction

float[] function GetModifiers(int Phase, int Gender)
	float[] Output = new float[14]
	float[] Preset = GetPhase(Phase, Gender)
	int i
	while i < 14
		Output[i] = Preset[Modifier + i]
		i += 1
	endWhile
	return Output
endFunction

int function GetMoodType(int Phase, int Gender)
	return GetPhase(Phase, Gender)[30] as int
endFunction

int function GetMoodAmount(int Phase, int Gender)
	return GetPhase(Phase, Gender)[31] as int
endFunction

int function GetIndex(int Phase, int Gender, int Mode, int id)
	return (GetPhase(Phase, Gender)[Mode + id]) as int
endFunction

; ------------------------------------------------------- ;
; --- System Use                                      --- ;
; ------------------------------------------------------- ;

function CountPhases()
	Phases = new int[2]
	; Male phases
	Phases[0] = Phases[0] + ((AddFloatValues(Male1) > 0) as int)
	Phases[0] = Phases[0] + ((AddFloatValues(Male2) > 0) as int)
	Phases[0] = Phases[0] + ((AddFloatValues(Male3) > 0) as int)
	Phases[0] = Phases[0] + ((AddFloatValues(Male4) > 0) as int)
	Phases[0] = Phases[0] + ((AddFloatValues(Male5) > 0) as int)
	; Female phases
	Phases[1] = Phases[1] + ((AddFloatValues(Female1) > 0) as int)
	Phases[1] = Phases[1] + ((AddFloatValues(Female2) > 0) as int)
	Phases[1] = Phases[1] + ((AddFloatValues(Female3) > 0) as int)
	Phases[1] = Phases[1] + ((AddFloatValues(Female4) > 0) as int)
	Phases[1] = Phases[1] + ((AddFloatValues(Female5) > 0) as int)
	; Enable it if phases are present
	if Phases[0] > 0 || Phases[1] > 0
		Enabled = true
	else
		Enabled = false
	endIf
endFunction

function Save(int id = -1)
	CountPhases()
	SlotID = id
	Log(Name, "Expressions["+id+"]")
endFunction

function Initialize()
	parent.Initialize()
	; Gender phase counts
	Phases = new int[2]
	; Individual Phases
	Male1   = Utility.CreateFloatArray(0)
	Male2   = Utility.CreateFloatArray(0)
	Male3   = Utility.CreateFloatArray(0)
	Male4   = Utility.CreateFloatArray(0)
	Male5   = Utility.CreateFloatArray(0)
	Female1 = Utility.CreateFloatArray(0)
	Female2 = Utility.CreateFloatArray(0)
	Female3 = Utility.CreateFloatArray(0)
	Female4 = Utility.CreateFloatArray(0)
	Female5 = Utility.CreateFloatArray(0)
endFunction

bool function ExportJson()
	JsonUtil.ClearAll(File)

	JsonUtil.SetStringValue(File, "Name", Name)
	JsonUtil.SetIntValue(File, "Enabled", Enabled as int)

	JsonUtil.SetIntValue(File, "Normal", HasTag("Normal") as int)
	JsonUtil.SetIntValue(File, "Victim", HasTag("Victim") as int)
	JsonUtil.SetIntValue(File, "Aggressor", HasTag("Aggressor") as int)

	JsonUtil.FloatListCopy(File, "Male1", Male1)
	JsonUtil.FloatListCopy(File, "Male2", Male2)
	JsonUtil.FloatListCopy(File, "Male3", Male3)
	JsonUtil.FloatListCopy(File, "Male4", Male4)
	JsonUtil.FloatListCopy(File, "Male5", Male5)
	JsonUtil.FloatListCopy(File, "Female1", Female1)
	JsonUtil.FloatListCopy(File, "Female2", Female2)
	JsonUtil.FloatListCopy(File, "Female3", Female3)
	JsonUtil.FloatListCopy(File, "Female4", Female4)
	JsonUtil.FloatListCopy(File, "Female5", Female5)

	return JsonUtil.Save(File, true)
endFunction

bool function ImportJson()
	if JsonUtil.GetStringValue(File, "Name") == "" || (JsonUtil.FloatListCount(File, "Female1") != 32 && JsonUtil.FloatListCount(File, "Male1") != 32)
		Log("Failed to import "+File)
		return false
	endIf

	Name = JsonUtil.GetStringValue(File, "Name", Name)
	Enabled = JsonUtil.GetIntValue(File, "Enabled", Enabled as int) as bool

	AddTagConditional("Normal", JsonUtil.GetIntValue(File, "Normal", HasTag("Normal") as int) as bool)
	AddTagConditional("Victim", JsonUtil.GetIntValue(File, "Victim", HasTag("Victim") as int) as bool)
	AddTagConditional("Aggressor", JsonUtil.GetIntValue(File, "Aggressor", HasTag("Aggressor") as int) as bool)

	if JsonUtil.FloatListCount(File, "Male1") == 32
		Male1 = new float[32]
		JsonUtil.FloatListSlice(File, "Male1", Male1)
	endIf
	if JsonUtil.FloatListCount(File, "Male2") == 32
		Male2 = new float[32]
		JsonUtil.FloatListSlice(File, "Male2", Male2)
	endIf
	if JsonUtil.FloatListCount(File, "Male3") == 32
		Male3 = new float[32]
		JsonUtil.FloatListSlice(File, "Male3", Male3)
	endIf
	if JsonUtil.FloatListCount(File, "Male4") == 32
		Male4 = new float[32]
		JsonUtil.FloatListSlice(File, "Male4", Male4)
	endIf
	if JsonUtil.FloatListCount(File, "Male5") == 32
		Male5 = new float[32]
		JsonUtil.FloatListSlice(File, "Male5", Male5)
	endIf

	if JsonUtil.FloatListCount(File, "Female1") == 32
		Female1 = new float[32]
		JsonUtil.FloatListSlice(File, "Female1", Female1)
	endIf
	if JsonUtil.FloatListCount(File, "Female2") == 32
		Female2 = new float[32]
		JsonUtil.FloatListSlice(File, "Female2", Female2)
	endIf
	if JsonUtil.FloatListCount(File, "Female3") == 32
		Female3 = new float[32]
		JsonUtil.FloatListSlice(File, "Female3", Female3)
	endIf
	if JsonUtil.FloatListCount(File, "Female4") == 32
		Female4 = new float[32]
		JsonUtil.FloatListSlice(File, "Female4", Female4)
	endIf
	if JsonUtil.FloatListCount(File, "Female5") == 32
		Female5 = new float[32]
		JsonUtil.FloatListSlice(File, "Female5", Female5)
	endIf

	CountPhases()

	return true
endFunction


; ------------------------------------------------------- ;
; --- REFACTOR DEPRECATION                            --- ;
; ------------------------------------------------------- ;

; int[] function GetPhase(int Phase, int Gender)
; endFunction
; function SetPhase(int Phase, int Gender, int[] Preset)
; endFunction

; ------------------------------------------------------- ;
; --- DEPRECATED                                      --- ;
; ------------------------------------------------------- ;

function ApplyTo(Actor ActorRef, int Strength = 50, bool IsFemale = true, bool OpenMouth = false)
	Apply(ActorRef, Strength, IsFemale as int)
	if OpenMouth
		OpenMouth(ActorRef)
	endIf
endFunction

float[] function PickPreset(int Strength, bool IsFemale)
	return GetPhase(CalcPhase(Strength, IsFemale), (IsFemale as int))
endFunction

int function CalcPhase(int Strength, bool IsFemale)
	return PickPhase(Strength, (IsFemale as int))
endFunction

; ------------------------------------------------------- ;
; --- Tagging System                                  --- ;
; ------------------------------------------------------- ;

; bool function AddTag(string Tag) native
; bool function HasTag(string Tag) native
; bool function RemoveTag(string Tag) native
; bool function ToggleTag(string Tag) native
; bool function AddTagConditional(string Tag, bool AddTag) native
; bool function ParseTags(string[] TagList, bool RequireAll = true) native
; bool function CheckTags(string[] CheckTags, bool RequireAll = true, bool Suppress = false) native
; bool function HasOneTag(string[] TagList) native
; bool function HasAllTag(string[] TagList) native

; function AddTags(string[] TagList)
; 	int i = TagList.Length
; 	while i
; 		i -= 1
; 		AddTag(TagList[i])
; 	endWhile
; endFunction

; int function TagCount() native
; string function GetNthTag(int i) native
; function TagSlice(string[] Ouput) native

; string[] function GetTags()
; 	int i = TagCount()
; 	Log(Registry+" - TagCount: "+i)
; 	if i < 1
; 		return sslUtility.StringArray(0)
; 	endIf
; 	string[] Output = sslUtility.StringArray(i)
; 	TagSlice(Output)
; 	Log(Registry+" - SKSE Tags: "+Output)
; 	return Output
; endFunction

; function RevertTags() native

float function GetModifier(Actor ActorRef, int id) global native
float function GetPhoneme(Actor ActorRef, int id) global native
function ApplyPresetArray(Actor ActorRef, float[] Preset) global native

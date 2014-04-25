scriptname sslExpressionLibrary extends Quest
{DEPRECATED: This script is no longer used in any sexlab systems, and is only provided as a means to provide backwards compatibility by redirecting all it's functions to their new iterations}

sslExpressionSlots property Slots hidden
	sslExpressionSlots function get()
		DEPRECATED()
		return SexLab.ExpressionSlots
	endFunction
endProperty
bool property Male = false autoreadonly hidden
bool property Female = true autoreadonly hidden
int property Phoneme = 0 autoreadonly hidden
int property Modifier = 1 autoreadonly hidden
int property Expression = 2 autoreadonly hidden
function OpenMouth(Actor ActorRef) global
	DEPRECATED()
	sslBaseExpression.OpenMouth(ActorRef)
endFunction
function CloseMouth(Actor ActorRef) global
	DEPRECATED()
	sslBaseExpression.CloseMouth(ActorRef)
endFunction
bool function IsMouthOpen(Actor ActorRef) global
	DEPRECATED()
	return sslBaseExpression.IsMouthOpen(ActorRef)
endFunction
function ClearMFG(Actor ActorRef) global
	DEPRECATED()
	sslBaseExpression.ClearMFG(ActorRef)
endFunction
function ClearPhoneme(Actor ActorRef) global
	DEPRECATED()
	sslBaseExpression.ClearPhoneme(ActorRef)
endFunction
function ClearModifier(Actor ActorRef) global
	DEPRECATED()
	sslBaseExpression.ClearModifier(ActorRef)
endFunction
sslBaseExpression function PickExpression(Actor ActorRef, Actor VictimRef = none)
	DEPRECATED()
	return Slots.PickExpression(ActorRef, VictimRef)
endFunction
function ApplyPreset(int[] Presets, Actor ActorRef, bool OpenMouth = false) global
	DEPRECATED()
	sslBaseExpression.ApplyPreset(ActorRef, Presets)
	if OpenMouth
		sslBaseExpression.OpenMouth(ActorRef)
	endIf
endFunction
function MFG(Actor ActorRef, int mode, int id, int value) global
	DEPRECATED()
endFunction
function _Defaults()
	DEPRECATED()
endFunction
function _Export()
	DEPRECATED()
endFunction
function _Import()
	DEPRECATED()
endFunction

; Libraries
sslAnimationLibrary property AnimLib hidden
	sslAnimationLibrary function get()
		DEPRECATED()
		return SexLab.AnimLib
	endFunction
endProperty
sslVoiceLibrary property VoiceLib hidden
	sslVoiceLibrary function get()
		DEPRECATED()
		return SexLab.VoiceLib
	endFunction
endProperty
sslThreadLibrary property ThreadLib hidden
	sslThreadLibrary function get()
		DEPRECATED()
		return SexLab.ThreadLib
	endFunction
endProperty
sslActorLibrary property ActorLib hidden
	sslActorLibrary function get()
		DEPRECATED()
		return SexLab.ActorLib
	endFunction
endProperty
; sslControlLibrary property ControlLib hidden
; 	sslControlLibrary function get()
; 		DEPRECATED()
; 		return SexLab.ControlLib
; 	endFunction
; endProperty
sslExpressionLibrary property ExpressionLib hidden
	sslExpressionLibrary function get()
		DEPRECATED()
		return SexLab.ExpressionLib
	endFunction
endProperty
sslAnimationSlots property Animations hidden
	sslAnimationSlots function get()
		DEPRECATED()
		return SexLab.AnimSlots
	endFunction
endProperty
sslCreatureAnimationSlots property CreatureAnimations hidden
	sslCreatureAnimationSlots function get()
		DEPRECATED()
		return SexLab.CreatureSlots
	endFunction
endProperty
sslVoiceSlots property Voices hidden
	sslVoiceSlots function get()
		DEPRECATED()
		return SexLab.VoiceSlots
	endFunction
endProperty
sslThreadSlots property Threads hidden
	sslThreadSlots function get()
		DEPRECATED()
		return SexLab.ThreadSlots
	endFunction
endProperty
sslExpressionSlots property Expressions hidden
	sslExpressionSlots function get()
		DEPRECATED()
		return SexLab.ExpressionSlots
	endFunction
endProperty
sslActorStats property ActorStats hidden
	sslActorStats function get()
		DEPRECATED()
		return SexLab.Stats
	endFunction
endProperty

SexLabFramework SexLab
sslExpressionLibrary function Setup()
	Stop()
	Start()
	SexLab = SexLabUtil.GetAPI()
	return self
endFunction
function DEPRECATED() global
	string log = "SexLab DEPRECATED -- sslExpressionLibrary.psc -- Use of this script has been deprecated, the mod that called this function should be updated as soon as possible. If you are not the author of this mod, notify them of this error if possible."
	Debug.TraceStack(log)
	if SexLabUtil.GetAPI().Config.DebugMode
		MiscUtil.PrintConsole(log)
	endIf
endFunction

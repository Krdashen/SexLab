scriptname sslVoiceFactory extends Quest

sslVoiceSlots property Slots auto hidden
sslBaseVoice property Voice auto hidden

; Gender Types
int property Male = 0 autoreadonly hidden
int property Female = 1 autoreadonly hidden
int property MaleFemale = -1 autoreadonly hidden

bool Locked

; ------------------------------------------------------- ;
; --- Registering Voices                              --- ;
; ------------------------------------------------------- ;

; Send callback event to start registration
function RegisterVoice(string Registrar)
	; Check duplicate
	if Slots.IsRegistered(Registrar)
		return
	endIf
	; Wait for factory to be free
	while Locked || Voice != none
		Utility.WaitMenuMode(0.15)
	endWhile
	Locked = true
	; Get free voice slot
	Voice = Slots.Register(Registrar)
	if Voice != none
		; Init voice
		Voice.Initialize()
		Voice.Registry = Registrar
		Voice.Enabled = true
		; Send load event
		SendEvent(Registrar)
	else
		FreeFactory()
	endIf
endFunction

; Temporary alpha testing
function SendEvent(string Registrar)
	RegisterForModEvent("Register"+Registrar, Registrar)
	; ModEvent.Send(ModEvent.Create("Register"+Registrar))
	SendModEvent("Register"+Registrar)
	UnregisterForAllModEvents()
endFunction

; Unlocks factory for next callback, MUST be called at end of callback
function Save()
	; Make sure we have a gender tag
	if Voice.Gender == 0
		Voice.AddTag("Male")
	elseIf Voice.Gender == 1
		Voice.AddTag("Female")
	elseIf Voice.Gender == -1
		Voice.AddTag("Male")
		Voice.AddTag("Female")
	endIf
	; Free up factory for use
	SexLabUtil.Log("'"+Voice.Name+"'", "Slot["+Slots.Voices.Find(Voice)+"]", "REGISTER VOICE", "trace,console", true)
	FreeFactory()
endfunction

;/-----------------------------------------------\;
;|	Callback Voice Property Shortcuts            |;
;\-----------------------------------------------/;

bool function AddTag(string tag)
	return Voice.AddTag(tag)
endFunction

string property Name hidden
	function set(string value)
		Voice.Name = value
	endFunction
endProperty

bool property Enabled hidden
	function set(bool value)
		Voice.Enabled = value
	endFunction
endProperty

int property Gender hidden
	function set(int value)
		Voice.Gender = value
	endFunction
endProperty

Sound property Mild hidden
	function set(Sound value)
		Voice.Mild = value
	endFunction
endProperty

Sound property Medium hidden
	function set(Sound value)
		Voice.Medium = value
	endFunction
endProperty

Sound property Hot hidden
	function set(Sound value)
		Voice.Hot = value
	endFunction
endProperty

function FreeFactory()
	; Clear wait lock
	Voice = none
	Locked = false
endFunction

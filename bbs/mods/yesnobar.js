// JS version of yesnobar.src
// Cyberdeck theme: grayscale colors

require("sbbsdefs.js", "P_NOABORT");

"use strict";

const yes_str = bbs.text(bbs.text.Yes);
const yes_key = yes_str[0];
const no_str = bbs.text(bbs.text.No);
const no_key = no_str[0];

while(console.question.substring(0, 2) == "\r\n") {
	console.crlf();
	console.question = console.question.substring(2);
}

if(console.question.substring(0, 2) == "\x01\?") {
	console.print(console.question.substring(0, 2));
	console.question = console.question.substring(2);
}

// Cyberdeck: gray bracket, white checkmark, gray question
console.putmsg("\x01n\x01w[\x01h\x01w@CHECKMARK@\x01n\x01w] \x01w@QUESTION->@? @CLEAR_HOT@", P_NOABORT);
var affirm = true;
while(bbs.online && !js.terminated) {
	var str;
	if(affirm)
		// Cyberdeck: selected = bright white on dark gray background, unselected = gray
		str = format("\x01h\x010\x01w[\x01h%s]\x01n\x01w %s ", yes_str, no_str);
	else
		str = format("\x01n\x01w %s \x010\x01h\x01w[%s]", yes_str, no_str);
	console.print(str);
	var key = console.getkey(0).toUpperCase();
	console.backspace(console.strlen(str));
	console.print("\x01n\x01h\x01>");
	if(console.aborted)
		break;
	if(key == '\r')
		break;
	if(key == yes_key) {
		affirm = true;
		break;
	}
	if(key == no_key) {
		affirm = false;
		break;
	}
	affirm = !affirm;
}

if(!console.aborted)
	console.ungetstr(affirm ? yes_key : no_key);
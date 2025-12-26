// login.js
// Login module for Synchronet BBS v3.1
// Cyberdeck theme: grayscale colors

"use strict";

load("sbbsdefs.js");

var options;
if((options=load("modopts.js","login")) == null)
	options={email_passwords: true};
if(!options.login_prompts)
	options.login_prompts = 10;
if(!options.inactive_hangup)
	options.inactive_hangup = 30;	 // seconds
if(options.guest === undefined)
	options.guest = true;

if(bbs.sys_status & SS_USERON) {
	// The following 2 lines are only required for "Re-login" capability
	bbs.logout();
	system.node_list[bbs.node_num-1].status = NODE_LOGON;
}
var guest = options.guest && system.matchuser("guest");

if(!bbs.online)
	exit();
var inactive_hangup = parseInt(options.inactive_hangup, 10);
if(inactive_hangup && inactive_hangup < console.max_socket_inactivity
	&& !(console.autoterm&(USER_ANSI | USER_PETSCII | USER_UTF8))) {
	console.max_socket_inactivity = inactive_hangup;
	log(LOG_NOTICE, "terminal not detected, reducing inactivity hang-up timeout to " + console.max_socket_inactivity + " seconds");
}
if(console.max_socket_inactivity > 0 && bbs.node_num == bbs.last_node) {
	console.max_socket_inactivity /= 2;
	log(LOG_NOTICE, "last node login inactivity timeout reduced to " + console.max_socket_inactivity);
}

for(var c=0; c < options.login_prompts; c++) {

	// The "node sync" is required for sysop interruption/chat/etc.
	bbs.nodesync();

	// Display login prompt
	// Cyberdeck: gray text, bright white highlights
	const legacy_login_prompt = options.legacy_prompts ? "NN: \x01[" : "";
	const legacy_password_prompt = options.legacy_prompts ? "PW: \x01[" : "";
	var str = "\x01n\x01w\x01hE\x01n\x01wnter \x01h\x01wU\x01n\x01wser \x01h\x01wN\x01n\x01wame";
	if(system.login_settings & LOGIN_USERNUM)
		str += "\x01n\x01w or \x01h\x01wN\x01n\x01wumber";
	if(!(system.settings&SYS_CLOSED))
		str += "\x01n\x01w or '\x01h\x01wN\x01n\x01wew\x01n\x01w'";
	if(guest)
		str += "\x01n\x01w or '\x01h\x01wG\x01n\x01wuest\x01n\x01w'";
	str += "\r\n\x01h\x01wL\x01n\x01wogin: \x01h\x01w";
	console.print("\r\n"
		+ legacy_login_prompt
		+ word_wrap(str, console.screen_columns-1).trimRight());

	// Get login string
	var str;
	if(bbs.rlogin_name.length)
		print(str=bbs.rlogin_name);
	else
		str=console.getstr(/* maximum user name length: */ LEN_ALIAS
						 , /* getkey/str mode flags: */ K_UPRLWR | K_TAB | K_ANSI_CPR);
	truncsp(str);
	if(!str.length) // blank
		continue;

	// New user application?
	if(str.toUpperCase()=="NEW") {
	   if(bbs.newuser()) {
		   bbs.logon();
		   exit();
	   }
	   continue;
	}
	// Continue normal login (prompting for password)
	// Cyberdeck: gray text, bright white for input
	if(bbs.login(str, legacy_password_prompt + "\x01n\x01w\x01hP\x01n\x01wassword: \x01h\x01w")) {
		bbs.logon();
		exit();
	}
	if(system.trashcan("name", str)) {
		alert(log(LOG_NOTICE, "!Failed login with blocked user name: " + str));
		break;
	}
	console.clearkeybuffer();	// Clear pending input (e.g. mistyped system password)
	bbs.rlogin_name='';		// Clear user/login name (if supplied via protocol)
	var usernum = system.matchuser(str);
	if(usernum) {
		system.put_telegram(usernum,
			format("\x01n\x01h%s %s \x01w\x01hFailed login attempt\x01n\x01w\r\n" +
				"from %s [%s] via %s (TCP port %u)\x01n\r\n"
				,system.timestr(), system.zonestr()
				,client.host_name, client.ip_address
				,client.protocol, client.port));
		if(options && options.email_passwords) {
			var u = new User(usernum);
			if(!(u.settings&(USER_DELETED|USER_INACTIVE))
				&& !u.is_sysop
				&& u.security.password
				&& netaddr_type(u.netmail) == NET_INTERNET
				&& !console.noyes("Email your password to you")) {
				var email_addr = u.netmail;
				if(options.confirm_email_address !== false) {
					// Cyberdeck: gray text, bright white for input
					console.print("\x01n\x01w\x01hP\x01n\x01wlease confirm your \x01h\x01wI\x01n\x01wnternet e-mail address: \x01h\x01w");
					var email_addr = console.getstr(LEN_NETMAIL);
				}
				if(email_addr.toLowerCase() == u.netmail.toLowerCase()) {

					var msgbase = new MsgBase("mail");
					if(msgbase.open()==false)
						alert(log(LOG_ERR,"!ERROR " + msgbase.last_error));
					else {
						var hdr = { to: u.alias,
									to_net_addr: u.netmail, 
									to_net_type: NET_INTERNET,
									from: system.operator, 
									from_ext: "1", 
									subject: system.name + " user account information"
						};

						var msgtxt = "Your user account information was requested on " + system.timestr() + "\r\n";
						msgtxt += "by " + client.host_name + " [" + client.ip_address +"] via " + 
							client.protocol + " (TCP port " + client.port + "):\r\n\r\n";

						msgtxt += "Account Number: " + u.number + "\r\n";
						msgtxt += "Account Created: " + system.timestr(u.stats.firston_date) + "\r\n";
						msgtxt += "Last Login: " + system.timestr(u.stats.laston_date) + "\r\n";
						msgtxt += "Last Login From: " + u.host_name + " [" + u.ip_address + "]" +
										" via " + u.connection + "\r\n";
						msgtxt += "Password: " + u.security.password + "\r\n";
						msgtxt += "Password Last Modified: " + system.datestr(u.security.password_date) + "\r\n";

						if(msgbase.save_msg(hdr, msgtxt)) {
							// Cyberdeck: gray text
							console.print("\r\n\x01n\x01w\x01hAccount Information Emailed Successfully\r\n");
							system.put_telegram(usernum, 
								format("\x01n\x01h%s %s \x01w\x01hEmailed account info\x01n\x01w\r\nto \x01h\x01w%s\x01n\r\n"
									,system.timestr(), system.zonestr()
									,u.netmail));
							log(LOG_NOTICE, "Account information (i.e. password) e-mailed to: " + u.netmail);
						} else
							alert(log(LOG_ERR,"!ERROR " + msgbase.last_error + "saving bulkmail message"));

						msgbase.close();
					}
					continue;
				}
				alert(log(LOG_WARNING,"Incorrect e-mail address: " + email_addr));
			}
		}
	}
	// Password failure counts as 2 attempts
	c++;
}

// Login failure
bbs.hangup();
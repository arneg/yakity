inherit Yakity.Base;

string name;
multiset(MMP.Uniform) members = (<>);

void create(object server, MMP.Uniform uniform, string name) {
	::create(server, uniform);
	this_program::name = name;
}

void groupcast(Yakity.Message m) {
	foreach (members; MMP.Uniform target;) {
		Yakity.Message t = m->clone();
		t->vars["_target"] = target;
		send(t);
	}
}

void castmsg(string mc, string data, mapping vars) {
	Yakity.Message m = Yakity.Message();
	foreach (members; MMP.Uniform t;) {
		sendmsg(t, mc, data, vars, uniform);
	}
}

void stop() {
	foreach (members; MMP.Uniform target;) {
		sendmsg(target, "_notice_leave", "Room is being shut down.", ([ "_supplicant" : target ]), uniform);
	}
}

int _request_enter(Yakity.Message m) {
	MMP.Uniform source = m->source();
	sendmsg(source, "_notice_enter", 0,  ([ "_supplicant" : source, "_members" : (array)members ]), uniform);

	if (!has_index(members, source)) {
		castmsg("_notice_enter", 0,  ([ "_supplicant" : source ]));
		members[source] = 1;
	}

	return Yakity.STOP;
}

int _notice_logout(Yakity.Message m) {
	MMP.Uniform source = m->source();

	members[source] = 0;
	castmsg("_notice_leave", "Logout", ([ "_supplicant" : source ]));
	return Yakity.STOP;
}

int _request_leave(Yakity.Message m) {
	MMP.Uniform source = m->source();

	if (has_index(members, source)) {
		castmsg("_notice_leave", 0, ([ "_supplicant" : source ]));
		members[source] = 0;
	} else {
		sendmsg(source, "_notice_leave", 0, ([ "_supplicant" : source ]), uniform);
	}
	return Yakity.STOP;
}

int _request_profile(Yakity.Message m) {
	MMP.Uniform source = m->source();

	sendmsg(source, "_update_profile", 0, ([ "_profile" : ([ "_name_display" : name ]) ]), uniform);
	return Yakity.STOP;	
}


int _message_public(Yakity.Message m) {
	MMP.Uniform source = m->source();

	if (!has_index(members, source)) {
		sendmsg(source, "_error_membership_required", "You must join the room first.", 0, uniform);
		return Yakity.STOP;
	}

	mapping vars = m->vars + ([ "_source_relay" : m->source() ]);
	castmsg(m->method, m->data, vars);

	return Yakity.STOP;
}

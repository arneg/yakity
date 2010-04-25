/*
Copyright (C) 2008-2009  Arne Goedeke
Copyright (C) 2008-2009  Matt Hardy

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
version 2 as published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/
inherit PSYC.Base;

string name;
multiset(MMP.Uniform) members = (<>);
ADT.CircularList history = ADT.CircularList(10);

void create(object server, MMP.Uniform uniform, string name) {
	::create(server, uniform);
	this_program::name = name;
}

void castmsg(string mc, string data, mapping vars) {
    	Serialization.Atom m = message_signature->encode(PSYC.Message(mc, data, vars));
	foreach (members; MMP.Uniform t;) {
	    	send(t, m);
	}
}

// TODO: We want to use a real psyc multicast here, but we dont have stuff properly
// 	 set up. This will go when PPP is integrated.
void groupcast(PSYC.Message|Serialization.Atom m, void|MMP.Uniform relay) {
	if (object_program(m) == PSYC.Message) {
		m = message_signature->encode(m);
	}

	foreach (members; MMP.Uniform t;) {
	    	send(t, m, relay);	
	}
}

void stop() {
	foreach (members; MMP.Uniform target;) {
		sendmsg(target, "_notice_leave", "Room is being shut down.", ([ "_supplicant" : target ]));
	}

	members = (<>);
}

int _request_enter(MMP.Packet p) {
	MMP.Uniform source = p->source();
	sendmsg(source, "_notice_enter", 0,  ([ "_supplicant" : source, "_members" : (array)members ]));

	if (!has_index(members, source)) {
		castmsg("_notice_enter", 0,  ([ "_supplicant" : source ]));
		members[source] = 1;

	}

	return PSYC.STOP;
}

int _request_history(MMP.Packet p) {
	MMP.Uniform source = p->source();

	if (!has_index(members, source)) {
		sendmsg(source, "_error_membership_required", "You must join the room first.");
		return PSYC.STOP;
	}

	foreach (history;;MMP.Packet p) {
	    	send(source, p->data, p->source());	
	}

	return PSYC.STOP;
}

int _notice_logout(MMP.Packet p) {
	MMP.Uniform source = p->source();

	if (has_index(members, source)) {
		members[source] = 0;
		castmsg("_notice_leave", "Logout", ([ "_supplicant" : source ]));
	}

	return PSYC.STOP;
}

int _request_leave(MMP.Packet p) {
	MMP.Uniform source = p->source();

	if (has_index(members, source)) {
		castmsg("_notice_leave", 0, ([ "_supplicant" : source ]));
		members[source] = 0;
	} else {
		sendmsg(source, "_notice_leave", 0, ([ "_supplicant" : source ]));
	}
	return PSYC.STOP;
}

int _request_profile(MMP.Packet p) {
	MMP.Uniform source = p->source();

	sendmsg(source, "_update_profile", 0, ([ "_profile" : ([ "_name_display" : name ]) ]));
	return PSYC.STOP;	
}


int _message_public(MMP.Packet p) {
	MMP.Uniform source = p->source();

	if (!has_index(members, source)) {
		sendmsg(source, "_error_membership_required", "You must join the room first.");
		return PSYC.STOP;
	}

	if (sizeof(history) == history->max_size()) {
	    history->pop_front();
	}

	history->push_back(p);
	groupcast(p->data, source);

	return PSYC.STOP;
}

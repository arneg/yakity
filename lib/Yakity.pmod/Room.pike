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
inherit MMP.Plugins.ChannelMaster;

string name;
ADT.CircularList history = ADT.CircularList(20);

void create(object server, MMP.Uniform uniform, string name) {
	::create(server, uniform);
	this_program::name = name;
	get_channel()->on_enter = on_enter;
	get_channel()->on_leave = on_leave;
}

void on_enter(MMP.Uniform u) {
    castmsg("_notice_context_enter", 0, ([ "_supplicant" : u ]));
}

void on_leave(MMP.Uniform u) {
    castmsg("_notice_context_leave", 0, ([ "_supplicant" : u ]));
}

void castmsg(string mc, string data, mapping vars, void|MMP.Uniform relay) {
    	Serialization.Atom m = message_signature->encode(PSYC.Message(mc, data, vars));
	get_channel()->groupcast(m, relay ? ([ "_source_relay" : relay ]) : UNDEFINED);
}

void groupcast(PSYC.Message|Serialization.Atom m, void|MMP.Uniform relay) {
	mapping vars = relay ? ([ "_source_relay" : relay ]) : 0;

	if (object_program(m) == PSYC.Message) {
		m = message_signature->encode(m);
	}

	get_channel()->groupcast(m, vars);
}

void stop() {
	foreach (get_channel()->members; MMP.Uniform target;) {
		sendmsg(target, "_notice_leave", "Room is being shut down.", ([ "_supplicant" : target ]));
		get_channel()->remove_member(target);
	}
}

int _request_history(MMP.Packet p) {
	MMP.Uniform source = p->source();

	if (!get_channel()->has_member(source)) {
		sendreplymsg(p, "_error_membership_required", "You must join the room first.");
		return PSYC.STOP;
	}

	foreach (history;;MMP.Packet p) {
	    	send(source, p->data, ([ "_source_relay" : p->source() ]));
	}

	return PSYC.STOP;
}

int _request_profile(MMP.Packet p) {
	MMP.Uniform source = p->source();

	sendreplymsg(p, "_update_profile", 0, ([ "_profile" : ([ "_name_display" : name ]) ]));
	return PSYC.STOP;	
}

int _request_context_enter(MMP.Packet p, PSYC.Message m, void|function cb) {
    int ret = ::_request_context_enter(p, m, cb);
    return ret;
}

int _message_public(MMP.Packet p) {
	MMP.Uniform source = p->source();

	if (!get_channel()->has_member(source)) {
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

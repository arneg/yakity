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

mixed user;
function logout_cb; // logout callback
object mmp_signature;

mapping(MMP.Uniform:int) clients = ([]);

void create(object server, object uniform, mixed user, function logout) {
	::create(server, uniform);
	this_program::user = user;
	logout_cb = logout;
	mmp_signature = Packet(Atom());
}

void implicit_logout() {
	if (logout_cb) {
		logout_cb(this);
		logout_cb = 0;
	} else {
		werror("NO logout callback given. Cleanup seems impossible.\n");
	}

}

void add_client(MMP.Uniform client) {
	clients[client] = 1;

	if (find_call_out(implicit_logout) != -1) {
		remove_call_out(implicit_logout);
	}
}

void remove_client(MMP.Uniform uniform) {
	m_delete(clients, uniform);

	if (!sizeof(clients)) call_out(implicit_logout, 3);
}

int(0..1) is_client(MMP.Uniform uniform) {
	return has_index(clients, uniform);
}

void logout() {
	sendmsg(uniform, "_notice_logout", "You are being terminated. Server restart.", ([]));
	call_out(logout_cb, 0, this);
}

void send_to_clients(MMP.Packet p) {
	foreach (clients; MMP.Uniform client;) {
		mapping vars = p->vars + ([
			"_source_relay" : p->source(),
			"_target" : client,
			"_source" : uniform
		]);
		MMP.Packet new = MMP.Packet(p->data, vars);
		server->msg(new);
	}
}

int _request_link(MMP.Packet p, PSYC.Message m, function callback) {
	// we have only newbie based linking
	if (!sizeof(clients)) {
		add_client(p->source());
	}

	sendreplymsg(p, "_notice_link");
}

int _request_unlink(MMP.Packet p, PSYC.Message m, function callback) {
	remove_client(p->source());
}

int _request_logout(MMP.Packet p) {

	if (p->source() == uniform) {
		implicit_logout();
	}

	return Yakity.STOP;
}

int _message_private(MMP.Packet p, PSYC.Message m, function callback) {
	MMP.Uniform source = p->source();

	// It might be smart to have some kind of smarter detection here.
	// this might go really wrong if people send bad replies
	if (source && source != uniform && p->vars["_source_relay"] != uniform) {
		sendreply(source, p->data, ([ "_source_relay" : source ]));
	}

	return PSYC.GOON;
}

mapping get_profile() {
	return ([ "_name_display" : user->real_name ]);
}

int _request_profile(MMP.Packet p, PSYC.Message m, function callback) {
	MMP.Uniform source = p->source();

	if (source) {
		sendreplymsg(p, "_update_profile", 0, ([ "_profile" : get_profile() ]));
	}

	return PSYC.STOP;
}

int msg(MMP.Packet p) {

	if (::msg(p) == PSYC.STOP) return PSYC.STOP;

	send_to_clients(p);
}

string _sprintf(int type) {
	if (type == 'O') {
		return sprintf("User(%s, %O)", uniform, clients);
	} else {
		return sprintf("User(%s)", uniform);
	}
}

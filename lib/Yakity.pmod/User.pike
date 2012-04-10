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

	call_out(implicit_logout, 3);
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

int(0..1) authenticate(MMP.Uniform uniform) {
	return has_index(clients, uniform) || ::authenticate(uniform);
}

void logout() {
	sendmsg(uniform, "_notice_logout", "You are being terminated. Server restart.", ([]));
	call_out(logout_cb, 0, this);
}

void send_to_clients(MMP.Packet p) {

	if (has_index(p->vars, "_context")) {
	    Serialization.Atom a = Packet(Atom())->encode(p);
	    foreach (clients; MMP.Uniform client;) {
		send(client, a);
	    }
	    return;
	}
	
	if (p->vars["_source_relay"] == uniform) {
		if (!has_index(p->vars, "_context")) {
			werror("Someone disguising as us: %O.\n", p->vars["_source"]);
			return;
		}

	}

	//werror("relaying %s(%s) from %O to users.\n", p->data->type, p->data->render(), p->vars);

	mapping vars = ([
		"_source_relay" : p->source(),
	]) + (p->vars & ({ "_tag", "_tag_reply" }));
	

	foreach (clients; MMP.Uniform client;) {
		send(client, p->data, copy_value(vars));
	}
}

int _request_link(MMP.Packet p, PSYC.Message m, function callback) {
	// we have only newbie based linking
	if (!sizeof(clients)) {
		add_client(p->source());
		sendreplymsg(p, "_notice_link");
	} else {
		sendreplymsg(p, "_failure_link", "This nickname is already taken.");
	}


	return PSYC.STOP;
}

int _request_unlink(MMP.Packet p, PSYC.Message m, function callback) {
	// use the technical source here!
	remove_client(p->vars["_source"]);
}

int _request_authentication(MMP.Packet p, PSYC.Message m, function callback) {
	//werror("%O requests authentication of %O\n", p->source(), m->vars["_supplicant"]);
	if (authenticate(m->vars["_supplicant"])) {
		sendreplymsg(p, "_notice_authentication");
	} else {
		sendreplymsg(p, "_failure_authentication");
	}

	return PSYC.STOP;
}

int _request_logout(MMP.Packet p, PSYC.Message m, function callback) {

	if (p->source() == uniform) {
		implicit_logout();
	}

	return PSYC.STOP;
}

int _message_private(MMP.Packet p, PSYC.Message m, function callback) {
	MMP.Uniform source = p->source();

	//werror("Generating reply for %O\n", source);

	sendreplymsg(p, "_notice_echo");

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
	if (!sizeof(clients) && p->data->type != "_request_link") {
	    if (has_index(p->vars, "_context")) {
		sendmsg(server->get_uniform(uniform->root), "_notice_context_leave", 0, ([ "_channel" : p->vars->_context, "_supplicant" : uniform ]));
		//sendmsg(p->vars->_context, "_failure_delivery_permanent", 0, ([ "_target" : uniform ]));
	    } else if (PSYC.abbrev(p->data->method, "_message")) {
		sendreplymsg(p, "_failure_delivery_permanent", 0, ([ "_target" : uniform ]));
	    } else {
		werror("Dropping packet %O that cannot be delivered.\n");
	    }
	    return PSYC.STOP;
	}
	return Traverse(({ ::msg, send_to_clients}), ({ p }))->start();
}

string _sprintf(int type) {
	if (0 && type == 'O') {
		return sprintf("User(%s, %O)", uniform, clients);
	} else {
		return sprintf("User(%s)", uniform);
	}
}

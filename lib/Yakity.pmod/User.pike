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
inherit Yakity.Base;

array(object) sessions = ({});
mixed user;
function logout_cb; // logout callback
int count = 0; // this is a local counter. the js speaks a subset of 
			   // what psyc should do
object mmp_signature;

// allowed to save 200 messages. this needs to be configurable somewhere.
MMP.Utils.QuotaMap history = MMP.Utils.QuotaMap(200);

void create(object server, object uniform, mixed user, function logout) {
	::create(server, uniform);
	this_program::user = user;
	logout_cb = logout;

	mmp_signature = Packet(Atom());

	object m = Yakity.Message();
	m->method = "_notice_login";
	m->vars = ([ "_profile" : get_profile() ]);
	broadcast(m);
}

void implicit_logout() {
	if (logout_cb) {
		logout_cb(this);
		object m = Yakity.Message();
		m->method = "_notice_logout";
		broadcast(m);
		logout_cb = 0;
	} else {
		werror("NO logout callback given. Cleanup seems impossible.\n");
	}

}

void add_session(object session) {
	sessions += ({ session });
	session->cb = incoming;
	session->error_cb = session_error;
	object m = Yakity.Message();
	m->vars = ([
		"_last_id" : count,
	]);
	m->method = "_status_circuit";
	m->data = "Welcome on board.";
	MMP.Packet p = MMP.Packet(message_encode(m), ([ "_source" : uniform ]));
	session->send(mmp_signature->encode(p));

	if (find_call_out(implicit_logout) != -1) {
		remove_call_out(implicit_logout);
	}
}

void logout() {
	sendmsg(uniform, "_notice_logout", "You are being terminated. Server restart.", ([]));
	call_out(logout_cb, 0, this);
}

void session_error(object session, string err) {
	sessions -= ({ session });
	session->error_cb = 0;
	session->cb = 0;

	if (!sizeof(sessions)) {
		if (-1 == find_call_out(implicit_logout)) call_out(implicit_logout, 0);
	}

	werror("ERROR: %O %s\n", session, err);
}
int _request_history_delete(MMP.Packet p) {
	if (p->source() != uniform) {
		return Yakity.GOON;
	}

	Yakity.Message m = message_decode(p->data);
	array(int) list = m->vars["_messages"];

	if (!arrayp(list)) {
		error("Bad request.\n");
	}

	foreach (list;;int n) {
		if (has_index(history, n)) m_delete(history, n);
	}

	return Yakity.STOP;
}

int _request_history(MMP.Packet p) {
	if (!p->misc["session"]) {
		return Yakity.STOP;
	}

	if (p->source() != uniform) {
		return Yakity.GOON;
	}

	Yakity.Message m = message_decode(p->data);
	array(int) list = m->vars["_messages"];

	if (!arrayp(list)) {
		error("Bad request.\n");
	}

	foreach (list;;int n) {
		if (has_index(history, n)) m->misc->session->send(history[n]);
	}

	return Yakity.STOP;
}

int _request_logout(MMP.Packet p) {

	if (p->source() == uniform) {
		implicit_logout();
	}

	return Yakity.STOP;
}

int _message_private(MMP.Packet p) {
	MMP.Uniform source = p->source();

	// It might be smart to have some kind of smarter detection here.
	// this might go really wrong if people send bad replies
	if (source && source != uniform && p->vars["_source_relay"] != uniform) {
		send(source, p->data, source);
	}

	return Yakity.GOON;
}

mapping get_profile() {
	return ([ "_name_display" : user->real_name ]);
}

int _request_profile(MMP.Packet p) {
	MMP.Uniform source = p->source();

	if (source) {
		sendmsg(source, "_update_profile", 0, ([ "_profile" : get_profile() ]));
	}

	return Yakity.STOP;
}

void incoming(object session, Serialization.Atom atom) {
	MMP.Packet p = mmp_signature->decode(atom);

	//werror("%s->incoming(%O, %O)\n", this, session, m);
	p->vars["_source"] = uniform;

	if (p->target() == uniform) {
		p->misc["session"] = session;
		if (Yakity.STOP == ::msg(p)) {
			return;
		}
		m_delete(p->misc, "session");
		// sending messages to yourself.
	}

	server->deliver(p);
}

int msg(MMP.Packet p) {

	if (::msg(p) == Yakity.STOP) return Yakity.STOP;

#ifdef ATOM_TRACE
	int before = gethrvtime(1);
#endif

	string atom;

	mixed err = catch {
		if (has_index(p->vars, "_context")) {
			mmp_signature->encode(p);
		}

	    	atom = mmp_signature->render(p);
	};

	if (err) {
		werror("Failed to encode %O: %s\n", p, describe_error(err));
		return Yakity.STOP;
	}

#ifdef ATOM_TRACE
	int stamp = gethrvtime(1);
	werror("render: %2.3f ms\t\tlifetime: %2.3f ms\n", (stamp - before) * 1E-6, (before - p->vars["_hrtime"]) * 1E-6);
#endif
	//history[count] = atom;

	foreach (sessions;; object s) { 
	    s->send(atom); 
	}
}

string _sprintf(int type) {
	if (type == 'O') {
		return sprintf("User(%s, %O)", uniform, sessions);
	} else {
		return sprintf("User(%s)", uniform);
	}
}

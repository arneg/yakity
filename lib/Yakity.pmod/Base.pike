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
inherit Serialization.Signature : SIG;
inherit Serialization.BasicTypes;
inherit Serialization.PsycTypes;

object server;
object uniform;
object message_signature;
object smsig;

void create(object server, object uniform) {
	this_program::server = server;
	this_program::uniform = uniform;
	SIG::create(server->type_cache);

	// race here!
	if (!has_index(server->type_cache[Yakity.Types.Message], 0)) {

		object pp = Serialization.Types.PBuilder();
		pp->register_type("string", "_method");
		pp->register_type("string", "_string");
		pp->register_type("int", "_integer");
		pp->register_type("mapping", "_mapping");
		pp->register_type("array", "_list");
		pp->register_type(MMP.Uniform, "_uniform");
		pp = pp->optimize();
		pp->t0 = Method();
		pp->t1 = UTF8String();
		pp->t2 = Int();
		pp->t3 = Mapping(pp,pp);
		pp->t4 = List(pp);
		pp->t5 = Uniform();

		message_signature = Yakity.Types.Message(Method(), Vars(0, ([ "_" : pp ])), pp);
		server->type_cache[Yakity.Types.Message][0] = message_signature;
		server->type_cache[Yakity.Types.Message][1] = smsig = Yakity.Types.Message(Method(), Atom(), Atom());
	} else {
		message_signature = server->type_cache[Yakity.Types.Message][0];
		smsig = server->type_cache[Yakity.Types.Message][1];
	}
}

Yakity.Message message_decode(Serialization.Atom a) {
	return message_signature->decode(a);
}

Serialization.Atom message_encode(Yakity.Message a) {
	return message_signature->encode(a);
}

void send(MMP.Uniform target, Serialization.Atom|Yakity.Message m, void|MMP.Uniform relay) {
	if (object_program(m) == Yakity.Message) {
		m = message_encode(m);
	}

	mapping vars = ([ "_source" : uniform, "_target" : target ]);

	if (relay) {
		vars["_source_relay"] = relay;
	}

	MMP.Packet p = MMP.Packet(m, vars);
	server->deliver(p);
}

void broadcast(Yakity.Message m) {
	MMP.Packet p = MMP.Packet(message_signature->encode(m), ([ "_source" : uniform ]));
	call_out(server->broadcast, 0, p);
}

void sendmsg(MMP.Uniform target, string method, void|string data, void|mapping vars) {
	Yakity.Message m = Yakity.Message();
	m->method = method;
	m->data = data;
	m->vars = vars;
	send(target, m);
}

int msg(MMP.Packet p) {
	string method;
#ifdef ATOM_TRACE
	int pstart = gethrvtime(1);
#endif

	if (sizeof(p->data->typed_data)) {
		method = p->data->typed_data[p->data->signature]->method;
	} else {
		method = smsig->decode(p->data)->method;
	}

#ifdef ATOM_TRACE
	int pstop = gethrvtime(1);
	int sstop;
# define REPORT	do { sstop = gethrvtime(1); werror("parsing: %2.3f\thandling: %2.3f \t", (pstop - pstart)*1E-6, (sstop - pstop)*1E-6); } while (0);
#else
# define REPORT	
#endif

	if (method[0] == '_') {
		mixed f;
		if ((f = this[method]) && functionp(f) && f(p) == Yakity.STOP) {
		    	REPORT;
			return Yakity.STOP;
		} 
	
		array(string) t = method/"_";

		for (int i = sizeof(t)-2; i >=0 ; i--) {
			string s = (i == 0) ? "_" : t[0..i]*"_";
			f = this[s];

			if (functionp(f) && f(p) == Yakity.STOP) {
				REPORT;
				return Yakity.STOP;
			}
		}
	}

	REPORT;
	return Yakity.GOON;
}

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
object server;
object uniform;

void create(object server, object uniform) {
	this_program::server = server;
	this_program::uniform = uniform;
}

void send(Yakity.Message m) {
	if (!m->source()) {
		m->vars["_source"] = uniform;
	}

	call_out(server->deliver, 0, m);
}

void broadcast(Yakity.Message m) {
	call_out(server->broadcast, 0, m);
}

void sendmsg(MMP.Uniform target, string method, string data, mapping vars, void|MMP.Uniform source) {
	Yakity.Message m = Yakity.Message();
	m->method = method;
	m->data = data;
	m->vars = vars || ([]);
	m->vars += ([ "_target" : target ]); // copy this!
	if (source) m->vars["_source"] = source;
	send(m);
}

int msg(Yakity.Message m) {
	string method = m->method;

	if (method[0] = '_') {
		array(string) t = method/"_";

		for (int i = sizeof(t)-1; i >=0 ; i--) {
			string s = (i == 0) ? "_" : t[0..i]*"_";
			mixed f = this[s];

			if (functionp(f)) {
				if (f(m) == Yakity.STOP) {
					return Yakity.STOP;
				}
			}
		}
	}

	return Yakity.GOON;
}

object Uniform() {
	return Serialization.Types.Uniform(server);
}

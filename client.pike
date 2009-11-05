
object parser = Serialization.AtomParser();
object cs, psig, user, server;
object type_cache = Serialization.TypeCache();
mapping messages = ([]);

inherit Serialization.Signature;
inherit Serialization.BasicTypes;
inherit Serialization.PsycTypes;

class FakeUser {
	inherit Yakity.Base;

	void chat_to(MMP.Uniform u) {
		string data = random_string(random(30) + 10);
		messages[data] = client_info(gethrtime());
		sendmsg(u, "_message_private", data);
		call_out(chat_to, 3+random(5), u);
	}

	void _message_private(MMP.Packet p) {
		werror("%O, %O, %d\n", uniform, p->vars["_source_relay"], p->vars["_source_relay"] == uniform);
		if (p->vars["_source_relay"] == uniform) {
			Yakity.Message m = message_decode(p->data);
			if (has_index(messages, m->data)) {
				object info = m_delete(messages, m->data);
				log(([
				 "component" : "user",
				 "method" : "echo",
				 "result" : "OK",
				 "start" : info->start,
				 "stop" : gethrtime(),
				]));
			} else {
				werror("got unknown echo: %O\n", m);
			}
		}
	}
}

class client_info(int start) {}

void log(mapping m) {
	if (m->component == "user") {
		//write("%d %f\n", m->start, (m->stop - m->start)/1000.0);
		werror("%d %f\n", m->start, (m->stop - m->start)/1000.0);
		//werror("%O\n", m);
	}
}

string data(string d) {

	parser->feed(d);

	while (Serialization.Atom a = parser->parse()) {
		user->msg(psig->decode(a));
	}
}

void create() {
	server = this;
	::create(type_cache);
}

mapping(string:MMP.Uniform) ucache = ([]);
object get_uniform(string u) {
	if (!has_index(ucache, u)) {
		ucache[u] = MMP.Uniform(u);
	}
	return ucache[u];
}

void deliver(MMP.Packet p) {
	Serialization.Atom a = psig->encode(p);
	cs->send(a->render());
}

int main(int argc, array(string) argv) {

	if (argc < 3) {
		werror("Not enough arguments given.\n");
		exit(1);
	}

	string url = argv[1];
	int number = (int)argv[2];
	string nick = sprintf("user%d", number);
	string partner = sprintf("user%d", number ^ 1);
	user = FakeUser(this, get_uniform("psyc://127.0.0.4/~"+nick));

	psig = Packet(Atom());

	cs = Meteor.ClientSession(url, log, ([
		"nick" : nick,
	]));
	cs->read_cb = data;

	object u = get_uniform("psyc://127.0.0.4/~"+partner);
	call_out(user->chat_to, 5+random(5), u);
	return -1;
}

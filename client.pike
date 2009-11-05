
object cs, psig, user, server;
object type_cache = Serialization.TypeCache();
mapping messages = ([]);
mapping(MMP.Uniform:object) users = ([]);
string murl, burl;
int lastmsg;
int firstmsg;

inherit Serialization.Signature;
inherit Serialization.BasicTypes;
inherit Serialization.PsycTypes;

class FakeUser {
	inherit Yakity.Base;
	object meteor;
	object parser = Serialization.AtomParser();

	void create(object server, string nick) {
		::create(server, server->get_uniform(burl+"~"+nick));
		meteor = Meteor.ClientSession(murl, log, ([
			"nick" : nick,
		]));
		meteor->read_cb = data;
	}

	string data(string d) {
		parser->feed(d);

		while (Serialization.Atom a = parser->parse()) {
			if (a->type == "_keepalive") continue;
			msg(psig->decode(a));
		}
	}

	void chat_to(MMP.Uniform u) {
		string data = random_string(random(30) + 10);
		messages[data] = client_info(gethrtime());
		sendmsg(u, "_message_private", data);
		call_out(chat_to, 1+random(2.0), u);
	}

	void _message_private(MMP.Packet p) {
		//werror("%O, %O, %d\n", uniform, p->vars["_source_relay"], p->vars["_source_relay"] == uniform);
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

class Average {
	// maximum of sum
	float max;
	array(float) values = ({});

	void create(float max) {
		this_program::max = max;
	}

	this_program add(float t) {
		values += ({ t });
		return this;
	}

	float average() {
		if (sizeof(values) == 0) {
			return 0.0;
		}

		float sum = `+(@values);

		if (sum > max) {
			values = values[1..];
			return average();
		}
		
		return sum/sizeof(values);
	}
}

object av_interval;

void log(mapping m) {
	if (m->component == "user") {
		write("ECHO\t%f\t%f\n", (float)m->start, (m->stop - m->start)/1E3);
	}

	if (m->component == "session" && m->method == "send") {
		write("SEND\t%f\t%f\n", (float)m->start, (m->stop - m->start)/1E3);
	}

	if (m->result == "FAIL") {
		werror("%O\n", m);
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

// this is slightly bullshit, but anyhow. who cares
void deliver(MMP.Packet p) {
	MMP.Uniform source = p->source();
	if (!has_index(users, source)) {
		error("Could not deliver %O\n", p);
	}
	Serialization.Atom a = psig->encode(p);
	users[source]->meteor->send(a->render());
}

int main(int argc, array(string) argv) {

	if (argc < 5) {
		werror("Not enough arguments given.\n");
		exit(1);
	}

	psig = Packet(Atom());
	murl = argv[1];
	burl = argv[2];
	int min = (int)argv[3];
	int max = (int)argv[4];

	for (int i = min; i <= max; i++) {
		string nick = sprintf("user%d", i);
		string partner = sprintf("user%d", i ^ 1);
		user = FakeUser(this, nick);
		users[user->uniform] = user;
		object u = get_uniform(burl+"~"+partner);
		call_out(user->chat_to, 5+random(5.0), u);
	}

 	av_interval = Average(3000.0);

	return -1;
}

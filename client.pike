
object parser = Serialization.AtomParser();
object cs;
object message_signature;
object server;
object type_cache = Serialization.TypeCache();
mapping messages = ([]);
object user;

inherit Serialization.Signature;
inherit Serialization.BasicTypes;
inherit Serialization.PsycTypes;

class FakeUser {
	inherit Yakity.Base;

	void chat_to(MMP.Uniform u) {
		object m = Yakity.Message();
		m->method = "_message_private";
		m->vars = ([
				   "_target" : u,
				   ]);
		m->data = random_string(random(30) + 10);
		
		messages[m->data] = client_info(gethrtime());

		cs->send(message_signature->encode(m)->render());
		call_out(chat_to, 3+random(5), u);
	}

}

class client_info(int start) {}

void log(mapping m) {
	if (m->component == "user") {
		write("%d %f\n", m->start, (m->stop - m->start)/1000.0);
		//werror("%O\n", m);
	}
}

string data(string d) {

	parser->feed(d);

	while (Serialization.Atom a = parser->parse()) {
		user->msg(message_signature->decode(a));
	}

}

void _echo_message_private(Yakity.Message m) {
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

void create() {
	server = this;
	::create(type_cache);
}

object get_uniform(string u) {
	return MMP.Uniform(u);
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

	object pp = Serialization.Types.Polymorphic();
	pp->register_type("string", "_method", Method());                                                                                                                   
	pp->register_type("string", "_string", UTF8String());
	pp->register_type(Yakity.Date, "_time", Yakity.Types.Date());
	pp->register_type("int", "_integer", Int());
	pp->register_type("mapping", "_mapping", Mapping(pp,pp));
	pp->register_type("array", "_list", List(pp));
	pp->register_type(MMP.Uniform, "_uniform", Serialization.Types.Uniform(this));
	message_signature = MMPPacket(Yakity.Types.Message(Method(), Mapping(Method(), pp), UTF8String()));

	cs = Meteor.ClientSession(url, log, ([
		"nick" : nick,
	]));
	cs->read_cb = data;

	object u = get_uniform("psyc://127.0.0.4/~"+partner);
	call_out(user->chat_to, 5+random(5), u);
	return -1;
}

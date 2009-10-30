inherit Serialization.Signature : SIG;
inherit Serialization.BasicTypes;
inherit Serialization.PsycTypes;

object parser = Serialization.AtomParser();
object cs;
object message_signature;


void log(mapping m) {
	werror("%O\n", m);
}


string data(string d) {

	parser->feed(d);

	while (Serialization.Atom a = parser->parse()) {
		werror("Incoming: %O\n", a);

	}

}

void chat_to(MMP.Uniform u) {
	object m = Yakity.Message();
	m->method = "_message_private";
	m->vars = ([
			   "_target" : u,
			   ]);
	m->data = random_string(random(30) + 10);

	cs->send(message_signature->encode(m)->render());
	call_out(chat_to, 10, u);
}

void create() {
	::create(Serialization.TypeCache());
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

	werror("%s and my partner %s\n", nick, partner);

	object pp = Serialization.Types.Polymorphic();
	pp->register_type("string", "_method", Method());                                                                                                                   
	pp->register_type("string", "_string", UTF8String());
	pp->register_type(Yakity.Date, "_time", Yakity.Types.Date());
	pp->register_type("int", "_integer", Int());
	pp->register_type("mapping", "_mapping", Mapping(pp,pp));
	pp->register_type("array", "_list", List(pp));
	pp->register_type(MMP.Uniform, "_uniform", Serialization.Types.Uniform(this));
	message_signature = Yakity.Types.Message(Method(), Mapping(Method(), pp), UTF8String());

	cs = Meteor.ClientSession(url, log, ([
		"nick" : nick,
	]));
	cs->read_cb = data;

	object u = get_uniform("psyc://127.0.0.4/~"+partner);
	call_out(chat_to, 10, u);
	return -1;
}

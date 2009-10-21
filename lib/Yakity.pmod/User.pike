inherit Yakity.Base;
inherit Serialization.Signature : SIG;
inherit Serialization.BasicTypes;
inherit Serialization.PsycTypes;

array(object) sessions = ({});
mixed user;
function logout_cb; // logout callback
int count = 0; // this is a local counter. the js speaks a subset of 
			   // what psyc should do
object message_signature;

mapping(int:object) history = ([]);

void create(object server, object uniform, mixed user, function logout) {
	::create(server, uniform);
	this_program::user = user;
	this_program::logout_cb = logout;

	SIG::create(server->type_cache);

	object pp = Serialization.Types.Polymorphic();
	pp->register_type("string", "_method", Method());                                                                                                                   
	pp->register_type("string", "_string", UTF8String());
	pp->register_type(Yakity.Date, "_time", Yakity.Types.Date());
	pp->register_type("int", "_integer", Int());
	pp->register_type("mapping", "_mapping", Mapping(pp,pp));
	pp->register_type("array", "_list", List(pp));
	pp->register_type(MMP.Uniform, "_uniform", Uniform());
 	message_signature = Yakity.Types.Message(Method(), Mapping(Method(), pp), UTF8String());

	object m = Yakity.Message();
	m->method = "_notice_login";
	m->vars = ([ "_source" : uniform ]);
	broadcast(m);
}

void implicit_logout() {
	logout_cb();
}

void add_session(object session) {
	sessions += ({ session });
	session->cb = incoming;
	session->error_cb = session_error;
	object m = Yakity.Message();
	m->vars = ([
		"_source" : uniform,
		"_last_id" : count,
	]);
	m->method = "_status_circuit";
	m->data = "Welcome on board.";
	session->send(message_signature->encode(m));

	if (find_call_out(implicit_logout) != -1) {
		remove_call_out(implicit_logout);
	}
}

void logout() {
	sendmsg(uniform, "_notice_logout", "You are being terminated. Server restart.", ([]), uniform);

	call_out(logout_cb, 0, this);
}

void session_error(object session, mixed err) {
	sessions -= ({ session });

	if (!sizeof(sessions)) {
		if (-1 == find_call_out(implicit_logout)) call_out(implicit_logout, 10);
	}

	werror("ERROR: %O %s", session, err);
}
int _request_history_delete(Yakity.Message m) {
	if (m->vars["_source"] != uniform) {
		return Yakity.GOON;
	}

	array(int) list = m->vars["_messages"];

	if (!arrayp(list)) {
		error("Bad request.\n");
	}

	foreach (list;;int n) {
		if (has_index(history, n)) m_delete(history, n);
	}

	return Yakity.STOP;
}

int _request_history(Yakity.Message m) {
	if (!m->misc["session"]) {
		return Yakity.STOP;
	}

	if (m->vars["_source"] != uniform) {
		return Yakity.GOON;
	}

	array(int) list = m->vars["_messages"];

	if (!arrayp(list)) {
		error("Bad request.\n");
	}

	foreach (list;;int n) {
		if (has_index(history, n)) m->misc->session->send(history[n]);
	}

	return Yakity.STOP;
}

int _request_logout(Yakity.Message m) {
	logout();

	return Yakity.STOP;
}

int _message_private(Yakity.Message m) {
	object source = m->source();

	if (source && source != uniform) {
		Yakity.Message reply = Yakity.Message();
		reply->vars = copy_value(m->vars);
		m_delete(reply->vars, "_source");
		reply->vars["_target"] = source;
		reply->method = "_echo_message_private";
		reply->data = m->data;
		send(reply);
	}

	return Yakity.GOON;
}

int _request_profile(Yakity.Message m) {
	MMP.Uniform source = m->vars["_source"];

	if (source) {
		Yakity.Message reply = Yakity.Message();
		reply->vars = ([
			"_profile" : ([
				"_name_display" : user->real_name,
			]),
			"_target" : source,
		]);
		reply->method = "_update_profile";
		send(reply);
	}

	return Yakity.STOP;
}

void incoming(object session, Serialization.Atom atom) {
	Yakity.Message m = message_signature->decode(atom);

	werror("%s->incoming(%O, %O)\n", this, session, m);
	m->vars["_source"] = user->source;

	if (m->target() == uniform) {
		m->misc["session"] = session;
		msg(m);
		m_delete(m->misc, "session");

		return;
	}

	// TODO: could be inaccurate.
	m->vars["_timestamp"] = Yakity.Date(time());
	send(m);
}

int msg(Yakity.Message m) {
	werror("%s->msg(%O)\n", this, m);

	Yakity.Message c = m->clone();
	c->vars["_id"] = ++count;

	if (::msg(c) == Yakity.STOP) return Yakity.STOP;

	Serialization.Atom atom;
	mixed err = catch {
		atom = message_signature->encode(c);
	} ;

	if (has_prefix(m->method, "_message") 
	||  has_prefix(m->method, "_echo_message")
	||  has_prefix(m->method, "_notice_enter")
	||  has_prefix(m->method, "_notice_leave")) {
		history[count] = atom;
	}

	foreach (sessions;; object s) {
		s->send(atom);
	}
}

string _sprintf(int type) {
	if (type == 'O') {
		return sprintf("User(%O, %O)", uniform, sessions);
	} else {
		return sprintf("User(%O)", uniform);
	}
}

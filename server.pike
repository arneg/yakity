inherit Meteor.SessionHandler;

mixed configuration;
object server;
object http_server;
object root;
string domain;
mapping(MMP.Uniform:object) users = ([]);
mapping(MMP.Uniform:object) rooms = ([]);

MMP.Uniform to_uniform(void|int type, void|string name) {
	if (type && name) {
		name = Standards.IDNA.to_ascii(name);
		return server->get_uniform(sprintf("psyc://%s/%c%s", domain, type, name));
	} else {
		return server->get_uniform(sprintf("psyc://%s", domain));
	}
}

void stop() {
	foreach (rooms;;object room) {
		room->stop();
	}
	foreach (users;MMP.Uniform u;object o) {
		m_delete(users, u);
		server->unregister_entity(u);
		o->logout();
	}
}

string status() {

	return sprintf("<br>sessions: <br><pre>%O</pre>", sessions)
			+ sprintf("<br> users: <br><pre>%O\n<pre>", users) 
			+ sprintf("<br> rooms: <br><pre>%O</pre>", rooms) 
			+ sprintf("<br> entities: <br><pre>%O</pre>", server->entities);
}


int main(int argc, array(string) argv) {
	domain = argv[2];
	http_server = Protocols.HTTP.Server.Port(handle_request, (int)argv[1], domain);

	server = Yakity.Server(Serialization.TypeCache());
	root = Yakity.Root(server, to_uniform());
	root->users = users;
	root->rooms = rooms;
	server->register_entity(root->uniform, root);
	return -1;
}

class Guest(string real_name) {
}

void logout_callback(object o) {
	m_delete(users, o->uniform);
	server->unregister_entity(o->uniform);
	werror("%O logged out.\n", o->uniform);
};


object get_user(mixed id) {
	MMP.Uniform uniform;
	object o;
	string name = id->variables["nick"];

	//werror("get_user %O\n", id);

	uniform = to_uniform('~', name);

	if (has_index(users, uniform)) return 0;

	object user = Guest(name);
	server->register_entity(uniform, o = Yakity.User(server, uniform, user, logout_callback));
	users[uniform] = o;

	return o;
}

void handle_request(Protocols.HTTP.Server.Request r) {
	string f = basename(r->not_query);
	void answer(int code, string data) {
		r->response_and_finish(([
			"data" : data,
			"error" : code,
		]));
	};
	void end() {
		r->finish(1);
	};

	mixed connection() {
		return r->my_fd;
	};

	mapping id = ([

		"request_headers" : r->request_headers,
		"misc" : ([ 
			"content_type_type" : has_index(r->request_headers, "content-type") ? (r->request_headers["content-type"]/";")[0] : "",
		]),
		"make_response_headers" : r->make_response_header,
		"connection" : connection,
		"data" : r->body_raw,
		"method" : r->request_type,				 
		"variables" : r->variables,
		"answer" : answer,
		"end" : end,
	]);
	//werror("requested: %s?%O\n", f, id->query);

	object session;

	if (id->method == "GET" && !has_index(id->variables, "id")) {
		string name = id->variables["nick"];

		if (!stringp(name) || !sizeof(name)) {
			answer(404, "You need to enter a nickname.");
			return;
		}

		if (sizeof(name) > 30) {
			answer(404, "C'mon, that nickname is too long.");
			return;
		}

		object user = get_user(id);

		if (!user) {
			werror("404 with love!\n");
			answer(404, sprintf("The username %s is already in use.", id->variables["nick"]));
			return;
		}

		session = get_new_session();

		user->add_session(session);
		r->response_and_finish(([
			"data" : session->client_id, 
			"type" : "text/atom",
			"error" : 200,
		]));
		return;
	}


	// we should check whether or not this is hitting a max connections limit somewhere.
	if ((session = sessions[id->variables["id"]])) {
		call_out(session->handle_id, 0, id);
		return;
	}

	werror("'%s' not in sessions %O\n", id->variables["id"], sessions);
	answer(500, "me dont know you");
} 

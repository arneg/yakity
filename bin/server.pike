#if constant(Meteor) 
inherit Meteor.SessionHandler;
#else
#error Cannot find Meteor library.
#endif

#ifndef BASE_PATH
# define BASE_PATH	"htdocs"
#endif

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

void print_help() {
	werror("Usage: server.pike -p <port> -d <domain> -b <bind address> -r <rooms>\n\n");
}

int main(int argc, array(string) argv) {
	array opt;
	mapping options = ([]);

    if (mixed err = catch { opt = Getopt.find_all_options(argv, ({
		({ "domain", Getopt.HAS_ARG, ({ "-d", "--domain" }) }),
		({ "port", Getopt.HAS_ARG, ({ "-p", "--port" }) }),
		({ "rooms", Getopt.HAS_ARG, ({ "-r", "--rooms" }) }),
		({ "bind", Getopt.HAS_ARG, ({ "-b", "--bind" }) }),
					   }), 1); }) {
		werror("error: %O\n", err);
		print_help();
		_exit(1);
    } else foreach (sort(opt);;array t) {
		options[t[0]] = t[1];
	}

	string bind;

	switch (has_index(options, "bind") | has_index(options, "domain") << 1) {
	case 3:
		bind = options["bind"];
		domain = options["domain"];
		break;
	case 2:
		bind = domain = options["domain"];
		break;
	case 1:
		bind = domain = options["bind"];
		break;
	default:
		werror("You have to specify either domain or bind address.\n");
		print_help();
		_exit(1);
	}

	int port = (int)options["port"] || 80;

	http_server = Protocols.HTTP.Server.Port(handle_request, port, bind);
	werror("Started HTTP server on %s:%d\n", bind, port);

	server = Yakity.Server(Serialization.TypeCache());
	root = Yakity.Root(server, to_uniform());
	server->root = root;
	root->users = users;
	root->rooms = rooms;
	server->register_entity(root->uniform, root);
	werror("Ready for clients.\n");
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

void answer(object r, int code, string data) {
	r->response_and_finish(([
		"data" : data,
		"error" : code,
	]));
}

string ext2type(string ext) {
    string t;

    switch (ext) {
	case "html":
	    t = "text/html";
	    break;
	case "js":
	    t = "application/javascript";
	    break;
	case "css":
	    t = "text/stylesheet";
	    break;
	case "png":
	case "jpg":
	case "jpeg":
	case "gif":
	    t = "application/octet-stream";
	    break;
	default:
	    t = "text/plain";
    }

    return t;
}

string make_response_headers(object r, mapping args) {
	mapping m = ([ "error" : 200 ]);
	m["size"] = -1;
	if (has_index(args, "Content-Type")) {
		m->type = args["Content-Type"];
	}
	m["extra_heads"] = args - ({ "Content-Type" });
	string s = r->make_response_header(m);
	return s;
}

void handle_request(Protocols.HTTP.Server.Request r) {
#if 1 || defined(HTTP_TRACE)
	int parsing_time = gethrtime(1) - r->parsing_start;
	werror("parsing time for HTTP request: %O ms\n", parsing_time*1E-6);
#endif
	string f = basename(r->not_query);
	mapping id = ([
		"request_headers" : r->request_headers,
		"misc" : ([ 
			"content_type_type" : has_index(r->request_headers, "content-type") ? (r->request_headers["content-type"]/";")[0] : "",
		]),
		"make_response_headers" : Function.curry(make_response_headers)(r),
		"connection" : Function.curry(`->)(r, "my_fd"),
		"data" : r->body_raw,
		"method" : r->request_type,
		"variables" : r->variables,
		"answer" : Function.curry(answer)(r),
		"end" : Function.curry(r->finish)(1),
	]);

	object session;

	switch (r->not_query) {
	    case "/":
	    {
		string s = replace(Stdio.read_file(sprintf("%s/index.html", (BASE_PATH))), "<meteorurl/>", "/meteor/");

		r->response_and_finish(([ "error" : 200,
					  "data" : s,
					  "type" : "text/html",
					  ]));
		return;
	    }
	}

	if (search(r->not_query, ".") != -1) {
	    string fname = sprintf("%s/%s", (BASE_PATH), r->not_query);

	    if (Stdio.exist(fname)) {
		r->response_and_finish(([ "error" : 200,
					  "file" : Stdio.File(fname),
					  "type" : ext2type((r->not_query / ".")[-1]),
					  ]));
		return;
	    } else {
			werror("%O not found.\n", fname);
		answer(r, 404, "File does not exist.");
		return;
	    }
	}

	write("survived tobij code\n");

	if (id->method == "GET" && !has_index(id->variables, "id")) {
		string name = id->variables["nick"];

		if (!stringp(name) || !sizeof(name)) {
			answer(r, 404, "You need to enter a nickname.");
			return;
		}

		if (sizeof(name) > 30) {
			answer(r, 404, "C'mon, that nickname is too long.");
			return;
		}

		object user = get_user(id);

		if (!user) {
			werror("404 with love!\n");
			answer(r, 404, sprintf("The username %s is already in use.", id->variables["nick"]));
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
	answer(r, 500, "me dont know you");
} 

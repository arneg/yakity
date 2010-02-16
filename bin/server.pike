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
	werror("\tThe bind address is optional. If not given, the domain is used as the bind address instead.\n");
}

class HTTPRequest {
	inherit Protocols.HTTP.Server.Request;
#ifdef TRACE_SOFT_MEMLEAKS
	inherit MMP.Utils.Screamer;
#endif

#ifdef HTTP_TRACE
	int parsing_start = 0;
	protected void read_cb(mixed dummy, string s) {
		if (!parsing_start && sizeof(s)) {
			parsing_start = gethrvtime(1);
		}
		::read_cb(dummy, s);
	}
	
	void finish(int clean) {
		parsing_start = 0;
		::finish(clean);
	}
#endif
	
}

#if constant(get_profiling_info)
void print_profiling_info(array|program a) {
    if (!arrayp(a)) a = ({ a });
    foreach (a;;program p) {
	mapping(string:array(int)) m = get_profiling_info(p)[1];

	werror("\n");
	
	foreach (sort(indices(m));;string fun) {
	    array(int) times = m[fun];
	    if (fun != "__INIT")
		werror("%O->%-20s %10f %10f micro s %8d calls\n", p, fun, (float)times[2]*1000/times[0], (float)times[1]*1000/times[0], times[0]);
	}
    }
}
#endif

void onexit(int signal) {
#ifdef TRACE
# if constant(get_profiling_info)
	catch { print_profiling_info(TRACE); };
# endif
#endif
	exit(0);
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

	mixed err = catch {
	    array(int) nofile = System.getrlimit("nofile");
	    if (arrayp(nofile) && sizeof(nofile) == 2 && nofile[1] > -1 && nofile[1] < 10000) {
		werror("Warning: The number of file descriptors is limited to %d. This will limit the amount of users you can serve.\n", nofile[1]);
	    }
	};

	http_server = Protocols.HTTP.Server.Port(handle_request, port, bind);
	http_server->request_program = HTTPRequest;
	werror("Started HTTP server on %s:%d\n", bind, port);

	server = Yakity.Server(Serialization.TypeCache());

	if (has_index(options, "rooms")) {
	    foreach (options["rooms"]/",";; string name) {
		name = String.trim_all_whites(name);
		MMP.Uniform u = to_uniform('@', name);
		object r = Yakity.Room(server, u, name);
		rooms[u] = r;
		server->register_entity(u, r);
	    }
	}

	werror("Created %d Rooms:\t%s\n", sizeof(rooms), (array(string))indices(rooms) * "\n\t\t\t" );

	root = Yakity.Root(server, to_uniform());
	root->users = users;
	root->rooms = rooms;
	server->root = root;
	server->register_entity(root->uniform, root);
	werror("Ready for clients.\n");
#if defined(TRACE) && !constant(get_profiling_info)
	werror("Warning: TRACE can only be used if pike has been compile --with-profiling.\n");
#endif
#ifdef TRACE
	signal(signum("SIGINT"), onexit);
#endif
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
    switch (ext) {
	case "html":
	    return "text/html";
	case "js":
	    return "application/javascript";
	case "css":
	    return "text/stylesheet";
	case "ico":
	    return "image/vnd.microsoft.icon";
	case "wav":
	    return "audio/wav";
	case "png":
	case "jpg":
	case "jpeg":
	case "gif":
	    return "application/octet-stream";
	default:
	    return "text/plain";
    }
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

// caching index.html with replacements
string index;
int ctime;

void handle_request(Protocols.HTTP.Server.Request r) {
#if defined(HTTP_TRACE)
	int parsing_time = gethrvtime(1) - r->parsing_start;
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
#ifdef TRACE_SOFT_MEMLEAKS
		"screamer" : MMP.Utils.Screamer(),
#endif
	]);

	object session;

	switch (r->not_query) {
	    case "/":
	    {
		string fname = sprintf("%s/index.html", (BASE_PATH));
		if (!index || file_stat(fname)->ctime > ctime) {
		    index = replace(Stdio.read_file(fname), "<meteorurl/>", "/meteor/");
		    mixed emitcb(Parser.HTML parser, mapping args, string content) {
			if (args["source"] == "chat_rooms") {
			    array(string) ret = allocate(sizeof(rooms));
			    int i = 0;
			    foreach (rooms; MMP.Uniform u; object o) {
				string t = replace(content, "&_.uniform;", (string)u);
				t = replace(t, "&_.name;", o->name);
				ret[i++] = t;	
			    }
			    return ret;
			}
			return 0;
		    };
		    object p = Parser.HTML();
		    p->add_container("emit", emitcb);
		    index = p->feed(index)->finish()->read();
		} 
		
		// handle the room names.

		r->response_and_finish(([ "error" : 200,
					  "data" : index,
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
			"extra_heads" : ([
				"Cache-Control" : "no-cache",
			]),
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

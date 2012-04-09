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
mapping(MMP.Uniform:object) users = ([]);
mapping(MMP.Uniform:object) rooms = ([]);

void print_help() {
werror(#"Usage: pike -M lib bin/server.pike [OPTIONS]\n
Possible options are:
 -h		: Print this message
 --hilfe	: Start an interactive server console
 --bind		: Address to bind
 --http-bind	: Address to bind for HTTP
 --psyc-bind	: Address to bind for PSYC
 	The above expect arguments of the form <domain>[:<port>].
 --domain	: Domain to use. Only necessary if different from the psyc-bind address.
 		  Should be used for NAT situations.
 --rooms	: List of rooms to create. Expects a comma seperated list of names.
");
}

void ERROR(mixed ... args) {
    werror(@args);
    print_help();
    exit(1);
}

void WARN(mixed ... args) {
    werror(@args);
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
		werror("%O->%-20s %10f %10f micro s %8d calls\t(%3.2f, %3.2f) ms\n", p, fun, (float)times[2]*1000/times[0], (float)times[1]*1000/times[0], times[0], (float)times[2], (float)times[1]);
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
		({ "rooms", Getopt.HAS_ARG, ({ "-r", "--rooms" }) }),
		({ "bind", Getopt.HAS_ARG, ({ "-b", "--bind" }) }),
		({ "psyc_bind", Getopt.HAS_ARG, ({ "--psyc-bind" }) }),
		({ "http_bind", Getopt.HAS_ARG, ({ "--http-bind" }) }),
		({ "hilfe", Getopt.NO_ARG, ({ "--hilfe" }) }),
		({ "help", Getopt.NO_ARG, ({ "-h" }) }),
					   }), 1); }) {
		ERROR("error: %O\n", err);
	} else foreach (sort(opt);;array t) {
		options[t[0]] = t[1];
	}

	if (options->help) {
	    print_help();
	    exit(0);
	}

	string http_bind = options->http_bind || options->bind || options->domain;
	string psyc_bind = options->psyc_bind || options->bind || options->domain;
	int psyc_port, http_port;

	if (!stringp(http_bind) || 1 == sscanf(http_bind, "%[^:]:%d", http_bind, http_port)) http_port = 80;
	if (!stringp(psyc_bind) || 1 == sscanf(psyc_bind, "%[^:]:%d", psyc_bind, psyc_port)) psyc_port = MMP.DEFAULT_PORT;

	if (!http_bind && !psyc_bind) {
	    ERROR("You have to specify a psyc or a http address to bind.\n");
	}

	mixed err = catch {
	    array(int) nofile = System.getrlimit("nofile");
	    if (arrayp(nofile) && sizeof(nofile) == 2 && nofile[1] > -1 && nofile[1] < 10000) {
		WARN("Warning: The number of file descriptors is limited to %d. This will limit the amount of users you can serve.\n", nofile[1]);
	    }
	};

	if (http_bind) {
	    werror("Starting HTTP server on %s:%d\n", http_bind, http_port);
	    http_server = Protocols.HTTP.Server.Port(handle_request, http_port, http_bind);
	    http_server->request_program = HTTPRequest;
	}

	mapping m = ([]);
	string domain;

	if (psyc_bind) {
	    m->bind = sprintf("%s:%d", psyc_bind||"0.0.0.0", psyc_port);

	    if (options->domain) {
		int port;

		switch (sscanf(options->domain, "%[^:]:%d", domain, port)) {
		case 0: if (!sizeof(domain)) ERROR("Malformed domain '%s'. Expected <host>[:<port>]\n", options->domain);
		case 1: port = MMP.DEFAULT_PORT; break;
		}
		if (domain != psyc_bind || port != psyc_port) m->vhosts = ({ sprintf("%s:%d", domain, port) });
	    } else domain = psyc_bind || http_bind;
	    werror("Using domain %s\n", domain||options->domain);

	    if (psyc_bind) werror("Starting WZTZ server on %s:%d\n", psyc_bind, psyc_port);
	    m->get_new = get_user;

	    server = MMP.Server(m);

	    if (has_index(options, "rooms")) {
		foreach (options["rooms"]/",";; string name) {
		    name = String.trim_all_whites(name);
		    MMP.Uniform u = server->to_uniform('@', name);
		    object r = Yakity.Room(server, u, name);
		    rooms[u] = r;
		    server->register_entity(u, r);
		}
		werror("Created Rooms:\t%s\n", (array(string))indices(rooms) * "\n\t\t\t" );
	    }


	    root = Yakity.Root(server, server->to_uniform());
	    root->users = users;
	    root->rooms = rooms;
	    server->register_entity(root->uniform, root);
	}
	werror("Ready for clients.\n");
#if defined(TRACE) && !constant(get_profiling_info)
	WARN("Warning: TRACE can only be used if pike has been compile --with-profiling.\n");
#endif
#ifdef TRACE
	signal(signum("SIGINT"), onexit);
#endif
	if (options->hilfe) {
	    mapping variables = ([]);
	    variables->broadcast = server->broadcast;
	    variables->server = server;
	    werror("Available variables are: %s\n", indices(variables) * ", ");
	    object stdin = Stdio.File();
	    stdin->assign(Stdio.stdin);
	    object stdout = Stdio.File();
	    stdout->assign(Stdio.stdout);

	    object hilfe = MMP.Utils.Hilfe(stdin, stdout);
	    hilfe->variables += variables;
#ifdef MEASURE_THROUGHPUT
	    hilfe->variables->do_it = do_it;
	    Meteor.measure_bytes(print, 1);
#endif
	}

	return -1;
}


#ifdef MEASURE_THROUGHPUT
void do_it(int i) {
    for (int j; j < i; j++) {
	call_out(server->root->broadcast, 0, Yakity.Message("_message_barsch", "sdfsd"*30, ([ "_nick" : "forelle" ])));
    }
}

void print(float f, float g) {
    write("o: %f mb/s,\ti: %f mb/s\n", f /1024/1024, g / 1024 / 1024);
    Meteor.measure_bytes(print, 1);
}
#endif

class Guest(string real_name) {
}

void logout_callback(object o) {
	m_delete(users, o->uniform);
	server->unregister_entity(o->uniform);
	werror("%O logged out.\n", o->uniform);
};


object get_user(MMP.Uniform uniform) {
	object o;
	string name = uniform->resource;
	if (name[0] != '~') return 0;
	name = name[1..];

	object user = Guest(name);
	o = Yakity.User(server, uniform, user, logout_callback);
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
	    return "text/css";
	case "ico":
	    return "image/vnd.microsoft.icon";
	case "wav":
	    return "audio/wav";
	case "ogg":
	    return "application/ogg";
	case "mp3":
	    return "application/mpeg";
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
	string path = Stdio.simplify_path(r->not_query);
	string f = basename(path);
	mapping id = ([
		"request_headers" : r->request_headers,
		"misc" : ([ 
			"content_type_type" : has_index(r->request_headers, "content-type") ? (r->request_headers["content-type"]/";")[0] : "",
		]),
		"make_response_headers" : Function.curry(make_response_headers)(r),
		"connection" : Function.curry(`->)(r, "my_fd"),
		"data" : r->body_raw,
		"method" : r->request_type,
#if constant(Protocols.HTTP.Server.Request.send_chunk)
		"send_chunk" : r->send_chunk,
#endif
		
		"variables" : r->variables,
		"answer" : Function.curry(answer)(r),
		"end" : Function.curry(r->finish)(1),
#ifdef TRACE_SOFT_MEMLEAKS
		"screamer" : MMP.Utils.Screamer(),
#endif
	]);

	object session;

	if (has_prefix(path, "/cgi-bin/")) {
	    if (Stdio.exist(path[1..])) {
		program p = (program)(".."+path);
		object o = p(this);

		o->parse(r);
	    } else {
		r->response_and_finish(([ "error" : 404,
					  "type" : "text/html",
					  "data" : sprintf("<h1>You broke <pre>%O</pre>, you buy it!", path) ]));
	    }

	    return;
	}

	switch (path) {
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

	if (search(path, ".") != -1) {
	    string fname = sprintf("%s/%s", (BASE_PATH), path);

	    if (Stdio.exist(fname)) {
		r->response_and_finish(([ "error" : 200,
					  "file" : Stdio.File(fname),
					  "type" : ext2type((path / ".")[-1]),
					  ]));
		return;
	    } else {
		werror("%O not found.\n", fname);
		answer(r, 404, Stdio.read_file((BASE_PATH) + "/404.inc"));
		return;
	    }
	}

	if (id->method == "GET" && !has_index(id->variables, "id")) {
		MMP.Uniform uniform = server->get_temporary();
		session = get_new_session();

		object temp = PSYC.Proxy(server, uniform, session);
		server->register_entity(uniform, temp);

		string response = sprintf("_id %s_uniform %s", Serialization.Atom("_string", session->client_id)->render(), Serialization.Atom("_string", (string)uniform)->render());

		r->response_and_finish(([
			"data" : Serialization.Atom("_vars", response)->render(), 
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

	werror("unknown session '%s'\n", id->variables["id"]);
	answer(r, 500, "me dont know you");
} 

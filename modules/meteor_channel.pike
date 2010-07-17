#include <module.h>

inherit "module";

constant module_type = MODULE_LOCATION|MODULE_TAG|MODULE_PROVIDER;
constant module_name = "Meteor";
constant module_doc = "This is a module to allow for realtime server push and user interaction. It features a simple channel model."
		      "It uses the same libraries as the webchat software <a href=\"http://yakitychat.com\">YakityChat</a>.";
constant module_author = "Arne Goedeke <a href=\"mailto:el@laramies.com\">";

inherit Meteor.SessionHandler;

mixed configuration;
object parser;
mapping(string:object) channels = ([]);

class Channel {
    mapping(object:int) subs = ([]);

    void add_session(object session) {
    }
    void publish(mixed o) {

    }
}

void stop() {
}

string status() {
	return sprintf("<br>sessions: <br><pre>%O</pre>", sessions);
}

void create() {
	set_module_creator("Arne Goedeke el@laramies.com");
	set_module_url("http://yakitychat.com");
	defvar("location", Variable.Location("/meteor/",
					     0, "Connection endpoint for js connections", "This is where the "
					     "module will be inserted in the virtual "
					     "namespace of your server."));
}

int start(int c, Configuration conf) {
	if (!configuration) {
		this_program::configuration = conf;
	}
}

function combine(function f1, function f2) {
	mixed f(mixed ...args) {
		return f1(f2(@args));
	};

	return f;
}

string make_response_headers(mapping headers) {
	return "HTTP/1.1 200 OK\r\n" + Roxen.make_http_headers(headers);
}

mixed find_file( string f, object id ) {
	//werror("requested: %s?%O\n", f, id->query);
	NOCACHE();

	object session;

	if (id->method == "GET" && !has_index(id->variables, "id")) {
		MMP.Uniform uniform = server->get_temporary();
		session = get_new_session();

		object temp = PSYC.Proxy(server, uniform, session);
		server->register_entity(uniform, temp);

		string response = sprintf("_id %s_uniform %s", Serialization.Atom("_string", session->client_id)->render(), Serialization.Atom("_string", (string)uniform)->render());

		return Roxen.http_string_answer(Serialization.Atom("_vars", response)->render(), "text/atom");
	}


	// we should check whether or not this is hitting a max connections limit somewhere.
	if ((session = sessions[id->variables["id"]])) {
		mapping new_id = ([
			"variables" : id->variables,
			"answer" : combine(id->send_result, Roxen.http_low_answer),
			"end" : id->end,
			"method" : id->method,
			"request_headers" : id->request_headers,
			"misc" : ([ 
				"content_type_type" : id->misc["content_type_type"],
			]),
			"make_response_headers" : make_response_headers,
			"connection" : id->connection,
			"data" : id->data,
		]);
		call_out(session->handle_id, 0, new_id);
		return Roxen.http_pipe_in_progress();
	}

	werror("'%s' not in sessions %O\n", id->variables["id"], sessions);
	
	return Roxen.http_low_answer(500, "me dont know you\n");
} 

string simpletag_sendmsg(string tagname, mapping args, string content, RequestID id) {
	NOCACHE();
	MMP.Uniform target = server->get_uniform(args["_target"]);

	mapping vars = ([]);
	foreach (args; string index; string val) {
		if (has_prefix(index, "_")) {
			vars[index] = val;
		}
	}

	root->sendmsg(target, args["method"], content, vars);
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc= ([
"sendmsg":#"
<desc type='cont'>Send a message to a given entity. All parameters starting with '_' are treated as variables to the packet. The tag content will be used as the packets data element. </desc>
<attr name=_target value=String><p> The address of the target entity.  </p></attr>
<attr name=method value=String><p> The method of the packet.  </p></attr> ",
"emit#chat_entities":#"
<desc type='cont'>Emits all entities known to the chat server. It offers the two variables 'uniform' and 'name'.</desc> ",
]);
#endif

#include <module.h>

inherit "module";

constant module_type = MODULE_LOCATION|MODULE_TAG|MODULE_PROVIDER;
constant module_name = "Meteor";
constant module_doc = "This is a module to allow for realtime server push and user interaction. It features a simple channel model."
		      "It uses the same libraries as the webchat software <a href=\"http://yakitychat.com\">YakityChat</a>.";
constant module_author = "Arne Goedeke <a href=\"mailto:el@laramies.com\">";

inherit Meteor.SessionHandler;
inherit Serialization.Signature : SIG;
inherit Serialization.BasicTypes;

mixed configuration;
object parser;
mapping(string:object) channels = ([]);

class Channel(string name) {
    mapping(object:int) subs = ([]);

    void add_session(object session) {
	subs[session] = 1;
    }

    void del_session(object session) {
	m_delete(subs, session);
    }

    void publish(mixed o) {
	if (sizeof(subs)) {
	    string s = parser->encode(({ name, o }))->render();
	    indices(subs)->send(s);
	} else {
	    call_out(m_delete, 0, channels, this);
	}
    }

    object session_error(object session, mixed ... args) {
	m_delete(subs, session);
	if (!sizeof(subs)) call_out(m_delete, 0, channels, this);
	return session;
    }
}

string query_provides() {
    return "meteor";
}

void publish(string channel, mixed o) {
    if (has_index(channels, channel)) {
	channels[channel]->publish(o);
    }
}

void stop() {
    values(sessions)->close();
}

string status() {
	return sprintf("<br>sessions: <br><pre>%O</pre>", sessions);
}

void create() {
	SIG::create(Serialization.TypeCache());
	set_module_creator("Arne Goedeke el@laramies.com");
	set_module_url("http://yakitychat.com");
	defvar("location", Variable.Location("/meteor/",
					     0, "Connection endpoint for js connections", "This is where the "
					     "module will be inserted in the virtual "
					     "namespace of your server."));
	parser = Serialization.Types.PBuilder();
	parser->register_type("string", "_string");
	parser->register_type("int", "_integer");
	parser->register_type("mapping", "_mapping");
	parser->register_type("array", "_list");
	parser = parser->optimize();
	parser->t0 = UTF8String();
	parser->t1 = Int();
	parser->t2 = Mapping(parser,parser);
	parser->t3 = List(parser);
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

#if 0
	if (id->method == "GET" && !has_index(id->variables, "id")) {
		session = get_new_session();

		string response = sprintf("_id %s", Serialization.Atom("_string", session->client_id)->render());

		return Roxen.http_string_answer(Serialization.Atom("_vars", response)->render(), "text/atom");
	}
#endif


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

string string_to_json(string s) {
#if constant(Public.Standards.JSON)
    return Public.Standards.JSON.encode(s);
#else
    // this is evil, but channel names are expected to be ok
    return sprintf("%O", s);
#endif
}

string simpletag_subscribe(string tagname, mapping args, string content, RequestID id) {
	string channel = args->channel;
	string cid;
	string callback = args->callback;
	object session;
	if (!stringp(channel) || !sizeof(channel)) error("No channel specified!");
	if (!stringp(callback) || !sizeof(callback)) error("No callback specified!");
	if (!has_index(channels, channel)) {
	    channels[channel] = Channel(channel);
	}
	if (!id->misc->meteor) {
	    id->misc->meteor = session = get_new_session();
	    session->error_cb = channels[channel]->session_error;
	    cid = session->client_id;
	} else {
	    session = id->misc->meteor;
	    session->error_cb = combine(channels[channel]->session_error, session->error_cb);
	}
	channels[channel]->add_session(session);
	if (cid) {
	    return sprintf(#"
		if (!meteor.default_sub) {
		    meteor.default_sub = new meteor.Subscriber(new meteor.Connection(%s, { id : %s }, 0, function(){}));
		    meteor.default_sub.connection.connect_new_incoming();
		    meteor.default_sub.subscribe(%s, %s);
		}
	    ", string_to_json(query("location")), string_to_json(cid), string_to_json(channel), callback);
	} else {
	    return sprintf(#"
		meteor.default_sub.subscribe(%s, %s);
	    ", string_to_json(channel), callback);
	}
}

string simpletag_publish(string tagname, mapping args, string content, RequestID id) {
	NOCACHE();
	string channel = args->channel;
	if (has_index(channels, channel)) {
	    channels[channel]->publish(content);
	}
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

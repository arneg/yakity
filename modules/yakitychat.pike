#include <module.h>

inherit "module";

constant module_type = MODULE_LOCATION|MODULE_TAG|MODULE_PROVIDER;
constant module_name = "YakityChat";
constant module_doc = "Webchat module. Check out the docs on the <a href=\"http://yakitychat.com/\" alt=\"Look for documentation here.\">YakityChat homepage</a>.";

constant unique = 1;
//constant thread_safe = 1;
//
inherit Meteor.SessionHandler;

mixed configuration;
object server;
object root;
mapping(MMP.Uniform:object) users = ([]);
mapping(MMP.Uniform:object) rooms = ([]);

MMP.Uniform to_uniform(void|int type, void|string name) {
	string domain = configuration->query("Domain");
	if (domain == "nowhere") domain = roxen->get_domain();
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

void create() {
	defvar("location", Variable.Location("/meteor/",
										 0, "Connection endpoint for js connections", "This is where the "
										 "module will be inserted in the virtual "
										 "namespace of your server."));
	defvar("rooms", Variable.StringList(({}), 0, "List of Rooms", "This is the list of rooms that users may join."));

}

int start(int c, Configuration conf) {
	if (!configuration) {
		this_program::configuration = conf;
		server = Yakity.Server(Serialization.TypeCache());
		root = Yakity.Root(server, to_uniform());
		root->users = users;
		root->rooms = rooms;
		server->register_entity(root->uniform, root);
		server->root = root;
	}
	if (!c) {
		getvar("rooms")->set_changed_callback(changed);
	}
	changed(getvar("rooms"));
}

class Guest(string real_name) {
}

void logout_callback(object o) {
	m_delete(users, o->uniform);
	server->unregister_entity(o->uniform);
	werror("%O logged out.\n", o->uniform);
};


object get_user(RequestID id) {
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
		string name = id->variables["nick"];

		if (!stringp(name) || !sizeof(name)) {
			return Roxen.http_low_answer(404, "You need to enter a nickname.");
		}

		if (sizeof(name) > 30) {
			return Roxen.http_low_answer(404, "C'mon, that nickname is too long.");
		}

		object user = get_user(id);

		if (!user) {
			werror("404 with love!\n");
			return Roxen.http_low_answer(404, sprintf("The username %s is already in use.", id->variables["nick"]));
		}

		session = get_new_session();

		user->add_session(session);
		return Roxen.http_string_answer(session->client_id, "text/atom");
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

void changed(Variable.StringList var) {
	// TODO delete things.
	mapping should = ([]);
	
	foreach (var->query(); ; string name) {
		if (!sizeof(name)) continue;

		MMP.Uniform u = to_uniform('@', name);
		should[u] = 1;
		if (!has_index(rooms, u)) {
			object r = Yakity.Room(server, u, name);
			rooms[u] = r;
			server->register_entity(u, r);
		}
	}

	// sort out the old ones
	foreach (rooms; MMP.Uniform u; object room) {
		if (!has_index(should, u)) {
			room->stop();
			server->unregister_entity(u);
			m_delete(rooms, u);
		}
	}
}


class TagRoomEmit {
    inherit RXML.Tag;

    constant name = "emit";
    constant plugin_name = "chat_rooms";

    array(mapping(string:string)) get_dataset(mapping m, RequestID id) {
		NOCACHE();
		mapping cb(MMP.Uniform u) {
			return ([
				"uniform" : (string)u,
				"name" : u->resource,
			]);
		};
		return map(indices(rooms), cb);
    }
}

class TagMemberEmit {
    inherit RXML.Tag;

    constant name = "emit";
    constant plugin_name = "room_members";

    array(mapping(string:string)) get_dataset(mapping m, RequestID id) {
		NOCACHE();
		mapping cb(MMP.Uniform u) {
			return ([
				"uniform" : (string)u,
				"name" : u->resource,
			]);
		};
		mixed room;
		if (!has_index(m, "room") || !sizeof(room = m["room"])) { 
			error("You have to specify a room.");
		}

		room = rooms[server->get_uniform(room)];

		if (!room) {
			return ({});
		}
		return map(indices(room->members), cb);
    }
}

string simpletag_user2uniform(string tagname, mapping args, string content, RequestID id) {
	return (string)to_uniform('~', args["user"]);
}

string simpletag_meteorurl(string tagname, mapping args, string content, RequestID id) {
	return query("location");
}


class TagUserEmit {
    inherit RXML.Tag;

    constant name = "emit";
    constant plugin_name = "chat_users";

    array(mapping(string:string)) get_dataset(mapping m, RequestID id) {
		NOCACHE();
		mapping cb(MMP.Uniform u) {
			return ([
				"uniform" : (string)u,
				"name" : u->resource,
			]);
		};
		return map(indices(users), cb);
    }
}

class TagEntitiesEmit {
    inherit RXML.Tag;

    constant name = "emit";
    constant plugin_name = "chat_entities";

    array(mapping(string:string)) get_dataset(mapping m, RequestID id) {
		NOCACHE();
		mapping cb(MMP.Uniform u) {
			return ([
				"uniform" : (string)u,
				"name" : u->resource,
			]);
		};
		return map(indices(server->entities), cb);
    }
}

string simpletag_sendmsg(string tagname, mapping args, string content, RequestID id) {
	MMP.Uniform target = server->get_uniform(args["_target"]);
	object user;
	NOCACHE();

	if (!(user = server->get_entity(target))) {
		werror("sendmsg to unknown user %s.\n", args["_target"]);
		return "";
	}

	Yakity.Message m = Yakity.Message();
	m->method = args["method"];
	m->vars = ([]);
	m->data = content;
	foreach (args; string index; string val) {
		if (has_prefix(index, "_")) {
			m->vars[index] = val;
		}
	}

	user->msg(m);
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc= ([
"user2uniform":#"
<desc type='tag'>Generates a users uniform.</desc>
<attr name=user value=String><p>
The users name.
</p></attr>",
"emit#chat_rooms":#"
<desc type='cont'>Emits all currently available rooms. It offers the two variables 'uniform' and 'name'.</desc> ",
"emit#room_members":#"
<desc type='cont'>Emits all users that are currently in the specified room. It offers the two variables 'uniform' and 'name'.</desc>
<attr name=room value=String><p>
The uniform of the room.
</p></attr>",
"meteorurl":#"
<desc type='tag'>Returns the meteor connection endpoint.</desc> ",
"user2uniform":#"
<desc type='tag'>Generates a users uniform.</desc>
<attr name=user value=String><p>
The users name.
</p></attr>",
"emit#chat_users":#"
<desc type='cont'>Emits all users currently logged in using a js connection. It offers the two variables 'uniform' and 'name'.</desc> ",
"sendmsg":#"
<desc type='cont'>Send a message to a given entity. All parameters starting with '_' are treated as variables to the packet. The tag content will be used as the packets data element. </desc>
<attr name=_target value=String><p> The address of the target entity.  </p></attr>
<attr name=method value=String><p> The method of the packet.  </p></attr> ",
"emit#chat_entities":#"
<desc type='cont'>Emits all entities known to the chat server. It offers the two variables 'uniform' and 'name'.</desc> ",
]);
#endif

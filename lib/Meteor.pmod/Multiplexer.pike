//mapping(string:object) channels = set_weak_flag(([]), Pike.WEAK);
mapping(string:object) channels = ([]);
mapping callbacks = ([]);

#ifdef _CONNECT
function new_con;
#endif

function _callback, _may_channel;
mixed session;
object ReqParser, SuccParser;

class Success {
    string name;

    void create(string|void name) {
	this_program::name = name;
    }

    string _sprintf(int fmt) {
	switch (fmt) {
	case 'O':
	    return sprintf("Success(%O)", name);
	}

	return 0;
    }
}

class Fail {
    string name, reason;

    void create(string|void name, string|void reason) {
	this_program::name = name;
	this_program::reason = reason;
    }

    string _sprintf(int fmt) {
	switch (fmt) {
	case 'O':
	    return sprintf("Fail(%O, %O)", name, reason);
	}
	return 0;
    }
}

class Req {
    string name;

    string _sprintf(int fmt) {
	switch (fmt) {
	case 'O':
	    return sprintf("Req(%O)", name);
	}

	return 0;
    }
}

object get_new_channel(string name) {
    if (has_index(channels, name)) {
	error("A Channel with name %O already exists in %O.\n",
	      name, this);
    }

    return channels[name] = .Channel(name, session);
}

object get_channel(string name) {
    return channels[name] || get_new_channel(name);
}

int(0..1) has_channel(string name) {
    return has_index(channels, name);
}

int(0..1) register_callback(string name, function|object|program cb) {
    if (has_channel(name) || has_index(callbacks, name))
	return 0;

    callbacks[name] = cb;

    return 1;
}

int(0..1) unregister_callback(string name) {
    if (!has_index(callbacks, name)) return 0;
    m_delete(callbacks, 1);

    return 1;
}

void close_channel(string name) {
    if (!has_index(channels, name)) {
	error("The channel can not be closed.");
    }
    m_delete(channels, name)->close();
}

int(0..1)|string may_channel(string name) {
    werror("may_channel(%O)\n", name);
    if (_may_channel) return _may_channel(name);
    return 1;
}

void callback(object channel, string name) {
    if (_callback) _callback(channel, name);
}

void create(mixed session, function|void callback,
	    function|void may_channel) {
    this_program::session = session;
    //call_out(session->send, 0, "_multiplex 0 ");
    session->send("_multiplex 0 ");
    session->cb = my_in;
    _callback = callback;
    _may_channel = may_channel;
    ReqParser = Serialization.Factory.generate_structs(([
	"_channel_request" : Req(),
    ]));
    SuccParser = Serialization.Factory.generate_structs(([
	"_channel_success" : Success(),
	"_channel_fail" : Fail(),
    ]));
    session->set_errorcb(MMP.Utils.combine_functions(sesserr, session->get_errorcb()));
}

void sesserr(mixed ... args) {
    array es = ({ });

    foreach (channels;; object channel) {
	mixed e = catch {
	    function|object|program f = channel->get_errorcb();
	    if (f) f(@args);
	};
	if (e) es += ({ e });
    }

    session = channels = callbacks = _may_channel = _callback = 0;

    if (sizeof(es)) werror("Multiplexer#sesser(%O) encountered the following errors: %O\n");
}

void my_in(object session, object atom) {
    string name, data;
    object res;
    object channel;

    werror("MULTIPLEXER: %O %O\n", session, atom);

    switch (atom->type) {
	case "_channel":
	    if (sscanf(atom->data, "%s %s", name, data) != 2) {
		werror("totally fcked up multiplex client: %O(%d)(%O)\n", session, res, atom->data);
		return;
	    }

	    if (has_channel(name)) get_channel(name)->incoming(data);
	    break;
	case "_channel_request":
	    res = ReqParser->decode(atom);
	    if (stringp(res->name) && sizeof(res->name)) {
		int|string msg = 1;
		int init = !has_channel(res->name) && !has_index(callbacks, res->name);
		if (init)
		    msg = may_channel(res->name);
		if (msg && intp(msg)) {
		    write("my_in: in the if.\n");
		    //channel->send(sprintf("_channel %d %s", sizeof(msg), msg));
		    session->send(SuccParser->encode(Success(res->name))->render());
		    if (init)
			callback(get_channel(res->name), res->name);
		    else if (has_index(callbacks, res->name))
			m_delete(callbacks, res->name)(get_channel(res->name));
		} else {
		    if (!stringp(msg)) msg = "You are not welcome here.";
		    channel = .Channel(res->name, session);
		    channel->send(SuccParser->encode(Fail(res->name, msg))->render());
		}
	    }

	    break;
#ifdef _CONNECT // i think this is unused and unneccessary
	case "_connect":
	    name = atom->data;
	    if (new_con) {
		new_con(this, name, get_channel(name));
	    }
	    break;
#endif
	default:
	    error("Invalid type %O on multiplexed base connection.\n");
    }
}

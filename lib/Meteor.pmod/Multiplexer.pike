//mapping(string:object) channels = set_weak_flag(([]), Pike.WEAK);
mapping(string:object) channels = ([]);

function new_con, _callback, _may_channel;

mixed session;

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
}

void my_in(object session, object atom) {
    string name, data;
    int res;
    object channel;

    werror("MULTIPLEXER: %O %O\n", session, atom);

    switch (atom->type) {
	case "_channel":
	    res = sscanf(atom->data, "%s %s", name, data);
	    switch (res) {
	    case 2:
		werror("MULTIPLEXER: calling %O->incoming(%O)\n", get_channel(name), data);
		get_channel(name)->incoming(data);
		break;
	    case 0:
		name = atom->data;
		if (name && sizeof(name) && !has_channel(name)) {
		    int|string msg;
		    msg = may_channel(name);
		    if (msg && intp(msg)) {
			msg = "ok";
			channel = get_new_channel(name);
			channel->send(sprintf("_channel %d %s", sizeof(msg), msg));
			callback(channel, name);
		    } else {
			if (!stringp(msg)) msg = "You are not welcome here.";
			channel = .Channel(name, session);
			channel->send(sprintf("_channel %d %s", sizeof(msg), msg));
		    }
		}
		break;
	    default:
		werror("totally fcked up multiplex client: %O(%d)(%O)\n", session, res, atom->data);
		return;
	    }
	    break;
	case "_connect":
	    name = atom->data;
	    if (new_con) {
		new_con(this, name, get_channel(name));
	    }
	    break;
	default:
	    error("Invalid type %O on multiplexed base connection.\n");
    }
}

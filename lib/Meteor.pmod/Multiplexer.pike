mapping(string:object) channels = set_weak_flag(([]), Pike.WEAK);

function new_con;

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

void create(mixed session) {
    this_program::session = session;
    call_out(session->send, 0, "_multiplex 0 ");
    session->cb = my_in;
}

void my_in(object session, object atom) {
    string name, data;

    werror("MULTIPLEXER: %O %O\n", session, atom);

    switch (atom->type) {
	case "_channel":
	    if (2 != sscanf(atom->data, "%s %s", name, data)) {
		werror("totally fcked up multiplex client: %O\n", session);
		return;
	    }
	    werror("MULTIPLEXER: calling %O->incoming(%O)\n", get_channel(name), data);
	    get_channel(name)->incoming(data);
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

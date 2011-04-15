mapping(string:object) channels = set_weak_flag(([]), Pike.WEAK);

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
}

inherit Yakity.Base;

mixed rooms, users;

void create(object server, MMP.Uniform uniform) {
	::create(server, uniform);
}

int _request_users(Yakity.Message m) {
	MMP.Uniform source = m->source();

	if (users) {
		mapping profiles = ([]);

		// possible race here!
		foreach (users; MMP.Uniform uniform; object o) {
			profiles[uniform] = o->get_profile();
		}

		sendmsg(source, "_update_users", 0,  ([ "_users" : profiles ]));
	}

	return Yakity.STOP;
}


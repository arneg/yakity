inherit Yakity.Base;

mixed rooms, users;

void create(object server, MMP.Uniform uniform) {
	::create(server, uniform);
}

int _request_users(Yakity.Message m) {
	MMP.Uniform source = m->source();

	if (users) {
		sendmsg(source, "_notice_enter", 0,  ([ "_users" : indices(users) ]));
	}

	return Yakity.STOP;
}


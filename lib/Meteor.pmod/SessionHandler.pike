mapping(string:object) sessions = set_weak_flag(([]), Pike.WEAK);
Thread.Mutex sessions_mutex = Thread.Mutex();

string get_new_id() {
	return MIME.encode_base64(random_string(10));
}

object get_new_session() {
	string s;
	object lock = sessions_mutex->lock();

	while (has_index(sessions, s = get_new_id()));
	sessions[s] = Meteor.Session(s);
	
	destruct(lock);
	return sessions[s];
}

MMP.Uniform user_to_uniform(string name) {
	return to_uniform('~', name);
}

MMP.Uniform room_to_uniform(string name) {
	return to_uniform('@', name);
}


MMP.Uniform to_uniform(int type, string name);

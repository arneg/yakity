inherit Yakity.User;
object roxen_conf;

void create(object server, object uniform, mixed user, function logout, function login, object roxen_conf) {
    ::create(server, uniform, user, logout, login);
    this_program::roxen_conf = roxen_conf;
}

int _request_link(MMP.Packet p, PSYC.Message m, function callback) {
    string u = uniform->obj[1..];
    array(UserDB) dbs = roxen_conf->user_databases();
    object user = roxen_conf->find_user(u);
    string pw = m["_password"];

    foreach (dbs;; object db) {
	object user = db->find_user(u);

	if (user && user->password_authenticate(pw)) {
	    add_client(p->source());
	    call_out(login_cb, 0, this);
	    sendreplymsg(p, "_notice_link");
	    return PSYC.STOP;
	}
    }

    sendreplymsg(p, "_failure_link", "User or password are invalid.");

    return PSYC.STOP;
}

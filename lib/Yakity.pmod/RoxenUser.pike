inherit Yakity.User;
object roxen_conf;

void create(object server, object uniform, mixed user, function logout, function login, object roxen_conf) {
    ::create(server, uniform, user, logout, login);
    this_program::roxen_conf = roxen_conf;
}

int _request_link(MMP.Packet p, PSYC.Message m, function callback) {
    string u = uniform->obj[1..];
    object user = roxen_conf->find_user(u);
    string pw = m["_password"];

    if (!user || !user->password_authenticate(pw)) {
	sendreplymsg(p, "_failure_link", "User or password are invalid.");
    } else if (sizeof(clients)) {
	sendreplymsg(p, "_failure_link", "Already logged in from somewhere else.");
    } else {
	add_client(p->source());
	sendreplymsg(p, "_notice_link");
    }

    return PSYC.STOP;
}

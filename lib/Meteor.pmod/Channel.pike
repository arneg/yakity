object session;
string name;
mapping misc = ([ ]);
function cb, errorcb;
Serialization.AtomParser par = Serialization.AtomParser();

void create(string name, object session) {
    this_program::name = name;
    this_program::session = session;
}

void set_cb(function cb) {
    this_program::cb = cb;
}

function get_cb() {
    return cb;
}

void set_errorcb(function errorcb) {
    this_program::errorcb = errorcb;
}

function get_errorcb() {
    return errorcb;
}

void send(string|MMP.Utils.Cloak|Serialization.Atom atom) {
    werror("CHANNEL(%s)->send(%O).\n", name, atom);
    if (object_program(atom) == Serialization.Atom)
	atom = atom->render();
    else atom = (string)atom;
    session->send(sprintf("_channel %d %s %s", sizeof(atom)+sizeof(name)+1, name, atom));
}

void incoming(string atom) {
    werror("CHANNEL(%s)->incoming(%O)\n", name, atom);
    par->feed(atom);

    while (object a = par->parse()) {
	if (cb) cb(this, a);
    }
}

void close() { // should this do anything?
    // send closing notification, for example?
}

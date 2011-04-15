object session;
string name;
function cb, errorcb;

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
    atom = (string)atom;
    session->send(sprintf("_channel %d %s %s", sizeof(atom)+sizeof(name)+1, name, atom));
}

void incoming(string atom) {
    if (cb) cb(atom);
}

void close() { // should this do anything?
    // send closing notification, for example?
}

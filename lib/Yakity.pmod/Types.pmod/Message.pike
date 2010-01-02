inherit Serialization.Types.Base;
object method, data, vars;
string type = "_message";

void create(object method, void|object vars, object data) {
	this_program::method = method;
	this_program::vars = vars;
	this_program::data = data;
}

// dont use this
// TODO: may not throw due to can_decode
string render_payload(Serialization.Atom atom) {
	Yakity.Message m = atom->get_typed_data(this);
	MMP.Utils.StringBuilder buf = MMP.Utils.StringBuilder();

	if (m->vars && sizeof(m->vars)) vars->render(m->vars, buf);
	method->render(m->method, buf);
	if (m->data) data->render(m->data, buf);


	return buf->get();
}

MMP.Utils.StringBuilder render(Yakity.Message m, MMP.Utils.StringBuilder buf) {
	array node = buf->add();

	if (m->vars && sizeof(m->vars)) vars->render(m->vars, buf);
	method->render(m->method, buf);
	if (m->data) data->render(m->data, buf);
	node[2] = sprintf("%s %d ", type, buf->count_length(node));

	return buf;
}

Yakity.Message decode(Serialization.Atom atom) {
	object m = atom->get_typed_data(this);

	if (m) return m;
	
	m = Yakity.Message();
	array(Serialization.Atom) list = Serialization.parse_atoms(atom->data);

	switch (sizeof(list)) {
	case 1: 
		m->method = method->decode(list[0]);
		m->data = 0;
		m->vars = ([]);
		break;
	case 2:
		if (list[0]->type == "_method") { // had no vars
			m->method = method->decode(list[0]);
			m->data = data->decode(list[1]);
			m->vars = ([]);
		} else {
			m->data = 0;
			m->vars = vars->decode(list[0]);
			m->method = method->decode(list[1]);
		}
		break;
	case 3:
		m->vars = vars->decode(list[0]);
		m->method = method->decode(list[1]);
		m->data = data->decode(list[2]);
		break;
	default:
		error("broken pdata: %O\n", list);
	}

	atom->set_typed_data(this, m);

	return m;
}

int (0..1) can_encode(mixed a) {
	return Program.inherits(object_program(a), Yakity.Message);
}

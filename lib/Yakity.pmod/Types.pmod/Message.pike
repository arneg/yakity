inherit Serialization.Types.Base;

object method, data, vars;

void create(object method, void|object vars, object data) {
	this_program::method = method;
	this_program::vars = vars;
	this_program::data = data;

	::create("_message");
}

// dont use this
// TODO: may not throw due to can_decode
void raw_to_medium(Serialization.Atom atom) {
	atom->pdata = Serialization.parse_atoms(atom->data);
}

void medium_to_raw(Serialization.Atom atom) {
	if (!arrayp(atom->pdata) && !sizeof(atom->pdata)) error("broken pdata: %O\n", atom->pdata);
	String.Buffer buf = String.Buffer();

	switch (sizeof(atom->pdata)) {
	case 1: 
		buf += method->render(atom->pdata[0]);
		break;
	case 2:
		if (atom->pdata[0]->type == "_method") { // had no vars
			buf += method->render(atom->pdata[0]);
			buf += data->render(atom->pdata[1]);
		} else {
			buf += vars->render(atom->pdata[0]);
			buf += method->render(atom->pdata[1]);
		}
		break;
	case 3:
		buf += vars->render(atom->pdata[0]);
		buf += method->render(atom->pdata[1]);
		buf += data->render(atom->pdata[2]);
		break;
	default:
		error("broken pdata: %O\n", atom->pdata);
	}

	atom->data = (string)buf;
}

void medium_to_done(Serialization.Atom atom) {
	if (!arrayp(atom->pdata) && !sizeof(atom->pdata)) error("broken pdata: %O\n", atom->pdata);
	object m = Yakity.Message();

	switch (sizeof(atom->pdata)) {
	case 1: 
		m->method = method->decode(atom->pdata[0]);
		m->data = 0;
		m->vars = ([]);
		break;
	case 2:
		if (atom->pdata[0]->type == "_method") { // had no vars
			m->method = method->decode(atom->pdata[0]);
			m->data = data->decode(atom->pdata[1]);
			m->vars = ([]);
		} else {
			m->data = 0;
			m->vars = vars->decode(atom->pdata[0]);
			m->method = method->decode(atom->pdata[1]);
		}
		break;
	case 3:
		m->vars = vars->decode(atom->pdata[0]);
		m->method = method->decode(atom->pdata[1]);
		m->data = data->decode(atom->pdata[2]);
		break;
	default:
		error("broken pdata: %O\n", atom->pdata);
	}

	atom->typed_data[this] = m;
}

void done_to_medium(Serialization.Atom atom) {
	if (!objectp(atom->typed_data[this])) error("broken typed_data: %O\n", atom->typed_data[this]);
	object m = atom->typed_data[this];
	atom->pdata = ({});
	if (vars && mappingp(m->vars)) 
		atom->pdata += ({ vars->encode(m->vars) });
	atom->pdata += ({ method->encode(m->method) });
	if (data && stringp(m->data))
		atom->pdata += ({ data->encode(m->data) });
}

int (0..1) low_can_encode(mixed a) {
	return has_index(a, "method");
}

int(0..1) can_encode(mixed a) {
	return has_index(a, "data") && has_index(a, "vars") && has_index(a, "method");
}

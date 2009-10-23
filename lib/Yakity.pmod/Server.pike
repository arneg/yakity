mapping(MMP.Uniform:object) entities = ([]); //set_weak_flag(([]), Pike.WEAK);
mapping(string:MMP.Uniform) uniform_cache = ([]); //set_weak_flag(([]), Pike.WEAK_VALUES);
object type_cache;

void create(object type_cache) {
	this_program::type_cache = type_cache;
}

MMP.Uniform get_uniform(string s) {
	if (has_index(uniform_cache, s)) {
		return uniform_cache[s];
	}

	object u = MMP.Uniform(s);
	return uniform_cache[(string)u] = u;
}

void broadcast(Yakity.Message m) {
	// TODO, this is seriously not good. time to revive
	// some psyc legacy using channels, etc. But for the
	// small scale webchat this is alright.

	foreach (entities;MMP.Uniform target;object o) {
		Yakity.Message t = m->clone();
		t->vars["_target"] = target;
		o->msg(t);
	}
}

void deliver(Yakity.Message m) {
	//werror("deliver(%O)\n", m);
	object o;

	if ((o = entities[m->target()])) {
		o->msg(m);
	} else {
		werror("Could not deliver %O to %O\n", m, m->target());
	}
}

void register_entity(MMP.Uniform u, object o) {
	entities[u] = o;

	// this is a hack to keep the uniform cache consistent
	if (!has_index(uniform_cache, (string)u)) {
		uniform_cache[(string)u] = u;
	}
}

void unregister_entity(MMP.Uniform u) {
	m_delete(entities, u);
}

object get_entity(MMP.Uniform u) {
	return entities[u];
}

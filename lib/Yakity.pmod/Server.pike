/*
Copyright (C) 2008-2009  Arne Goedeke
Copyright (C) 2008-2009  Matt Hardy

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
version 2 as published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/
mapping(MMP.Uniform:object) entities = ([]); //set_weak_flag(([]), Pike.WEAK);
mapping(string:MMP.Uniform) uniform_cache = set_weak_flag(([]), Pike.WEAK_VALUES);
#ifdef ENABLE_THREADS
Thread.Mutex ucm = Thread.Mutex();
#endif
object type_cache;
object root;

void create(void|object type_cache) {
	this_program::type_cache = type_cache || Serialization.TypeCache();
}

MMP.Uniform get_uniform(string s) {
	if (has_index(uniform_cache, s)) {
		return uniform_cache[s];
	}

#ifdef ENABLE_THREADS
	object lock = ucm->lock();
#endif

	if (has_index(uniform_cache, s)) {
		return uniform_cache[s];
	}

	object u = MMP.Uniform(s);
	uniform_cache[(string)u] = u;
#ifdef ENABLE_THREADS
	destruct(lock);
#endif
	return u;
}

#ifdef PROGRESSBAR
int lasttime;
float lasthrtime;
int bcastcnt; // immanuel kant
#endif

void broadcast(MMP.Packet p) {
	// TODO, this is seriously not good. time to revive
	// some psyc legacy using channels, etc. But for the
	// small scale webchat this is alright.

	p->vars["_context"] = root->uniform;
	foreach (entities;;object o) {
#ifdef PROGRESSBAR
		if ((++bcastcnt%9048) == 0) {
		    werror("broadcasts: %20d (%f msgs/s)\n", bcastcnt, 9048/(1E-9* (gethrtime(1) - lasttime)));

		    lasttime = gethrtime(1);
		}
#endif
		o->msg(p);
	}
}

#ifdef PROGRESSBAR
int lasttime2;
float lasthrtime2;
int bcastcnt2; // immanuel kant
#endif


void deliver(MMP.Packet p) {
	//werror("deliver(%O)\n", m);
	object o;

	if ((o = entities[p->target()])) {
#ifdef PROGRESSBAR
		if ((++bcastcnt2%1000) == 0) {

		    werror("deliveries: %20d (%f msgs/s)\n", bcastcnt2, 1E12/(gethrtime(1) - lasttime2));

		    lasttime2 = gethrtime(1);
		}
#endif
		o->msg(p);
	} else {
		werror("Could not deliver %O to %O\n", p, p->target());
	}
}

void register_entity(MMP.Uniform u, object o) {
	entities[u] = o;
#ifdef ENABLE_THREADS
	object lock = ucm->lock();
#endif

	// this is a hack to keep the uniform cache consistent
	if (!has_index(uniform_cache, (string)u)) {
		uniform_cache[(string)u] = u;
	}

#ifdef ENABLE_THREADS
	destruct(lock);
#endif
}

void unregister_entity(MMP.Uniform u) {
	m_delete(entities, u);
}

object get_entity(MMP.Uniform u) {
	return entities[u];
}

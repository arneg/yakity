// test examples from json.org

inherit Serialization.Signature;
inherit Serialization.BasicTypes;
inherit Serialization.PsycTypes;

mapping(string:object) ucache = ([]);

object get_uniform(string s) {
	if (!has_index(ucache, s)) {
		ucache[s] = MMP.Uniform(s);
	}
	return ucache[s];
}

mapping server = ([
				 "get_uniform" : MMP.Uniform,
				 ]);

void create() {
	::create(Serialization.TypeCache());
}

int main() {

#if LONG	
	object m = MMP.Packet(Yakity.Message("_message_private", random_string(1000), ([ "_hihi" : aggregate_mapping(@map(allocate(100, 50), random_string)) ]) ),
		([ "_source" : MMP.Uniform("psyc://example.org/~user1"), "_target" : MMP.Uniform("psyc://example.org/~user2")]));
#else
	object m = MMP.Packet(Yakity.Message("_message_private", "hallo", ([ "_hihi" : aggregate_mapping(@allocate(10, "huhu")) ]) ),
		([ "_source" : MMP.Uniform("psyc://example.org/~user1"), "_target" : MMP.Uniform("psyc://example.org/~user2")]));
#endif

	object pp = Serialization.Types.Polymorphic();
	pp->register_type(MMP.Uniform, "_uniform", Uniform());
	pp->register_type("string", "_method", Method());
	pp->register_type("string", "_string", UTF8String());
	pp->register_type("int", "_integer", Int());
#ifndef MAPPING
	pp->register_type("mapping", "_vars", Vars(0,([ "_" : Method() ])));
#else
	pp->register_type("mapping", "_mapping", Mapping(pp,pp));
#endif
	pp->register_type("array", "_list", List(pp));
	object p = Packet(Yakity.Types.Message(Method(), Vars(0, ([ "_" : pp ])), pp));

#ifdef N
	float f1 = gauge {
		for (int i = 0; i < N; i++) {
			string s = p->encode(m)->render();
		}
	};
	string s = p->encode(m)->render();
	float f2 = gauge {
		for (int i = 0; i < N; i++) {
			object atom = Serialization.parse_atoms(s)[0];
			mapping n = p->decode(atom);
		}
	};
	float f3 = gauge {
		for (int i = 0; i < N; i++) {
#endif
			string s = p->encode(m)->render();
			object atom = Serialization.parse_atoms(s)[0];
			mapping n = p->decode(atom);
#ifdef N
		}
	};
	werror("atom x%d: render: %2f, parse: %2f, both: %2f\n", N, f1, f2, f3);
#endif

	return 0;
}

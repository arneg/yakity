// test examples from json.org

inherit Serialization.Signature;
inherit Serialization.BasicTypes;
inherit Serialization.PsycTypes;

mapping server = ([
				 "get_uniform" : MMP.Uniform,
				 ]);

void create() {
	::create(Serialization.TypeCache());
}

int main() {

	
	object m = MMP.Packet(Yakity.Message("_message_private", random_string(1000), ([ "_hihi" : aggregate_mapping(@map(allocate(100, 50), random_string)) ]) ),
		([ "_source" : MMP.Uniform("psyc://example.org/~user1"), "_target" : MMP.Uniform("psyc://example.org/~user2")]));

	object msig;
	object pp = Serialization.Types.Polymorphic();
	pp->register_type("string", "_method", Method());
	pp->register_type("string", "_string", UTF8String());
	pp->register_type("int", "_integer", Int());
	pp->register_type("mapping", "_mapping", Mapping(pp,pp));
	pp->register_type("array", "_list", List(pp));
	pp->register_type(MMP.Uniform, "_uniform", Uniform());
	object p = Packet(Yakity.Types.Message(Method(), Vars(0, ([ "_" : pp ])), pp));

	float f2 = gauge {
		for (int i = 0; i < 1000; i++) {
			string s = p->encode(m)->render();
			object atom = Serialization.parse_atoms(s)[0];
			mapping n = p->decode(atom);
		}
	};
	werror("atom x1000: %O\n", f2);

	return 0;
}

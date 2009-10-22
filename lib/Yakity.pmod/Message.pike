mapping(string:mixed) vars;
string method, data;
mapping misc = ([]);

MMP.Uniform source() {
	return vars["_source"];	
}

MMP.Uniform target() {
	return vars["_target"];
}

this_program clone() {
	this_program o = this_program();
	o->vars = copy_value(vars);
	o->method = method;
	o->data = data;

	return o;
}

string _sprintf(int type) {
	return sprintf("Message(%s, %s -> %s)", method||"", source(), target());
}

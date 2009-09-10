constant module_type = MODULE_TAG|MODULE_LOCATION;
constant module_name = "Webhaven: JSON data export";

// Include and inherit code that is needed in every module.
#include <module.h>
inherit "module";

void create() {
	defvar("location", Variable.Location("/json_export/",
			 0, "Virtual directory where json exported data can be accessed.",
			 "This is where data is exported in json format. Use some directory which is not used otherwise."));
}

void start() {
	set_my_db("jobtask_webhavendemo");
}

string simpletag_jsondata(string tagname, mapping args, string content, RequestID id) {
	return sprintf("<script type=\"text/javascript\" src=\"%s/%s\"></script>", query("location"), "test.js");
}

// JSON EXPORT STUFF
mixed find_file(string file, RequestID id) {
	NOCACHE();
	int time1 = gethrtime();
	array(mapping) res = get_my_sql()->query("SELECT website,email,id,postal_street,name,lastname,firstname,status,postal_city,phone_main from companies;");
	int time2 = gethrtime();
	string json = Public.Parser.JSON2.render(res);
	int time3 = gethrtime();
	return Roxen.http_string_answer(sprintf("var dbtime = %d; var jsontime = %d; var data = %s;", time3 - time2, time2 - time1, json), "text/javascript");	
}

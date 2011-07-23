object conf;
void register_channel(string name, function cb) {
    werror(">> CONF >> %O\n", conf);
    conf->get_provider("meteor.channel")->register_channel(name, cb);
}

function unregister_channel(string name) {
    return conf->get_provider("meteor.channel")->unregister_channel(name);
}

function get_channel_cb(string name) {
    return conf->get_provider("meteor.channel")->get_channel_cb(name);
}

void start(int i, mixed conf) {
    werror(">> START CONF >> %O, %O\n", i, conf);
    this_program::conf = conf;
    this->module_dependencies(conf, ({ "meteorchannel" }), 1);
}

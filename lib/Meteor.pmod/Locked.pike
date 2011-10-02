object channel, authProvider;
object AuthInfo, FailInfo;
function|object|program cb;

class Auth {
    string hmac;
    string token;
    int expiry;

    int(0..1) verify(object provider) {
	if (provider->authenticate)
	    return provider->authenticate(channel, token, expiry, hmac);
	else 
	    return String.string2hex(provider->hmac(sprintf("%s,%d", token, expiry))) == hmac
		    && expiry <= time();
    }

    string _sprintf(int c) {
	switch (c) {
	case 'O':
	    return sprintf("Auth(%O, %O, %d)", hmac, token, expiry);
	}

	return 0;
    }
}

class Success { }

class Fail {
    string reason;

    void create(string|void reason) {
	this_program::reason = reason;
    }
}

void create(object channel, object authProvider,
	    function|object|program cb) {
    this_program::channel = channel;
    this_program::authProvider = authProvider;
    this_program::cb = cb;
    channel->cb = _incoming;
    AuthInfo = Serialization.Factory.generate_structs(([
	"_auth" : Auth(),
    ]));
    FailInfo = Serialization.Factory.generate_structs(([
	"_fail" : Fail(),
	"_success" : Success(),
    ]));
    werror("Locked created successfully.\n");
}

void _incoming(object channel, object atom) {
    Auth data = AuthInfo->decode(atom);

    if (data->verify(authProvider)) {
	channel->send(FailInfo->encode(Success())->render());
	channel->cb = 0;
	call_out(cb, 0, channel, channel->name);
	werror("Connection authenticated. will call callback.\n");
	return;
    }

    werror("Connection was not authenticated.\n");

    channel->send(FailInfo->encode(Fail("Authentication failed"))->render());
}

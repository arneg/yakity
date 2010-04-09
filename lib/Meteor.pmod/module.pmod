#ifdef MEASURE_THROUGHPUT
int obytes = 0;

void measure(int bytes) {
    obytes += bytes;
}

void measure_bytes(function f, void|int time) {
    int old_bytes = obytes;
    int t = gethrtime(1);

    void cb() {
	f((float)(obytes-old_bytes)/(gethrtime(1)-t));	
    };

    call_out(cb, time||1);
}

#endif


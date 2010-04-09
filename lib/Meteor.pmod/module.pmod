#ifdef MEASURE_THROUGHPUT
int obytes = 0;

void measure_bytes(function f, int time) {
    int old_bytes = obytes;
    int t = gethrtime(1);

    void cb() {
	f((obytes-old_bytes)/(gethrtime(1)-t));	
    };

    call_out(cb, time||1);
}

#endif


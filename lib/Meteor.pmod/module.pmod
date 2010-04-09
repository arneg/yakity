#ifdef MEASURE_THROUGHPUT
int obytes = 0;

void measure(int bytes) {
    obytes += bytes;
}

void measure_bytes(function f, void|int time) {
    int old_bytes = obytes;
    int t = gethrtime();

    void cb() {
	f((obytes-old_bytes)/(1E-6*(gethrtime()-t)));	
    };

    call_out(cb, time||1);
}

#endif


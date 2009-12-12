class Average {
	// maximum of sum
	float maxsum;
	int maxsize;
	array(float) values = ({});

	void create(int|float max) {
		if (intp(max)) {
			maxsize = max;
		} else {
			maxsum = max;
		}
	}

	this_program add(float t) {
		values += ({ t });
		return this;
	}

	float average() {
		float sum;

		if (sizeof(values) == 0) {
			return 0.0;
		}

		for (int i = 0; i < sizeof(values); i += 1000) {
		    sum += `+(@values[i..i + 999]);
		}

		if (maxsize) {
			if (sizeof(values) > maxsize) {
				values = values[1..];
				return average();
			}
		} else if (maxsum && sum > maxsum) {
			values = values[1..];
			return average();
		}
		
	//	werror("average of %d is %f (sum: %f)\n", sizeof(values), sum/sizeof(values), sum);
		return sum/sizeof(values);
	}
}


int main(int argc, array(string) argv) {
	int start;
	float skip = 0.0;
	int last;
	string tfilter;
	object mav = Average(1000);
	object eav = Average(1000);

	if (argc < 3) {
		error("missing arguments\n");
	}

	tfilter = argv[1];
	skip = (float)argv[2];

	while(string s=Stdio.stdin.gets()) {
		array(string) a = (s/"\t");
		string type = a[0];
		if (type != tfilter) continue;

		int time = (int)(a[1]/".")[0];
		if (!last) last = time;
		float value = (float)a[2];

		if (!start) start = time;

		float stime = (time-start)/1E6;
		float msinterval = (time-last)/1E3;
		mav->add(msinterval);
		float freq = mav->average() > 0.0 ? 1E3/mav->average() : 0.0;

		eav->add(value);

		if (stime >= skip) {
			write("%f\t%f\t%f\t%f\n", stime, value, eav->average(), freq);
		}

		last = time;
	}

	return 0;
}

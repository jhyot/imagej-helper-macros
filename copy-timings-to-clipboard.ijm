// ImageJ macro to get timings of time slices.
// Can handle any file that Bio-Formats (LOCI) can read.
// Timings are copied to the clipboard with each slice separated
// by a newline.

run("Bio-Formats Macro Extensions");

id = File.openDialog("Choose a file");

Ext.setId(id);

Ext.getSeriesCount(snum);
sarr = newArray(snum);

for (i = 0; i < snum; i++) {
	Ext.setSeries(i);
	Ext.getSeriesName(sname);
	Ext.getSizeC(cnum);
	Ext.getSizeT(tnum);
	sarr[i] = sname + " (" + cnum + "C x " + tnum + "T)";
}

Dialog.create("Choose series");
Dialog.addChoice("Series name", sarr);

Dialog.show();

schoicestr = Dialog.getChoice();

for (i = 0; i < snum; i++) {
	if (sarr[i] == schoicestr)
		schoicenum = i;
}

Ext.setSeries(schoicenum);
Ext.getSizeC(cnum);
Ext.getSizeT(tnum);

truecnum = 0;

if (cnum > 1) {
	Dialog.create("Choose channels");
	Dialog.addMessage("Output: channels as columns, time as rows");
	for (i = 0; i < cnum; i++) {
		Dialog.addCheckbox("C=" + i, true);
	}
	Dialog.show();
	channels = newArray(cnum);
	for (i = 0; i < cnum; i++) {
		channels[i] = Dialog.getCheckbox();
		if (channels[i])
			truecnum += 1;
	}
} else {
	channels = newArray(1);
	channels[0] = true;
	truecnum = 1;
}

s = "";

for (i = 0; i < tnum; i++) {
	for (j = 0; j < cnum; j++) {
		if (channels[j]) {
			Ext.getIndex(0, j, i, idx);
			Ext.getPlaneTimingDeltaT(t, idx);
			if (t == t) {
				s = s + t + "\t";
			} else {
				exit("Unable to get timing data for c=" + j + " t=" + i +
					" index=" + idx);
			}
		}
	}
	s = s + "\n";
}

String.copy(s);

showStatus("Slice timings copied to clipboard (" + truecnum + "C x " + tnum + "T)");

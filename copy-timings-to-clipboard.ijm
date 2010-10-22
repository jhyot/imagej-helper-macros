// ImageJ macro to get timings of time slices.
// Can handle any file that Bio-Formats (LOCI) can read.
// Timings are copied to the clipboard with each slice separated
// by a newline.

run("Bio-Formats Macro Extensions");

id = File.openDialog("Choose a file");

Ext.setId(id);

Ext.getSeriesCount(snum);

// Arrays holding series names
sarr = newArray(snum);
sarr2 = newArray(snum + 1);
// Arrays holding channel and time numbers for each series
carr = newArray(snum);
tarr = newArray(snum);

for (i = 0; i < snum; i++) {
	Ext.setSeries(i);
	Ext.getSeriesName(sname);
	Ext.getSizeC(cnum);
	Ext.getSizeT(tnum);
	sarr[i] = sname + " (" + cnum + "C x " + tnum + "T)";
	sarr2[i] = sarr[i];
	carr[i] = cnum;
	tarr[i] = tnum;
}

sarr2[snum] = "*-None-*";

Dialog.create("Choose series");
Dialog.addMessage("Choose single series or series range.");
Dialog.addChoice("Range from:", sarr);
Dialog.addChoice("Range to:", sarr2, sarr2[snum]);
Dialog.addCheckbox("Remove last time point of each series", true);

Dialog.show();

rangefromstr = Dialog.getChoice();
rangetostr = Dialog.getChoice();
removelast = Dialog.getCheckbox();

// Set to -1 if no "range to" series selected
rangetonum = -1;
for (i = 0; i < snum; i++) {
	if (sarr[i] == rangefromstr)
		rangefromnum = i;
	if (sarr2[i] == rangetostr)
		rangetonum = i;
}

if ((rangetonum <= rangefromnum) && (rangetonum != -1))
	exit("\"Range to\" series has to come after \"range from\" series");


cmaxnum = carr[rangefromnum];
	
for (i = rangefromnum+1; i <= rangetonum; i++) {
	if (carr[i] > cmaxnum)
		cmaxnum = carr[i];
}

Dialog.create("Choose channels");
Dialog.addMessage("Output: channels as columns, time as rows");
for (i = 0; i < cmaxnum; i++) {
	Dialog.addCheckbox("C=" + i, true);
}
Dialog.show();
channels = newArray(cmaxnum);

truecnum = 0;
for (i = 0; i < cmaxnum; i++) {
	channels[i] = Dialog.getCheckbox();
	if (channels[i])
		truecnum += 1;
}

out = "";
s = rangefromnum;

totaltnum = 0;

do {
	Ext.setSeries(s);
	
	if (removelast)
		tarr[s] -= 1;
	
	for (i = 0; i < tarr[s]; i++) {
		for (j = 0; j < cmaxnum; j++) {
			if (channels[j]) {
				if (j < carr[s]) {
					Ext.getIndex(0, j, i, idx);
					Ext.getPlaneTimingDeltaT(t, idx);
					if (t == t) {
						out = out + t + "\t";
					} else {
						exit("Unable to get timing data for c=" + j + " t=" + i +
							" index=" + idx);
					}
				} else {
					// No such channel in this series
					out = out + "\t";
				}
			}
		}
		out = out + "\n";
		totaltnum += tarr[s];
	}
	
	s++;
} while (s <= rangetonum);

String.copy(out);

showStatus("Slice timings copied to clipboard (" + truecnum + "C x " + totaltnum + "T)");

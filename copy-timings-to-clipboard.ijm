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
	sarr[i] = sname;
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

Ext.getImageCount(tnum);

s = "";

for (i = 0; i < tnum; i++) {
	Ext.getPlaneTimingDeltaT(t, i);
	if (t == t)
		s = s + t + "\n";
}

String.copy(s);

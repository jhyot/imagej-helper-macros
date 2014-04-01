// ImageJ macro to measure all ROIs for all slices in all open images.
// Saves pixel area, avg. intensity and st.dev., integrated intensity
// to a single file.

// ROIs must not be associated with a slice, otherwise this macro will possibly
// not work (i.e. name must not be in "sss-yyyy-xxxx" format).

setBatchMode(true);

// Ask for filename for saving results
filePath = File.openDialog("Choose file for saving results");
f = File.open(filePath);

// Write header with data for all ROIs and column names

for (r = 0; r < roiManager("count"); r++) {
	roiManager("select", r);
	
	getSelectionBounds(x, y, w, h);
	
	print(f, "roi=" + (r+1) + ";x=" + x + ";y=" + y + ";w=" + w + ";h=" + h);
}

print(f, "slice\troi\tarea\tintavg\tintsd\tintsum");


// Get measurements

// loop through all open images
for (i = 1; i <= nImages(); i++) {
	
	showProgress((i-1)/(nImages()-1));
	
	selectImage(i);
	imgTitle = getTitle();
	imgFilename = getInfo("image.filename");
	
	print(f, "Filename=" + imgFilename);
	print(f, "Title=" + imgTitle);
	
	// loop through all slices
	for (s = 1; s <= nSlices(); s++) {
	
		setSlice(s);
		
		// loop through ROIs
		for (r = 0; r < roiManager("count"); r++) {
		
			roiManager("select", r);
			
			getRawStatistics(npx, mean, min, max, sd);
			
			print(f, s + "\t" + (r+1) + "\t" + npx + "\t" +
				 mean + "\t" + sd + "\t" + (npx*mean));
		
		} // ROI loop
	} // slices loop
} // open images loop

setBatchMode(false);

showStatus("All done.");

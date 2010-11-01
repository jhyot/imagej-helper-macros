// ImageJ macro to measure average intensities of ring arrays.
// Can handle single images or stacks of images.
// Results can be written to text file for each individual ring (one row per ring, 
// one file per slice in stack)
// or as averaged values in a single file (one row per slice)

DEBUG = true;

origImg = getImageID();
selectImage(origImg);

setBatchMode(true);

// if line and dot ROI defined
// use them to extract grid position and angle
correctRoi = false;
if (roiManager("count") == 2) {
	// select first defined ROI (line for angle measurement)
	roiManager("select", 0);
	
	if (selectionType() == 5) {
		getLine(x1, y1, x2, y2, w);
		dx = x2-x1;
		dy = y2-y1;
		d = sqrt(dx*dx + dy*dy);
		angle = acos(dx/d);
		if (dy > 0) {
			angle *= -1;
		}
		
		// select second ROI (for starting ring center)
		roiManager("select", 1);
		if (selectionType() == 10) {
			getSelectionCoordinates(xarr, yarr);
			x0 = xarr[0];
			y0 = yarr[0];
			
			// Correctly extracted grid angle and pos from ROIs
			correctRoi = true;
		}
	}
}


if (!correctRoi) {
	showMessageWithCancel("Unable to automatically extract grid angle and position.\nExactly 1 line and 1 point ROI needs to be defined.\nContinue anyway?");
	
	x0 = 0;
	y0 = 0;
	angle = 0;
}

// get user input
Dialog.create("Ring intensity measurement");
Dialog.addNumber("Count intensity within radius [px]", 8);
Dialog.addNumber("Measure background within radius [px]", 25);
Dialog.addNumber("Median filter radius for BG [px] (0 = no median filter)", 1);
Dialog.addNumber("Distance between rings [px]", 25.9);
Dialog.addNumber("Number of rings n*n; n=", 10);
Dialog.addNumber("First ring x coord", x0);
Dialog.addNumber("First ring y coord", y0);
Dialog.addNumber("Grid angle [deg]", 180/PI*angle);
Dialog.show();

rInt = Dialog.getNumber();
rBg = Dialog.getNumber();
rBgMedian = Dialog.getNumber();
ringDist = Dialog.getNumber();
nRings = Dialog.getNumber();
x0 = Dialog.getNumber();
y0 = Dialog.getNumber();
angle = PI/180*Dialog.getNumber(); // convert to radians

// If image is stack, ask additional options
if (nSlices() > 1) {
	Dialog.create("Measure slices");
	Dialog.addNumber("Start with slice", 1);
	Dialog.addNumber("End with slice", nSlices());
	Dialog.addCheckbox("Create only one file with totals", true);
	Dialog.show();
	
	minSlice = Dialog.getNumber();
	maxSlice = Dialog.getNumber();
	oneFile = Dialog.getCheckbox();
} else {
	minSlice = 1;
	maxSlice = 1;
	oneFile = false;
}

if (maxSlice < minSlice) {
	setBatchMode(false);
	exit("Ending slice must be equal or higher than starting slice");
}

// calculate x, y steps between rings
stepx = ringDist * cos(angle);
stepy = -1 * ringDist * sin(angle); // in image, "up" is negative y

print("=========");
print("Analyzing " + nRings + " x " + nRings + " array");
print("Count intensity within radius " + rInt + " px");
print("Background radius " + rBg + " px");
print("Grid angle: " + 180/PI*angle + " deg");
print("Distance between rings: " + ringDist + " px");
print("First ring: x=" + x0 + " ; y=" + y0);
print("x step size: " + stepx + " px; y step size: " + stepy + " px");

if (nSlices() > 1) {
	print("Analyzing stack from slice " + minSlice + " to " + maxSlice);
}

// Only one file or more?
if ((oneFile) || (nSlices() <= 1)) {
	// Only one file, ask for filename
	filePath = File.openDialog("Choose file for saving results");
	// Open file and write header
	f = File.open(filePath);
	print(f, "File=" + getInfo("image.filename"));
	print(f, "Title=" + getTitle());
	print(f, "Arraysize=" + nRings);
	print(f, "IntRadiusPx=" + rInt);
	print(f, "BgRadiusPx=" + rBg);
	print(f, "GridAngleDeg=" + 180/PI*angle);
	print(f, "RingDistPx=" + ringDist);
	print(f, "FirstRingX=" + x0);
	print(f, "FirstRingY=" + y0);
	print(f, "StepX=" + stepx);
	print(f, "StepY=" + stepy);
	if (nSlices() <= 1) {
		// not a stack
		print(f, "Stack=false");
		// write column names
		print(f, "xpos ypos intsum intavg bgint");
	} else {
		print(f, "Stack=true");
		print(f, "MinSlice=" + minSlice);
		print(f, "MaxSlice=" + maxSlice);
		print(f, "slice intsum intsumsd intavg intavgsd bg bgsd");
	}
} else {
	// One file per slice, ask for directory; define file names automatically
	dirPath = getDirectory("Choose directory for result files");
}

if (DEBUG)
	dbgTotTime = getTime();

existingRoiNum = roiManager("count");

// Create ROIs for rings and background
for (i = 0; i < nRings; i++) {   // "rows"
	for (j = 0; j < nRings; j++) {    // within row
		// set coord of ring to be selected
		// first, step within row
		currx = x0 + j*stepx;
		curry = y0 + j*stepy;
		
		// then, step rows
		currx -= i*stepy;
		curry += i*stepx;
		
		// draw ring and background circles, add to ROI manager
		// makeOval wants upper left corner of bounding rectangle as coords
		makeOval(currx - rInt, curry - rInt, rInt*2, rInt*2);
		roiManager("Add");
		makeOval(currx - rBg, curry - rBg, rBg*2, rBg*2);
		roiManager("Add");
		
		// Rename ROIs so they become slice-independent
		k = i*nRings + j + 1;
		roiManager("Select", roiManager("count") - 2);
		roiManager("Rename", "r" + k);
		roiManager("Select", roiManager("count") - 1);
		roiManager("Rename", "b" + k);
	}
}

// Iterate over slices, analyze them

for (s = minSlice; s <= maxSlice; s++) {

	if (DEBUG)
		dbgSliceTime = getTime();
	
	showProgress((s-minSlice)/(maxSlice-minSlice));

	setSlice(s);
	
	// If writing multiple files, open one for current slice
	// and write header
	if  ((!oneFile) && (nSlices() > 1)) {
		if (s < 10)
			sPadded = "00" + s;
		else if (s < 100)
			sPadded = "0" + s;
		else
			sPadded = "" + s;
		f = File.open(dirPath + getInfo("image.filename") + "." + sPadded);
		print(f, "File=" + getInfo("image.filename"));
		print(f, "Title=" + getTitle());
		print(f, "Arraysize=" + nRings);
		print(f, "IntRadiusPx=" + rInt);
		print(f, "BgRadiusPx=" + rBg);
		print(f, "GridAngleDeg=" + 180/PI*angle);
		print(f, "RingDistPx=" + ringDist);
		print(f, "FirstRingX=" + x0);
		print(f, "FirstRingY=" + y0);
		print(f, "StepX=" + stepx);
		print(f, "StepY=" + stepy);
		print(f, "Stack=true");
		print(f, "Slice=" + s);
		print(f, "xpos ypos intsum intavg bgint");
	}
	
	
	roiManager("Deselect");
	run("Select None");
	
	// duplicate image for median filtering and background determination
	run("Duplicate...", "tempduplicatebg");
	duplImg = getImageID();
	selectImage(duplImg);
	
	if (rBgMedian > 0) {
		run("Median...", "radius="+rBgMedian);
	}
	
	ringMin = newArray(nRings*nRings);
	
	// step through each ring BG ROI, save min pixel value; average = background
	for (i = 0; i < nRings*nRings; i++) {
		// every 2nd ROI after previously existing ones
		roiManager("select", 2*i + existingRoiNum + 1);
		if (selectionType() != 1) {
			File.close(f);	
			setBatchMode(false);
			exit("ROI " + (2*i + existingRoiNum + 1) + " not an oval");
		}
		getRawStatistics(npx, mean, min);
		ringMin[i] = min;
	}
	
	Array.getStatistics(ringMin, min, max, mean, sd);
	bgAvg = mean;
	bgSd = sd;
	
	// close duplicated image
	close();
	
	selectImage(origImg);

	ringIntAvg = newArray(nRings*nRings);
	ringIntSum = newArray(nRings*nRings);

	// step through each ring ROI, save sum and avg pixel value
	for (i = 0; i < nRings*nRings; i++) {
		// every 2nd ROI after previously existing ones
		roiManager("select", 2*i + existingRoiNum);
		if (selectionType() != 1) {
			File.close(f);	
			setBatchMode(false);
			exit("ROI " + (2*i + existingRoiNum) + " not an oval");
		}
		getRawStatistics(npx, mean);
		ringIntAvg[i] = mean - bgAvg;
		ringIntSum[i] = ringIntAvg[i] * npx;
		
		getSelectionBounds(x, y, w, h);
		if (!oneFile) {
			print(f, (x+rInt) + " " + (y+rInt) + " " +
				ringIntSum[i] + " " + ringIntAvg[i] + " " + ringMin[i]);
		}
	}
	
	Array.getStatistics(ringIntSum, min, max, mean, sd);
	ringIntSumAvg = mean;
	ringIntSumSd = sd;
	
	Array.getStatistics(ringIntAvg, min, max, mean, sd);
	ringIntAvgAvg = mean;
	ringIntAvgSd = sd;
	
	if (oneFile) {
		print(f, s + " " + ringIntSumAvg + " " + ringIntSumSd + " " +
			ringIntAvgAvg + " " + ringIntAvgSd + " " +
			bgAvg + " " + bgSd);
	}
	
	
	roiManager("Deselect");
	run("Select None");
	
	// If multiple files, write summary and close current file
	if (!oneFile) {
		print(f, "");
		print(f, "intsum intsumsd intavg intavgsd bg bgsd");
		print(f, ringIntSumAvg + " " + ringIntSumSd + " " +
			ringIntAvgAvg + " " + ringIntAvgSd + " " +
			bgAvg + " " + bgSd);
		File.close(f);
	}
	
	if (DEBUG)
		showStatus("Slice " + (s-minSlice+1) + "/" + (maxSlice-minSlice+1) + ": " +
				(getTime() - dbgSliceTime) + " ms");

} // iterate slices

print("Analysis finished.");
if (DEBUG)
	print("Total time: " + (getTime() - dbgTotTime) + " ms");

if (oneFile)
	File.close(f);
	
setBatchMode(false);



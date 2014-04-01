// ImageJ macro to measure average intensities of ring arrays.
// Can handle single images or stacks of images.
// Results can be written to text file for each individual ring (one row per ring, 
// one file per slice in stack)
// or as averaged values in a single file (one row per slice)

// Methods for background:
// Median min: Takes minimal value around ring from median filtered image as BG value.
//	       Subtracts BG value from avg ring intensity.
// Avg normalized: Takes average value within bounds of an inner circle and outer rectangle as BG value.
//		   Divides avg ring intensity by BG value.
// No BG: Does not do any background correction.


// ==============================
// == PARAMETER DEFAULT VALUES ==
// ==============================

// Measure ring intensity within radius [px]
rInt = 8;

// Default method, one of:
// "Median min";  "Avg normalized"; "No BG"
bgMethod = "No BG";

// Measure background intensity within radius (median min method) [px]
rBg = 25;

// Median filter radius for background (median min method) [px] (0 = no filter)
rBgMedian = 1;

// Background inner radius (avg normalized method) [px]
rBgInner = 10;

// Background outer radius (avg normalized method) [px]
rBgOuter = 13;

// Distance between two rings [px]
ringDist = 25.8;

// Grid side length [rings]
nRings = 10;

// First ring x coordinate [px]
x0 = 0;

// First ring y coordinate [px]
y0 = 0;

// Grid angle [radians]
angle = 0;

// Read parameters from file?
readParamFromFile = false;

// When stack, save only one file with summary measurements?
oneFile = true;

// ==================================
// == END PARAMETER DEFAULT VALUES ==
// ==================================


DEBUG = true;

setBatchMode(true);

origImg = getImageID();
selectImage(origImg);

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
	showMessageWithCancel("Unable to automatically extract grid angle and position.\n" +
				"Exactly 1 line and 1 point ROI needs to be defined.\n" +
				"Continue anyway?");
}

bgMethodArr = newArray("Median min", "Avg normalized", "No BG");

// get user input
Dialog.create("Ring intensity measurement");
Dialog.addChoice("Background method:", bgMethodArr, bgMethod);
Dialog.addCheckbox("Read parameters from file (ignore values below)", readParamFromFile);
Dialog.addNumber("Count intensity within radius [px]", rInt);
Dialog.addNumber("Background radius (median min method) [px]", rBg);
Dialog.addNumber("Median filter radius for BG [px] (0 = no median filter)", rBgMedian);
Dialog.addNumber("Background inner radius (avg normalized method) [px]", rBgInner);
Dialog.addNumber("Background outer radius (avg normalized method) [px]", rBgOuter);
Dialog.addNumber("Distance between rings [px]", ringDist);
Dialog.addNumber("Number of rings n*n; n=", nRings);
Dialog.addNumber("First ring x coord", x0);
Dialog.addNumber("First ring y coord", y0);
Dialog.addNumber("Grid angle [deg]", 180/PI * angle);
Dialog.show();


bgMethod = Dialog.getChoice();

if (Dialog.getCheckbox()) {
	// Get parameters from file
	paramFile = File.openAsString("");
	paramLines = split(paramFile, "\n");
	
	for (i = 0; i < lengthOf(paramLines); i++) {
		param = split(paramLines[i], "=");
		
		if (lengthOf(param) >= 2)
			paramFloat = parseFloat(param[1]);
		else
			paramFloat = NaN;

		if (!isNaN(paramFloat)) {
			// Extract params.
			// If not found, will leave as default
			// ATTN: if x0, y0 and angle was extracted from ROIs,
			// these are the new "default" values
			if (param[0] == "IntRadiusPx")
				rInt = paramFloat;
			else if (param[0] == "BgRadiusPx")
				rBg = paramFloat;
			else if (param[0] == "BgMedianPx")
				rBgMedian = paramFloat;
			else if (param[0] == "BgInnerRadiusPx")
				rBgInner = paramFloat;
			else if (param[0] == "BgOuterRadiusPx")
				rBgOuter = paramFloat;
			else if (param[0] == "RingDistPx")
				ringDist = paramFloat;
			else if (param[0] == "Arraysize")
				nRings = paramFloat;
			else if (param[0] == "FirstRingX")
				x0 = paramFloat;
			else if (param[0] == "FirstRingY")
				y0 = paramFloat;
			else if (param[0] == "GridAngleDeg")
				angle = PI/180 * paramFloat;
		}
	}
	
} else {
	rInt = Dialog.getNumber();
	rBg = Dialog.getNumber();
	rBgMedian = Dialog.getNumber();
	rBgInner = Dialog.getNumber();
	rBgOuter = Dialog.getNumber();
	ringDist = Dialog.getNumber();
	nRings = Dialog.getNumber();
	x0 = Dialog.getNumber();
	y0 = Dialog.getNumber();
	angle = PI/180 * Dialog.getNumber(); // convert to radians
}

// If image is stack, ask additional options
if (nSlices() > 1) {
	Dialog.create("Measure slices");
	Dialog.addNumber("Start with slice", 1);
	Dialog.addNumber("End with slice", nSlices());
	Dialog.addCheckbox("Create only one file with totals", oneFile);
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
stepx = ringDist*cos(angle);
stepy = -1 * ringDist * sin(angle); // in image, "up" is negative y

print("=========");
print("Analyzing " + nRings + " x " + nRings + " array");
print("Count intensity within radius " + rInt + " px");
print("Background method: " + bgMethod);
if (bgMethod == "Median min") {
	print("Background radius " + rBg + " px");
	if (rBgMedian > 0) {
		print("BG median filter: " + rBgMedian + " px");
	} else {
		print("No BG median filter applied");
	}
} else if (bgMethod == "Avg normalized") {
	print("Background between radius " + rBgInner + " px and " + rBgOuter + " px");
} else if (bgMethod == "No BG") {
	// Nothing to print
} else {
	print("Background method unknown");
}
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
	print(f, "BgMethod=" + bgMethod);
	print(f, "BgRadiusPx=" + rBg);
	print(f, "BgMedianPx=" + rBgMedian);
	print(f, "BgInnerPx=" + rBgInner);
	print(f, "BgOuterPx=" + rBgOuter);
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
		print(f, "xpos\typos\tintsum\tintavg\tbgint");
	} else {
		print(f, "Stack=true");
		print(f, "MinSlice=" + minSlice);
		print(f, "MaxSlice=" + maxSlice);
		print(f, "slice\tintsum\tintsumsd\tintavg\tintavgsd\tbg\tbgsd");
	}
} else {
	// One file per slice, ask for base filename
	fileBasePath = File.openDialog("Choose base filename for result files");
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
		
		// draw ring circle, add to ROI manager
		// makeOval wants upper left corner of bounding rectangle as coords
		makeOval(currx - rInt, curry - rInt, rInt*2, rInt*2);
		roiManager("Add");
		
		// draw background ROIs and add to ROI manager, depending on BG Method
		if (bgMethod == "Median min") {
			makeOval(currx - rBg, curry - rBg, rBg*2, rBg*2);
			roiManager("Add");
		} else if (bgMethod == "Avg normalized") {
			makeOval(currx - rBgInner, curry - rBgInner, rBgInner*2, rBgInner*2);
			roiManager("Add");
			makeRectangle(currx - rBgOuter, curry - rBgOuter, rBgOuter*2, rBgOuter*2);
			roiManager("Add");
		} else if (bgMethod == "No BG") {
			// Do nothing
		} else {
			exit("Background method unknown: " + bgMethod);
		}
		
		// Rename ROIs so they become slice-independent
		k = i*nRings + j + 1;
		if (bgMethod == "Median min") {
			roiManager("Select", roiManager("count") - 2);
			roiManager("Rename", "r" + k);
			roiManager("Select", roiManager("count") - 1);
			roiManager("Rename", "b" + k);
		} else if (bgMethod == "Avg normalized") {
			roiManager("Select", roiManager("count") - 3);
			roiManager("Rename", "r" + k);
			roiManager("Select", roiManager("count") - 2);
			roiManager("Rename", "bi" + k);
			roiManager("Select", roiManager("count") - 1);
			roiManager("Rename", "bo" + k);
		} else if (bgMethod == "No BG") {
			roiManager("Select", roiManager("count") - 1);
			roiManager("Rename", "r" + k);
		} else {
			exit("Background method unknown: " + bgMethod);
		}
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
		f = File.open(fileBasePath + "." + sPadded);
		print(f, "File=" + getInfo("image.filename"));
		print(f, "Title=" + getTitle());
		print(f, "Arraysize=" + nRings);
		print(f, "IntRadiusPx=" + rInt);
		print(f, "BgMethod=" + bgMethod);
		print(f, "BgRadiusPx=" + rBg);
		print(f, "BgMedianPx=" + rBgMedian);
		print(f, "BgInnerPx=" + rBgInner);
		print(f, "BgOuterPx=" + rBgOuter);
		print(f, "GridAngleDeg=" + 180/PI*angle);
		print(f, "RingDistPx=" + ringDist);
		print(f, "FirstRingX=" + x0);
		print(f, "FirstRingY=" + y0);
		print(f, "StepX=" + stepx);
		print(f, "StepY=" + stepy);
		print(f, "Stack=true");
		print(f, "Slice=" + s);
		print(f, "xpos\typos\tintsum\tintavg\tbgint");
	}
	
	
	roiManager("Deselect");
	run("Select None");
	
	// Find out background values for each ring
	// Algorithm depends on Method
	
	ringBg = newArray(nRings*nRings);
	
	if (bgMethod == "Median min") {
		// For BG method "median min"
		// duplicate image for median filtering and background determination
		run("Duplicate...", "tempduplicatebg");
		duplImg = getImageID();
		selectImage(duplImg);
		
		if (rBgMedian > 0) {
			run("Median...", "radius="+rBgMedian);
		}
		
		// step through each ring BG ROI, save min pixel value ( = background)
		for (i = 0; i < nRings*nRings; i++) {
			// every 2nd ROI after previously existing ones
			roiManager("select", 2*i + existingRoiNum + 1);
			if (selectionType() != 1) {
				File.close(f);	
				setBatchMode(false);
				exit("ROI " + (2*i + existingRoiNum + 1) + " not an oval");
			}
			getRawStatistics(npx, mean, min);
			ringBg[i] = min;
		}
	
		// close duplicated image
		close();
	
		selectImage(origImg);
		
	} else if (bgMethod == "Avg normalized") {
		// For BG method "avg normalized",
		// Determine average intensity within bounds
		
		// select the BG ROIs, calculate avg intensity for each ring ( = background)
		for (i = 0; i < nRings*nRings; i++) {
			// 2nd and 3rd ROI of 3-ROI "bundle" per ring after the existing ones
			roiManager("select", 3*i + existingRoiNum + 1);
			if (selectionType() != 1) {
				File.close(f);	
				setBatchMode(false);
				exit("ROI " + (3*i + existingRoiNum + 1) + " not an oval");
			}
			
			getRawStatistics(npx, mean);
			intDenInner = npx * mean;
			npxInner = npx;
			
			roiManager("select", 3*i + existingRoiNum + 2);
			if (selectionType() != 0) {
				File.close(f);	
				setBatchMode(false);
				exit("ROI " + (3*i + existingRoiNum + 2) + " not a rectangle");
			}
			
			getRawStatistics(npx, mean);
			intDenOuter = npx * mean;
			npxOuter = npx;
			
			ringBg[i] = (intDenOuter - intDenInner) /
				     (npxOuter - npxInner);			
		}		
	} else if (bgMethod == "No BG") {
		// Do nothing
	} else {
		exit("Background method unknown: " + bgMethod);
	}
	
	Array.getStatistics(ringBg, min, max, mean, sd);
	bgAvg = mean;
	bgSd = sd;


	// Get intensities for each ring
	
	ringIntAvg = newArray(nRings*nRings);
	ringIntSum = newArray(nRings*nRings);

	// step through each ring ROI, save sum and avg pixel value
	for (i = 0; i < nRings*nRings; i++) {
		if (bgMethod == "Median min") {
			// every 2nd ROI after previously existing ones
			roinum = 2*i + existingRoiNum;
		} else if (bgMethod == "Avg normalized") {
			// every 3rd ROI after previously existing ones
			roinum = 3*i + existingRoiNum;
		} else if (bgMethod == "No BG") {
			// each ROI after previously existing ones
			roinum = i + existingRoiNum;
		} else {
			exit("Background method unknown: " + bgMethod);
		}
		
		roiManager("select", roinum);
		
		if (selectionType() != 1) {
			File.close(f);	
			setBatchMode(false);
			exit("ROI " + roinum + " not an oval");
		}
		getRawStatistics(npx, mean);
		
		if (bgMethod == "Median min") {
			ringIntAvg[i] = mean - bgAvg;
		} else if (bgMethod == "Avg normalized") {
			ringIntAvg[i] = mean / ringBg[i];
		} else if (bgMethod == "No BG") {
			ringIntAvg[i] = mean;
		} else {
			exit("Background method unknown: " + bgMethod);
		}
		
		ringIntSum[i] = mean * npx;
		
		getSelectionBounds(x, y, w, h);
		if (!oneFile) {
			print(f, (x+rInt) + "\t" + (y+rInt) + "\t" +
				ringIntSum[i] + "\t" + ringIntAvg[i] + "\t" + ringBg[i]);
		}
	}
	
	Array.getStatistics(ringIntSum, min, max, mean, sd);
	ringIntSumAvg = mean;
	ringIntSumSd = sd;
	
	Array.getStatistics(ringIntAvg, min, max, mean, sd);
	ringIntAvgAvg = mean;
	ringIntAvgSd = sd;
	
	if (oneFile) {
		print(f, s + "\t" + ringIntSumAvg + "\t" + ringIntSumSd + "\t" +
			ringIntAvgAvg + "\t" + ringIntAvgSd + "\t" +
			bgAvg + "\t" + bgSd);
	}
	
	
	roiManager("Deselect");
	run("Select None");
	
	// If multiple files, write summary and close current file
	if (!oneFile) {
		print(f, "");
		print(f, "intsum\tintsumsd\tintavg\tintavgsd\tbg\tbgsd");
		print(f, ringIntSumAvg + "\t" + ringIntSumSd + "\t" +
			ringIntAvgAvg + "\t" + ringIntAvgSd + "\t" +
			bgAvg + "\t" + bgSd);
		File.close(f);
	}
	
	if (DEBUG)
		showStatus("Slice " + (s-minSlice+1) + "/" + (maxSlice-minSlice+1) + ": " +
				(getTime() - dbgSliceTime) + " ms");

} // iterate slices

if (DEBUG)
	print("Total time: " + (getTime() - dbgTotTime) + " ms");

if (oneFile)
	File.close(f);
	
setBatchMode(false);

print("Analysis finished.");
showStatus("Analysis finished.");



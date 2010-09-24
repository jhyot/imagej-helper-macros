origImg = getImageID();

setBatchMode(true);

// Copy active image title to clipboard for easy pasting into save file dialog
//String.copy(getTitle());

// file format: one row per ring
// xpos ypos pxsum pxavg
f = File.open("");

print(f, "xpos ypos intsum intavg bgint");

// check if exactly two ROIs defined

if (roiManager("count") != 2) {
	File.close(f);	
	setBatchMode(false);
	exit("Need exactly 1 line ROI and 1 dot ROI");
}


// select first defined ROI (line for angle measurement)
roiManager("select", 0);

if (selectionType() != 5) {
	File.close(f);	
	setBatchMode(false);
	exit("First ROI needs to be a line");
}

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
if (selectionType() != 10) {
	File.close(f);	
	setBatchMode(false);
	exit("Second ROI needs to be a point");
}

getSelectionCoordinates(xarr, yarr);
x0 = xarr[0];
y0 = yarr[0];


// get user input
Dialog.create("Ring intensity measurement");
Dialog.addNumber("Count intensity within radius [px]", 7);
Dialog.addNumber("Measure background within radius [px]", 26);
Dialog.addNumber("Median filter radius for BG [px] (0 = no median filter)", 1);
Dialog.addNumber("Distance between rings [px]", 26);
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

// calculate x, y steps between rings
stepx = ringDist * cos(angle);
stepy = -1 * ringDist * sin(angle); // in image, "up" is negative y

print("Analyzing " + nRings + " x " + nRings + " array");
print("Count intensity within radius " + rInt + " px, background radius " + rBg + " px");
print("Grid angle: " + 180/PI*angle + " deg; distance between rings: " + ringDist + " px");
print("First ring: x=" + x0 + " ; y=" + y0);
print("x step size: " + stepx + " px; y step size: " + stepy + " px");

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
	}
}

roiManager("Deselect");
run("Select None");

// duplicate image for median filtering and background determination
run("Duplicate...", "tempduplicatebg");
if (rBgMedian > 0) {
	run("Median...", "radius="+rBgMedian);
}

ringMin = newArray(nRings*nRings);

// step through each ring BG ROI, save min pixel value; average = background
for (i = 0; i < nRings*nRings; i++) {
	roiManager("select", 2*i+3);   // first 2 ROIs are line and point; then every 2nd ROI
	if (selectionType() != 1) {
		File.close(f);	
		setBatchMode(false);
		exit("ROI " + (2*i+3) + " not an oval");
	}
	getRawStatistics(npx, mean, min);
	ringMin[i] = min;
}

Array.getStatistics(ringMin, min, max, mean, sd);
bgAvg = mean;
bgSd = sd;

// close duplicated image
close();

ringIntAvg = newArray(nRings*nRings);
ringIntSum = newArray(nRings*nRings);

// step through each ring ROI, save sum and avg pixel value
for (i = 0; i < nRings*nRings; i++) {
	roiManager("select", 2*i+2);   // first 2 ROIs are line and point; then every 2nd ROI
	if (selectionType() != 1) {
		File.close(f);	
		setBatchMode(false);
		exit("ROI " + (2*i+3) + " not an oval");
	}
	getRawStatistics(npx, mean);
	ringIntAvg[i] = mean - bgAvg;
	ringIntSum[i] = ringIntAvg[i] * npx;
	
	getSelectionBounds(x, y, w, h);
	print(f, (x+rInt) + " " + (y+rInt) + " " + ringIntSum[i] + " " + ringIntAvg[i] + " " + ringMin[i]);
}

Array.getStatistics(ringIntSum, min, max, mean, sd);
ringIntSumAvg = mean;
ringIntSumSd = sd;

Array.getStatistics(ringIntAvg, min, max, mean, sd);
ringIntAvgAvg = mean;
ringIntAvgSd = sd;


roiManager("Deselect");
run("Select None");


print("==========");
print((nRings*nRings) + " rings analyzed");
print("Intensity = " + d2s(ringIntSumAvg, 1) + " +/- " + d2s(ringIntSumSd, 1));
print("Intensity/Pixel = " + d2s(ringIntAvgAvg, 1) + " +/- " + d2s(ringIntAvgSd, 1));
print("Background = " + d2s(bgAvg, 1) + " +/- " + d2s(bgSd, 1));
print("==========");

File.close(f);	
setBatchMode(false);



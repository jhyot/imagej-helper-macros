ImageJ Helper Macros
--------------------

A set of [ImageJ][imagej] macros I wrote during my PhD thesis to assist with fluorescence
intensity measurements. Currently there are 3 different macros, each in its own file.
These macros can be imported and run via the usual ImageJ macro commands (refer to the
ImageJ manual/wiki for a description of how to run macros).

  [imagej]: http://imagej.net/

### copy-timings-to-clipboard.ijm

This macro analyses any optical microscopy time series file and copies
the acquisition times of each frame to the clipboard. After starting the
macro, select the time series file you wish to analyse, and then select
which series and channels you’d like to include in the output. After the
macro finishes, the timings are copied into the clipboard in a
tab-separated format (a column for each selected channel), so that it
can be easily pasted e.g. into a spread sheet.

The [Bio-Formats][bioformats] plugin for ImageJ must be installed for the macro to
work.

  [bioformats]: http://www.openmicroscopy.org/site/products/bio-formats

### measure-ring-intensities.ijm

This macro measures the fluorescence intensity over a regular ring/dot pattern.
See (Hyotyla, 2016, pp. 49, 91) for the kind of pattern that this macro was written for.

The macro can handle a single image or a stack of images. Upon running
the macro a dialog window will ask for various parameters. The grid
angle and position of the top-left ring can optionally be determined in
a visual way: Draw exactly one line ROI horizontally across a row of
rings (determines the angle), and one point ROI in the center of the
top-left ring (determines the *x* and *y* starting coordinates).

Parameters can also be read in from a file. The parameter file can be
chosen in the next window appearing after closing the parameter dialog.
In the parameter file, parameters must be defined one per line in the
format `parameterName=value`. For a list of all parameters look at the
header of a result file after running the analysis once. Missing or
invalid parameter values will be replaced by a default value.

Fluorescence intensities can be adjusted for background by two different
methods (the third option is no background adjustment).

* median min
  * The median min method runs a median filter over the image to reduce
noise outliers and takes the minimum intensity value around each ring as
the background for that ring. This background value is subtracted from
the ring intensity to arrive at the background-corrected ring intensity.

* avg normalized
  * The avg normalized method takes the average intensity (no
filtering applied) within a background ring region (bounded by an inner
and outer radius as defined in the analysis parameters), and normalizes
the nanoring intensity by this background average for each ring.

### roi-multi-measure.ijm

This is a small helper macro to quickly measure all ROIs for all slices
in all open images. The user can define ROIs for a single image, and
then automatically have the ROIs measured in all slices and images. For
this to work, the ROIs must not be named in a slice-specific way, i.e.
the `sss-yyyy-xxxx` format is not allowed. The macro writes the pixel
area, average intensity, standard deviation, and integrated intensity
into a single file.


References
----------
Hyotyla, Janne T. *Nanomechanics of Confined Polymer Systems.*
2016, PhD Thesis, University of Basel, Faculty of Science.


License
-------
This software is licensed under the MIT license. See the `LICENSE` file for full details.

Copyright (c) 2016 University of Basel


Acknowledgements
----------------
Macros originally written by Janne Hyötylä, [jhyotyla@gmail.com](mailto:jhyotyla@gmail.com)

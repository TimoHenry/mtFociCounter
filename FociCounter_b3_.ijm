
/***********************************************************************************************************************
						*####*####*####*   Foci-quantifier_Macro   *####*####*####*
************************************************************************************************************************

AUTHOR: Timo Rey, EPFL, 2020; MRC-MBU & EMBO fellow, 2021/22
LICENCE: 

PURPOSE:
This is a macro intended to allow quantification of different aspects of foci-distribution inside mitochondria.

NOTES:
In case you are using this to check our data: sorry, it's not perfect, but workable!
-> you CAN reproduce our entire analysis.
-> but, you CANNOT simply press 1 button.

WORKFLOW: 
1) segment individual cells from large 2- or 3-D FOVs (image-stacks)
2) segment individual foci & "clean" them with mito-mask (if 3D, project to 2D first)
3) quantify count & distances of foci
*/

DATE = "20211210";

// ####################################################           #######################################################
// ***********************************************  code starts below  ***********************************************
// ####################################################           #######################################################




close("*");				 												// close everything to get a clean start

// Create GenericDialog user-interface (GUI):
Dialog.create("Welcome");
Dialog.addMessage("Hello! please choose whether you would like to\nselect cells from large FOVs\nor if you already have single-cell .tif files")

// Ask user which analysis they would like to do:
Dialog.addMessage("Today I feel like:");								// explanation
Dialog.addCheckbox("Finding cells", false);								// add checkboxes
Dialog.addCheckbox("Finding foci", true);								// set default values to true or false
Dialog.addCheckbox("Measuring distances", false);

Dialog.show();															// generte the GUI

// Get the answers:
FIND_CELLS        = Dialog.getCheckbox();								// catch answer to first checkbox from above
FIND_FOCI         = Dialog.getCheckbox();								// catch answer to second checkbox from above
MEASURE_DISTANCES = Dialog.getCheckbox();




							// **** *** **** FIND_CELLS starts here *** **** ***
if(FIND_CELLS){                                              			// If user wants to analyse cells, run this part of the macro:

// Make a list with all the files to analyse:
INPUT_DIR  = getDir("Please choose an input-directory");     			// Ask user to specify an input-directory:
OUT_DIR    = INPUT_DIR+"../outCells/";                         			// select output directory
mkdir(OUT_DIR);															// creates out-directory, in case it does not already exist

to_analyse = SelectFiles(INPUT_DIR, ".tif");               				// Find all files with according ending [e.g. .tif]
// For every file (FOV):
for (i=0; i<to_analyse.length; i++){                         			// For every FOV:
	getReady(INPUT_DIR, to_analyse[i]);			     	     			// prepare z-projection
	identifyCells();                                         			// let user label cell-areas
	saveSingleCells(to_analyse[i]);                          			// Save new image-stacks for each cell & channel individually
	roiManager("Save", OUT_DIR+to_analyse[i]+"_rois.zip");   			// save list of cells
	close("*");                                              			// close all open windows for this FOV.
    close("Roi Manager");};                                  			// close ROI-manager to reset for next FOV

};							// **** *** **** FIND_CELLS ends here *** **** ***





							// *** **** *** FIND_FOCI starts here **** *** ****
if(FIND_FOCI){                                                      	// If user wants to analyse foci, run this part of the macro:

// Find all files:
	if(!FIND_CELLS){                                                	// in case FIND_CELLS did not run:
		CELLS_DIR  = getDir("Please choose an input-directory");};  	// ask for input-directory with .tifs
	else{CELLS_DIR = OUT_DIR;};                                    		// otherwise simply use OUT_DIR as new input-directory
	OUT_DIR2       = CELLS_DIR+"../outFoci/";							// new out-directory
	mkdir(OUT_DIR2);													// creates out-directory, in case it does not already exist
	
	Dialog.create("Find files");										// create a GUI
	Dialog.addNumber("How many channels do you have? ", 2);				// NOTE: add flexibility here: to allow f.i. 2 foci-channels
	Dialog.addMessage("Please indicate specific file-extensions");		// explanation	
	Dialog.addString("mitochondria: ", "channel2.tif");
	Dialog.addString("foci: ", "channel1.tif");
	Dialog.addString("foci: ", "channel3.tif");
	Dialog.show();														// generate the GUI

	num_channels   = Dialog.getNumber();								// NOTE: add flexibility here: to allow f.i. 2 foci-channels
	mito_extension = Dialog.getString();
	foci_extension = Dialog.getString();
	if(num_channels!=2){print("wow, that's a problem for now");}; 		// NOTE: add flexibility here: to allow f.i. 2 foci-channels
	
	// create lists with all files:
	mito_files = SelectFiles(CELLS_DIR, mito_extension);            	// Find all files with mitochondria (e.g. channel_2)
	foci_files = SelectFiles(CELLS_DIR, foci_extension);				// Find all files with foci (e.g. channel_1)


// for every cell:
for (i=0; i<mito_files.length; i++){                      				// For every cell

// 1) get mitomasks (process channel 1):	

  	OpenImg(CELLS_DIR, mito_files[i]);                              	// Open image-stack for channel 1 (mito)
	roiManager("reset");                                 		    	// to make sure roi-manager is clear
	roiManager("Add");													// Add cell-outline to ROI-manager

	// Define top & bottom of the cell & z-project:	
	strt_stp = cell_depth(mito_files[i]);                           	// returns array with user-defined starting & stopping slice

	// binarise mitochondria:
	selectWindow("MAX_" + mito_files[i]);								// choose z-projection for masking of mitochondria
	run("Duplicate...", "title=mask");									// duplicate z-projection with new name
	setOption("BlackBackground", true);
	run("Convert to Mask");
	//run("Dilate");                                                  	// dilate the binary to allow for a bit of tolerance around the maximum
	name_mito_mask = "MASK_MAX_" + mito_files[i];						// create name of mito_mask
	selectWindow("mask");												// choose mask
	rename(name_mito_mask);												// rename mask with mask-name

	// determine cell area & mito fraction:
	roiManager("Select", 0);											// select cell ROI
	run("Set Measurements...", "area area_fraction redirect=None decimal=1");	// define measurement parameters: Area & area fraction
	run("Measure");														// Measure
	cell_area = getResult("Area", 0);									// Create variable to hold cell area (in image-dependent units)
	mito_fraction = getResult("%Area", 0);								// Create variable to hold mitochondrial fraction within cell-outline (from binary)
	close("Results");													// close output table
																		// NOTE: results will be output and saved in "focicount" function

	// OPTIONAL (for developers): unhash below to make a composite image of the binaries to inspect overlap:
	//run("Images to Stack", "name=Stack title=[] use keep");			// collect images in a stack
	//run("Make Composite", "display=Composite");						// turn into composite

	saveAndClose("MAX_"+mito_files[i]);                             	// save & close mito-z-projection for overlays & inspection	

// 2) get raw foci-locations (process channel 2):
	OpenImg(CELLS_DIR, foci_files[i]);									// Open image-stack for channel 1 (mito)
	roiManager("reset");                                 		    	// to clear the list
	roiManager("Add");                                              	// retrieve cell-area

	start_slice = strt_stp[0];									    	// get values from array because "Z Project..." cannot handle complex variables
	stop_slice  = strt_stp[1];
	run("Z Project...", "start=start_slice stop=stop_slice projection=[Max Intensity]"); // max instensity projection vs. [Sum Slices] for summed intensity
	close(foci_files[i]);                          						// close original stack, keep only z-projection

	// Find maxima with given prominence-level:
	Dialog.create("Prominence");										// create a GUI
	Dialog.addMessage("Would you like to use: ");						// explanation	
	Dialog.addCheckbox("Range of prominences?", true);					// add checkboxes
	Dialog.addCheckbox("Particular prominence?", false);				// 
	Dialog.addNumber("If only 1, which one?", 10000);					// ask user to decide on prominence
	Dialog.show();	

	prominence_range = Dialog.getCheckbox();							// check whether user wants to test range
	if (!prominence_range) {											// if not
		prominence = Dialog.getNumber();								// get the single prominence-value entered
		FindMaxWithProminence(prominence);								// create foci-mask with this
// 3) filter foci:		
		name_foci_binary = foci_files[i]+"_"+prominence;				// remember name of prominence-map
		imageCalculator("Multiply create",name_foci_binary,name_mito_mask);}; // multiply the binary-images to retain only pixels that were present in both (1*1=1, 1*0=0 ;-D )
		
	else {																// in case user want to test the full range of prominences
		prominences = newArray(10000, 15000, 20000, 30000, 40000);		// could change range here
		for (k = 0; k < lengthOf(prominences); k++) {					// for all prominences in the list
			prominence = prominences[k];								// get particular prominence
			FindMaxWithProminence(prominence);							// create foci-mask with this
// 3) filter foci:
			name_foci_binary = foci_files[i]+"_"+prominences[k];		// remember name of prominence-map		
			imageCalculator("Multiply create",name_foci_binary,name_mito_mask); // multiply the binary-images to retain only pixels that were present in both (1*1=1, 1*0=0 ;-D )
		};};
		
	saveAndClose("MAX_"+foci_files[i]);									// save & close foci-z-projection for overlays & inspection <- note: srt&stp indexes are not attached to name => keep it consistent


// 4) quantify foci:
	if (!prominence_range){name_remaining_foci = "Result of "+name_foci_binary;
		quantifyFoci(name_remaining_foci, prominence);};
	
	else {for (k = 0; k < lengthOf(prominences); k++){					// for all prominences in the list
		name_remaining_foci = "Result of "+foci_files[i]+"_"+prominences[k];
		quantifyFoci(name_remaining_foci, prominences[k]);};};
	
	
	close("*");															// close all windows
	
};};							// *** **** *** FIND_FOCI ends here **** *** ****








// NOTE: add "emergency escape" <- remember 'rth'-roi

							// ***** ** ***** MEASURE_DISTANCEs starts here ***** ** *****
// To create a user-interface to allow hand-annotation of distances from automatically produced list of foci
if(MEASURE_DISTANCES){                                          		// If user wants to measure distances from foci to mito-features, run this part of the macro:
// Find all files:
	if(!FIND_FOCI){                                             		// in case FIND_FOCI did not run:
		in_dir  = getDir("Please choose an input-directory");}; 		// ask for input-directory with .tifs
	else{in_dir = OUT_DIR2;};                                   		// otherwise simply use OUT_DIR2 as new input-directory
	OUT_DISTs       = in_dir+"../outDistances/";						// new out-directory
	mkdir(OUT_DISTs);													// creates out-directory, in case it does not already exist

	prominence	   = getNumber("Please indicate prominence value:", 200);// Let user choose which prominence-ROIs should be analysed
	mito_extension = "channel1.tif";									// define extension to identify mitochondrial z-projections for each cell
	roi_extension  = ""+prominence+".zip";									// define extension to identify ROIs for each cell
	mito_files 	   = SelectFiles(in_dir, mito_extension);       		// make a list with all mito-images
	roi_files      = SelectFiles(in_dir, roi_extension);				// and a list with all ROIs

for (c = 0; c < mito_files.length; c++){								// Run code below for every cell (mito-file) in the input-directory

// (I) Measure distance to poles:
	// 1) For every cell, open files:
	OpenImg(in_dir, mito_files[c]);										// open mito-projection. NOTE: should z-projection of foci also be overlayed?
	open(in_dir+roi_files[c]);											// open ROIs
	number_of_foci = roiManager("count");                       		// get number of rois (aka foci)
	run("Set Measurements...", "centroid redirect=None decimal=1"); 	// to later get x & y of ROI-centroid
																		// note: could find & display centroid instead of square.
	// for every ROI, show only ROI[r] & let user draw:
	for (r = 0; r<number_of_foci; r++) {
		roiManager("reset");											// clear roiManager
		open(in_dir+roi_files[c]);										// open ROIs for this FOV
		number_of_distances = drawDistances(r);							// let user draw lines to poles for current ROI & return number of lines
		if(number_of_distances > 2){									// check there are at least 1) focus, 1 line to closest pole, 1 line to other pole
		measureDistances(number_of_distances);};						// Measure distances & save the data.
		else{};};														// otherwise got to next roi


// (II) potential future development: Measure distance between foci inside same parent-mito:

// (III) potential future develoment: Measure integrated intensity & area, etc. of foci: // -> use centroid, then do as in IntInt-script:

};};              			// ***** ** ***** MEASURE_DISTANCEs ends here ***** ** *****





// ####################################################           #######################################################
// **************************************************** functions *******************************************************
// ####################################################           #######################################################

// Return list of all relevant files in a directory: 
function SelectFiles(IN_DIR, ending) {
	LIST = getFileList(IN_DIR);                          // make a list with all files in this directory
	to_process = newArray();                             // make a list with FOVs that will be processed
	for (i=0; i<LIST.length; i++) {                      // for every entry in the list
		filename = LIST[i];                              // get its file-name
		if (endsWith(filename, ending)) {                // check if file has a particular ending / is a particular file-type
			to_process = Array.concat(to_process, LIST[i]); // if yes, append to list to keep
      		//print(LIST[i]);                            // developer option: can print all treated files to log by unhashing this line.
      		};};
	return to_process;};                                 // return list of files with particular ending.

// *************************************************************************************************************************************************************
// Open a FOV:
function OpenImg(dir_name, file_name) {
	open(dir_name+file_name);};                          // open image

// *************************************************************************************************************************************************************
// Prepare paricular FOV -> make z-projection to see cells:
function getReady(dir,fov) { 
	OpenImg(dir,fov);					                 // open the image.
	// treat image:
	run("Z Project...", "projection=[Max Intensity]");   // make a z-projection
	setTool("brush");};                                  // get brush-tool to select cell-area

// *************************************************************************************************************************************************************
// Let user select all cells & save their area to ROI-manager:
function identifyCells(){
	// Find all cells:
	answer="More";										 // pre-define variable for while-loop
	while(answer != "Done") {                            // until all cells in this FOV are labelled
    	waitForUser("select area of a cell & add to ROI-manager [t], THEN press 'OK'");
    	roiManager("Show None");
		roiManager("Show All with labels");
    	Dialog.create("Cell outlines");
    	Dialog.addMessage("Are there more cells you'd like to outline?"); 
  		items = newArray("Done", "More");                 // let use decide whether they want to label more cells
  		Dialog.addRadioButtonGroup("To do:",items,2,1,"More");
  		Dialog.show();
  		answer = Dialog.getRadioButton();};};

// *************************************************************************************************************************************************************
// Save new image-stacks for each cell & channel individually:
function saveSingleCells(current_fov){
	// Save a new image per cell & channel:  	
	selectWindow(current_fov);                            // go back to original window
	numRois = roiManager("count");                        // get number of rois (aka cells)
	makeNewDir(OUT_DIR);                                  // check if directory already exists - if not, make a new one.
	for(cell=0; cell<numRois; cell++) {
		for (j=1; j<=2; j++){                             // for both channels mito (=ch1) & Br(d)U (=ch2) <- can adapt j <= no.channels
			roiManager("Select", cell);
			run("Duplicate...", "duplicate channels=j");
			saveAs("Tiff", OUT_DIR+current_fov+ "_cell"+cell+"_channel"+j+".tif");
			close();};};};                                // close the new image for this cell & channel

// *************************************************************************************************************************************************************
// Create new directory in case it does not yet exist:
function makeNewDir(what_dir){
	if(!File.exists(what_dir)){                          // if directory does not exist
		File.makeDirectory(what_dir);};};                // make a new directory
														 // note: printing to log, will stop the flow.

// *************************************************************************************************************************************************************
// Define top & bottom of the cell:	
function cell_depth(filename){
	waitForUser("Check slices to find top & bottom of the cell, THEN press 'OK'");   // let user choose top & bottom
	start_slice = getNumber("Specify starting slice for z-projection", 15);           // Ask user for the number
	stop_slice  = getNumber("_Specify stop-slice for z-projection", 25);
	// z-project the entire cell:
	run("Z Project...", "start=start_slice stop=stop_slice projection=[Max Intensity]");// max intensity projection vs. sum [Sum Slices]
	close(filename);                                                            // close original stack, keep only z-projection
	start_and_stop = newArray(start_slice, stop_slice);								 // need to collect in 1 array to return both values
	return start_and_stop;};
	
// NOTE: could upgrade to ask for user-satisfaction with resulting projection & let them re-try if not:														 
	/*for(k=0; k<2; k++){
	//k = getBoolean("Are you happy with the result?");                                  // Ask user to decide whether they are content with result or redo:
	*/


// *************************************************************************************************************************************************************
// Save & close a particular window:
	function saveAndClose(window_name){
	selectWindow(window_name);								// choose the window
	saveAs("tiff", OUT_DIR2+window_name);					// save as .tif
	close(window_name);                                    // close the window		
	};


// *************************************************************************************************************************************************************
// Find maxima with given prominence-level:
	function FindMaxWithProminence(prominence){
		selectWindow("MAX_"+foci_files[i]);									// choose z-projection of foci
		roiManager("Select", 0);											// select only content of the cell, exclude neighbouring cells etc.
		run("Find Maxima...", "prominence=prominence output=[Single Points]"); // find all foci -> creates binary
		run("Dilate");                                                  	// dilate the binary to allow for a bit of tolerance around the maximum
		name_foci_binary = foci_files[i]+"_"+prominence;				    // make up new name for prominence-map
		rename(name_foci_binary);};


// *************************************************************************************************************************************************************
// Foci counting:
function quantifyFoci(name_remaining_foci, prominence){
	roiManager("reset");												// clear ROI manager
	selectWindow(name_remaining_foci);
	run("Analyze Particles...", "size=0 circularity=0.00 add");			// turn binary into ROIs
	roiManager("Show All without labels");	

	// Create & save output:
	nROIs = roiManager("count"); 										// count number of MRGs
	if(nROIs > 0){
	roiManager("Save", OUT_DIR2+mito_files[i]+"_ROI_"+prominence+".zip");};// save ROIs; else: do not save, as it raises an error to save an empty list
	File.append("../"+mito_files[i]+","+cell_area+","+mito_fraction+","+start_slice+","+stop_slice+","+prominence+","+nROIs, OUT_DIR2+"Results_"+DATE+".csv");

	// add option: save overlay(s) -> rois on mito & on foci-projections
	// calculate mito-area to normalise
	};


// *************************************************************************************************************************************************************
// Make directory in case it does not exist:
function mkdir(path){
	if(!File.exists(path)){					// Checks whether directory already exists
		File.makeDirectory(path);};};		// Creates a directory


// *************************************************************************************************************************************************************
// let user draw distances to poles & return number of distances:
function drawDistances(r){
	roiManager("Select", r);										// select r-th ROI
	roiManager("reset");											// clear roi-manager with ALL rois
	//run("Close");													// close ROI-manager alternatively, use: roiManager("reset");
	roiManager("Add");												// add-back r-th ROI to ROI-manager
	// 1) to closest pole:
	setTool("freeline");											// set selection-tool to freeline
	waitForUser("Please draw a line to the closest pole, press [t].\n Then draw a line to another pole & add [t]. \n THEN press 'OK'.");   // let user draw a line to closest pole
	// 2) to other pole [see above]
	// 2.2) to other branches:
	waitForUser("If there are other branches, add these, THEN press 'OK'.");// let user draw a line to closest pole
	// 3) save the list of these ROIs:
	roiManager("Save", "_"+r+".zip");								// save ROIs
	// 4) measure & save distances:
	this_focus = roiManager("count");                        		// get number of ROIs (aka distances or poles)
	return this_focus;};


// *************************************************************************************************************************************************************
// Measure distances & save the data:
function measureDistances(number_of_distances){
	for (f = 0; f < number_of_distances; f++){							// for every distance
		roiManager("Select", f);
		roiManager("Measure");};										// measure (centroid-position for ROI, distances for lines.
	out_name = OUT_DISTs+roi_files[c]+"_roi"+r+"_Results"+DATE+".csv";			// save cell-ID (roi_files, incl. prominence) + roi-ID (i) as .csv
	saveAs("Results", out_name);
	close("Results");};													// clear results-table for next measurement								


// *************************************************************************************************************************************************************



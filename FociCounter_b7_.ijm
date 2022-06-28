
/********************************************************************************************************************
							*####*####*####*   FociCounter_Macro   *####*####*####*
*********************************************************************************************************************

AUTHOR: Timo Rey, EPFL, 2020; MRC-MBU & EMBO fellow, 2021/22
LICENCE:  MIT licence

PURPOSE:
This is a macro intended to allow fully reproducible quantification of foci inside mitochondria from fluorescence images of (mammalian) cell culture.

WORKFLOW:
0) Convert microscopy output files to .tif image stacks
1) Segment individual cells:
	INPUT: image stacks in .tif format
	manual or automated 2D Z-projection from 3D image stacks
	manual or *(*automated*)* cell segmentation
	copy and save a new image for each cell
	OUTPUT: z-projected image for each cell, list of ROIs to identify cells in original image
	
2) Analyse foci for each cell:
	INPUT: z-projected image for each cell with ROI of cell-outline
	manual or automated 2D Z-projection from 3D image stacks
	option 1: segment nucleus
	option 2: segment mitochondria + quantify mitochondrial area
	find maxima with range of prominences
	option 3: find second maxima
	filter maxima with: cell-outline, nucleus-area, mitochondrial-area
	*(*quantify maxima descriptors*)* 
	OUTPUT: .csv file with cell & maxima descriptors, list of ROIs with maxima, if options: binary masks
	
3) Analyse foci-overlap:
	INPUT: 2 binary images with foci
	decide: prominence levels for each, allowed distance (with range?)
	do co-localisation
	OUTPUT: overlap
	
4) alpha version only: measure distances of foci
	INPUT: z-projected image for each cell with at least foci & mitochondria channel, list of ROIs with maxima
	for every roi, let user measure distance
		to tips
		*(*to neighbours*)*
		*(*find sibling-pairs*)*
	OUTPUT: .csv file with distances, list of ROIs with distances*/



// ####################################################           ######################################################
//    ********************************************  code starts here  ***********************************************
// ####################################################           ######################################################

// First: find out what user wants to do:
close("*");				 															// close everything to get a clean start

// Create Generic dialog User-Interface (GUI):
Dialog.create("Welcome");
Dialog.addMessage("Hello! /nPlease choose whether you would like to \n+Convert files to .tif /nSelect cells from large FOVs \nAlready have single-cell .tif files to analyse");
TODOs = newArray("Convert to Tiff", "Find Cells", "Find Foci", "Co-localise Foci", "Measure Distances");	// define list of options
// Ask user which analysis they would like to do:
Dialog.addChoice("What would you like to do?", TODOs);								// ask to choose from list of options
Dialog.addString("What date is it today?", "20220623");								// ask for date to label output files
Dialog.show();																		// generate the GUI
// Get the answers:
WHAT_TO_DO			= Dialog.getChoice();											// get user-selection
DATE				= Dialog.getString();											// catch date



// ---------------------------------------------------------------------------------------------------------------------
// 000 000 000 000 000 000 000 000 000 000 000 000 00 CONVERT TO TIFF 00 000 000 000 000 000 000 000 000 000 000 000 000
// ---------------------------------------------------------------------------------------------------------------------
// Mini-script to convert microscopy output (e.g. .czi from Zeiss or .ims from Andor) into .tif image-stacks:
if(WHAT_TO_DO=="Convert to Tiff"){
	
// Create GUI:
Dialog.create("Convert to Tiff");
Dialog.addMessage("If not in Tiff-format, all files with specific ending will be opened and saved as .tif");
Dialog.addString("What is the current file-ending? ", ".ims");						// ask for file-type if not tiff
Dialog.show();																		// generate the GUI

NOT_TIFF_END		 = Dialog.getString();											// file-type to search for in input directory
Input_dir			 = convertToTiff(NOT_TIFF_END);									// finds or creates input directory with only .tif files

print("The following directory was created, containing your .tif-files");
print(Input_dir);
};



// ---------------------------------------------------------------------------------------------------------------------
// 111 111 111 111 111 111 111 111 111 111 111 111 11 1 FIND CELLS 1 11 111 111 111 111 111 111 111 111 111 111 111 111
// ---------------------------------------------------------------------------------------------------------------------
// This sections enables user to segment individual cells from larger fields of view (FOVs):
// required INPUT: .tif files with microscopy images
if(WHAT_TO_DO=="Find Cells"){

// Create GenericDialog user-interface (GUI):
Dialog.create("Finding Cells");
Dialog.addMessage("Semi-automated option (default) will let you choose to \nautomate maximum intensity projection \n and/or cell segmentation.")
// Ask user which analysis they would like to do:
Dialog.addMessage("Select if you opt for fully automated black-box:");				// explanation
Dialog.addCheckbox("Fully automated?", false);										// set default values to true or false
Dialog.addMessage("If semi-automated, which part do you want to adapt?");
Dialog.addCheckbox("Z-projection?", false);											// default is false -> max-projection of all z-steps
Dialog.addCheckbox("Manual cell segmentation?", true);								// default is true -> manual segmentation of cells 
Dialog.show();																		// generte the GUI

AUTOMATED_CELLS		= Dialog.getCheckbox();											// get answer to whether semi- or fully automated workflow
USER_Z 			 	= Dialog.getCheckbox();											// get answer to whether user wants to adapt z-projection
CELL_OUTLINE 		= Dialog.getCheckbox();											// get answer to whether user wants to manually segment cells


// Find the input files and make a list:
Input_dir			= getDir("Please choose an input-directory /n[only .tif will be processed]");	// ask user to specify an input-directory
Out_dir       		= Input_dir+"../outCells_"+DATE+"/";							// specify output sub-directory
mkdir(Out_dir);																		// creates out-directory, in case it does not already exist
to_analyse     		= selectFiles(Input_dir, ".tif");               				// Find all files with according ending [e.g. .tif]


// For fully automated cell-segmentation:
if(AUTOMATED_CELLS){
	Z_STYLE=newArray("projection=[Max Intensity]", true);							// default: max-intensity z-projection over all slices
	// For every file (FOV):
	// ************** need to adapt processFOVs function for "false" case
	processFOVs(true);																// set this to false once automation is implemented  
};
// For semi-automated cell-segmentation:
else{																				// If chose semi-automated cell segmentation (default)
	// check if user wants to adapt z-projection:
	if(USER_Z){																		// if user wants to adapt z-projection
		Z_STYLE = getZprojection()};												// returns type of z-projection and whether this can be used for all FOV (true) or needs to be re-decided for each FOV (false)
	else{Z_STYLE=newArray("projection=[Max Intensity]", true, "MAX_");};			// max-intensity project over all z-slices (default)
	// process every FOV:
	CELL_OUTLINE	= true;															// override this until automated cell outline implemented.
	processFOVs(CELL_OUTLINE);
};
};		



// ---------------------------------------------------------------------------------------------------------------------
// 222 222 222 222 222 222 222 222 222 222 222 222 222 2 FIND Foci 2 222 222 222 222 222 222 222 222 222 222 222 222 222
// ---------------------------------------------------------------------------------------------------------------------
// This section allows user to find and filter foci and then outputs a .csv file with all descriptors
// required INPUT:
if(WHAT_TO_DO=="Find Foci"){

// Get user-input:
Dialog.create("Image set-up");														// create GUI
Dialog.addMessage("Welcome to 'Find Foci'.");
Dialog.addNumber("How many channels are in the input impage stacks?", 3);
Dialog.addMessage("Which analysis would you like to do?");
Dialog.addCheckbox("Subtract nucleus?", true);										// area will be subtracted from foci-channel (- filter)
Dialog.addNumber("If yes, which channel is this?", 3);
Dialog.addCheckbox("Filter with mitochondria?", true);								// area will be multiplied with foci-channel (+ filter)
Dialog.addNumber("If yes, which channel is this?", 2);
Dialog.addMessage("To localise foci:");												// no choice, since this is the point...
Dialog.addNumber("Which channel is this?", 1);
Dialog.addNumber("Start of prominence range", 5);									// ask user to decide on prominence
Dialog.addNumber("End of prominence range", 50);									// ask user to decide on prominence
Dialog.addCheckbox("Localise second foci?", false);									// for second foci, e.g. EdU (replicating mtDNA)
Dialog.addNumber("If yes, which channel?", 4);
Dialog.addNumber("Start of prominence range", 5);									// ask user to decide on prominence for second foci-channel
Dialog.addNumber("Start of prominence range", 50);

Dialog.addMessage("How would you like to do the segmentation?");
seg_Options 	= newArray("simple", "deep-learning", "manual", "pre-segmented");	
Dialog.addRadioButtonGroup("Nuclei:",seg_Options,2,1,"simple");						// default will segment nuclei manually.
Dialog.addRadioButtonGroup("Mitochondria:",seg_Options,2,1,"simple");				// default will segment mitochondria automatically.

Dialog.show();

// get answers:
num_channels			= Dialog.getNumber();										// number of channels to process <- important for file-names
with_nucleus			= newArray(Dialog.getCheckbox());							// whether nuclei should be segmented
with_nucleus[1]			= Dialog.getNumber();										// which channel nuclei are in
with_mito				= newArray(Dialog.getCheckbox());
with_mito[1]			= Dialog.getNumber();
with_foci				= newArray(true);											// To find foci, foci is always true
with_foci[1]			= Dialog.getNumber();										// which channel in image stack
with_foci[2]			= Dialog.getNumber();										// start of prominence sweep
with_foci[3]			= Dialog.getNumber();										// endpoint of prominence sweep
with_2foci				= newArray(Dialog.getCheckbox());
with_2foci[1]			= Dialog.getNumber();
with_2foci[2]			= Dialog.getNumber();
with_2foci[3]			= Dialog.getNumber();
segNuc_Style			= Dialog.getRadioButton();
segMito_Style			= Dialog.getRadioButton();

// Get input file location with singled cells:
Input_dir  				= getDir("Choose an input directory with image stacks of segmented cells. (in .tif format)");	// ask for input-directory with .tifs
Out_dir					= Input_dir+"../outFoci_"+DATE+"/";							// name new out-directory in parent directory
mkdir(Out_dir);																		// creates out-directory, in case it does not already exist
to_analyse     			= selectFiles(Input_dir, ".tif");      	         			// Find all files with according ending [e.g. .tif] and return a list

// check if & where pre-segmented binaries available:
if(segNuc_Style=="pre-segmented"){
	In_Binary_Nuclei	= getDir("Choose directory with only nuclear binary images with correct naming.");
	Binary_Nuclei     	= selectFiles(In_Binary_Nuclei, ".tif");};					// Find all files with according ending [e.g. .tif] and return a list
if(segMito_Style=="pre-segmented"){
	In_Binary_Mito		= getDir("Choose directory with only mitochondria binary images with correct naming.");
	Binary_Mito     	= selectFiles(In_Binary_Mito, ".tif");};					// Find all files with according ending [e.g. .tif] and return a list
else{cell_area = 0; mito_fraction = 0;};											// if there is no mito-channel, set cell area to 0



// For every cell:
for (i=0; i<to_analyse.length; i++){
	// open image:
	OpenImg(Input_dir, to_analyse[i]);
	// get cell-outline:
	cell_Roi = Input_dir+to_analyse[i]+"_roi.zip";
	roiManager("reset");                                 		    				// to make sure roi-manager is clear
	roiManager("Add");																// Add cell-outline to ROI-manager
	roiManager("select", 0);
	roiManager("rename", "Cell_Outline");
	roiManager("save", cell_Roi);
	// split channels:
	run("Split Channels");

// option 1) if with nucleus:
	if(with_nucleus[0]){
		Nuc_Window			= "C"+with_nucleus[1]+"-"+to_analyse[i];
	// segment nucleus:
		selectWindow(Nuc_Window);
		segmentNucleus(segNuc_Style);
	// save binary
		Nuc_Binary			= "nucBinary_"+to_analyse[i];
		if(segNuc_Style!="pre-segmented"){											// re-name the newly created binary
			selectWindow(Nuc_Window);
			rename(Nuc_Binary);};
		else{selectWindow(Nuc_Binary);};											// if loaded pre-produced binary, no need to re-name
		saveAs("Tiff", Out_dir+Nuc_Binary);
	};

// option 2) if with mitochondria:
	if(with_mito[0]){
		mito_Window		= "C"+with_mito[1]+"-"+to_analyse[i];
	// segment mitochondria:
		selectWindow(mito_Window);
		segmentMitochondria(segMito_Style);
	// save binary:
		Mito_Binary		= "mitoBinary_"+to_analyse[i];
		selectWindow(mito_Window);
		rename(Mito_Binary);
		saveAs("Tiff", Out_dir+Mito_Binary);
	// determine cell area & mito fraction:
		selectWindow(Mito_Binary);													// choose mask
		roiManager("reset");
		roiManager("open", cell_Roi);
		roiManager("Select", 0);													// select cell ROI
		run("Set Measurements...", "area area_fraction redirect=None decimal=1");	// define measurement parameters: Area & area fraction
		run("Measure");																// Measure
		cell_area = getResult("Area", 0);											// Create variable to hold cell area (in image-dependent units)
		mito_fraction = getResult("%Area", 0);										// Create variable to hold mitochondrial fraction within cell-outline (from binary)
		close("Results");															// close output table
	};																				// NOTE: results will be output and saved in "focicount" function

// Find & filter foci:
	// find, filter and save foci as ROIs:
	findFoci(with_foci[2], with_foci[3], "C"+with_foci[1]+"-"+to_analyse[i],"1st");	// pass input variables for: (prom_start, prom_stop, foci_Window, foci_type)
	
// option 3) if with 2nd type of foci:
	if(with_2foci[0]){
	// find, filter and save foci as ROIs:
	findFoci(with_2foci[2], with_2foci[3], "C"+with_2foci[1]+"-"+to_analyse[i],"2nd")};


close("*");}; // end of "for every cell"
};



// ---------------------------------------------------------------------------------------------------------------------
// 333 333 333 333 333 333 333 333 333 333 333 333 3 CO-LOCALISE FOCI 3 333 333 333 333 333 333 333 333 333 333 333 333
// ---------------------------------------------------------------------------------------------------------------------
// This is an alpha-version (not tested!) to assess the co-localisation of two foci-types (such as EdU and mtDNA)
if(WHAT_TO_DO=="Co-localise Foci"){
	print("Sorry, this part is not implemented yet. Please come back later.");
};
// ---------------------------------------------------------------------------------------------------------------------
// 444 444 444 444 444 444 444 444 444 444 444 44 4 MEASURE DISTANCES 4 44 444 444 444 444 444 444 444 444 444 444 444
// ---------------------------------------------------------------------------------------------------------------------
// This is an alpha-version (not tested!) to measure distances between mitochondrial foci
if(WHAT_TO_DO=="Measure Distances"){
	print("Sorry, this part is not implemented yet. Please come back later.");
};






// ####################################################           #######################################################
// **************************************************** functions *******************************************************
// ####################################################           #######################################################

// convertToTiff:
// Returns input directory with only .tif files to analyse.
function convertToTiff(NOT_TIFF_END){
	IN_DIR = getDir("Please choose an input-directory");     						// ask user to specify an input-directory
	Input_dir = IN_DIR+"tiff_input"+DATE+"\\";										// name a new input directory
	mkdir(Input_dir);																// creates tiff-files directory, in case it does not already exist
	// Convert input files to .tif:
	to_analyse = selectFiles(IN_DIR, NOT_TIFF_END);               					// Find all files with according ending [e.g. .czi from LSM-microscopes]
	for (i=0; i<to_analyse.length; i++){                         					// For every FOV:
		OpenImg(IN_DIR, to_analyse[i]);			    	 	     					// open image
		saveAs("Tiff", Input_dir+to_analyse[i]);
		close("*");                                              					// close all open windows for this FOV.
		};
	return Input_dir;};
// *************************************************************************************************************************************************************
// mkdir:
// Make directory in case it does not already exist.
function mkdir(path){
	if(!File.exists(path)){															// Checks whether directory already exists
		File.makeDirectory(path);};};												// Create new directory
// *************************************************************************************************************************************************************
// selectFiles:
// Returns list of all relevant files in a directory. 
function selectFiles(IN_DIR, ending) {
	LIST = getFileList(IN_DIR);                          							// make a list with all files in this directory
	to_process = newArray();                             							// make a list with FOVs that will be processed
	for (i=0; i<LIST.length; i++) {                      							// for every entry in the list
		filename = LIST[i];                             							// get its file-name
		if (endsWith(filename, ending)) {               							// check if file has a particular ending / is a particular file-type
			to_process = Array.concat(to_process, LIST[i]);							// if yes, append to list to keep
      		//print(LIST[i]);                            							// developer option: can print all treated files to log by unhashing this line.
      		};};
	return to_process;};                                 							// return list of files with particular ending.
// *************************************************************************************************************************************************************
// OpenImg:
// Opens an image with specific name.
function OpenImg(dir_name, file_name) {
	open(dir_name+file_name);};                       			   					// open image
// *************************************************************************************************************************************************************
// *************************************************************************************************************************************************************
// getZprojection:
// Returns z-projection style according to user-input.
function getZprojection(){
	Dialog.create("User defined Z-projection");
	// if user wants to change the type of projection:
	ZTYPE = newArray("Max Intensity (default)", "Summed Intensity", "Average Intensity");
	Dialog.addChoice("Which z-projection type do you prefer?", ZTYPE);
	// if user wants to change the range of slices used for projection:
	ZRANGE = newArray("full range (default)", "fixed range", "manual range");
	Dialog.addChoice("What range of z-slices?", ZRANGE);
	Dialog.addNumber("If fixed range, from where?", 0);
	Dialog.addNumber("To where?", 1);
	Dialog.show();
	// collect user-input:
	Z_TYPE 			 	= Dialog.getChoice();
	Z_RANGE 			= Dialog.getChoice();


	// if user wants to define specific start and stop slices with fixed range:
	if(Z_RANGE=="fixed range"){
		start_slice		= Dialog.getNumber();
		stop_slice		= Dialog.getNumber();
		if(Z_TYPE=="Summed Intensity"){
			projectionStyle = "start=start_slice stop=stop_slice projection=[Sum Slice]";
			suffix = "SUM_";};
		if(Z_TYPE=="Average Intensity"){
			projectionStyle = "start=start_slice stop=stop_slice projection=[Average Intensity]";
			suffix = "AVG_";};
		else{projectionStyle = "start=start_slice stop=stop_slice projection=[Max Intensity]";
			suffix = "MAX_";};
		Z_STYLE = newArray(projectionStyle, true, suffix);
		return Z_STYLE;};
		
		
	// To adapt for every image:
	if(Z_RANGE=="manual range"){
		if(Z_TYPE=="Summed Intensity"){
			projectionStyle = "projection=[Sum Slice]";
			suffix = "SUM_";};
		if(Z_TYPE=="Average Intensity"){
			projectionStyle = "projection=[Average Intensity]";
			suffix = "AVG_";};
		else{projectionStyle = "projection=[Max Intensity]";
			suffix = "MAX_";};
		Z_STYLE = newArray(projectionStyle, false, suffix);
		return Z_STYLE;};


	// if no adaptation of range:
	if(Z_RANGE=="Max Intensity (default)"){
		if(Z_TYPE=="Summed Intensity"){
			projectionStyle = "projection=[Sum Slice]";
			suffix = "SUM_";};
		if(Z_TYPE=="Average Intensity"){
			projectionStyle = "projection=[Average Intensity]";
			suffix = "AVG_";};
		else{projectionStyle = "projection=[Max Intensity]";
			suffix = "MAX_";};
		Z_STYLE = newArray(projectionStyle, true, suffix);
		return Z_STYLE;};};
// *************************************************************************************************************************************************************
// processFOVS:
// Produces new images with segmented cells.
function processFOVs(CELL_OUTLINE){
	for (i=0; i<to_analyse.length; i++){                         					// For every file (FOV):
		zProject(Input_dir, to_analyse[i], Z_STYLE);			     				// produces z-projection
		getReady();																	// makes composit, ready for user-based cell segmentation
		identifyCells(CELL_OUTLINE);                                    			// let user label cell-areas
		saveSingleCells(to_analyse[i]);                          					// Save new image-stack for each cell & channel individually
		roiManager("Save", Out_dir+to_analyse[i]+"_rois.zip");   					// save list of cells
		close("*");                                              					// close all open windows for this FOV.
   		close("Roi Manager");	                                  					// close ROI-manager to reset for next FOV
   		};};
// *************************************************************************************************************************************************************
// zProject:
// Creates a 2D z-projection from 3D image-stack.
function zProject(dir, fov, Z_STYLE){
	OpenImg(dir, fov);					                 							// open the image.
	if(Z_STYLE[1]){																	// if no-more user-input is required for z-projection
		run("Z Project...", Z_STYLE[0]);};											// create Z-projection
	else{																			// allow user to choose z-slices for every FOV	
		waitForUser("Check slices to find top & bottom of the cell, THEN press 'OK'");   // let user choose top & bottom
		start_slice = getNumber("Specify starting slice for z-projection", 1);		// Ask user for the number
		stop_slice  = getNumber("_Specify stop-slice for z-projection", 5);
		//start_and_stop = newArray(start_slice, stop_slice);						// collect to save later [for reproducibility] - not implemented
		run("Z Project...", "start=start_slice stop=stop_slice"+Z_STYLE[1]);};};	// Z-project
// *************************************************************************************************************************************************************
// getReady:
// Prepare image for user inspection.
function getReady(){ 
	run("Make Composite");															// Creat composite with all channels in one image for good visual inspection
	run("Brightness/Contrast...");													// Start contrast tool for user to adapt contrast to better view.
	run("Enhance Contrast", "saturated=0.35");										// Run enhance contrast tool for better view of cell
	setTool("brush");};                                  							// get brush-tool to select cell-area
// *************************************************************************************************************************************************************
// identifyCells:
// Returns set of ROIs with cell-outline, either from user-selection or automatically.
function identifyCells(CELL_OUTLINE){
	// Manually label each cell:
	if(CELL_OUTLINE){
		answer="More";																// pre-define variable for while-loop
		while(answer != "Done") {                           						// until all cells in this FOV are labelled
    		waitForUser("Select area of a cell & add to ROI-manager [t], THEN press 'OK'");
    		roiManager("Show None");
			roiManager("Show All with labels");
    		Dialog.create("Cell outlines");
    		Dialog.addMessage("Are there more cells you'd like to outline?"); 
  			items = newArray("Done", "More");          								// let user decide whether they want to label more cells
  			Dialog.addRadioButtonGroup("To do:",items,2,1,"More");
  			Dialog.show();
  			answer = Dialog.getRadioButton();};};
  	// Fully automated cell-segmentation:
	else{print("you opted for automated cell-outlining. good luck!")				// append fully automated cell-segmentation here
	};};
// *************************************************************************************************************************************************************
// saveSingleCells:
// Save new, cropped 2D-projected image-stack for each cell.
function saveSingleCells(current_fov){
	// Save a new image per cell:  	
	selectWindow(Z_STYLE[2]+current_fov);                            				// grad z-projection (Z_STYLE[2] holds suffix from z-projection)
	numRois = roiManager("count");                        							// get number of rois (aka cells)
	mkdir(Out_dir);                                 								// check if directory already exists - if not, make a new one.
	for(cell=0; cell<numRois; cell++) {
		roiManager("Select", cell);
		run("Duplicate...", "duplicate");
		//run("Clear Outside");
		saveAs("Tiff", Out_dir+current_fov+ "_cell"+cell+".tif");
		close();};};                     		          					 		// close the new image for this cell
// *************************************************************************************************************************************************************
// *************************************************************************************************************************************************************
// segmentNucleus:
// This function creates a binary image of the nuclear area.
function segmentNucleus(segNuc_Style){
		// automated - simple:
		if(segNuc_Style=="simple"){
			run("Gaussian Blur...", "sigma=2");										// to blurr noise (mainly cellular background)
			run("Auto Threshold", "method=Huang2 white");							// run autothreshold
			run("Convert to Mask");													// convert to binary mask to allow following commands
			run("Dilate");															// to smooth the edges, and to be conservative
			run("Fill Holes");};													// fill holes within nucleus		
		// automated - deepL:
		if(segNuc_Style=="deep-learning"){
			print("This is not implemented yet");};									// implement StarDist or DenoiSeg
		// manual:
		if(segNuc_Style=="manual"){
			// let user draw outline of nucleus first:
			run("Brightness/Contrast...");
			run("Enhance Contrast", "saturated=0.35");
			waitForUser("Select nucleus, THEN press 'OK'");
			run("Clear Outside");													// set everything outside the selection to 0
			// then segment as automated-simple:
			run("Auto Threshold", "method=Huang2 white");							// run autothreshold
			run("Convert to Mask");													// convert to binary mask to allow following commands
			run("Dilate");															// to smooth the edges, and to be conservative
			run("Fill Holes");};													// fill holes within nucleus		
		// external binary:
		if(segNuc_Style=="pre-segmented"){
			close(Nuc_Window);														// close raw image of nuclear channel
			print("fyi, the correct name for binary nuclei would be:");				// let user know, in case it does not work...
			print("nucBinary_"+to_analyse[i]);
			OpenImg(In_Binary_Nuclei, Binary_Nuclei[i]);};};						// open pre-segmented nucleus
// *************************************************************************************************************************************************************
// *************************************************************************************************************************************************************
// segmentMitochondria:
// This function will generate a binary image with segmented mitochondria 
function segmentMitochondria(segMito_Style){
	// automated - simple:
	if(segMito_Style=="simple"){
		roiManager("reset");
		roiManager("open", cell_Roi);
		roiManager("Select", 0);
		run("Clear Outside");
		resetMinAndMax();
		setOption("BlackBackground", true);
		run("Convert to Mask");
		run("Fill Holes");															// fill holes within mito
		// add watershed?};															// to delineate individual mitochondria
		};
	// automated - deepL?
	if(segMito_Style=="deep-learning"){
		waitForUser("This is not implemented yet");};								// potentially implement deep-learning or other methods here
	// manual:
	if(segMito_Style=="manual"){
		// let user draw outline of each mitochondrion by hand:
		waitForUser("please note: this is not recommended and is not tested");
		run("Brightness/Contrast...");
		run("Enhance Contrast", "saturated=0.35");
		answer="More";																// pre-define variable for while-loop
		while(answer != "Done") {                           						// until all cells in this FOV are labelled
			waitForUser("Select mitochondria, add to ROI-manager, THEN press 'OK'");
   			roiManager("Show None");
			roiManager("Show All with labels");
   			Dialog.create("mitochondria");
   			Dialog.addMessage("Are there more mitochondria you'd like to outline?"); 
			items = newArray("Done", "More");          								// let user decide whether they want to label more cells
			Dialog.addRadioButtonGroup("To do:",items,2,1,"More");
			Dialog.show();
			answer = Dialog.getRadioButton();};
		// turn ROIs to mask:														// could implement to iterate through list and choose each mito
		run("Create Mask");};														// will create mask from last generated ROI.
	// external binary
	if(segMito_Style=="pre-segmented"){
		//close(mito_Window);														// close raw image of nuclear channel
		print("fyi, the correct name for binary mito would be:");					// let user know, in case it does not work...
		print("mitoBinary_"+to_analyse[i]);
		OpenImg(In_Binary_Mito, Binary_Mito[i]);};};								// open pre-segmented nucleus
// *************************************************************************************************************************************************************
// *************************************************************************************************************************************************************
// findFoci:
// Converts foci-channel to binary, saves this, then turns binary into ROI and saves these, then outputs .csv file with descriptors
function findFoci(prom_start, prom_stop, foci_Window, foci_type){
	// make array of prominence values:
	increment 			= (prom_stop-prom_start)/5;									// sorry, could not find syntax. -> could implement function range(start, stop, intervall)
	prominences 		= newArray(prom_start, prom_start+increment, prom_start+2*increment, prom_start+3*increment, prom_start+4*increment, prom_stop);
	// find maxima:
	for (k = 0; k < lengthOf(prominences); k++) {									// for all prominences in the list
		prominence = prominences[k];												// get particular prominence
		name_foci_binary= FindMaxWithProminence(prominence,foci_Window,foci_type);	// creates binary image with foci and returns name of binary image with foci
	// save binary with all maxima:
		saveAs("Tiff", Out_dir+name_foci_binary);
	// filter maxima:
		if(with_nucleus[0]){
			print("we are processing:");
			print(name_foci_binary);
			imageCalculator("Subtract create", name_foci_binary, Nuc_Binary);		// subtracts nuclear area from foci-binary image
			// note: could add measurement of mtDNA-signal in nuclear area
			close(name_foci_binary);												// closes 'old', raw binary image
			selectWindow("Result of "+name_foci_binary);
			rename(name_foci_binary);};												// renames new, filtered image
		if(with_mito[0]){
			imageCalculator("AND create", name_foci_binary, Mito_Binary);			// AND gate for mitochondrial area
			close(name_foci_binary);												// closes 'old', binary image
			selectWindow("Result of "+name_foci_binary);
			rename(name_foci_binary);};												// renames new, filtered image			
	// turn filtered binary into ROIs and save:
		nROIs = fociToRoi(name_foci_binary, prominences[k]);
	// get descriptors:
	// here should add measurements such as integrated intensity or size etc. to describe foci
	
	
	// Save data to .csv file:
	File.append("../"+to_analyse[i]+","+cell_area+","+mito_fraction+","+prominence+","+nROIs+","+foci_type, Out_dir+"Results_"+DATE+".csv");
	// note: could also add focus location for downstream analysis of foci-density or distribution
	};};
// *************************************************************************************************************************************************************
// FindMaxWithProminence:
// Finds maxima with given prominence-level and produces binary image
	function FindMaxWithProminence(prominence, foci_Window, foci_type){
		selectWindow(foci_Window);													// choose channel of foci
		roiManager("reset");
		roiManager("open", cell_Roi);
		roiManager("Select", 0);													// select only content of the cell, exclude neighbouring cells etc.
		run("Find Maxima...", "prominence=prominence output=[Single Points]");		// find all foci -> creates binary
		run("Dilate");                                                  			// dilate the binary to allow for a bit of tolerance around the maximum
		out_name = foci_type+"fociBinary_";											// name according to foci_type (1st or 2nd)
		name_foci_binary = out_name+to_analyse[i]+"_"+prominence;					// make up new name for prominence-map
		rename(name_foci_binary);
		return name_foci_binary+".tif";};
// *************************************************************************************************************************************************************
// fociToRoi:
// Turns binary image into ROIs and saves a list of ROIs
function fociToRoi(filtered_foci_binary, prominence){
	// turn binary into ROIs
	roiManager("reset");															// clear ROI manager
	selectWindow(filtered_foci_binary);
	run("Analyze Particles...", "size=0 circularity=0.00 add");						// turn binary into ROIs
	roiManager("Show All without labels");											// display identified ROIs
	// Create & save output:
	nROIs = roiManager("count"); 													// count number of MRGs
	if(nROIs > 0){
	roiManager("Save", Out_dir+filtered_foci_binary+".zip");};						// save ROIs; else: do not save, as it raises an error to save an empty list
	return nROIs;};



// ####################################################################  naming conventions  ####################################################################
// Variables: begin with Capital Letters using Snake_Font (underscores)
// Parameters (fixed variables): all CAPITAL LETTERS using SNAKE_FONT
// functions: minor starting letter with fusedFontUsingCapitalLettersToDistinguishWords

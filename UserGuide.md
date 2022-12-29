# User Guide
This is a userguide with a step-by-step protocol on how to set up mtFociCounter as well as a short description of its features.

## 1) Step-by-step setup:
1) Download this repository from github  
2) Move or copy the .ijm script from your Download to the plugin folder of your Fiji  
  on Mac: go to "Applications" in Finder. then, right-click on Fiji and select "Show package contents"  
  Windows: go to Fiji.app folder.  
  [also see point 8. on https://syn.mrc-lmb.cam.ac.uk/acardona/fiji-tutorial/#s8]  
3) start Fiji and select "Foci Counter" from Fiji -> Plugins to start  
Alternatively:  
2) start Fiji and drag-and-drop the .ijm script (or simply open it with Fiji)  
3) press the "Run" button at the bottom-left of the scripting window to start  
  
---------------------------------------------------------------------------------------------------------------  
Each of the features below can and has to be used individually. We also recommend to apply a stage to all available images and only then pass to the next stage.  

## 2)  Current Features:
### a) Convert to Tiff
**INPUT:** directory/folder with images  
**OUTPUT:** new directory with .tif images  

Allows user to specify a file-ending depending on the microscope outpt. All such files within a given folder will then be opened and saved as .tif  
The user may have to click OK for each image to pass through opening, depending on the input format.

### b) Find Cells
**INPUT:** directory with 3D images in .tif format.  
**OUTPUT:** directory with z-projected images in .tif format containing a region of interest (ROI) selection  
Z-projects 3D image-stacks and then allows delineation of single cells in the images.  
Allows user to manually outline individual cells in large fields of view.  
Several cells can be chosen in each FOV: care-fully read and follow the instructions in the graphical user interfaces.   
NOTE: mode of Z-projection can be adapted (default is maximum intensity projection across all available slices).

### c) Find Foci
**INPUT:** directory with 2D images in .tif format containing an ROI (at least a Foci-channel is needed).  
other optional input possible - see below.  
**OUTPUT:** you will receive one .csv file with foci-count and other optional descriptors for each cell. you can open this with excel, libre office or other programs.
In addition, for every cell you will receive 6 binary images with your foci and 6 .zip files, which you can drag & drop onto Fiji to overlay as ROIs on your input-image.

In this part, foci are identified using "find max" with a range of prominences.
These foci can then be filtered using a nuclear mask to exclude the nuclear area (e.g. for anti-mtDNA stainings),  
and with a mitochondrial mask to ensure that only foci inside mitochondria are counted.  
The nuclear and mitochondrial masks can be created in different ways, albeit only 2 methods are currently implemented:  
*simple*: this will segment signal from noise using Fijis simple built-in algorithms <- currently recommend for mitochondria  
*manual*: this allows users to manually draw the segmentation <- currently recommended for nuclei  
Alternatively, *pre-segmented* masks can be loaded as well, which allows the use of external software to create better segmentations.  

### d) Co-localise Foci
This feature is not implemented yet. sorry.  
It will allow to analyse two types of foci (e.g. anti-mtDNA + EdU-Click) at the same time and determine their respective number and co-localisation.
If it would be useful for you to have this, do not hesitate to let me know - it should be fast to implement, simply has not made it to the top of my ToDo's yet..

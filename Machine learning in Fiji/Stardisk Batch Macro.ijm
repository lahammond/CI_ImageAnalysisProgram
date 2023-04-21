// StarDist Macro
// For 2021 Image Analysis Program

// Author: 	Luke Hammond
// Cellular Imaging | Zuckerman Institute, Columbia University
// Date:	November 10, 2021

// Preprocesses tif files and then runs Ilastik. Ilastik output is merged with original data.
// Ilastik output is expected to be a 16bit tif, 8 bit will be converted to 16

// Initialization
requires("1.53c");
run("Options...", "iterations=3 count=1 black edm=Overwrite");
run("Colors...", "foreground=white background=black selection=yellow");
run("Clear Results"); 
run("Close All");
close("Log");

#@ File(label="Raw data:", value = "C:/", style="directory") inputdir
#@ Integer(label="Channel to be enhanced:", value = 2, style="spinner") ChEnhance



// Process folder
if (File.exists(inputdir)) {
    if (File.isDirectory(inputdir) == 0) {
       	print(inputdir + "Is a file, please select only directories containing images to be processed.");
    } else {
		
		// Process Folder:
		
		starttime = getTime();
		input = inputdir + "/";
		
		print("Processing folder: " + inputdir + " ");
		files = getFileList(input);	
		files = ImageFilesOnlyArray(files);		

		// Create folders:
	
		File.mkdir(input + "StarDist_Output");
		StarDistOut = input + "StarDist_Output/";

		for(i=0; i<files.length; i++) {				
			print("Processing image " + (i+1) +" of " + files.length +"...");
			run("Bio-Formats Importer", "open=[" + input + files[i] + "] autoscale color_mode=Default view=Hyperstack stack_order=XYCZT series_1");

			//rename
			rawfilename =  clean_title(files[i]);
			rename("Raw");

			//split and extract channel
			getDimensions(width, height, ChNum, slices, frames);	
				
			if (ChNum > 1) {
				run("Split Channels");
				selectWindow("C"+ChEnhance+"-Raw");
				rename("Raw");
				close("\\Others");
			}
	
			// Process / Segment in StarDist
			run("Command From Macro", "command=[de.csbdresden.stardist.StarDist2D], args=['input':'Raw', 'modelChoice':'Versatile (fluorescent nuclei)', 'normalizeInput':'true', 'percentileBottom':'1.0', 'percentileTop':'99.8', 'probThresh':'0.479071', 'nmsThresh':'0.3', 'outputType':'Both', 'nTiles':'1', 'excludeBoundary':'2', 'roiPosition':'Automatic', 'verbose':'false', 'showCsbdeepProgress':'false', 'showProbAndDist':'false'], process=[false]");
			selectWindow("Label Image");

			// Could include further processing here - e.g. threshold 1, analyze particles with size parameters. then save updated objects and any measurements you care about
			
			save(StarDistOut + rawfilename+"SD.tif");
			close("*");
			}
   	print("");
    print("Processing complete.");
    }

}

function Ilastik_Processing(IlastikDir, IlastikProject, IlastikInput, IlastikOutput) {
		print("Performing Ilastik pixel classification...");		
		//Prepare text inputs for batch
		q ="\"";
		//inputI = replace(input, "\\", "/");
		IlastikDir1 = replace(IlastikDir+"/ilastik.exe", "\\", "/");
		IlastikDir1 = q + IlastikDir1 + q;	
		
		IlastikProject1 = replace(IlastikProject, "\\", "/");
		IlastikProject1 = q + IlastikProject1 + q;
	
		IlastikOutDir = IlastikOutput;
		IlastikOutDir = replace(IlastikOutDir, "\\", "/");
		IlastikOutDir = q + IlastikOutDir + "{nickname}_Probabilities.tif" + q;

		IlastikInput = IlastikInput;
		IlastikInput = q + IlastikInput + q;
			
		ilcommand = IlastikDir1 +" --headless --project="+IlastikProject1+" --output_filename_format=" + IlastikOutDir + " " + IlastikInput;
		
		// Create Batch and run
		run("Text Window...", "name=Batch");
		//print("[Batch]", "@echo off" + "\n");
		print("[Batch]", ilcommand);
		run("Text...", "save=["+input +"Ilastikrun.bat]");
		selectWindow("Ilastikrun.bat");
		run("Close"); 
		runilastik = input + "Ilastikrun.bat";
		runilastik = replace(runilastik, "\\", "/");
		runilastik = q + runilastik + q;
		exec(runilastik);

		//Cleanup
		DeleteFile(input+"Ilastikrun.bat");
		print("");

}

function ImageFilesOnlyArray (arr) {
	//pass array from getFileList through this e.g. NEWARRAY = ImageFilesOnlyArray(NEWARRAY);
	setOption("ExpandableArrays", true);
	f=0;
	files = newArray;
	for (i = 0; i < arr.length; i++) {
		if(endsWith(arr[i], ".tif") || endsWith(arr[i], ".nd2") || endsWith(arr[i], ".LSM") || endsWith(arr[i], ".czi") || endsWith(arr[i], ".jpg") ) {   //if it's a tiff image add it to the new array
			files[f] = arr[i];
			f = f+1;
		}
	}
	arr = files;
	arr = Array.sort(arr);
	return arr;
}

function clean_title(imagename){
	nl=lengthOf(imagename);
	nl2=nl-3;
	Sub_Title=substring(imagename,0,nl2);
	Sub_Title = replace(Sub_Title, "(", "_");
	Sub_Title = replace(Sub_Title, ")", "_");
	Sub_Title = replace(Sub_Title, "-", "_");
	Sub_Title = replace(Sub_Title, "+", "_");
	Sub_Title = replace(Sub_Title, " ", "_");
	Sub_Title = replace(Sub_Title, ".", "_");
	Sub_Title=Sub_Title;
	return Sub_Title;
}

function DeleteFile(Filelocation){
	if (File.exists(Filelocation)) {
		a=File.delete(Filelocation);
	}
}


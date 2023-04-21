// Preprocessing and Ilastik Pixel Classification Macro
// For 2021 Image Analysis Program

// Author: 	Luke Hammond
// Cellular Imaging | Zuckerman Institute, Columbia University
// Date:	22 June 2021

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
#@ Integer(label="Background Subtraction (rolling ball radius in px, 0 if none):", value = 5, style="spinner") BGSub
//#@ Integer(label="Unsharp Mask Radius:", value = 5, style="spinner") USRad
//#@ BigDecimal(label="Unsharp Mask Weight:", value = 0.7, style="spinner") USW
#@ File(label="Ilastik project location:", value = "C:/", style="file") IlastikProject
#@String  (visibility="MESSAGE", value="------------------------------------------------------------------") line
#@ File(label="Ilastik location:", value = "C:/Program Files/ilastik-1.3.3post3", style="directory") IlastikDir


setBatchMode(true);


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
	
		File.mkdir(input + "Enhanced");
		EnhanceOut = input + "Enhanced/";
		File.mkdir(input + "Ilastik_Output");
		IlastikOut = input + "Ilastik_Output/";
		//File.mkdir(input + "Merged");
		//MergeOut = input + "Merged/";

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
	
			// BG Subtract
			if(BGSub > 0) {
				run("Subtract Background...", "rolling="+BGSub);
			}
			// Unsharp
			//if(USRad > 0) {
			//	run("Unsharp Mask...", "radius="+USRad+" mask="+USW);
			//}

			// save enhanced image
			//outname = rawfilename+"BG_"+BGSub+"_USMask_"+USRad+".tif";
			outname = rawfilename+"BG_"+BGSub+".tif";
			save(EnhanceOut + outname);
			close("*");

			// Process / Segment in Ilastik

			Ilastik_Processing(IlastikDir, IlastikProject, EnhanceOut + outname, IlastikOut);
			//Ilastik_Processing(IlastikDir, IlastikProject, IlastikInput, IlastikOutput)

		
			/*
			//Open and merge
			//inserts a single probability image into multichannel raw data
			
			//open and copy ilastik results
			//open(IlastikOut+rawfilename+"BG_"+BGSub+"_USMask_"+USRad+"_Probabilities.tif");
			run("Bio-Formats Importer", "open=[" +IlastikOut+rawfilename+"BG_"+BGSub+"_Probabilities.tif] autoscale color_mode=Default view=Hyperstack stack_order=XYCZT series_1");

			run("16-bit");
			
			run("Select All");
			run("Copy");
			open(input+files[i]);
			run("Add Slice", "add=channel");
			setSlice(2);
			run("Paste");
			//save(MergeOut + rawfilename+"BG_"+BGSub+"_USMask_"+USRad+"_Probabilities_Overlay.tif");
			save(MergeOut + rawfilename+"BG_"+BGSub+"_Probabilities_Overlay.tif");
			*/
			
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


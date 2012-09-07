import jp.nyatla.nyar4psg.*;

import ddf.minim.*;
import ddf.minim.effects.*;
import nl.tudelft.ti1100a.audio.*;

import processing.opengl.*;

// CAMERA SUPPORT
// * if you have a Sony PS3 Eye on Windows, use CL-Eye, i.e. CAMERA_MODE = 1
// don't forget to set cleye_path correctly below
// * if you have any other camera on any other system, use GSVideo, i.e. CAMERA_MODE = 0
// * if you have a Mac, use the built-in cam support, i.e. CAMERA_MODE = 2
//
// because processing doesn't support conditional imports, you have to have both the gsvideo and
// cl-eye libraries installed. if you have a version of the ti1100a-2011-sketchbook.zip
// later than 2011-09-06, you're fine!

// CAPTURE_MODE = 0 for GSVIDEO
// CAPTURE_MODE = 1 for CL-EYE
// CAPTURE_MODE = 2 for built-in processing camera support, for example on Mac.
int CAPTURE_MODE = 1;

// we want to use CLEye for PS3 Eye support on Windows --------------
import cl.eye.*;
// ----------- VERY IMPORTANT -------------
// make sure cleye_path contains te right path to the cleyemulticam library on your computer
String cleye_path = "h:\\sketchbook\\libraries\\cleyemulticam\\library\\CLEyeMulticam.dll";
CLCamera cl_cam;
PImage cam_image;
int cam_width = 640;
int cam_height = 480;
int cam_rate = 15;
int duration;
int beats;
float sampleRate;

// end of CLEye (also see lots of code below) --------------------------

// Camera shit
import codeanticode.gsvideo.*;
GSCapture gsvideo_cam;

import processing.video.*;
Capture gen_video;

//end of camera shit

// Detectie bord
NyARMultiBoard nya;

//lettertypes
PFont font, font2d;

// Sound controller
Minim minim = new Minim(this);

// Clicktrack houd de beat synchronisatie bij
ClickTrack clicktrack = new ClickTrack(minim, 110, 4);

// De loopmixer
LoopMixer mixer = new LoopMixer(minim, clicktrack);
// Een lijst met loops
LoopMixer.Loop[] loops = new LoopMixer.Loop[9];

// De filter voor de loops
LowPassSP[] bpf = new LowPassSP[9];

// De kolom waarin een marker zich bevind
int[] CFpos = new int[9];

// Volume per kolom in procenten, voor de CrossFader
float k0 = 100, k1 = 100, k2 = 100;


int heightY;

void setup() {
	// Scherm grootte en 3d initializatie
	size(640, 480, P3D);
	colorMode(HSB);

	// lettertype initializatie
	font=createFont("FFScala", 32);
	font2d = createFont("FFScala", 10);

	// Camera initializatie
	if (CAPTURE_MODE == 0) 
	{
		gsvideo_cam=new GSCapture(this, width, height);
		gsvideo_cam.play();
	}
	else if (CAPTURE_MODE == 1) 
	{
		CLCamera.loadLibrary(cleye_path);
		cl_cam = new CLCamera(this);
		cl_cam.createCamera(0, CLCamera.CLEYE_COLOR_PROCESSED, CLCamera.CLEYE_VGA, cam_rate);
		cl_cam.setCameraParam(CLCamera.CLEYE_AUTO_GAIN, 1);
		cl_cam.setCameraParam(CLCamera.CLEYE_AUTO_EXPOSURE, 1);
		cl_cam.setCameraParam(CLCamera.CLEYE_AUTO_WHITEBALANCE, 1);

		cl_cam.startCamera();
		cam_image = createImage(cam_width, cam_height, RGB);
	}
	else 
	{
		gen_video = new Capture(this, width, height, 12);
	}

	// de filenames van de patt bestanden
	String[] patts = {
		"patt.kanji", "patt.hiro", "patt.1", "patt.2", "patt.3", "patt.4", "patt.5", "patt.CF", "patt.BPM"
	};

	// de breedte van de markers gelinkt aan patts
	double[] widths = {
		40, 40, 40, 40, 40, 40, 40, 40, 40
	};

	// Initializatie van de detectie software
	nya=new NyARMultiBoard(this, width, height, "camera_para.dat", patts, widths);
	print(nya.VERSION);

	nya.gsThreshold=120;
	nya.cfThreshold=0.4;

	// Loops een liedje geven
	loops[1] = mixer.new Loop("1.wav", 2);
	loops[2] = mixer.new Loop("2.wav", 4);
	loops[3] = mixer.new Loop("3.wav", 4);
	loops[4] = mixer.new Loop("4.wav", 4);
	loops[5] = mixer.new Loop("5.wav", 4);
	loops[6] = mixer.new Loop("6.wav", 6);

	// starten van de clicktrack 
	clicktrack.start();
	clicktrack.mute();

	// beatlistener
	clicktrack.addRhythmListener(new RhythmListenerAdapter() {
		public void beat() 
		{
			heightY = 30;
		}
	});
	
	
	// De lowpassfilter aan de loops binden
	for (int i=0;i<loops.length;i++) 
	{
		if (loops[i]!=null) 
		{
			bpf[i] = new LowPassSP(440, loops[i].sampleRate());
			loops[i].addEffect(bpf[i]);
		}
	}
}

// Teken de hoekpunten van de marker
void drawMarkerPos(int[][] pos2d)
{
	for (int i=0;i<4;i++) 
	{
		ellipse(pos2d[i][0], pos2d[i][1], 5, 5);
	}
}

//Wordt iedere frame aangeroepen
void draw() 
{
	// need to put camera image on screen, so temporarily disable depth testing
	hint(DISABLE_DEPTH_TEST);

	// Camera beeld naar scherm schrijven
	if (CAPTURE_MODE == 0) 
	{
		// GSVideo support here --------------------------------
		// we only do something when the camera input is available
		if (gsvideo_cam.available() !=true) 
		{
			return;
		}
		// get an image from the camera
		gsvideo_cam.read();

		// put webcam image on screen
		image(gsvideo_cam, 0, 0);

		// perform the marker detection
		// this method returns true if one or more markers were found
		nya.detect(gsvideo_cam);

		// end of GSVideo -------------------------------------
	}
	else if (CAPTURE_MODE == 1) 
	{
		// CLEye way --------------------------------------------
		cam_image.loadPixels();
		cl_cam.getCameraFrame(cam_image.pixels, 1000);
		cam_image.updatePixels();

		// blit the camera image on the screen
		image(cam_image, 0, 0);

		// nyartoolkit detection
		nya.detect(cam_image);
		// CLEye end ---------------------------------------------
	}
	else 
	{
		// generic capture support. works out of the box on the Mac.

		if (gen_video.available() != true) 
		{
			return;
		}

		gen_video.read();

		// put webcam image on screen
		image(gen_video, 0, 0);

		// perform the marker detection
		// this method returns true if one or more markers were found
		nya.detect(gen_video);
	}


	//hint(ENABLE_DEPTH_TEST);


	// going to be doing 2D drawing (drawMarkerPos) so temporarily disable depth testing
	//hint(DISABLE_DEPTH_TEST);

	// for all detected markers, draw corner points
	// also switch sound on and off
	// Werk alleen als de kanji-marker word gedetecteerd
	if (nya.markers[0].detected) {
		for (int i=0; i < nya.markers.length; i++)
		{
			if (nya.markers[i].detected)
			{
				drawMarkerPos(nya.markers[i].pos2d);

				if (loops[i]!=null) loops[i].start();
			}
			else
			{
				if (loops[i]!=null) loops[i].stop();
			}
		}
	}
	else
	{
		for (int i=0; i < nya.markers.length; i++) {
			if (loops[i]!=null) loops[i].stop();
		}
	}

	// depth test back on, we're going to draw 3D YEAH!!
	hint(ENABLE_DEPTH_TEST);
	// Zet de lampen aan
	lights();
	// Neem heightY af
	if (heightY > 10) heightY -= 2;

	// Als de kanji-marker(de hoekmarker) is gedetecteerd
	if (nya.markers[0].detected) 
	{
		for (int i=0; i <nya.markers.length; i++)
		{
			if (nya.markers[i].detected)
			{
				// Zet 0,0,0 naar het midden van de gedetecteerde marker
				nya.markers[i].beginTransform();

				translate(0, 0, 20);

				if (i==1)
				{
					// Teken 5 dozen op elkaar met heightY
					noStroke();
					fill((heightY-10)*18, 360, 360);
					translate(0, 0, -20-heightY+5);
					for (int j=0; j<5;j++) {
						translate(0, 0, heightY+5);
						box(40, 40, -heightY);
					}
				}
				else if (i==0)
				{
					// Teken het grid in 3d
					translate(0, 0, -20);
					int gridsize = 400;
					int gridsizex = 180;
					stroke((frameCount*4)%360, 360, 360);
					for (int j =0; j<1; j++) {
						for (int k=0; k<3; k++) {
							line(k*gridsizex, j*gridsize, 0, k*gridsizex, (j+1)*gridsize, 0);
							line(k*gridsizex, j*gridsize, 0, (k+1)*gridsizex, j*gridsize, 0);
							line((k+1)*gridsizex, j*gridsize, 0, (k+1)*gridsizex, (j+1)*gridsize, 0);
							line((k+1)*gridsizex, (j+1)*gridsize, 0, k*gridsizex, (j+1)*gridsize, 0);
						}
					}
				}
				else if (i==2)
				{
					rotateY(HALF_PI/2);
					fill((frameCount*6)%360,360,360);
					box(40,40,heightY+20);
				}
				nya.markers[i].endTransform();
			}

			if (i!=0&&nya.markers[i].detected) 
			{
				// zet de 0,0,0 naar de kanji marker
				nya.markers[0].beginTransform();
				// bereken de relatieve positie tussen marker 0 en marker i
				PMatrix3D mat = transformation_matrix(nya.markers[0], nya.markers[i]);
				PVector zi = new PVector(0.0, 0.0, 0.0);
				PVector zi0 = new PVector();
				mat.mult(zi, zi0);
				// in zi0 zit de positie van marker i
				translate(zi0.x, 0, 0);
				noStroke();
				//Teken de indicatie sphere voor de crossfade
				sphere(20);
				translate(-zi0.x, 0.0);

				// bereken de hoek van de marker i
				PVector ziz = new PVector(0.0, 1.0, 0.0);
				PVector ziz0 = new PVector();

				mat.mult(ziz, ziz0);

				PVector ziu = PVector.sub(zi0, ziz0);

				float graaie = atan(ziu.x/(ziu.y + pow(10, -6))); // hoek in radialen
				textFont(font, 20.0);
				rotateX(radians(-180));
				
				// Store the vertical column
				for (int j=0; j<3; j++) 
				{
					if (zi0.x>j*180&&zi0.x<(j+1)*180) 
					{
						CFpos[i] = j;
						break;
					} 
					else 
					{
						CFpos[i] = -1;
					}
				}
				
				// schrijf de tekst bij de marker
				text("Rotation: " + int(degrees(-graaie)), zi0.x, -zi0.y+20, -zi0.z);
				if (loops[i]!=null) 
				{
					text("Volume: " + loops[i].getVolume(), zi0.x, -zi0.y, -zi0.z);
				}
				text("Marker: " + i, zi0.x, -zi0.y+40, -zi0.z);
				text("Column: " + CFpos[i] + ", " + zi0.x, zi0.x, -zi0.y+60, -zi0.z);

				
				// De crossfader code
				if (i==7) 
				{
					// het volume in procenter per kolom
					k0 = 100;
					k1 = 100;
					k2 = 100;
					if (CFpos[i]>-1) 
					{
						if (CFpos[i]==0) 
						{ // eerste kolom, 3e kolom uit
							k2 = 0;
							k1 = zi0.x / 180 *100; // zi0 is tussen 0 en 180
							k0 = 100;
						} 
						else if (CFpos[i] == 1) 
						{ // tweede kolom, 1e en 3e kolom faden
							k2 = (zi0.x - 180) /180 * 100; //zi0.x is tussen 180 en 360
							k1 = 100;
							k0 = (-zi0.x + 360) / 180 *100;
						} 
						else if (CFpos[i] == 2) 
						{ // laatste kolom
							k2 = 100;
							k1 = (-zi0.x + 540) /180 *100;
							k0 = 0;
						}
						// println ("k0: " + k0);
						// println ("k1: " + k1);
						// println ("k2: " + k2);
					}
				}
				if (i==8) // de bpm marker
				{
					// pas het tempo aan
					clicktrack.setBpm(zi0.y);
				}

				if (loops[i]!=null) 
				{
					if (CFpos[i]==-1) // de marker bevindt zich links van de kanji marker
					{
						loops[i].setVolume(0);
					} 
					else if (CFpos[i]==0) 
					{
						loops[i].setVolume(pow(zi0.y*0.005, 2)*(k0/100));
					} 
					else if (CFpos[i]==1) 
					{
						loops[i].setVolume(pow(zi0.y*0.005, 2)*(k1/100));
					} 
					else if (CFpos[i]==2) 
					{
						loops[i].setVolume(pow(zi0.y*0.005, 2)*(k2/100));
					}
					
					if (degrees(-graaie)>10) 
					{
						bpf[i].setFreq((180f-(degrees(-graaie)+91f))/180f*800f);
					}
				}
				rotateX(radians(180));
				nya.markers[0].endTransform();
			}
		}
	}
}

// calculate transformation matrix that can be used to transform
// from subspace of source_marker to subspace of destination marker (often the board origin)
PMatrix3D transformation_matrix(NyARMultiBoardMarker source_marker, NyARMultiBoardMarker dest_marker)
{
	// dest_vector = inverse(dest_marker_matrix) * source_marker_matrix * source_vector
	// so we need transformation_matrix = inverse(dest_marker_matrix) * source_marker_matrix

	// get copy of source_marker_matrix
	PMatrix3D pms = new PMatrix3D(source_marker.transmatP3D);

	// get copy of dest_marker_matrix
	PMatrix3D pmd = new PMatrix3D(dest_marker.transmatP3D);

	// concatenate them
	PMatrix3D trfm_mat = new PMatrix3D(); // identity matrix

	// Matrix inversie
	pms.invert();

	// Matrix vermenigvuldiging
	trfm_mat.preApply(pmd);
	trfm_mat.preApply(pms);

	return trfm_mat;
}

void keyPressed() 
{
	switch (key) {
		case ' ':
			if(clicktrack.isPlaying()) {
				clicktrack.pause();
			}
			else
			{
				clicktrack.start();
			}
			break;
	}
}
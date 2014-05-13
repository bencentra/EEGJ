/******************************
*******************************
*	Imports and Dependencies  *
*	- TheMidiBus 			  *
*	- serial 				  *
*	- Arduino (Firmata) 	  *
*	- Ani 					  *
*	- java.util.Map 		  *
*******************************
*******************************/

import themidibus.*;
import processing.serial.*;
import org.firmata.*;
import cc.arduino.*;
import de.looksgood.ani.*;
import java.util.Map;

/*******************
********************
*	Instance Vars  *
********************
********************/

// Sketch props
int WIDTH = 3072;			// Width of the sketch
int HEIGHT = 768;			// Height of the sketch
int WIDGET_HEIGHT = 40;		// Size of the widgets
boolean playing;			// Is the game running?
boolean DEBUG = false;		// Debug mode
int FRAME_RATE = 60;		// Frame rate of the sketch

// Colors
color neutralColor = color(255,220,46);		// Yellow
color relaxColor = color(16,255,160);		// Green
color veryRelaxColor = color(13,255,234);	// Blue
color focusColor = color(240,133,46);		// Orange
color veryFocusColor = color(155,34,184);	// Pink
color otherColor = color(133,0,192);		// Purple

// MidiBus and instruments
String MIDI_PORT = "Virtual MIDI Bus";							// Name of system's virtual MIDI bus
MidiBus mb;														// MidiBus instance
int channel1, channel2, channel3, channel4, channel5, channel6; // MIDI channel numbers
RiriSequence kick, perc1, perc2, bass, synth1, synth2;			// RiriSequences for each instrument

// Data and levels
int HISTORY_LENGTH = 8;			// Number of previous data points to keep
int BASE_LEVEL_STEP = 4;		// Base step for changing the overall brain level (focusRelaxLevel)
int MAX_FOCUS = 100;			// Max "focus" value
int MAX_RELAX = -100;			// Max "relax" value
int MAX_BPM = 100;				// Max tempo (in beats per minute)
int MIN_BPM = 50;				// Min tempo (in beats per minute)
int pulse, bpm, grain;			// Pulse reading, global bpm, global "grain" (music activity level)
int focusRelaxLevel, level;		// Brain level reading, global brain level
IntList levelHist; //pulseHist, // Lists for pulse history, brain level history

// Timekeeping
int BEATS_PER_MEASURE = 4;					// Number of beats in each measure (default: 4)
int MEASURES_PER_PHASE = 8;					// Number of measures per song section (default: 8)
int PHASES_PER_SONG = 4;					// Number of sections in the song (default: 4)
int DELAY_THRESHOLD = 100;					// Maximum allowed delay (in milliseconds)
int beat, measure, phase, mils, lastMils; 	// Current beat, measure, phase, and time (in milliseconds)
int delay, delayA, delayB;					// Current accumulated delay and delay trackers

// Music & scales
int SCORE_EASING_STEPS = 5;				// Number of frames to ease score effect over
int score_easing = SCORE_EASING_STEPS;	// Easing step counter
int score_effect_val = 0;				// Current value for the score effect
int PITCH_C = 60;						// MIDI pitch of the middle "C" note
int PITCH_F = 65;						// MIDI pitch of the middle "F" note
int PITCH_G = 67;						// MIDI pitch of the middle "G" note
int[] SCALE = {0, 3, 5, 7, 8};			// Minor pentatonic scale pattern (in intervals)
float[] BEATS = {1, .5, .25, .125};		// Beat values (as fractions of a beat)
int pitch;								// Current base pitch

// Filters
int highPassFilterVal, lowPassFilterVal;	// Values for the high and low pass filters (controlled by Records)

// MindFlex (Serial)
String MINDFLEX_PORT = "COM3";	// Name of the serial port the MindFlex Arduino is connected to
int START_PACKET = 3;			// What packet of brain data to start using for the game
int LEVEL_STEP = 10;			// Amount to increase focusRelaxLevel by each read
Serial mindFlex;				// Serial object for the MindFlex
PrintWriter output;				// Writer for outputting brain data
int packetCount;				// Counter for current brain data packet
int globalMax;					// Maximum brain wave value, used for rounding

// DataGen - Tom
HashMap<String,Integer> inputSettings;	// Map of input settings for the Data Generator
DataGenerator dummyDataGenerator;		// Data Generator instance
boolean useDummyData;					// Switch for using the data generator

// Brain Level Graphs - Ben
RiriGraph relaxGraph, focusGraph;	// Brain Level Graph UI components
PImage relaxGraphBG, focusGraphBG;	// Background images for Graphs

// Speakers - Brennan
RiriSpeaker relaxSpeaker1, relaxSpeaker2, focusSpeaker1, focusSpeaker2; // Speaker UI components
PImage relaxSpeakerBG, focusSpeakerBG;									// Background images for Speakers

// Records - Mia
String RECORD_ARDUINO_PORT = "COM5";								// Name of the serial port the pressure sensor Arduino is connected to
int RELAX_RECORD_PIN = 2;											// Data pin number for the "relax" Record
int FOCUS_RECORD_PIN = 0;											// Data pin number for the "focus" Record
Arduino recordArduino;												// Arduino object for the pressure sensor Arduino
boolean recordArduinoOn;											// Switch for using the record Arduino
RiriRecord relaxRecord, focusRecord;								// Effect Record UI components
float relaxRecordData, focusRecordData;								// Data values for Records
color relaxRecordColor, focusRecordColor, recordBackgroundColor;	// Colors for the Records active and background colors

// Widgets - Brennan
String WIDGET_DIR = "widgets/";										// Widgets image/shape directory
int KNOB_SIZE = 120;												// Size of the knob widgets
int KNOB_Y = 630;													// Starting Y position of the widgets
PShape knob_blue, knob_green, knob_orange, knob_pink;				// Shapes for the knobs (loaded from SVGs)
PShape knobtrack_white, knobtrack_dark;								// Shapes for the knobtracks (loaded from SVGs)
PShape brain, dot_green, dot_dark, jellybean_dark, jellybean_pink;	// Shapes for the brain status (loaded from SVGs)
PImage knob_yellow_image;											// Image for the yellow "grain" knob (loaded from image)
SVGWidget relaxKnob1, relaxKnob2, relaxKnob3, relaxKnob4; 			// Widget objects for the relax knobs
SVGWidget focusKnob1, focusKnob2, focusKnob3, focusKnob4;			// Widget objects for the focus knobs
SVGWidget brainGood, brainBad, brainWidget;							// Widget objects for the brain status 
ImageWidget grainKnob;												// Widget object for the grain knob

// Stage - Tom and Whitney
ScrollingStage myStage;	// Main game stage instance

// Panels - Antwan
PImage focusOverlay, relaxOverlay, focusShadow, relaxShadow, widgetOverlay; // Images for the overlays and panels

/*******************
********************
*	Sketch Setup   *
********************
********************/

/*
*	init()
*	- Initialize the sketch
*/
void init() {
	// If we're not in debug mode, go fullscreen
	if (DEBUG != true) {
	  	frame.removeNotify();
	 	frame.setUndecorated(true);
	  	frame.addNotify();
	}
	super.init(); 
}

/*
*	setup()
*	- Initialize all data and objects used in the sketch
*/
void setup() {
	// Sketch setup
	size(WIDTH, HEIGHT);
	background(0);
	frameRate(FRAME_RATE);
	smooth();
	Ani.init(this);
	playing = false;
	// MidiBus setup
	MidiBus.list();
	mb = new MidiBus(this, -1, MIDI_PORT);
	mb.sendTimestamps();
	channel1 = 0;
	channel2 = 1;
	channel3 = 2;
	channel4 = 3;
	channel5 = 4;
	channel6 = 5;
	// Data setup
	pulse = 80;
	bpm = pulse;
	//pulseHist = new IntList();
	focusRelaxLevel = 0;
	level = 0;
	levelHist = new IntList();
	grain = 0;
	// Time setup
	delay = 0;
	mils = millis();
	lastMils = mils;
	beat = 0; 
	measure = 0;
	phase = 1;
	// Filter setup
	highPassFilterVal = 0;
	lowPassFilterVal = 127;
	// DataGen setup
	inputSettings = new HashMap<String,Integer>();
	useDummyData = false;
	// MindFlex setup
	// If the Serial connection fails, default to dummy data
	packetCount = 0;
	globalMax = 0;
	println("Serial:");
	for (int i = 0; i < Serial.list().length; i++) {
	    println("[" + i + "] " + Serial.list()[i]);
	}
	try {
		mindFlex = new Serial(this, MINDFLEX_PORT, 9600);
		mindFlex.bufferUntil(10);
		String date = day() + "_" + month() + "_" + year();
  		String time = "" + hour() + minute() + second();
		output = createWriter("brain_data/brain_data_out_"+date+"_"+time+".txt");
	}
	catch (Exception e) {
		println("MindFlex Serial Exception: " + e.getMessage());
		useDummyData = true;
	}
	// Stage
	myStage = new ScrollingStage(WIDTH/2, KNOB_Y/2, WIDTH/3, HEIGHT);
	// Graph setup
  	relaxGraphBG = loadImage("graphs/relax_gradient2.png");
  	focusGraphBG = loadImage("graphs/focus_gradient2.png");
  	relaxGraph = new RiriGraph(4*(WIDTH/6) + 30, 20, WIDTH/6, 2*HEIGHT/3 + 20, relaxGraphBG, 0);
  	focusGraph = new RiriGraph(WIDTH/6 - 30, 20, WIDTH/6, 2*HEIGHT/3 + 20, focusGraphBG, 1);
  	// Speaker setup
  	relaxSpeakerBG = loadImage("speakers/relax_radial.png");
  	focusSpeakerBG = loadImage("speakers/focus_radial.png");
  	relaxSpeaker1 = new RiriSpeaker(WIDTH - 250 - 120, HEIGHT/4 - 125, 200, 200, relaxSpeakerBG);
  	relaxSpeaker2 = new RiriSpeaker(WIDTH - 350 - 70, 3*(HEIGHT/4) - 175, 300, 300, relaxSpeakerBG);
  	focusSpeaker1 = new RiriSpeaker(155, HEIGHT/4 - 125, 200, 200, focusSpeakerBG);
  	focusSpeaker2 = new RiriSpeaker(110, 3*(HEIGHT/4) - 175, 300, 300, focusSpeakerBG);
  	// Record setup
  	// If the Arduino connection fails, default to dummy data
  	relaxRecordData = 0;
  	focusRecordData = 0;
	try{
		recordArduinoOn = true;
	    //recordArduino = new Arduino(this, Arduino.list()[RECORD_ARDUINO_PORT], 57600); 
	    recordArduino = new Arduino(this, RECORD_ARDUINO_PORT, 57600); 
	}
	catch(Exception e){
		println("Sensor Arduino Exception: "+e.getMessage());
	    recordArduinoOn = false;
	    //useDummyData = true;
	}
	focusRecord = new RiriRecord(focusRecordData, recordArduinoOn, 32, HEIGHT/5 + 15, 5*(WIDTH/18) + 15, 5*(HEIGHT/6) + 20, false);
	relaxRecord = new RiriRecord(relaxRecordData, recordArduinoOn, 32, HEIGHT/5 + 15, 13*(WIDTH/18) - 15, 5*(HEIGHT/6) + 20, true);
	// Initialize DataGen
	inputSettings.put("brainwave", 1000);
	inputSettings.put("pressure", 200);
    dummyDataGenerator = new DataGenerator(inputSettings);
    // Widgets
	knobtrack_white = loadShape(WIDGET_DIR+"knobtrack_white.svg");
	knobtrack_dark = loadShape(WIDGET_DIR+"knobtrack_dark.svg");
	knob_yellow_image = loadImage(WIDGET_DIR+"knob_yellow2.png");
	knob_blue = loadShape(WIDGET_DIR+"knob_blue.svg");
	knob_green = loadShape(WIDGET_DIR+"knob_green.svg");
	knob_orange = loadShape(WIDGET_DIR+"knob_orange.svg");
	knob_pink = loadShape(WIDGET_DIR+"knob_pink.svg");
	brain = loadShape(WIDGET_DIR+"brain.svg");
	dot_green = loadShape(WIDGET_DIR+"dot_green.svg");
	dot_dark = loadShape(WIDGET_DIR+"dot_dark.svg");
	jellybean_pink = loadShape(WIDGET_DIR+"jellybean_pink.svg");
	jellybean_dark = loadShape(WIDGET_DIR+"jellybean_dark.svg");
	relaxKnob1 = new SVGWidget(16*(WIDTH/30) + 10, KNOB_Y, KNOB_SIZE, KNOB_SIZE, knob_green);
	relaxKnob2 = new SVGWidget(17*(WIDTH/30) + 10, KNOB_Y, KNOB_SIZE, KNOB_SIZE, knob_green);
	relaxKnob3 = new SVGWidget(18*(WIDTH/30) + 10, KNOB_Y, KNOB_SIZE, KNOB_SIZE, knob_blue);
	relaxKnob4 = new SVGWidget(19*(WIDTH/30) + 10, KNOB_Y, KNOB_SIZE, KNOB_SIZE, knob_blue);
	focusKnob1 = new SVGWidget(10*(WIDTH/30) - 10, KNOB_Y, KNOB_SIZE, KNOB_SIZE, knob_pink);
	focusKnob2 = new SVGWidget(11*(WIDTH/30) - 10, KNOB_Y, KNOB_SIZE, KNOB_SIZE, knob_pink);
	focusKnob3 = new SVGWidget(12*(WIDTH/30) - 10, KNOB_Y, KNOB_SIZE, KNOB_SIZE, knob_orange);
	focusKnob4 = new SVGWidget(13*(WIDTH/30) - 10, KNOB_Y, KNOB_SIZE, KNOB_SIZE, knob_orange);
	grainKnob = new ImageWidget(14*(WIDTH/30) + 5, KNOB_Y + 20, KNOB_SIZE - 30, KNOB_SIZE - 30, knob_yellow_image);
	relaxKnob1.rotation(-90);
	relaxKnob2.rotation(-90);
	relaxKnob3.rotation(-90);
	relaxKnob4.rotation(-90);
	focusKnob1.rotation(-90);
	focusKnob2.rotation(-90);
	focusKnob3.rotation(-90);
	focusKnob4.rotation(-90);
	grainKnob.rotation(-90);
	brainWidget = new SVGWidget(15*(WIDTH/30) + 15, KNOB_Y, KNOB_SIZE, KNOB_SIZE, brain);
	brainGood = new SVGWidget(15*(WIDTH/30) - KNOB_SIZE/2 + 20, KNOB_Y - KNOB_SIZE/5, KNOB_SIZE, KNOB_SIZE, dot_green);
	brainBad = new SVGWidget(15*(WIDTH/30) - KNOB_SIZE/2 + 20, KNOB_Y + KNOB_SIZE/8, KNOB_SIZE, KNOB_SIZE, jellybean_dark);
	// Overlays
	focusOverlay = loadImage("overlays/focusoverlay.png");
	relaxOverlay = loadImage("overlays/relaxoverlay.png");
	focusShadow = loadImage("overlays/focusspeaker_shade.png");
	relaxShadow = loadImage("overlays/relaxspeaker_shade.png");
	widgetOverlay = loadImage("overlays/widgetoverlay.png");
}

/*
*	draw()
*	- Update values for UI components
*	- Draw the UI components
*	- Play the music
*/

void draw() {
	// If the sketch just started and debug is off, launch from the top-left corner of the screen
	if (frameCount == 1 && DEBUG != true) {
	    frame.setLocation(0,0); 
	}
	// Start tracking the delay caused by drawing
	delayA = millis();
  	// Draw the stage
  	background(0);
  	myStage.update();
  	myStage.draw();
  	// Update UI components after the stage has loaded
  	if (myStage.doneLoading) {
  		// Graphs
	  	relaxGraph.draw();
	  	focusGraph.draw();
	  	// Overlays
	  	image(focusOverlay, 0, 0);
	  	image(relaxOverlay, 2*(WIDTH/3), 0);
	  	image(widgetOverlay, WIDTH/3, 0);
	  	// Records
	  	// Get data from the pressure sensors or, if disconnected, the data generator
		if (recordArduinoOn) {
		    relaxRecordData = recordArduino.analogRead(RELAX_RECORD_PIN);
		    focusRecordData = recordArduino.analogRead(FOCUS_RECORD_PIN); 
		}
		else {
		    relaxRecordData = (Float.parseFloat(dummyDataGenerator.getInput("pressure")));
		    focusRecordData = (Float.parseFloat(dummyDataGenerator.getInput("pressure"))); 
		}
		relaxRecord.dataValue = relaxRecordData;
	 	focusRecord.dataValue = focusRecordData;
		relaxRecord.draw();
		focusRecord.draw();
		// Draw an indicator if the pressure sensor Arduino is disconnected
		if (!recordArduinoOn) {
			noStroke();
			fill(otherColor);
		    ellipse(relaxRecord.xPos + relaxRecord.recordWidth/2 + 20, relaxRecord.yPos + relaxRecord.recordHeight/2, 20, 20);
		    ellipse(focusRecord.xPos - focusRecord.recordWidth/2 - 20, focusRecord.yPos + focusRecord.recordHeight/2, 20, 20);
		}
	  	// Speakers
	  	relaxSpeaker1.draw();
	  	relaxSpeaker2.draw();
	  	focusSpeaker1.draw();
	  	focusSpeaker2.draw();
	  	// Shadow
	  	noFill();
	  	noStroke();
	  	image(focusShadow, 0, 0);
	  	image(relaxShadow, 2*(WIDTH/3), 0);
	  	// Timemarkers
	  	// Fills in a new circle for each measure of the song
	  	// (Expects default of 8 measures per phase, 4 phases per song)
	  	for (int i = 0; i < MEASURES_PER_PHASE * PHASES_PER_SONG; i++) {
	  		int timeX = WIDTH/3 + 155 + i*23;
	  		int timeY = 600;
	  		int diameter = (i % MEASURES_PER_PHASE == 7) ? 15 : 10;
	  		if (i < measure + (MEASURES_PER_PHASE * (phase - 1))) {
	  			fill(255);
	  		}
	  		else {
	  			fill(155);
	  		}
	  		ellipse(timeX, timeY, diameter, diameter);
	  	}
		// Widgets
		for (int i = 0; i < 4; i++) {
			shape(knobtrack_dark, (16+i)*(WIDTH/30) + 10, KNOB_Y, KNOB_SIZE, KNOB_SIZE);
		}
		relaxKnob1.draw();
		relaxKnob2.draw();
		relaxKnob3.draw();
		relaxKnob4.draw();
		for (int i = 0; i < 4; i++) {
			shape(knobtrack_dark, (10+i)*(WIDTH/30) - 10, KNOB_Y, KNOB_SIZE, KNOB_SIZE);
		}
		focusKnob1.draw();
		focusKnob2.draw();
		focusKnob3.draw();
		focusKnob4.draw();
		shape(knobtrack_white, 14*(WIDTH/30) - 20, KNOB_Y - 5, KNOB_SIZE + 20, KNOB_SIZE + 20);
		grainKnob.draw();
		brainWidget.draw();
		// Toggle the brain status from "good" to "bad" if the MindFlex Arduino is disconnected
		if (useDummyData) {
			brainGood.setShape(dot_dark);
			brainBad.setShape(jellybean_pink);
		}
		else {
			brainGood.setShape(dot_green);
			brainBad.setShape(jellybean_dark);
		}
		brainGood.draw();
		brainBad.draw();
  	}
  	// Finish tracking the draw delay
	delayB = millis();
	// Music
	// Play the song if the game has started
	if (playing) {
		// Play music
		playMusic(delayB - delayA);
		// Filters
		// Only use if the pressure sensors are connected
		if (recordArduinoOn) {
			highPassFilterVal = (int) map(relaxRecordData, 0, 1023, 0, 127);
			lowPassFilterVal = (int) map(focusRecordData, 0, 1023, 127, 0); 
		}
		RiriMessage highPassFilterMsg = new RiriMessage(176, 0, 102, highPassFilterVal);
    	highPassFilterMsg.send();
    	RiriMessage lowPassFilterMsg = new RiriMessage(176, 0, 103, lowPassFilterVal);
    	lowPassFilterMsg.send();
    	// Score effect
    	// If a point was score, ease the effect in. Afterward, slowly fade back to normal
    	if (score_easing < SCORE_EASING_STEPS) {
    		score_effect_val += (120 / SCORE_EASING_STEPS);
    		score_easing++;
    	}
    	else {
    		score_effect_val -= 2;
    		if (score_effect_val < 0) {
    			score_effect_val = 0;
    		}
    	}
    	RiriMessage effectMsg = new RiriMessage(176, 0, 106, score_effect_val);
    	effectMsg.send();
	}
	// Debug log
	if (DEBUG) {
		textAlign(LEFT);
		textSize(10);
		noStroke();
		fill(0, 0, 0, 125);
		rect(0, 0, WIDTH/6, HEIGHT/5);
		fill(255);
		text("focusRelaxLevel: " + focusRelaxLevel, 0, 20);
		text("level: " + level, 0, 40);
		text("grain: " + grain, 0, 60);
		text("pulse: " + pulse, 0, 80);
		text("bpm: " + bpm, 0, 100);
		text("useDummyData: " + useDummyData, 0, 120);
		text("recordArduinoOn: " + recordArduinoOn, 0, 140);
		text("beat: " + beat, 200, 20);
		text("measure: " + measure, 200, 40);
		text("phase: " + phase, 200, 60);
		text("highPass: "+highPassFilterVal, 200, 100);
		text("lowPass: "+lowPassFilterVal, 200, 120);
		noFill();
		stroke(255, 0, 0);
		strokeWeight(3);
		rect(0, 0, WIDTH/3, HEIGHT);
		rect(WIDTH/3, 0, WIDTH/3, HEIGHT);
		rect(2*(WIDTH/3), 0, WIDTH/3, HEIGHT);
		noStroke();
	}
}

/********************
*********************
*	Music Playing   *
*********************
********************/

/*
*	startEEGJ()
*	- Start the game and the song
*/

void startEEGJ() {
	// Only start if the stage is done loading
	if (myStage.doneLoading) {
		// Toggle the playing boolean
		playing = true;
		// Reset the score and brain level
		focusRelaxLevel = 0;
		myStage.score = 0;
		// Start recording in Ableton
		//RiriMessage msg = new RiriMessage(176, 0, 104, 127);
	    //msg.send();
	    // Prepare the music and start playing
		setupMusic();
		startMusic();
	}
}

/*
*	stopEEGJ()
*	- Stop playing the music
*	- Reset the game state
*	- Reset the widgets for the next song
*/

void stopEEGJ() {
	// Only stop if the stage is done loading
	if (myStage.doneLoading) {
		// Reset the game state
		myStage.setActiveHitzone(0);
		myStage.activeNote = 0;
		// Reset the widget positions
		relaxKnob1.rotation(-90);
		relaxKnob2.rotation(-90);
		relaxKnob3.rotation(-90);
		relaxKnob4.rotation(-90);
		focusKnob1.rotation(-90);
		focusKnob2.rotation(-90);
		focusKnob3.rotation(-90);
		focusKnob4.rotation(-90);
		grainKnob.rotation(-90);
		// Stop the music
		stopMusic();
		// Reset the filters
		//RiriMessage msg = new RiriMessage(176, 0, 105, 127); 
		//msg.send();
		//msg = new RiriMessage(176, 0, 104, 0); 
	    //msg.send();
	    // Stop recording
	    RiriMessage msg2 = new RiriMessage(176, 0, 106, 0);
		msg2.send();
		// Toggle the playing boolean
		playing = false;
	}
}

/*
*	setupMusic()
*	- Reset song state (beats, measures, phase)
*	- Create the first measure for all the instrument RiriSequences
*/

void setupMusic() {
	// Reset song position
	beat = 0;
	measure = 0;
	phase = 1;
	pitch = PITCH_C;
	// Setup the instruments
	createInstruments();
	createKickMeasure();
	createRestMeasure(perc1);
	createRestMeasure(perc2);
	createRestMeasure(bass);
	createRestMeasure(synth1);
	createRestMeasure(synth2);
}

/*
*	startMusic()
*	- Start playing all instrument RiriSequences
*/

void startMusic() {
	// Start all the music tracks
	kick.start();
	perc1.start();
	perc2.start();
	bass.start();
	synth1.start();
	synth2.start();
}

/*
*	playMusic()
*	- Progress the song if a beat (in nanoseconds) has passed
*	- Prepare the next measure of music when necessary
*	- Update the brain level history
*/

void playMusic(int drawDelay) {
	// Get current time
	mils = millis();
	// Beat Change
	// Occurs if the current time is greater than the time of the last beat plus the length of a beat
	// Accounts for delay introduced by draw and previous calls to playMusic
	if (mils >= lastMils + beatsToNanos(1)/1000 - delay - drawDelay) {
		// Start tracking the delay introduces in playMusic
		int milsA = mils;
		// Update values and histories
		updateLevelHistory();
		//updateBpmHistory();
		// Update graphs and speakers
		relaxGraph.setMarkerX((int) map(level, 100, -100, 0, relaxGraph.graphWidth));
		relaxSpeaker1.setSpeakerSize((int) map(level, 100, -100, 0, relaxSpeaker1.graphWidth/1.1));	
		relaxSpeaker2.setSpeakerSize((int) map(level, 100, -100, 0, relaxSpeaker2.graphWidth/1.1));
		focusGraph.setMarkerX((int) map(level, -100, 100, 0, focusGraph.graphWidth));
		focusSpeaker1.setSpeakerSize((int) map(level, -100, 100, 0, focusSpeaker1.graphWidth/1.1));
		focusSpeaker2.setSpeakerSize((int) map(level, -100, 100, 0, focusSpeaker2.graphWidth/1.1));
		// Update the Active Hit Zone on the stage
		// Active Hit Zone depends on the current brain level
		if (level >= 50) {
			myStage.setActiveHitzone(1);
		}
		else if (level < 50 && level >= 20) {
			myStage.setActiveHitzone(2);
		}
		else if (level < 20 && level >= -20) {
			myStage.setActiveHitzone(3);
		}
		else if (level < -20 && level > -50) {
			myStage.setActiveHitzone(4);
		}
		else {
			myStage.setActiveHitzone(5);
		}
		// Spawn a new note on the stage if there is none
		if (myStage.activeNote == 0) {
			int notePos = 0;
			// Determine where to spawn the note based on the current active hit zone
			if (myStage.activeHitzone == 5) {
				notePos = myStage.activeHitzone + round(random(-1, 0));
			}
			else if (myStage.activeHitzone == 1) {
				notePos = myStage.activeHitzone + round(random(0, 1));
			}
			else {
				notePos = myStage.activeHitzone + round(random(-1, 1));
			}
			myStage.spawnNote(notePos);
		}
		// Move the current note down the stage
		else {
			myStage.incrementNote(1);
		}
		// Measure change
		if (beat == BEATS_PER_MEASURE) {
			beat = 1;
			// Phase change
			if (measure == MEASURES_PER_PHASE) {
				measure = 1;
				if (phase == PHASES_PER_SONG) {
					// We're done!
					phase++;
					stopEEGJ();
				}
				else {
					phase++;
					// Reset the brain level if we're maxed out/too high
					if (abs(focusRelaxLevel) >= 60)
						focusRelaxLevel = 0;
				}
			}
			else if (measure == MEASURES_PER_PHASE - 1) {
				// Prepare for the next phase
				setPhaseKey();
				measure++;
			}
			else {
				measure++;
			}
		}
		else if (beat == BEATS_PER_MEASURE - 1) {
			// Prepare the next measure
			setMeasureLevelAndGrain();
			setMeasureBPM();
			// Reset instruments to keep everything in sync
			if (measure == MEASURES_PER_PHASE) {
				resetInstruments();
			}
			createMeasure();
			// Generate some dummy data if we don't have the MindFlex
			if (useDummyData) {
				String input = dummyDataGenerator.getInput("brainwave");
				calculateFocusRelaxLevel(input);
			}
			beat++;
		}
		else {
			beat++;
		}
		// Update the time of the last beat
		lastMils = millis();
		// Calculate the delay
		int milsB = millis();
		//println("\tB: "+milsB);
		delay += milsB - milsA;
		//delay = milsB - milsA;
		//println("DELAY: "+delay);
		// Reset the delay if it's too great
		if (delay > DELAY_THRESHOLD) delay = 10;
	}
}

/*
*	stopMusic()
*	- Stop all the instrument RiriSequences
*/

void stopMusic() {
	// Stop all instruments
	kick.quit();
	perc1.quit();
	perc2.quit();
	bass.quit();
	synth1.quit();
	synth2.quit();
}

/******************
*******************
*	Instruments   *
*******************
*******************/

/*
*	createInstruments()
*	- Initialize the RiriSequence objects for each instrument on a different channel
*/

void createInstruments() {
	kick = new RiriSequence(channel1);
	perc1 = new RiriSequence(channel2);
	perc2 = new RiriSequence(channel3);
	bass = new RiriSequence(channel4);
	synth1 = new RiriSequence(channel5);
	synth2 = new RiriSequence(channel6);
}

/*
*	resetInstruments()
*	- Recreate the instrument RiriSequence objects 
*/

void resetInstruments() {
	// Stop the music
	stopMusic();
	// Create the instrument RiriSequence objects
	createInstruments();
	// Add a beat of rest for each instrument
	kick.addRest(beatsToNanos(1));
	perc1.addRest(beatsToNanos(1));
	perc2.addRest(beatsToNanos(1));
	bass.addRest(beatsToNanos(1));
	synth1.addRest(beatsToNanos(1));
	synth2.addRest(beatsToNanos(1));
	// Start the music again
	startMusic();
}

/*
*	createMeasure()
*	- Call each instrument's create function
*/

void createMeasure() {
	createKickMeasure();
	createPerc1Measure();
	createPerc2Measure();
	createBassMeasure();
	createSynth1Measure();
	createSynth2Measure();
}

/*
*	createRestMeasure()
*	- Add a measure of rest to the given instrument RiriSequence
*/

void createRestMeasure(RiriSequence seq) {
	seq.addRest(beatsToNanos(BEATS_PER_MEASURE));
}

/*
*	createKickMeasure()
*	- Create a measure for the bass drum instrument
*/

void createKickMeasure() { 
	// Play a repeated riff
	kick.addNote(36, 120, beatsToNanos(.5));
	kick.addNote(36, 120, beatsToNanos(.5));
	kick.addRest(beatsToNanos(.5));
	kick.addNote(36, 120, beatsToNanos(.5));
	kick.addRest(beatsToNanos(.5));
	kick.addNote(36, 120, beatsToNanos(.5));
	kick.addNote(36, 120, beatsToNanos(.25));
	kick.addNote(36, 120, beatsToNanos(.75));
}

/*
*	createPerc1Measure
*	- Create a measure for the clap and hi-hat cymbal
*/

void createPerc1Measure() { 
	// Shortcuts to important MIDI pitches
	int close = 42;
	int open = 46;
	int clap = 39;
	// Only play if focus is active
	if (level >= 0) {
		// Grain 1 = clap every other beat
		if (grain == 1) {
			perc1.addRest(beatsToNanos(1));
			perc1.addNote(clap, 120, beatsToNanos(1));
			perc1.addRest(beatsToNanos(1));
			perc1.addNote(clap, 120, beatsToNanos(1));
		}
		// Grain 2 = two claps
		else if (grain == 2) {
			perc1.addRest(beatsToNanos(1));
			perc1.addNote(clap, 120, beatsToNanos(.75));
			perc1.addNote(clap, 120, beatsToNanos(.25));
			perc1.addRest(beatsToNanos(1));
			perc1.addNote(clap, 120, beatsToNanos(.75));
			perc1.addNote(clap, 120, beatsToNanos(.25));
		}
		// Grain 3 = claps and hi-hat
		else if (grain == 3) {
			perc1.addNote(close, 120, beatsToNanos(.25));
			perc1.addNote(close, 80, beatsToNanos(.25));
			perc1.addNote(close, 80, beatsToNanos(.25));
			perc1.addNote(close, 80, beatsToNanos(.25));
			perc1.addNote(clap, 120, beatsToNanos(.25));
			perc1.addNote(close, 80, beatsToNanos(.25));
			perc1.addNote(close, 80, beatsToNanos(.25));
			perc1.addNote(clap, 120, beatsToNanos(.25));
			perc1.addNote(close, 120, beatsToNanos(.25));
			perc1.addNote(close, 80, beatsToNanos(.25));
			perc1.addNote(close, 80, beatsToNanos(.25));
			perc1.addNote(close, 80, beatsToNanos(.25));
			perc1.addNote(clap, 120, beatsToNanos(.25));
			perc1.addNote(close, 80, beatsToNanos(.25));
			perc1.addNote(close, 80, beatsToNanos(.25));
			perc1.addNote(clap, 120, beatsToNanos(.25));
		}
		// Grain 0 = rest
		else {
			createRestMeasure(perc1);
		}
	}
	else {
		createRestMeasure(perc1);
	}
}

/*
*	createPerc2Measure()
*	- Create a measure for the woodblock
*/

void createPerc2Measure() { 
	// Always play every other beat
	perc2.addRest(beatsToNanos(1));
	perc2.addNote(40, 120, beatsToNanos(1));
	perc2.addRest(beatsToNanos(1));
	perc2.addNote(40, 120, beatsToNanos(1));
}

/*
*	createBassMeasure()
*	- Create a measure for the bass synth
*/

void createBassMeasure() {
	// Determine the adjusted grain and velocity based on brain level
	int g = (level >= 0) ? grain : 0;
	int velocity = (level >= 0) ? 80 + 10*grain : 80 - 10*grain;
	// Play randomized half-notes if the grain is low
	if (g == 0 || g == 1) {
		// Random notes for now
		for (int i = 0; i < 2; i++) {
			int p1 = pitch + SCALE[(int) random(0, SCALE.length)] - 24;
			bass.addNote(p1, 80, beatsToNanos(2));
		}
	}
	// If the grain is high, play a motif (random notes followed by root pitch)
	else {
		// Random notes for now
		for (int i = 0; i < 2; i++) {
			int p1 = pitch + SCALE[(int) random(0, SCALE.length)] - 24;
			bass.addNote(p1, 80, beatsToNanos(.75));
		}
		// Also the root pitch
		bass.addNote(pitch + SCALE[0] - 24, 80, beatsToNanos(2.5));
	}
}

/*
*	createSynth1Measure()
*	- Create a measure for the arpeggiator/lead synth
*/

void createSynth1Measure() { 
	// Play if relax is active
	if (level <= 0) {
		// Grain 0 = random quarter notes
		if (grain == 0) {
			float interval = BEATS[grain];
			for (int i = 0; i < BEATS_PER_MEASURE - 1; i++) {
				int p1 = pitch + SCALE[(int) random(0, SCALE.length)];
				synth1.addNote(p1, 80, beatsToNanos(interval));
			}
			synth1.addNote(pitch, 80, beatsToNanos(interval));
		}  
		// Grain 1 = I and V arpeggiation
		else if (grain == 1) {
			float interval = BEATS[grain];
			int[] notes = {SCALE[0], SCALE[3], SCALE[0]+12, SCALE[3]};
			for (int i = 0; i < BEATS_PER_MEASURE/interval; i++) {
				int num = i%notes.length;
				synth1.addNote(pitch + notes[num], 80, beatsToNanos(interval));
			}
		}
		// Grain 2 = I, iii, and V arpeggiation
		else  if (grain == 2) {
			float interval = BEATS[1];
			int[] notes = {SCALE[0], SCALE[1], SCALE[3], SCALE[1], SCALE[3], SCALE[0]+12, SCALE[1]+12, SCALE[0]+12};
			for (int i = 0; i < BEATS_PER_MEASURE/interval; i++) {
				int num = i%notes.length;
				synth1.addNote(pitch + notes[num], 80, beatsToNanos(interval));
			}
		}
		// Grain 3 = I, iii, and V arpeggiation, faster
		else {
			float interval = BEATS[2];
			int[] notes = {SCALE[0], SCALE[1], SCALE[3], SCALE[1], SCALE[3], SCALE[0]+12, SCALE[1]+12, SCALE[0]+12};
			for (int i = 0; i < BEATS_PER_MEASURE/interval; i++) {
				int num = i%notes.length;
				synth1.addNote(pitch + notes[num], 80, beatsToNanos(interval));
			}
		}
	}
	else {
		createRestMeasure(synth1);
	}
}

/*
*	createSynth2Measure()
*	- Create a measure for the pad/harmony synth
*/

void createSynth2Measure() { 
	// Determine the interval based on the grain
	float interval = (level <= 0) ? BEATS[grain] : BEATS[0];
	int velocity = (level <= 0) ? 80 + 10*grain : 80 - 20*grain;
	// Play a number of chords based on the interval
	for (int i = 0; i < (BEATS_PER_MEASURE/interval) / BEATS_PER_MEASURE; i++) {
		int p1 = pitch - 12;
		int p2 = pitch + SCALE[(int) random(1, SCALE.length)] - 12;
		RiriChord c1 = new RiriChord(channel6);
		c1.addNote(p1, velocity, beatsToNanos(interval*BEATS_PER_MEASURE));
		c1.addNote(p2, velocity, beatsToNanos(interval*BEATS_PER_MEASURE));
		synth2.addChord(c1);
	}
}

/*********************
**********************
*	Keyboard Input   *
**********************
*********************/

/*
*	keyPressed()
*	- Handle keyboard input
*/

void keyPressed() {
	// Play/stop
	if (key == ' ') {
		if (!playing) startEEGJ();
		else stopEEGJ();
	}
	// Focus/relax
	if (keyCode == LEFT) {
		addRelax();
	}
	if (keyCode == RIGHT) {
		addFocus();
	}
	// Pulse
	if (keyCode == UP) {
		pulse += 3;
	}
	if (keyCode == DOWN) {
		pulse -= 3;
	}
	// Filters
	if (key == 'q') {
		highPassFilterVal += 5;
		if (highPassFilterVal > 127) highPassFilterVal = 127;
	}
	if (key == 'a') {
		highPassFilterVal -= 5;
		if (highPassFilterVal < 0) highPassFilterVal = 0;
	}
	if (key == 'w') {
		lowPassFilterVal += 5;
		if (lowPassFilterVal > 127) lowPassFilterVal = 127;
	}
	if (key == 's') {
		lowPassFilterVal -= 5;
		if (lowPassFilterVal < 0) lowPassFilterVal = 0;
	}
	// MIDI control setup for Ableton
	if (key == 'z') { //  High Pass
		RiriMessage msg = new RiriMessage(176, 0, 102, 0);
    	msg.send();
	}
	if (key == 'x') { // Low Pass
		RiriMessage msg = new RiriMessage(176, 0, 103, 127);
    	msg.send();
	}
	if (key == 'c') { // Record
		RiriMessage msg = new RiriMessage(176, 0, 104, 0);
    	msg.send();
	}
	if (key == 'v') { // Stop
		RiriMessage msg = new RiriMessage(176, 0, 105, 0); 
    	msg.send();
	}
	if (key == 'b') { // Score Effect
		RiriMessage msg = new RiriMessage(176, 0, 106, 0);
		msg.send();
	}
	// DEBUG
	if (key == '0') {
		println("1/4: "+beatsToNanos(1));
		println("1/8: "+beatsToNanos(.5));
		println("1/16: "+beatsToNanos(.25));
		println("1/32: "+beatsToNanos(.125));
	}
}

/****************
*****************
*	Utilities   *
*****************
****************/

/*
*	Convert a given number of beats to nanoseconds
*/

int beatsToNanos(float BEATS){
  // (one second split into single BEATS) * # needed
  float convertedNumber = (60000000 / bpm) * BEATS;
  return round(convertedNumber);
}

/*
*	Adjust the brain level on keyboard input
*/

void addFocus() {
	focusRelaxLevel += (BASE_LEVEL_STEP - grain);
	if (focusRelaxLevel > MAX_FOCUS) focusRelaxLevel = MAX_FOCUS;
}

void addRelax() {
	focusRelaxLevel -= (BASE_LEVEL_STEP - grain);
	if (focusRelaxLevel < MAX_RELAX) focusRelaxLevel = MAX_RELAX;
}

/*
*	Update the histories for brain level and BPM
*/

void updateLevelHistory() {
	if (levelHist.size() == 4) {
		levelHist.remove(0);
	}
	levelHist.append(focusRelaxLevel);
}

/*
void updateBpmHistory() {
	if (pulseHist.size() == 4) {
		pulseHist.remove(0);
	}
	pulseHist.append(pulse);
}
*/

/*
*	Set the value of the bpm and level for the current measure
*/

void setMeasureBPM() {
	// Slow down if relaxed
	if (level < -20) {
		bpm = (int) map(level, -20, -100, 80, 65);
	}
	// Speed up if focused
	else if (level > 20) {
		bpm = (int) map(level, 20, 100, 80, 95);
	}
	// Default to 80 BPM
	else {
		bpm = 80;
	}
}

void setMeasureLevelAndGrain() {
	// Get the average focusRelaxLevel
	float val = 0;
	for (int i = 0; i < levelHist.size(); i++) {
		val += levelHist.get(i);
	}
	val = val/levelHist.size();
	// Set level
	level = (int) val;
	// Set grain
	val = abs(val);
	if (val < 20) {
		grain = 0;
	}
	else if (val >= 20 && val < 40) {
		grain = 1;
	}
	else if (val >= 40 && val < 60) {
		grain = 2;
	}
	else if (val >= 60) {
		grain = 3;
	}
	else {
		grain = 0; // Iunno
	}
	// Rotate the grain knob widget
	grainKnob.rotation((int) map(grain, 0, 3, -90, 90));
}

/*
*	Determine the key for the current phase of the song
*/

void setPhaseKey() {
	int p = phase + 1;
	if (p == PHASES_PER_SONG - 2) {
		pitch = PITCH_F;
	}
	else if (p == PHASES_PER_SONG - 1) {
		pitch = PITCH_G;
	}
	else {
		pitch = PITCH_C;
	}
}

/*
*	MindFlex serial event
*/

void serialEvent(Serial p) {
	// Read in the data
	String input;
	try {
		input = p.readString().trim();
		//print("Received string over serial: ");
		//println(input);
		output.println(input);
	}
	catch (Exception e) {
		input = dummyDataGenerator.getInput("brainwave");
		useDummyData = true;
	}
	calculateFocusRelaxLevel(input);
}

/*
*	Calculate the focusRelaxLevel based on MindFlex/dummy data input
*/

void calculateFocusRelaxLevel(String input) {
	// Parse the data
	boolean goodRead = false;
	if (input.indexOf("ERROR:") != -1 || input.length() == 0) {
		//println("bad");
		goodRead = false;
	}
	else {
		//println("good");
		goodRead = true;
	}
	// Only interpret the data if the read was good
	if (goodRead) {
		// Convert the input string into an array of integers
		String[] brainData = input.split(",");
		int[] intData = new int[brainData.length];
		// Only convert a properly formatted input packet
		if (brainData.length > 8) {
			packetCount++;
			// Only convert if we've already gotten a few good data packets
			if (packetCount > START_PACKET) {
				for (int i = 0; i < brainData.length; i++) {
					// Convert the data
					String strVal = brainData[i].trim();
					int intVal = Integer.parseInt(strVal);
					// Zero the data if the signal sucks
					if ((Integer.parseInt(brainData[0]) == 200) && (i > 2)) {
			          	intVal = 0;
			        }
			        // Add the data to the array
			        intData[i] = intVal;
				}
			}
		}

		// Format the data
		int connection = intData[0];
		println("CONNECTION: "+connection);
		int min = -1; 
		int max = -1;
		// Calculate the local (this packet) and global (sketch lifetime) maximum brainwave value
		for (int i = 3; i < intData.length; i++) {
			if (max < 0 || intData[i] > max) {
				max = intData[i];
				if (max > globalMax) {
					globalMax = max;
				}
			}
			if (min < 0 || intData[i] < min) {
				min = intData[i];
			}
		}
		//println("MIN " + min + " MAX " + max);

		// Rotate the knobs if the game is running
		if (playing) {
			/*relaxKnob1.rotation((int) map(intData[3], min, max, -90, 90));
			relaxKnob2.rotation((int) map(intData[4], min, max, -90, 90));
			relaxKnob3.rotation((int) map(intData[5], min, max, -90, 90));
			relaxKnob4.rotation((int) map(intData[6], min, max, -90, 90));
			focusKnob4.rotation((int) map(intData[7], min, max, -90, 90));
			focusKnob3.rotation((int) map(intData[8], min, max, -90, 90));
			focusKnob2.rotation((int) map(intData[9], min, max, -90, 90));
			focusKnob1.rotation((int) map(intData[10], min, max, -90, 90));*/
			relaxKnob1.rotation((int) map(intData[3], 0, globalMax, -90, 90));
			relaxKnob2.rotation((int) map(intData[4], 0, globalMax, -90, 90));
			relaxKnob3.rotation((int) map(intData[5], 0, globalMax, -90, 90));
			relaxKnob4.rotation((int) map(intData[6], 0, globalMax, -90, 90));
			focusKnob4.rotation((int) map(intData[7], 0, globalMax, -90, 90));
			focusKnob3.rotation((int) map(intData[8], 0, globalMax, -90, 90));
			focusKnob2.rotation((int) map(intData[9], 0, globalMax, -90, 90));
			focusKnob1.rotation((int) map(intData[10], 0, globalMax, -90, 90));
		}

		// Interpret the data
		int[] tmp = new int[intData.length - 3];
		// Map the brainwave values based on the globalMax high value
		for (int i = 3; i < intData.length; i++) {
			//tmp[i-3] = (int) map(intData[i], min, max, 0, 100);
			tmp[i-3] = (int) map(intData[i], 0, globalMax, 0, 100);
		}
		// Get an average of the "focus" and "relax" brainwaves
		int focusVal = 0;
		int relaxVal = 0;
		float newLevel = 0;
		// Split the brain data in two halves, relax and focus
		for (int i = 1; i < tmp.length; i++) {
			if (i < tmp.length/2) {
				relaxVal += tmp[i];
			}
			else {
				focusVal += tmp[i];
			}
		}
		focusVal = (int) (focusVal / 4);
		relaxVal = (int) (relaxVal / 4);


		// Set the brain level
		newLevel = focusVal - relaxVal;
		// METHOD 1: Set focusRelaxLevel to the difference of focus and relax
		// focusRelaxLevel = (int) newLevel;
		// METHOD 2: Adjust focusRelaxLevel based on a fraction of the difference of focus and relax
		//focusRelaxLevel += (int) (newLevel / 4);
		//focusRelaxLevel += (int) newLevel;
		// METHOD 3: Adjust focusRelaxLevel based on "direction" of mental activity
		// and adjust by the current grain
		if (newLevel >= 0) {
			focusRelaxLevel += (focusRelaxLevel >= 0) ? (LEVEL_STEP - grain*2) : LEVEL_STEP;
		}
		else if (newLevel <= -1) {
			focusRelaxLevel -= (focusRelaxLevel < 0) ? (LEVEL_STEP - grain*2) : LEVEL_STEP;
		}
		if (focusRelaxLevel > MAX_FOCUS) {
			focusRelaxLevel = MAX_FOCUS;
		}
		else if (focusRelaxLevel < MAX_RELAX) {
			focusRelaxLevel = MAX_RELAX;
		}
		//newLevel = map(focusVal - relaxVal, 0, 100, -100, 100);
		//println("NEW LEVEL: "+newLevel);
		println("FOCUS: "+focusVal+", RELAX: "+relaxVal+", NEW LEVEL: "+newLevel);
	}
	else {
		// Do something
	}
}
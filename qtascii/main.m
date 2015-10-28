/*
	File:		qtplyr.c
	
	Description: ASCII art QuickTime Movie Player
	
	Author:		QuickTime Engineering
 
	Copyright: 	© Copyright 2002 Apple Computer, Inc. All rights reserved.
	
	Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
 ("Apple") in consideration of your agreement to the following terms, and your
 use, installation, modification or redistribution of this Apple software
 constitutes acceptance of these terms.  If you do not agree with these terms,
 please do not use, install, modify or redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and subject
 to these terms, Apple grants you a personal, non-exclusive license, under Apple’s
 copyrights in this original Apple software (the "Apple Software"), to use,
 reproduce, modify and redistribute the Apple Software, with or without
 modifications, in source and/or binary forms; provided that if you redistribute
 the Apple Software in its entirety and without modifications, you must retain
 this notice and the following text and disclaimers in all such redistributions of
 the Apple Software.  Neither the name, trademarks, service marks or logos of
 Apple Computer, Inc. may be used to endorse or promote products derived from the
 Apple Software without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or implied,
 are granted by Apple herein, including but not limited to any patent rights that
 may be infringed by your derivative works or by other works in which the Apple
 Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
 WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
 WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
 COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
 OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT
 (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
	Change History (most recent first):
 <1>	 	05/21/02	td		first file
 */

/* 	Top X Tips for better ASCII QuickTime Movie Viewing
	10) Grow your terminal to fit the Movie
	9) Ask marketing folks if you can incorporate this code into your
 latest QuickTime product and see if they think you're serious
	8) Set your terminal to White on Black for optimal look
	7) Download your favorite movie trailer
	6) While you're at it, download some Graphics Importer sample code (why not?)
	5) Jedi mind trick your manager "...you want to send me to WWDC"
	4) Order the pizza.
	4) Dim the lights and turn up the audio
	2) Turn off terminal transparancy for fastest performance
	1) Usage [smelltheglove:/Volumes/Spock] moof% ASCIIMoviePlayer sillymovie.mov
 
 
 Additions by Jonas Maebe (jonas.maebe@rug.ac.be) - 22/10/2002:
 
 + color support! (standard enabled, remove the USE_COLOR define below to disable
 * several optimizations so that only the changed portions of the screen are redrawn
 
 TODO: sometimes it may be better to redraw some characters (if their color and boldness is the
 same as the current color/boldness) instead of skipping them, though this should be profiled.
 
 Note that color support requires a lot of cpu power (maybe Quartz Extreme helps as well). It's a lot
 slower than black&white on my G4/400 with Rage128Pro (AGP).
 */

#import <Foundation/Foundation.h>
#include <stdio.h>
#include <QuickTime/QuickTime.h>

#define USE_COLOR

#define ESC	27

#define	SCALE	(1)
#if 0
// 16x9
#define	WIDTH	((float)(80*SCALE))
#define HEIGHT	((float)(17*SCALE))
#else
// 4x3
#define	WIDTH	((float)(80*SCALE))
#define HEIGHT	((float)(24*SCALE))
#endif

#define INTWIDTH ((int)(WIDTH))
#define INTHEIGHT ((int)(HEIGHT))

#define BLACK   30
#define RED     31
#define GREEN   32
#define YELLOW  33
#define BLUE    34
#define MAGENTA 35
#define CYAN    36
#define WHITE   37

static short prevframe[INTHEIGHT][INTWIDTH];

// ASCII pixel value array
char convert[256];

char line[100000];
char *linepos;

int lastcolor = -1, lastbold = -1;

// DrawCompleteProc - After the frame has been drawn QuickTime calls us to do some work
static pascal OSErr DrawCompleteProc(Movie theMovie, long refCon)
{
#ifdef USE_COLOR
    //                 R  G  B
    static char colors[4][4][4] =
    //    000   001  002 003     010  011 012   013    020   021  022 023      030   031  032  033
    {{{BLACK,BLUE,BLUE,BLUE},{GREEN,CYAN,CYAN,BLUE},{GREEN,CYAN,CYAN,CYAN},{GREEN,GREEN,CYAN,CYAN}},
        //    100  101    102    103     110    111   112  113    120   121   122  123    130    131  132  133
        {{RED,MAGENTA,MAGENTA,BLUE},{YELLOW,GREEN,CYAN,BLUE},{YELLOW,GREEN,CYAN,CYAN},{GREEN,GREEN,CYAN,CYAN}},
        //   200 201     202     203       210    211     212     213       220     221   222   223    230     231   232   233
        {{RED,MAGENTA,MAGENTA,MAGENTA},{YELLOW,MAGENTA,MAGENTA,MAGENTA},{YELLOW,YELLOW,WHITE,CYAN},{YELLOW,YELLOW,WHITE,CYAN}},
        //   300 301  302    303       310 311 312     313       320     321   322   323       330     331   332   333
        {{RED,RED,MAGENTA,MAGENTA},{RED,RED,MAGENTA,MAGENTA},{YELLOW,YELLOW,WHITE,MAGENTA},{YELLOW,YELLOW,YELLOW,WHITE}}};
#endif //USE_COLOR
    
    int		y, x, cury = 0, curx = 0;
    GWorldPtr	offWorld = (GWorldPtr)refCon;
    Rect		bounds;
    Ptr		baseAddr;
    long		rowBytes;
    float		yfact;
    float		xfact;
    char		ch;
    
    // get the information we need from the GWorld
    GetPixBounds(GetGWorldPixMap(offWorld), &bounds);
    baseAddr = GetPixBaseAddr(GetGWorldPixMap(offWorld));
    rowBytes = GetPixRowBytes(GetGWorldPixMap(offWorld));
    yfact = (double)(bounds.bottom - bounds.top) / HEIGHT;
    xfact = (double)(bounds.right - bounds.left) / WIDTH;
    // goto home
    printf("%c[0;0H", ESC);
    
    // for each row
    for (y = 0; y < INTHEIGHT; ++y) {
        long	*p;
        
        linepos = line;
        // for each pixel on this row
        p = (long*)(baseAddr + rowBytes * (long)(y * yfact));
        for (x = 0; x < INTWIDTH; ++x) {
            UInt32			color;
            long			Y;
            long			R;
            long			G;
            long			B;
            
            color = *(long *)((long)p + 4 * (long)(x*xfact));
            R = (color & 0x00FF0000) >> 16;
            G = (color & 0x0000FF00) >> 8;
            B = (color & 0x000000FF) >> 0;
            
            // convert to YUV for comparison
            // 5 * R + 9 * G + 2 * B
            Y = (R + (R << 2) + G + (G << 3) + (B + B)) >> 4;
            ch = convert[Y];
            
            {
                char	attr;
                
#ifdef USE_COLOR
                int	bold = (Y % 5) > 4;
                
                color = colors[R>>6][G>>6][B>>6];
                attr = (bold << 7) | color;
#else //USE_COLOR
                color = WHITE;
                attr = color;
#endif //USE_COLOR
                
                // if the color, boldness and character didn't change from the last frame, don't draw again
                if (prevframe[y][x] != ((attr << 8) | ch)) {
                    
#ifdef USE_COLOR
                    // change both the color and the boldness
                    static char allseq[7] = "\x1B[X;3Xm";
                    // change the color
                    static char colorseq[5] = "\x1B[3Xm";
                    // change the boldness
                    static char boldseq[4] = "\x1B[Xm";
#endif //USE_COLOR
                    
                    // move 1-9 positions to the right
                    static char xmoveseq1[4] = "\x1B[XC";
                    // move 10-99 positions to the right
                    static char xmoveseq2[5] = "\x1B[XXC";
                    // move 100-999 positions to the right
                    static char xmoveseq3[6] = "\x1B[XXXC";
                    
                    // calculate the difference between the position of the current character and the
                    // the position right after the previously drawn character (that's where the cursor still is)
                    int xdiff = x - curx;
                    
                    // remember the character we're going to draw
                    prevframe[y][x] = ((attr << 8) | ch);
                    
                    // is the cursor in the right position?
                    if (xdiff != 0) {
                        // no, check which sequence is optimal to move the cursor
                        if (xdiff < 10) {
                            xmoveseq1[2] = xdiff + '0';
                            memcpy(linepos,xmoveseq1,sizeof(xmoveseq1));
                            linepos+=sizeof(xmoveseq1);
                        }
                        else if (xdiff < 100) {
                            xmoveseq2[2] = (xdiff / 10) + '0';
                            xmoveseq2[3] = (xdiff % 10) + '0';
                            memcpy(linepos,xmoveseq2,sizeof(xmoveseq2));
                            linepos+=sizeof(xmoveseq2);
                        }
                        else {
                            int xdiffdiv100 = xdiff / 100;
                            xmoveseq3[2] = (xdiffdiv100) + '0';
                            xmoveseq3[3] = (xdiff / 10 - xdiffdiv100 * 10) + '0';
                            xmoveseq3[4] = (xdiff % 10) + '0';
                            memcpy(linepos,xmoveseq3,sizeof(xmoveseq3));
                            linepos+=sizeof(xmoveseq3);
                        }
                    }
                    
#ifdef USE_COLOR
                    // now that we're in the right position, check whether currently set color and
                    // boldness are correct and if not, adjust them
                    if (color != lastcolor) {
                        if (bold != lastbold) {
                            allseq[2] = bold + '0';
                            allseq[5] = (color - 30) + '0';
                            memcpy(linepos,allseq,sizeof(allseq));
                            linepos+=sizeof(allseq);
                            lastcolor = color;
                            lastbold = bold;
                        }
                        else {
                            colorseq[3] = (color - 30) + '0';
                            memcpy(linepos,colorseq,sizeof(colorseq));
                            linepos+=sizeof(colorseq);
                            lastcolor = color;
                        }
                    }
                    else if (bold != lastbold) {
                        boldseq[2] = bold + '0';
                        memcpy(linepos,boldseq,sizeof(boldseq));
                        linepos+=sizeof(boldseq);
                        lastbold = bold;
                    }
#endif //USE_COLOR
                    
                    // draw the character itself
                    *linepos++ = ch;
                    curx = x+1;
                    cury = y;
                }
            }
        }
        // we're at the end of the line -> terminate the string and draw it
        *linepos = '\0';
        puts(line);
        curx = 0;
    }
    
    return noErr;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        MovieController	thePlayer = nil;
        Movie		theMovie = nil;
        GWorldPtr	offWorld;
        Rect		bounds;
        short		resRefNum = -1;
        short		actualResId = DoTheRightThing;
        FSSpec		theFSSpec;
        OSErr		result = 0;
        MovieDrawingCompleteUPP	myDrawCompleteProc = NewMovieDrawingCompleteUPP(DrawCompleteProc);
        int i;
        CFStringRef inPath;
        
        /* build the luminance value to ASCII value conversion table
         Y			  ASCII
         0 - 30 			  space
         31 - 40 	 		.
         41 - 51 	 		,
         52 - 61 	 		:
         62 - 71 	 		!
         72 - 81 	 		-
         82 - 92 	 		+
         93 - 102  			=
         103 - 112 			;
         113 - 122 			i
         123 - 133 			o
         134 - 143 			t
         144 - 153 			7
         154 - 163 			6
         164 - 174			x
         175 - 184			0
         185 - 194			s
         195 - 204			&
         205 - 215			8
         216 - 225			%
         226 - 235			#
         236 - 245			@
         246 - 255			$
         */
        for (i = 0; i < 256; ++i) {
            char *table = "   .,:!-+=;iot76x0s&8%#@$";
            convert[i] = table[i * strlen(table) / 256];
        }
        
        EnterMovies();
        // home
        printf("%c[0;0H", ESC);
        // erase to end of display
        printf("%c[0J", ESC);
        
        // Convert movie path to CFString
        if (argc > 1) {
            inPath = CFStringCreateWithCString(NULL, argv[1], CFStringGetSystemEncoding());
            if (!inPath) { printf("Could not get CFString\n"); goto bail; }
        } else { printf("You need to at least type a path to a .mov file!\n"); goto bail; }
        
        result = NativePathNameToFSSpec(argv[1], &theFSSpec, 0 /* flags */);
        if (result) {printf("NativePathNameToFSSpec failed %d\n", result); goto bail; }
        result = OpenMovieFile(&theFSSpec, &resRefNum, 0);
        if (result) {printf("OpenMovieFile failed %d\n", result); goto bail; }
        
        result = NewMovieFromFile(&theMovie, resRefNum, &actualResId, (unsigned char *) 0, 0, (Boolean *) 0);
        if (result) {printf("NewMovieFromFile failed %d\n", result); goto bail; }
        
        if (resRefNum != -1)
            CloseMovieFile(resRefNum);
        
        memset(prevframe,-1,sizeof(prevframe));
        
        GetMovieBox(theMovie, &bounds);
        QTNewGWorld(&offWorld, k32ARGBPixelFormat, &bounds, NULL, NULL, 0);
        LockPixels(GetGWorldPixMap(offWorld));
        SetGWorld(offWorld, NULL);
        
        thePlayer = NewMovieController(theMovie, &bounds, mcTopLeftMovie | mcNotVisible);
        SetMovieGWorld(theMovie, offWorld, NULL);
        SetMovieActive(theMovie, true);
        SetMovieDrawingCompleteProc(theMovie, movieDrawingCallWhenChanged, myDrawCompleteProc, (long)offWorld);
        MCDoAction(thePlayer, mcActionPrerollAndPlay, (void*)Long2Fix(1));
        
        do {
            MCIdle(thePlayer);
        } while (1);
        
    bail:
        DisposeMovieController( thePlayer );
        DisposeMovie(theMovie);
        DisposeMovieDrawingCompleteUPP(myDrawCompleteProc);
        
        return result;
    }
    return 0;
}

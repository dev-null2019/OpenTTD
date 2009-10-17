/* $Id$ */

/******************************************************************************
 *                             Cocoa video driver                             *
 * Known things left to do:                                                   *
 *  Scale&copy the old pixel buffer to the new one when switching resolution. *
 ******************************************************************************/

#ifdef WITH_COCOA

#include "../../stdafx.h"

#if (MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_9)

#define Rect  OTTDRect
#define Point OTTDPoint
#import <Cocoa/Cocoa.h>
#undef Rect
#undef Point

#include "../../debug.h"
#include "../../core/geometry_type.hpp"
#include "cocoa_v.h"
#include "../../gfx_func.h"

/**
 * Important notice regarding all modifications!!!!!!!
 * There are certain limitations because the file is objective C++.
 * gdb has limitations.
 * C++ and objective C code can't be joined in all cases (classes stuff).
 * Read http://developer.apple.com/releasenotes/Cocoa/Objective-C++.html for more information.
 */


/* From Menus.h (according to Xcode Developer Documentation) */
extern "C" void ShowMenuBar();
extern "C" void HideMenuBar();


/* Structure for rez switch gamma fades
 * We can hide the monitor flicker by setting the gamma tables to 0
 */
#define QZ_GAMMA_TABLE_SIZE 256

struct OTTD_QuartzGammaTable {
	CGGammaValue red[QZ_GAMMA_TABLE_SIZE];
	CGGammaValue green[QZ_GAMMA_TABLE_SIZE];
	CGGammaValue blue[QZ_GAMMA_TABLE_SIZE];
};

/* Add methods to get at private members of NSScreen.
 * Since there is a bug in Apple's screen switching code that does not update
 * this variable when switching to fullscreen, we'll set it manually (but only
 * for the main screen).
 */
@interface NSScreen (NSScreenAccess)
	- (void) setFrame:(NSRect)frame;
@end

@implementation NSScreen (NSScreenAccess)
- (void) setFrame:(NSRect)frame;
{
/* The 64 bits libraries don't seem to know about _frame, so this hack won't work. */
#ifndef __LP64__
	_frame = frame;
#endif
}
@end




uint QZ_ListModes(OTTD_Point *modes, uint max_modes, CGDirectDisplayID display_id, int device_depth)
{
	CFArrayRef mode_list;
	CFIndex num_modes;
	CFIndex i;
	uint count = 0;

	mode_list  = CGDisplayAvailableModes(display_id);
	num_modes = CFArrayGetCount(mode_list);

	/* Build list of modes with the requested bpp */
	for (i = 0; i < num_modes && count < max_modes; i++) {
		CFDictionaryRef onemode;
		CFNumberRef     number;
		int bpp;
		int intvalue;
		bool hasMode;
		uint16 width, height;

		onemode = (const __CFDictionary*)CFArrayGetValueAtIndex(mode_list, i);
		number = (const __CFNumber*)CFDictionaryGetValue(onemode, kCGDisplayBitsPerPixel);
		CFNumberGetValue (number, kCFNumberSInt32Type, &bpp);

		if (bpp != device_depth) continue;

		number = (const __CFNumber*)CFDictionaryGetValue(onemode, kCGDisplayWidth);
		CFNumberGetValue(number, kCFNumberSInt32Type, &intvalue);
		width = (uint16)intvalue;

		number = (const __CFNumber*)CFDictionaryGetValue(onemode, kCGDisplayHeight);
		CFNumberGetValue(number, kCFNumberSInt32Type, &intvalue);
		height = (uint16)intvalue;

		/* Check if mode is already in the list */
		{
			uint i;
			hasMode = false;
			for (i = 0; i < count; i++) {
				if (modes[i].x == width &&  modes[i].y == height) {
					hasMode = true;
					break;
				}
			}
		}

		if (hasMode) continue;

		/* Add mode to the list */
		modes[count].x = width;
		modes[count].y = height;
		count++;
	}

	/* Sort list smallest to largest */
	{
		uint i, j;
		for (i = 0; i < count; i++) {
			for (j = 0; j < count-1; j++) {
				if (modes[j].x > modes[j + 1].x || (
					modes[j].x == modes[j + 1].x &&
					modes[j].y >  modes[j + 1].y
					)) {
					uint tmpw = modes[j].x;
					uint tmph = modes[j].y;

					modes[j].x = modes[j + 1].x;
					modes[j].y = modes[j + 1].y;

					modes[j + 1].x = tmpw;
					modes[j + 1].y = tmph;
				}
			}
		}
	}

	return count;
}

/* Small function to test if the main display can display 8 bpp in fullscreen */
bool QZ_CanDisplay8bpp()
{
	OTTD_Point p;

	/* We want to know if 8 bpp is possible in fullscreen and not anything about resolutions.
	 * Because of this we want to fill a list of 1 resolution of 8 bpp on display 0 (main) and return if we found one. */
	return QZ_ListModes(&p, 1, 0, 8);
}

class FullscreenSubdriver: public CocoaSubdriver {
	CGDirectDisplayID  display_id;         ///< 0 == main display (only support single display)
	CFDictionaryRef    cur_mode;           ///< current mode of the display
	CFDictionaryRef    save_mode;          ///< original mode of the display
	CGDirectPaletteRef palette;            ///< palette of an 8-bit display


	/* Gamma functions to try to hide the flash from a rez switch
	 * Fade the display from normal to black
	 * Save gamma tables for fade back to normal
	 */
	uint32 FadeGammaOut(OTTD_QuartzGammaTable* table)
	{
		CGGammaValue redTable[QZ_GAMMA_TABLE_SIZE];
		CGGammaValue greenTable[QZ_GAMMA_TABLE_SIZE];
		CGGammaValue blueTable[QZ_GAMMA_TABLE_SIZE];
		float percent;
		int j;
		unsigned int actual;

		if (CGGetDisplayTransferByTable(
					display_id, QZ_GAMMA_TABLE_SIZE,
					table->red, table->green, table->blue, &actual
				) != CGDisplayNoErr ||
				actual != QZ_GAMMA_TABLE_SIZE) {
			return 1;
		}

		memcpy(redTable,   table->red,   sizeof(redTable));
		memcpy(greenTable, table->green, sizeof(greenTable));
		memcpy(blueTable,  table->blue,  sizeof(greenTable));

		for (percent = 1.0; percent >= 0.0; percent -= 0.01) {
			for (j = 0; j < QZ_GAMMA_TABLE_SIZE; j++) {
				redTable[j]   = redTable[j]   * percent;
				greenTable[j] = greenTable[j] * percent;
				blueTable[j]  = blueTable[j]  * percent;
			}

			if (CGSetDisplayTransferByTable(
						display_id, QZ_GAMMA_TABLE_SIZE,
						redTable, greenTable, blueTable
					) != CGDisplayNoErr) {
				CGDisplayRestoreColorSyncSettings();
				return 1;
			}

			CSleep(10);
		}

		return 0;
	}

	/* Fade the display from black to normal
	 * Restore previously saved gamma values
	 */
	uint32 FadeGammaIn(const OTTD_QuartzGammaTable* table)
	{
		CGGammaValue redTable[QZ_GAMMA_TABLE_SIZE];
		CGGammaValue greenTable[QZ_GAMMA_TABLE_SIZE];
		CGGammaValue blueTable[QZ_GAMMA_TABLE_SIZE];
		float percent;
		int j;

		memset(redTable, 0, sizeof(redTable));
		memset(greenTable, 0, sizeof(greenTable));
		memset(blueTable, 0, sizeof(greenTable));

		for (percent = 0.0; percent <= 1.0; percent += 0.01) {
			for (j = 0; j < QZ_GAMMA_TABLE_SIZE; j++) {
				redTable[j]   = table->red[j]   * percent;
				greenTable[j] = table->green[j] * percent;
				blueTable[j]  = table->blue[j]  * percent;
			}

			if (CGSetDisplayTransferByTable(
						display_id, QZ_GAMMA_TABLE_SIZE,
						redTable, greenTable, blueTable
					) != CGDisplayNoErr) {
				CGDisplayRestoreColorSyncSettings();
				return 1;
			}

			CSleep(10);
		}

		return 0;
	}

	/* Wait for the VBL to occur (estimated since we don't have a hardware interrupt) */
	void WaitForVerticalBlank()
	{
		/* The VBL delay is based on Ian Ollmann's RezLib <iano@cco.caltech.edu> */
		double refreshRate;
		double position;
		double adjustment;
		CFNumberRef refreshRateCFNumber;

		refreshRateCFNumber = (const __CFNumber*)CFDictionaryGetValue(cur_mode, kCGDisplayRefreshRate);
		if (refreshRateCFNumber == NULL) return;

		if (CFNumberGetValue(refreshRateCFNumber, kCFNumberDoubleType, &refreshRate) == 0)
			return;

		if (refreshRate == 0) return;

		double linesPerSecond = refreshRate * this->device_height;
		double target = this->device_height;

		/* Figure out the first delay so we start off about right */
		position = CGDisplayBeamPosition(display_id);
		if (position > target) position = 0;

		adjustment = (target - position) / linesPerSecond;

		CSleep((uint32)(adjustment * 1000));
	}


	bool SetVideoMode(int w, int h)
	{
		CFNumberRef number;
		int bpp;
		int gamma_error;
		OTTD_QuartzGammaTable gamma_table;
		NSRect screen_rect;
		CGError error;
		NSPoint pt;

		/* Destroy any previous mode */
		if (pixel_buffer != NULL) {
			free(pixel_buffer);
			pixel_buffer = NULL;
		}

		/* See if requested mode exists */
		boolean_t exact_match;
		this->cur_mode = CGDisplayBestModeForParameters(this->display_id, this->device_depth, w, h, &exact_match);

		/* If the mode wasn't an exact match, check if it has the right bpp, and update width and height */
		if (!exact_match) {
			number = (const __CFNumber*) CFDictionaryGetValue(cur_mode, kCGDisplayBitsPerPixel);
			CFNumberGetValue(number, kCFNumberSInt32Type, &bpp);
			if (bpp != this->device_depth) {
				DEBUG(driver, 0, "Failed to find display resolution");
				goto ERR_NO_MATCH;
			}

			number = (const __CFNumber*)CFDictionaryGetValue(cur_mode, kCGDisplayWidth);
			CFNumberGetValue(number, kCFNumberSInt32Type, &w);

			number = (const __CFNumber*)CFDictionaryGetValue(cur_mode, kCGDisplayHeight);
			CFNumberGetValue(number, kCFNumberSInt32Type, &h);
		}

		/* Capture the main screen */
		CGDisplayCapture(this->display_id);

		/* Store the mouse coordinates relative to the total screen */
		mouseLocation = [ NSEvent mouseLocation ];
		mouseLocation.x /= this->device_width;
		mouseLocation.y /= this->device_height;

		/* Fade display to zero gamma */
		gamma_error = FadeGammaOut(&gamma_table);

		/* Put up the blanking window (a window above all other windows) */
		error = CGDisplayCapture(display_id);

		if (CGDisplayNoErr != error) {
			DEBUG(driver, 0, "Failed capturing display");
			goto ERR_NO_CAPTURE;
		}

		/* Do the physical switch */
		if (CGDisplaySwitchToMode(display_id, cur_mode) != CGDisplayNoErr) {
			DEBUG(driver, 0, "Failed switching display resolution");
			goto ERR_NO_SWITCH;
		}

		/* Since CGDisplayBaseAddress and CGDisplayBytesPerRow are no longer available on 10.7,
		 * disable until a replacement can be found. */
		if (MacOSVersionIsAtLeast(10, 7, 0)) {
			this->window_buffer = NULL;
			this->window_pitch  = 0;
		} else {
#if (MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_7)
			this->window_buffer = CGDisplayBaseAddress(this->display_id);
			this->window_pitch  = CGDisplayBytesPerRow(this->display_id);
#endif
		}

		this->device_width  = CGDisplayPixelsWide(this->display_id);
		this->device_height = CGDisplayPixelsHigh(this->display_id);

		/* Setup double-buffer emulation */
		this->pixel_buffer = malloc(this->device_width * this->device_height * this->device_depth / 8);
		if (this->pixel_buffer == NULL) {
			DEBUG(driver, 0, "Failed to allocate memory for double buffering");
			goto ERR_DOUBLEBUF;
		}

		if (this->device_depth == 8 && !CGDisplayCanSetPalette(this->display_id)) {
			DEBUG(driver, 0, "Not an indexed display mode.");
			goto ERR_NOT_INDEXED;
		}

		/* If we don't hide menu bar, it will get events and interrupt the program */
		HideMenuBar();

		/* Hide the OS cursor */
		CGDisplayHideCursor(this->display_id);

		/* Fade the display to original gamma */
		if (!gamma_error) FadeGammaIn(&gamma_table);

		/* There is a bug in Cocoa where NSScreen doesn't synchronize
		 * with CGDirectDisplay, so the main screen's frame is wrong.
		 * As a result, coordinate translation produces incorrect results.
		 * We can hack around this bug by setting the screen rect ourselves.
		 * This hack should be removed if/when the bug is fixed.
		 */
		screen_rect = NSMakeRect(0, 0, this->device_width, this->device_height);
		[ [ NSScreen mainScreen ] setFrame:screen_rect ];

		this->UpdatePalette(0, 256);

		/* Move the mouse cursor to approx the same location */
		CGPoint display_mouseLocation;
		display_mouseLocation.x = mouseLocation.x * this->device_width;
		display_mouseLocation.y = this->device_height - (mouseLocation.y * this->device_height);

		_cursor.in_window = true;

		CGDisplayMoveCursorToPoint(this->display_id, display_mouseLocation);

		return true;

		/* Since the blanking window covers *all* windows (even force quit) correct recovery is crucial */
ERR_NOT_INDEXED:
		free(pixel_buffer);
		pixel_buffer = NULL;
ERR_DOUBLEBUF:
		CGDisplaySwitchToMode(display_id, save_mode);
ERR_NO_SWITCH:
		CGReleaseAllDisplays();
ERR_NO_CAPTURE:
		if (!gamma_error) FadeGammaIn(&gamma_table);
ERR_NO_MATCH:
		this->device_width = 0;
		this->device_height = 0;

		return false;
	}

	void RestoreVideoMode()
	{
		/* Release fullscreen resources */
		OTTD_QuartzGammaTable gamma_table;
		int gamma_error;
		NSRect screen_rect;

		gamma_error = FadeGammaOut(&gamma_table);

		/* Restore original screen resolution/bpp */
		CGDisplaySwitchToMode(display_id, save_mode);
		CGReleaseAllDisplays();

		/* Bring back the cursor */
		CGDisplayShowCursor(this->display_id);

		ShowMenuBar();
		/* Reset the main screen's rectangle
		 * See comment in SetVideoMode for why we do this
		 */
		screen_rect = NSMakeRect(0, 0, CGDisplayPixelsWide(display_id), CGDisplayPixelsHigh(display_id));
		[ [ NSScreen mainScreen ] setFrame:screen_rect ];

		/* Destroy the pixel buffer */
		if (pixel_buffer != NULL) {
			free(pixel_buffer);
			pixel_buffer = NULL;
		}

		if (!gamma_error) FadeGammaIn(&gamma_table);

		this->device_width  = CGDisplayPixelsWide(this->display_id);
		this->device_height = CGDisplayPixelsHigh(this->display_id);
	}

public:
	FullscreenSubdriver(int bpp)
	{
		if (bpp != 8 && bpp != 32) {
			error("Cocoa: This video driver only supports 8 and 32 bpp blitters.");
		}

		/* Initialize the video settings; this data persists between mode switches */
		display_id = kCGDirectMainDisplay;
		save_mode  = CGDisplayCurrentMode(display_id);

		if (bpp == 8) palette = CGPaletteCreateDefaultColorPalette();

		this->device_width  = CGDisplayPixelsWide(this->display_id);
		this->device_height = CGDisplayPixelsHigh(this->display_id);
		this->device_depth  = bpp;
		this->pixel_buffer   = NULL;

		num_dirty_rects = MAX_DIRTY_RECTS;
	}

	virtual ~FullscreenSubdriver()
	{
		RestoreVideoMode();
	}

	virtual void Draw(bool force_update)
	{
		const uint8 *src   = (uint8 *)this->pixel_buffer;
		uint8 *dst         = (uint8 *)this->window_buffer;
		uint pitch         = this->window_pitch;
		uint width         = this->device_width;
		uint num_dirty     = this->num_dirty_rects;
		uint bytesperpixel = this->device_depth / 8;

		/* Check if we need to do anything */
		if (num_dirty == 0) return;

		if (num_dirty >= MAX_DIRTY_RECTS) {
			num_dirty = 1;
			this->dirty_rects[0].left   = 0;
			this->dirty_rects[0].top    = 0;
			this->dirty_rects[0].right  = this->device_width;
			this->dirty_rects[0].bottom = this->device_height;
		}

		WaitForVerticalBlank();
		/* Build the region of dirty rectangles */
		for (uint i = 0; i < num_dirty; i++) {
			uint y      = dirty_rects[i].top;
			uint left   = dirty_rects[i].left;
			uint length = dirty_rects[i].right - left;
			uint bottom = dirty_rects[i].bottom;

			for (; y < bottom; y++) {
				memcpy(dst + y * pitch + left * bytesperpixel, src + y * width * bytesperpixel + left * bytesperpixel, length * bytesperpixel);
			}
		}

		num_dirty_rects = 0;
	}

	virtual void MakeDirty(int left, int top, int width, int height)
	{
		if (num_dirty_rects < MAX_DIRTY_RECTS) {
			dirty_rects[num_dirty_rects].left = left;
			dirty_rects[num_dirty_rects].top = top;
			dirty_rects[num_dirty_rects].right = left + width;
			dirty_rects[num_dirty_rects].bottom = top + height;
		}
		num_dirty_rects++;
	}

	virtual void UpdatePalette(uint first_color, uint num_colors)
	{
		if (this->device_depth != 8) return;

		for (uint32 index = first_color; index < first_color+num_colors; index++) {
			/* Clamp colors between 0.0 and 1.0 */
			CGDeviceColor color;
			color.red   = _cur_palette[index].r / 255.0;
			color.blue  = _cur_palette[index].b / 255.0;
			color.green = _cur_palette[index].g / 255.0;

			CGPaletteSetColorAtIndex(palette, color, index);
		}

		CGDisplaySetPalette(display_id, palette);
	}

	virtual uint ListModes(OTTD_Point* modes, uint max_modes)
	{
		return QZ_ListModes(modes, max_modes, this->display_id, this->device_depth);
	}

	virtual bool ChangeResolution(int w, int h)
	{
		int old_width  = this->device_width;
		int old_height = this->device_height;

		if (SetVideoMode(w, h))
			return true;

		if (old_width != 0 && old_height != 0)
			SetVideoMode(old_width, old_height);

		return false;
	}

	virtual bool IsFullscreen()
	{
		return true;
	}

	virtual int GetWidth()
	{
		return this->device_width;
	}

	virtual int GetHeight()
	{
		return this->device_height;
	}

	virtual void *GetPixelBuffer()
	{
		return pixel_buffer;
	}

	/*
		Convert local coordinate to window server (CoreGraphics) coordinate.
		In fullscreen mode this just means copying the coords.
	*/
	virtual CGPoint PrivateLocalToCG(NSPoint* p)
	{
		CGPoint cgp;

		cgp.x = p->x;
		cgp.y = p->y;

		return cgp;
	}

	virtual NSPoint GetMouseLocation(NSEvent *event)
	{
		NSPoint pt = [ NSEvent mouseLocation ];
		pt.y = this->device_height - pt.y;

		return pt;
	}

	virtual bool MouseIsInsideView(NSPoint *pt)
	{
		return pt->x >= 0 && pt->y >= 0 && pt->x < this->device_width && pt->y < this->device_height;
	}

	virtual bool IsActive()
	{
		return true;
	}
};

CocoaSubdriver *QZ_CreateFullscreenSubdriver(int width, int height, int bpp)
{
	/* OSX 10.7 doesn't support this way of the fullscreen driver. If we end up here
	 * OpenTTD was compiled without SDK 10.7 available and - and thus we don't support
	 * fullscreen mode in OSX 10.7 or higher, as necessary elements for this way have
	 * been removed from the API.
	 */
	if (MacOSVersionIsAtLeast(10, 7, 0)) {
		return NULL;
	}

	FullscreenSubdriver *ret = new FullscreenSubdriver(bpp);

	if (!ret->ChangeResolution(width, height)) {
		delete ret;
		return NULL;
	}

	return ret;
}

#endif /* (MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_9) */
#endif /* WITH_COCOA */

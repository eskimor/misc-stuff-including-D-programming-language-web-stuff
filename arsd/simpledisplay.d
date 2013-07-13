module simpledisplay;
/*
	Stuff to add:

	take a screenshot function!

	Pens and brushes?
	Maybe a global event loop?

	Mouse deltas
	Key items
*/

version(html5) {} else {
	version(linux)
		version = X11;
	version(OSX) {
		version(OSXCocoa) {}
		else { version = X11; }
	}
		//version = OSXCocoa; // this was written by KennyTM
	version(FreeBSD)
		version = X11;
	version(Solaris)
		version = X11;
}

public import arsd.color; // no longer stand alone... :-( but i need a common type for this to work with images easily.

struct Point {
	int x;
	int y;
}

struct Size {
	int width;
	int height;
}


struct KeyEvent {
	uint keycode;
	bool pressed;
}

struct MouseEvent {
	int type; // movement, press, release, double click

	int x;
	int y;

	int button;
	int buttonFlags;
}

struct MouseClickEvent {

}

struct MouseMoveEvent {

}


struct Pen {
	Color color;
	int width;
	Style style;
/+
// From X.h

#define LineSolid		0
#define LineOnOffDash		1
#define LineDoubleDash		2
       LineDou-        The full path of the line is drawn, but the
       bleDash         even dashes are filled differently from the
                       odd dashes (see fill-style) with CapButt
                       style used where even and odd dashes meet.



/* capStyle */

#define CapNotLast		0
#define CapButt			1
#define CapRound		2
#define CapProjecting		3

/* joinStyle */

#define JoinMiter		0
#define JoinRound		1
#define JoinBevel		2

/* fillStyle */

#define FillSolid		0
#define FillTiled		1
#define FillStippled		2
#define FillOpaqueStippled	3


+/
	enum Style {
		Solid,
		Dashed
	}
}


final class Image {
	this(int width, int height) {
		this.width = width;
		this.height = height;

		impl.createImage(width, height);
	}

	this(Size size) {
		this(size.width, size.height);
	}

	~this() {
		impl.dispose();
	}

	final void putPixel(int x, int y, Color c) {
		if(x < 0 || x >= width)
			return;
		if(y < 0 || y >= height)
			return;

		impl.setPixel(x, y, c);
	}

	final void opIndexAssign(Color c, int x, int y) {
		putPixel(x, y, c);
	}

	/// this is here for interop with arsd.image. where can be a TrueColorImage's data member
	/// if you pass in a buffer, it will put it right there. length must be width*height*4 already
	/// if you pass null, it will allocate a new one.
	ubyte[] getRgbaBytes(ubyte[] where = null) {
		if(where is null)
			where = new ubyte[this.width*this.height*4];
		convertToRgbaBytes(where);
		return where;
	}

	/// this is here for interop with arsd.image. from can be a TrueColorImage's data member
	void setRgbaBytes(in ubyte[] from ) {
		assert(from.length == this.width * this.height * 4);
		setFromRgbaBytes(from);
	}

	// FIXME: make properly cross platform by getting rgba right

	/// warning: this is not portable across platforms because the data format can change
	ubyte* getDataPointer() {
		return impl.rawData;
	}

	/// for use with getDataPointer
	final int bytesPerLine() const pure @safe nothrow {
		version(Windows)
			return ((cast(int) width * 3 + 3) / 4) * 4;
		else version(X11)
			return 4 * width;
		else version(OSXCocoa)
			return 4 * width;
		else version(html5)
			return 4 * width;
		else static assert(0);
	}

	/// for use with getDataPointer
	final int bytesPerPixel() const pure @safe nothrow {
		version(Windows)
			return 3;
		else version(X11)
			return 4;
		else version(OSXCocoa)
			return 4;
		else version(html5)
			return 4;
		else static assert(0);
	}

	immutable int width;
	immutable int height;
    private:
	mixin NativeImageImplementation!() impl;
}

void displayImage(Image image, SimpleWindow win = null) {
	if(win is null) {
		win = new SimpleWindow(image);
		{
			auto p = win.draw;
			p.drawImage(Point(0, 0), image);
		}
		win.eventLoop(0,
			(int, bool pressed) {
				win.close();
			} );
	} else {
		win.image = image;
	}
}

/// Most functions use the outlineColor instead of taking a color themselves.
struct ScreenPainter {
	SimpleWindow window;
	this(SimpleWindow window, NativeWindowHandle handle) {
		this.window = window;
		if(window.activeScreenPainter !is null) {
			impl = window.activeScreenPainter;
			impl.referenceCount++;
		//	writeln("refcount ++ ", impl.referenceCount);
		} else {
			impl = new ScreenPainterImplementation;
			impl.window = window;
			impl.create(handle);
			impl.referenceCount = 1;
			window.activeScreenPainter = impl;
		//	writeln("constructed");
		}
	}

	~this() {
		impl.referenceCount--;
		//writeln("refcount -- ", impl.referenceCount);
		if(impl.referenceCount == 0) {
			//writeln("destructed");
			impl.dispose();
			window.activeScreenPainter = null;
		}
	}

	// @disable this(this) { } // compiler bug? the linker is bitching about it beind defined twice

	this(this) {
		impl.referenceCount++;
		//writeln("refcount ++ ", impl.referenceCount);
	}

	@property void outlineColor(Color c) {
		impl.outlineColor(c);
	}

	@property void fillColor(Color c) {
		impl.fillColor(c);
	}

	void updateDisplay() {
		// FIXME
	}

	void clear() {
		fillColor = Color(255, 255, 255);
		drawRectangle(Point(0, 0), window.width, window.height);
	}

	void drawPixmap(Sprite s, Point upperLeft) {
		impl.drawPixmap(s, upperLeft.x, upperLeft.y);
	}

	void drawImage(Point upperLeft, Image i) {
		impl.drawImage(upperLeft.x, upperLeft.y, i);
	}

	void drawText(Point upperLeft, string text) {
		// bounding rect other sizes are ignored for now
		impl.drawText(upperLeft.x, upperLeft.y, 0, 0, text);
	}

	void drawPixel(Point where) {
		impl.drawPixel(where.x, where.y);
	}


	void drawLine(Point starting, Point ending) {
		impl.drawLine(starting.x, starting.y, ending.x, ending.y);
	}

	void drawRectangle(Point upperLeft, int width, int height) {
		impl.drawRectangle(upperLeft.x, upperLeft.y, width, height);
	}

	/// Arguments are the points of the bounding rectangle
	void drawEllipse(Point upperLeft, Point lowerRight) {
		impl.drawEllipse(upperLeft.x, upperLeft.y, lowerRight.x, lowerRight.y);
	}

	void drawArc(Point upperLeft, int width, int height, int start, int finish) {
		impl.drawArc(upperLeft.x, upperLeft.y, width, height, start, finish);
	}

	void drawPolygon(Point[] vertexes) {
		impl.drawPolygon(vertexes);
	}


	// and do a draw/fill in a single call maybe. Windows can do it... but X can't, though it could do two calls.

	//mixin NativeScreenPainterImplementation!() impl;


	// HACK: if I mixin the impl directly, it won't let me override the copy
	// constructor! The linker complains about there being multiple definitions.
	// I'll make the best of it and reference count it though.
	ScreenPainterImplementation* impl;
}

	// HACK: I need a pointer to the implementation so it's separate
	struct ScreenPainterImplementation {
		SimpleWindow window;
		int referenceCount;
		mixin NativeScreenPainterImplementation!();
	}

// FIXME: i haven't actually tested the sprite class on MS Windows

/**
	Sprites are optimized for fast drawing on the screen, but slow for direct pixel
	access. They are best for drawing a relatively unchanging image repeatedly on the screen.

	You create one by giving a window and an image. It optimizes for that window,
	and copies the image into it to use as the initial picture. Creating a sprite
	can be quite slow (especially over a network connection) so you should do it
	as little as possible and just hold on to your sprite handles after making them.

	Then you can use sprite.drawAt(painter, point); to draw it, which should be
	a fast operation - much faster than drawing the Image itself every time.

	FIXME: you are supposed to be able to draw on these similarly to on windows.
*/
class Sprite {
	// FIXME: we should actually be able to draw upon these, same as windows
	//ScreenPainter drawUpon();

	this(SimpleWindow win, Image i) {
		this.width = i.width;
		this.height = i.height;

		version(X11) {
			auto display = XDisplayConnection.get();
			handle = XCreatePixmap(display, cast(Drawable) win.window, width, height, 24);
			XPutImage(display, cast(Drawable) handle, DefaultGC(display, DefaultScreen(display)), i.handle, 0, 0, 0, 0, i.width, i.height);
		} else version(Windows) {
			BITMAPINFO infoheader;
			infoheader.bmiHeader.biSize = infoheader.bmiHeader.sizeof;
			infoheader.bmiHeader.biWidth = width;
			infoheader.bmiHeader.biHeight = height;
			infoheader.bmiHeader.biPlanes = 1;
			infoheader.bmiHeader.biBitCount = 24;
			infoheader.bmiHeader.biCompression = BI_RGB;

			ubyte* rawData;

			// FIXME: this should prolly be a device dependent bitmap...
			handle = CreateDIBSection(
				null,
				&infoheader,
				DIB_RGB_COLORS,
				cast(void**) &rawData,
				null,
				0);

			if(handle is null)
				throw new Exception("couldn't create pixmap");

			auto itemsPerLine = ((cast(int) width * 3 + 3) / 4) * 4;
			auto arrLength = itemsPerLine * height;
			rawData[0..arrLength] = i.rawData[0..arrLength];
		} else version(OSXCocoa) {
			// FIXME: I have no idea if this is even any good
			ubyte* rawData;
        
			auto colorSpace = CGColorSpaceCreateDeviceRGB();
			context = CGBitmapContextCreate(null, width, height, 8, 4*width,
                                            colorSpace,
                                            kCGImageAlphaPremultipliedLast
                                                   |kCGBitmapByteOrder32Big);
            		CGColorSpaceRelease(colorSpace);
            		rawData = CGBitmapContextGetData(context);

			auto rdl = (width * height * 4);
			rawData[0 .. rdl] = i.rawData[0 .. rdl];
		} else version(html5) {
			handle = nextHandle;
			nextHandle++;
			Html5.createImage(handle, i);
		} else static assert(0);
	}

	void dispose() {
		version(X11)
			XFreePixmap(XDisplayConnection.get(), handle);
		else version(Windows)
			DeleteObject(handle);
		else version(OSXCocoa)
			CGContextRelease(context);
		else version(html5)
			Html5.freeImage(handle);
		else static assert(0);

	}

	int width;
	int height;
	version(X11)
		Pixmap handle;
	else version(Windows)
		HBITMAP handle;
	else version(OSXCocoa)
		CGContextRef context;
	else version(html5) {
		static int nextHandle;
		int handle;
	}
	else static assert(0);

	void drawAt(ScreenPainter painter, Point where) {
		painter.drawPixmap(this, where);
	}
}

class SimpleWindow {
	int width;
	int height;

	// HACK: making the best of some copy constructor woes with refcounting
	private ScreenPainterImplementation* activeScreenPainter;

	/// Creates a window based on the given image. It's client area
	/// width and height is equal to the image. (A window's client area
	/// is the drawable space inside; it excludes the title bar, etc.)
	this(Image image, string title = null) {
		this(image.width, image.height, title);
		this.image = image;
	}

	this(Size size, string title = null) {
		this(size.width, size.height, title);
	}

	this(int width, int height, string title = null) {
		this.width = width;
		this.height = height;
		impl.createWindow(width, height, title is null ? "D Application" : title);
	}

	~this() {
		impl.dispose();
	}

	/// Closes the window and terminates it's event loop.
	void close() {
		impl.closeWindow();
	}

	/// The event loop automatically returns when the window is closed
	/// pulseTimeout is given in milliseconds.
	final int eventLoop(T...)(
		long pulseTimeout,    /// set to zero if you don't want a pulse. Note: don't set it too big, or user input may not be processed in a timely manner. I suggest something < 150.
		T eventHandlers) /// delegate list like std.concurrency.receive
	{

		// FIXME: add more events
		foreach(handler; eventHandlers) {
			static if(__traits(compiles, handleKeyEvent = handler)) {
				handleKeyEvent = handler;
			} else static if(__traits(compiles, handleCharEvent = handler)) {
				handleCharEvent = handler;
			} else static if(__traits(compiles, handlePulse = handler)) {
				handlePulse = handler;
			} else static if(__traits(compiles, handleMouseEvent = handler)) {
				handleMouseEvent = handler;
			} else static assert(0, "I can't use this event handler " ~ typeof(handler).stringof ~ "\nNote: if you want to capture keycode events, this recently changed to (int code, bool pressed) instead of the old (int code)");
		}


		return impl.eventLoop(pulseTimeout);
	}

	ScreenPainter draw() {
		return impl.getPainter();
	}

	@property void image(Image i) {
		version(Windows) {
			BITMAP bm;
			HDC hdc = GetDC(hwnd);
			HDC hdcMem = CreateCompatibleDC(hdc);
			HBITMAP hbmOld = SelectObject(hdcMem, i.handle);

			GetObject(i.handle, bm.sizeof, &bm);

			BitBlt(hdc, 0, 0, bm.bmWidth, bm.bmHeight, hdcMem, 0, 0, SRCCOPY);

			SelectObject(hdcMem, hbmOld);
			DeleteDC(hdcMem);
			DeleteDC(hwnd);

			/*
			RECT r;
			r.right = i.width;
			r.bottom = i.height;
			InvalidateRect(hwnd, &r, false);
			*/
		} else
		version(X11) {
			if(!destroyed)
			XPutImage(display, cast(Drawable) window, gc, i.handle, 0, 0, 0, 0, i.width, i.height);
		} else
		version(OSXCocoa) {
           		draw().drawImage(Point(0, 0), i);
			setNeedsDisplay(view, true);
		} else version(html5) {
			// FIXME html5
		} else static assert(0);
	}

	/// What follows are the event handlers. These are set automatically
	/// by the eventLoop function, but are still public so you can change
	/// them later. wasPressed == true means key down. false == key up.

	/// Handles a low-level keyboard event
	void delegate(int key, bool wasPressed) handleKeyEvent;

	/// Handles a higher level keyboard event - c is the character just pressed.
	void delegate(dchar c) handleCharEvent;

	void delegate() handlePulse;

	void delegate(MouseEvent) handleMouseEvent;

	/** Platform specific - handle any native messages this window gets.
	  *
	  * Note: this is called *in addition to* other event handlers.

	  * On Windows, it takes the form of void delegate(UINT, WPARAM, LPARAM).

	  * On X11, it takes the form of void delegate(XEvent).
	**/
	NativeEventHandler handleNativeEvent;

  private:
	mixin NativeSimpleWindowImplementation!() impl;
}

/* Additional utilities */


Color fromHsl(real h, real s, real l) {
	return arsd.color.fromHsl([h,s,l]);
}



/* ********** What follows is the system-specific implementations *********/
version(Windows) {

	SimpleWindow[HWND] windowObjects;

	alias void delegate(UINT, WPARAM, LPARAM) NativeEventHandler;
	alias HWND NativeWindowHandle;

	extern(Windows)
	int WndProc(HWND hWnd, UINT iMessage, WPARAM wParam, LPARAM lParam) nothrow {
	    try {
            if(hWnd in windowObjects) {
                auto window = windowObjects[hWnd];
                return window.windowProcedure(hWnd, iMessage, wParam, lParam);
            } else {
                return DefWindowProc(hWnd, iMessage, wParam, lParam);
            }
	    } catch (Exception e) {
            assert(false, "Exception caught in WndProc");
	    }
	}

	mixin template NativeScreenPainterImplementation() {
		HDC hdc;
		HWND hwnd;
		HDC windowHdc;
		HBITMAP oldBmp;

		void create(NativeWindowHandle window) {
			auto buffer = this.window.impl.buffer;
			hwnd = window;
			windowHdc = GetDC(hwnd);

			hdc = CreateCompatibleDC(windowHdc);
			oldBmp = SelectObject(hdc, buffer);

			// X doesn't draw a text background, so neither should we
			SetBkMode(hdc, TRANSPARENT);
		}

		// just because we can on Windows...
		//void create(Image image);

		void dispose() {
			// FIXME: this.window.width/height is probably wrong
			BitBlt(windowHdc, 0, 0, this.window.width, this.window.height, hdc, 0, 0, SRCCOPY);

			ReleaseDC(hwnd, windowHdc);

			if(originalPen !is null)
				SelectObject(hdc, originalPen);
			if(currentPen !is null)
				DeleteObject(currentPen);
			if(originalBrush !is null)
				SelectObject(hdc, originalBrush);
			if(currentBrush !is null)
				DeleteObject(currentBrush);

			SelectObject(hdc, oldBmp);

			DeleteDC(hdc);
		}

		HPEN originalPen;
		HPEN currentPen;

		Color _foreground;
		@property void outlineColor(Color c) {
			_foreground = c;
			HPEN pen;
			if(c.a == 0) {
				pen = GetStockObject(NULL_PEN);
			} else {
				pen = CreatePen(PS_SOLID, 1, RGB(c.r, c.g, c.b));
			}
			auto orig = SelectObject(hdc, pen);
			if(originalPen is null)
				originalPen = orig;

			if(currentPen !is null)
				DeleteObject(currentPen);

			currentPen = pen;

			// the outline is like a foreground since it's done that way on X
			SetTextColor(hdc, RGB(c.r, c.g, c.b));
		}

		HBRUSH originalBrush;
		HBRUSH currentBrush;
		@property void fillColor(Color c) {
			HBRUSH brush;
			if(c.a == 0) {
				brush = GetStockObject(HOLLOW_BRUSH);
			} else {
				brush = CreateSolidBrush(RGB(c.r, c.g, c.b));
			}
			auto orig = SelectObject(hdc, brush);
			if(originalBrush is null)
				originalBrush = orig;

			if(currentBrush !is null)
				DeleteObject(currentBrush);

			currentBrush = brush;

			// background color is NOT set because X doesn't draw text backgrounds
			//   SetBkColor(hdc, RGB(255, 255, 255));
		}

		void drawImage(int x, int y, Image i) {
			BITMAP bm;

			HDC hdcMem = CreateCompatibleDC(hdc);
			HBITMAP hbmOld = SelectObject(hdcMem, i.handle);

			GetObject(i.handle, bm.sizeof, &bm);

			BitBlt(hdc, x, y, bm.bmWidth, bm.bmHeight, hdcMem, 0, 0, SRCCOPY);

			SelectObject(hdcMem, hbmOld);
			DeleteDC(hdcMem);
		}

		void drawPixmap(Sprite s, int x, int y) {
			BITMAP bm;

			HDC hdcMem = CreateCompatibleDC(hdc);
			HBITMAP hbmOld = SelectObject(hdcMem, s.handle);

			GetObject(s.handle, bm.sizeof, &bm);

			BitBlt(hdc, x, y, bm.bmWidth, bm.bmHeight, hdcMem, 0, 0, SRCCOPY);

			SelectObject(hdcMem, hbmOld);
			DeleteDC(hdcMem);
		}

		void drawText(int x, int y, int x2, int y2, string text) {
			/*
			RECT rect;
			rect.left = x;
			rect.top = y;
			rect.right = x2;
			rect.bottom = y2;

			DrawText(hdc, text.ptr, text.length, &rect, DT_LEFT);
			*/

			TextOut(hdc, x, y, text.ptr, text.length);
		}

		void drawPixel(int x, int y) {
			SetPixel(hdc, x, y, RGB(_foreground.r, _foreground.g, _foreground.b));
		}

		// The basic shapes, outlined

		void drawLine(int x1, int y1, int x2, int y2) {
			MoveToEx(hdc, x1, y1, null);
			LineTo(hdc, x2, y2);
		}

		void drawRectangle(int x, int y, int width, int height) {
			Rectangle(hdc, x, y, x + width, y + height);
		}

		/// Arguments are the points of the bounding rectangle
		void drawEllipse(int x1, int y1, int x2, int y2) {
			Ellipse(hdc, x1, y1, x2, y2);
		}

		void drawArc(int x1, int y1, int width, int height, int start, int finish) {
			// FIXME: start X, start Y, end X, end Y
			Arc(hdc, x1, y1, x1 + width, y1 + height, 0, 0, 0, 0);
		}

		void drawPolygon(Point[] vertexes) {
			POINT[] points;
			points.length = vertexes.length;

			foreach(i, p; vertexes) {
				points[i].x = p.x;
				points[i].y = p.y;
			}

			Polygon(hdc, points.ptr, points.length);
		}
	}


	// Mix this into the SimpleWindow class
	mixin template NativeSimpleWindowImplementation() {
		ScreenPainter getPainter() {
			return ScreenPainter(this, hwnd);
		}

		HBITMAP buffer;

		void createWindow(int width, int height, string title) {
			const char* cn = "DSimpleWindow";

			HINSTANCE hInstance = cast(HINSTANCE) GetModuleHandle(null);

			WNDCLASS wc;

			wc.cbClsExtra = 0;
			wc.cbWndExtra = 0;
			wc.hbrBackground = cast(HBRUSH) GetStockObject(WHITE_BRUSH);
			wc.hCursor = LoadCursor(null, IDC_ARROW);
			wc.hIcon = LoadIcon(hInstance, null);
			wc.hInstance = hInstance;
			wc.lpfnWndProc = &WndProc;
			wc.lpszClassName = cn;
			wc.style = CS_HREDRAW | CS_VREDRAW;
			if(!RegisterClass(&wc))
				throw new Exception("RegisterClass");

			import std.string : toStringz;
			hwnd = CreateWindow(cn, toStringz(title), WS_OVERLAPPEDWINDOW,
				CW_USEDEFAULT, CW_USEDEFAULT, width, height,
				null, null, hInstance, null);

			windowObjects[hwnd] = this;

			HDC hdc = GetDC(hwnd);
			buffer = CreateCompatibleBitmap(hdc, width, height);

			auto hdcBmp = CreateCompatibleDC(hdc);
			// make sure it's filled with a blank slate
			auto oldBmp = SelectObject(hdcBmp, buffer);
			auto oldBrush = SelectObject(hdcBmp, GetStockObject(WHITE_BRUSH));
			Rectangle(hdcBmp, 0, 0, width, height);
			SelectObject(hdcBmp, oldBmp);
			SelectObject(hdcBmp, oldBrush);
			DeleteDC(hdcBmp);

			ReleaseDC(hwnd, hdc);

			// We want the window's client area to match the image size
			RECT rcClient, rcWindow;
			POINT ptDiff;
			GetClientRect(hwnd, &rcClient);
			GetWindowRect(hwnd, &rcWindow);
			ptDiff.x = (rcWindow.right - rcWindow.left) - rcClient.right;
			ptDiff.y = (rcWindow.bottom - rcWindow.top) - rcClient.bottom;
			MoveWindow(hwnd,rcWindow.left, rcWindow.top, width + ptDiff.x, height + ptDiff.y, true);

			ShowWindow(hwnd, SW_SHOWNORMAL);
		}


		void dispose() {
			DeleteObject(buffer);
		}

		void closeWindow() {
			DestroyWindow(hwnd);
		}

		HWND hwnd;

		// the extern(Windows) wndproc should just forward to this
		int windowProcedure(HWND hwnd, uint msg, WPARAM wParam, LPARAM lParam) {
			assert(hwnd is this.hwnd);

			MouseEvent mouse;
			switch(msg) {
				case WM_CHAR:
					wchar c = cast(wchar) wParam;
					if(handleCharEvent)
						handleCharEvent(cast(dchar) c);
				break;
				case WM_MOUSEMOVE:

				case WM_LBUTTONDOWN:
				case WM_LBUTTONUP:
				case WM_LBUTTONDBLCLK:

				case WM_RBUTTONDOWN:
				case WM_RBUTTONUP:
				case WM_RBUTTONDBLCLK:

				case WM_MBUTTONDOWN:
				case WM_MBUTTONUP:
				case WM_MBUTTONDBLCLK:
					mouse.type = 0;
					mouse.x = LOWORD(lParam);
					mouse.y = HIWORD(lParam);
					mouse.buttonFlags = wParam;

					if(handleMouseEvent)
						handleMouseEvent(mouse);
				break;
				case WM_KEYDOWN:
				case WM_KEYUP:
					if(handleKeyEvent)
						handleKeyEvent(wParam, msg == WM_KEYDOWN);
				break;
				case WM_CLOSE:
				case WM_DESTROY:
					PostQuitMessage(0);
				break;
				case WM_PAINT: {
					BITMAP bm;
					PAINTSTRUCT ps;

					HDC hdc = BeginPaint(hwnd, &ps);

					HDC hdcMem = CreateCompatibleDC(hdc);
					HBITMAP hbmOld = SelectObject(hdcMem, buffer);

					GetObject(buffer, bm.sizeof, &bm);

					BitBlt(hdc, 0, 0, bm.bmWidth, bm.bmHeight, hdcMem, 0, 0, SRCCOPY);

					SelectObject(hdcMem, hbmOld);
					DeleteDC(hdcMem);


					EndPaint(hwnd, &ps);
				} break;
				  default:
					return DefWindowProc(hwnd, msg, wParam, lParam);
			}
			 return 0;

		}

		int eventLoop(long pulseTimeout) {
			MSG message;
			int ret;

			import core.thread;

			if(pulseTimeout) {
				bool done = false;
				while(!done) {
					if(PeekMessage(&message, hwnd, 0, 0, PM_NOREMOVE)) {
						ret = GetMessage(&message, hwnd, 0, 0);
						if(ret == 0)
							done = true;

						TranslateMessage(&message);
						DispatchMessage(&message);
					}

					if(!done && handlePulse !is null)
						handlePulse();
					Thread.sleep(dur!"msecs"(pulseTimeout));
				}
			} else {
				while((ret = GetMessage(&message, hwnd, 0, 0)) != 0) {
					if(ret == -1)
						throw new Exception("GetMessage failed");
					TranslateMessage(&message);
					DispatchMessage(&message);
				}
			}

			return message.wParam;
		}
	}

	mixin template NativeImageImplementation() {
		HBITMAP handle;
		ubyte* rawData;

		void setPixel(int x, int y, Color c) {
			auto itemsPerLine = ((cast(int) width * 3 + 3) / 4) * 4;
			// remember, bmps are upside down
			auto offset = itemsPerLine * (height - y - 1) + x * 3;

			rawData[offset + 0] = c.b;
			rawData[offset + 1] = c.g;
			rawData[offset + 2] = c.r;
		}

		void convertToRgbaBytes(ubyte[] where) {
			assert(where.length == this.width * this.height * 4);

			auto itemsPerLine = ((cast(int) width * 3 + 3) / 4) * 4;
			int idx = 0;
			int offset = itemsPerLine * (height - 1);
			// remember, bmps are upside down
			for(int y = height - 1; y >= 0; y--) {
				auto offsetStart = offset;
				for(int x = 0; x < width; x++) {
					where[idx + 0] = rawData[offset + 2]; // r
					where[idx + 1] = rawData[offset + 1]; // g
					where[idx + 2] = rawData[offset + 0]; // b
					where[idx + 3] = 255; // a
					idx += 4; 
					offset += 3;
				}

				offset = offsetStart - itemsPerLine;
			}
		}

		void setFromRgbaBytes(in ubyte[] what) {
			assert(what.length == this.width * this.height * 4);

			auto itemsPerLine = ((cast(int) width * 3 + 3) / 4) * 4;
			int idx = 0;
			int offset = itemsPerLine * (height - 1);
			// remember, bmps are upside down
			for(int y = height - 1; y >= 0; y--) {
				auto offsetStart = offset;
				for(int x = 0; x < width; x++) {
					rawData[offset + 2] = what[idx + 0]; // r
					rawData[offset + 1] = what[idx + 1]; // g
					rawData[offset + 0] = what[idx + 2]; // b
					//where[idx + 3] = 255; // a
					idx += 4; 
					offset += 3;
				}

				offset = offsetStart - itemsPerLine;
			}
		}


		void createImage(int width, int height) {
			BITMAPINFO infoheader;
			infoheader.bmiHeader.biSize = infoheader.bmiHeader.sizeof;
			infoheader.bmiHeader.biWidth = width;
			infoheader.bmiHeader.biHeight = height;
			infoheader.bmiHeader.biPlanes = 1;
			infoheader.bmiHeader.biBitCount = 24;
			infoheader.bmiHeader.biCompression = BI_RGB;

			handle = CreateDIBSection(
				null,
				&infoheader,
				DIB_RGB_COLORS,
				cast(void**) &rawData,
				null,
				0);
			if(handle is null)
				throw new Exception("create image failed");

		}

		void dispose() {
			DeleteObject(handle);
		}
	}

	enum KEY_ESCAPE = 27;
}
version(X11) {

	alias void delegate(XEvent) NativeEventHandler;
	alias Window NativeWindowHandle;

	enum KEY_ESCAPE = 9;

	mixin template NativeScreenPainterImplementation() {
		Display* display;
		Drawable d;
		Drawable destiny;
		GC gc;

		void create(NativeWindowHandle window) {
			this.display = XDisplayConnection.get();

    			auto buffer = this.window.impl.buffer;

			this.d = cast(Drawable) buffer;
			this.destiny = cast(Drawable) window;

			auto dgc = DefaultGC(display, DefaultScreen(display));

			this.gc = XCreateGC(display, d, 0, null);

			XCopyGC(display, dgc, 0xffffffff, this.gc);

		}

		void dispose() {
    			auto buffer = this.window.impl.buffer;

			// FIXME: this.window.width/height is probably wrong

			// src x,y     then dest x, y
			XCopyArea(display, d, destiny, gc, 0, 0, this.window.width, this.window.height, 0, 0);

			XFreeGC(display, gc);
			XFlush(display);
		}

		bool backgroundIsNotTransparent = true;
		bool foregroundIsNotTransparent = true;

		Color _outlineColor;
		Color _fillColor;

		@property void outlineColor(Color c) {
			_outlineColor = c;
			if(c.a == 0) {
				foregroundIsNotTransparent = false;
				return;
			}

			foregroundIsNotTransparent = true;

			XSetForeground(display, gc,
				cast(uint) c.r << 16 |
				cast(uint) c.g << 8 |
				cast(uint) c.b);
		}

		@property void fillColor(Color c) {
			_fillColor = c;
			if(c.a == 0) {
				backgroundIsNotTransparent = false;
				return;
			}

			backgroundIsNotTransparent = true;

			XSetBackground(display, gc,
				cast(uint) c.r << 16 |
				cast(uint) c.g << 8 |
				cast(uint) c.b);

		}

		void swapColors() {
			auto tmp = _fillColor;
			fillColor = _outlineColor;
			outlineColor = tmp;
		}

		void drawImage(int x, int y, Image i) {
			// source x, source y
			XPutImage(display, d, gc, i.handle, 0, 0, x, y, i.width, i.height);
		}

		void drawPixmap(Sprite s, int x, int y) {
			XCopyArea(display, s.handle, d, gc, 0, 0, s.width, s.height, x, y);
		}

		void drawText(int x, int y, int x2, int y2, string text) {
			import std.string : split;
			foreach(line; text.split("\n")) {
				XDrawString(display, d, gc, x, y + 12, line.ptr, cast(int) line.length);
				y += 16;
			}
		}

		void drawPixel(int x, int y) {
			XDrawPoint(display, d, gc, x, y);
		}

		// The basic shapes, outlined

		void drawLine(int x1, int y1, int x2, int y2) {
			if(foregroundIsNotTransparent)
				XDrawLine(display, d, gc, x1, y1, x2, y2);
		}

		void drawRectangle(int x, int y, int width, int height) {
			if(backgroundIsNotTransparent) {
				swapColors();
				XFillRectangle(display, d, gc, x, y, width, height);
				swapColors();
			}
			if(foregroundIsNotTransparent)
				XDrawRectangle(display, d, gc, x, y, width, height);
		}

		/// Arguments are the points of the bounding rectangle
		void drawEllipse(int x1, int y1, int x2, int y2) {
			drawArc(x1, y1, x2 - x1, y2 - y1, 0, 360 * 64);
		}

		// NOTE: start and finish are in units of degrees * 64
		void drawArc(int x1, int y1, int width, int height, int start, int finish) {
			if(backgroundIsNotTransparent) {
				swapColors();
				XFillArc(display, d, gc, x1, y1, width, height, start, finish);
				swapColors();
			}
			if(foregroundIsNotTransparent)
				XDrawArc(display, d, gc, x1, y1, width, height, start, finish);
		}

		void drawPolygon(Point[] vertexes) {
			XPoint[] points;
			points.length = vertexes.length;

			foreach(i, p; vertexes) {
				points[i].x = cast(short) p.x;
				points[i].y = cast(short) p.y;
			}

			if(backgroundIsNotTransparent) {
				swapColors();
				XFillPolygon(display, d, gc, points.ptr, cast(int) points.length, PolygonShape.Complex, CoordMode.CoordModeOrigin);
				swapColors();
			}
			if(foregroundIsNotTransparent) {
				XDrawLines(display, d, gc, points.ptr, cast(int) points.length, CoordMode.CoordModeOrigin);
			}
		}
	}


	class XDisplayConnection {
		private static Display* display;

		static Display* get(SimpleWindow window = null) {
			// FIXME: this shouldn't even be necessary
			version(with_eventloop)
				if(window !is null)
					this.window = window;
			if(display is null) {
				display = XOpenDisplay(null);
				if(display is null)
					throw new Exception("Unable to open X display");
				version(with_eventloop) {
					import arsd.eventloop;
					addFileEventListeners(display.fd, &eventListener, null, null);
				}
			}

			return display;
		}

		version(with_eventloop) {
			import arsd.eventloop;
			static void eventListener(OsFileHandle fd) {
				while(XPending(display))
					doXNextEvent(window);
			}

			static SimpleWindow window;
		}

		static void close() {
			if(display is null)
				return;

			version(with_eventloop) {
				import arsd.eventloop;
				removeFileEventListeners(display.fd);
			}

			XCloseDisplay(display);
			display = null;
		}
	}

	mixin template NativeImageImplementation() {
		XImage* handle;
		ubyte* rawData;

		void createImage(int width, int height) {
			auto display = XDisplayConnection.get();
			auto screen = DefaultScreen(display);

			// This actually needs to be malloc to avoid a double free error when XDestroyImage is called
			import core.stdc.stdlib : malloc;
			rawData = cast(ubyte*) malloc(width * height * 4);

			handle = XCreateImage(
				display,
				DefaultVisual(display, screen),
				24, // bpp
				ImageFormat.ZPixmap,
				0, // offset
				rawData,
				width, height,
				8 /* FIXME */, 4 * width); // padding, bytes per line
		}

		void dispose() {
			// note: this calls free(rawData) for us
			if(handle)
			XDestroyImage(handle);
		}

		/*
		Color getPixel(int x, int y) {

		}
		*/

		void setPixel(int x, int y, Color c) {
			auto offset = (y * width + x) * 4;
			rawData[offset + 0] = c.b;
			rawData[offset + 1] = c.g;
			rawData[offset + 2] = c.r;
		}

		void convertToRgbaBytes(ubyte[] where) {
			assert(where.length == this.width * this.height * 4);

			// if rawData had a length....
			//assert(rawData.length == where.length);
			for(int idx = 0; idx < where.length; idx += 4) {
				where[idx + 0] = rawData[idx + 2]; // r
				where[idx + 1] = rawData[idx + 1]; // g
				where[idx + 2] = rawData[idx + 0]; // b
				where[idx + 3] = 255; // a
			}
		}

		void setFromRgbaBytes(in ubyte[] where) {
			assert(where.length == this.width * this.height * 4);

			// if rawData had a length....
			//assert(rawData.length == where.length);
			for(int idx = 0; idx < where.length; idx += 4) {
				rawData[idx + 2] = where[idx + 0]; // r
				rawData[idx + 1] = where[idx + 1]; // g
				rawData[idx + 0] = where[idx + 2]; // b
				//rawData[idx + 3] = 255; // a
			}
		}

	}

	mixin template NativeSimpleWindowImplementation() {
		GC gc;
		Window window;
		Display* display;

		Pixmap buffer;

		ScreenPainter getPainter() {
			return ScreenPainter(this, window);
		}

		void createWindow(int width, int height, string title) {
			display = XDisplayConnection.get(this);
			auto screen = DefaultScreen(display);

			window = XCreateSimpleWindow(
				display,
				RootWindow(display, screen),
				0, 0, // x, y
				width, height,
				1, // border width
				BlackPixel(display, screen), // border
				WhitePixel(display, screen)); // background

			XTextProperty windowName;
			windowName.value = title.ptr;
			windowName.encoding = XA_STRING;
			windowName.format = 8;
			windowName.nitems = cast(uint) title.length;

			XSetWMName(display, window, &windowName);

			buffer = XCreatePixmap(display, cast(Drawable) window, width, height, 24);

			gc = DefaultGC(display, screen);

			// clear out the buffer to get us started...
			XSetForeground(display, gc, WhitePixel(display, screen));
			XFillRectangle(display, cast(Drawable) buffer, gc, 0, 0, width, height);
			XSetForeground(display, gc, BlackPixel(display, screen));

			// This gives our window a close button
			Atom atom = XInternAtom(display, "WM_DELETE_WINDOW".ptr, true); // FIXME: does this need to be freed?
			XSetWMProtocols(display, window, &atom, 1);

			XMapWindow(display, window);

			XSelectInput(display, window,
				EventMask.ExposureMask |
				EventMask.KeyPressMask |
				EventMask.StructureNotifyMask
				| EventMask.PointerMotionMask // FIXME: not efficient
				| EventMask.ButtonPressMask
				| EventMask.ButtonReleaseMask
			);

			XFlush(display);
		}

		void closeWindow() {
			XFreePixmap(display, buffer);
			XDestroyWindow(display, window);
			XFlush(display);
		}

		void dispose() {
		}

		bool destroyed = false;

		int eventLoop(long pulseTimeout) {
			bool done = false;
			import core.thread;

			while (!done) {
			while(!done &&
				(pulseTimeout == 0 || (XPending(display) > 0)))
			{
				done = doXNextEvent(this); // FIXME: what about multiple windows? This wasn't originally going to support them but maybe I should
			}
				if(!done && pulseTimeout !=0) {
					if(handlePulse !is null)
						handlePulse();
					Thread.sleep(dur!"msecs"(pulseTimeout));
				}
			}

			return 0;
		}
	}
}

version(X11) {
	bool doXNextEvent(SimpleWindow t) {
		bool done;
		XEvent e;
		XNextEvent(t.display, &e);

		version(with_eventloop)
			import arsd.eventloop;

		switch(e.type) {
		  case EventType.Expose:
			XCopyArea(t.display, cast(Drawable) t.buffer, cast(Drawable) t.window, t.gc, 0, 0, t.width, t.height, 0, 0);
		  break;
		  case EventType.ClientMessage: // User clicked the close button
		  case EventType.DestroyNotify:
			done = true;
			t.destroyed = true;
			version(with_eventloop)
				exit();
		  break;

		  case EventType.MotionNotify:
			MouseEvent mouse;
			auto event = e.xmotion;

			mouse.type = 0;
			mouse.x = event.x;
			mouse.y = event.y;
			mouse.buttonFlags = event.state;

			if(t.handleMouseEvent)
				t.handleMouseEvent(mouse);
		  	version(with_eventloop)
				send(mouse);
		  break;
		  case EventType.ButtonPress:
		  case EventType.ButtonRelease:
			MouseEvent mouse;
			auto event = e.xbutton;

			mouse.type = e.type == EventType.ButtonPress ? 1 : 2;
			mouse.x = event.x;
			mouse.y = event.y;
			mouse.button = event.button;
			//mouse.buttonFlags = event.detail;

			if(t.handleMouseEvent)
				t.handleMouseEvent(mouse);
			version(with_eventloop)
				send(mouse);
		  break;

		  case EventType.KeyPress:
			auto ch = cast(dchar) XKeycodeToKeysym(
				XDisplayConnection.get(),
				e.xkey.keycode,
				0); // FIXME: we should check shift, etc. too, so it matches Windows' behavior better

			if(t.handleCharEvent)
				t.handleCharEvent(ch);
			version(with_eventloop)
				send(ch);
		  goto case;
		  case EventType.KeyRelease:
			if(t.handleKeyEvent)
				t.handleKeyEvent(e.xkey.keycode, e.type == EventType.ButtonPress);

			version(with_eventloop)
				send(KeyEvent(e.xkey.keycode, e.type == EventType.ButtonPress));
		  break;
		  default:
		}

		return done;
	}
}

/* *************************************** */
/*      Done with simpledisplay stuff      */
/* *************************************** */

// Necessary C library bindings follow

version(Windows) {
	import core.sys.windows.windows;

	pragma(lib, "gdi32");

	extern(Windows) {
		// The included D headers are incomplete, finish them here
		// enough that this module works.
		alias GetObjectA GetObject;
		alias GetMessageA GetMessage;
		alias PeekMessageA PeekMessage;
		alias TextOutA TextOut;
		alias DispatchMessageA DispatchMessage;
		alias GetModuleHandleA GetModuleHandle;
		alias LoadCursorA LoadCursor;
		alias LoadIconA LoadIcon;
		alias RegisterClassA RegisterClass;
		alias CreateWindowA CreateWindow;
		alias DefWindowProcA DefWindowProc;
		alias DrawTextA DrawText;

		bool MoveWindow(HWND hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
		HBITMAP CreateDIBSection(HDC, const BITMAPINFO*, uint, void**, HANDLE hSection, DWORD);
		bool BitBlt(HDC hdcDest, int nXDest, int nYDest, int nWidth, int nHeight, HDC hdcSrc, int nXSrc, int nYSrc, DWORD dwRop);
		bool DestroyWindow(HWND);
		int DrawTextA(HDC hDC, LPCTSTR lpchText, int nCount, LPRECT lpRect, UINT uFormat);
		bool Rectangle(HDC, int, int, int, int);
		bool Ellipse(HDC, int, int, int, int);
		bool Arc(HDC, int, int, int, int, int, int, int, int);
		bool Polygon(HDC, POINT*, int);
		HBRUSH CreateSolidBrush(COLORREF);

		HBITMAP CreateCompatibleBitmap(HDC, int, int);

		uint SetTimer(HWND, uint, uint, void*);
		bool KillTimer(HWND, uint);


		enum BI_RGB = 0;
		enum DIB_RGB_COLORS = 0;
		enum DT_LEFT = 0;
		enum TRANSPARENT = 1;

	}

}

else version(X11) {

// X11 bindings needed here
/*
	A little of this is from the bindings project on
	D Source and some of it is copy/paste from the C
	header.

	The DSource listing consistently used D's long
	where C used long. That's wrong - C long is 32 bit, so
	it should be int in D. I changed that here.

	Note:
	This isn't complete, just took what I needed for myself.
*/

pragma(lib, "X11");

extern(C):


KeySym XKeycodeToKeysym(
    Display*		/* display */,
    KeyCode		/* keycode */,
    int			/* index */
);

Display* XOpenDisplay(const char*);
int XCloseDisplay(Display*);


enum MappingType:int {
	MappingModifier		=0,
	MappingKeyboard		=1,
	MappingPointer		=2
}

/* ImageFormat -- PutImage, GetImage */
enum ImageFormat:int {
	XYBitmap	=0,	/* depth 1, XYFormat */
	XYPixmap	=1,	/* depth == drawable depth */
	ZPixmap	=2	/* depth == drawable depth */
}

enum ModifierName:int {
	ShiftMapIndex	=0,
	LockMapIndex	=1,
	ControlMapIndex	=2,
	Mod1MapIndex	=3,
	Mod2MapIndex	=4,
	Mod3MapIndex	=5,
	Mod4MapIndex	=6,
	Mod5MapIndex	=7
}

enum ButtonMask:int {
	Button1Mask	=1<<8,
	Button2Mask	=1<<9,
	Button3Mask	=1<<10,
	Button4Mask	=1<<11,
	Button5Mask	=1<<12,
	AnyModifier	=1<<15/* used in GrabButton, GrabKey */
}

enum KeyOrButtonMask:uint {
	ShiftMask	=1<<0,
	LockMask	=1<<1,
	ControlMask	=1<<2,
	Mod1Mask	=1<<3,
	Mod2Mask	=1<<4,
	Mod3Mask	=1<<5,
	Mod4Mask	=1<<6,
	Mod5Mask	=1<<7,
	Button1Mask	=1<<8,
	Button2Mask	=1<<9,
	Button3Mask	=1<<10,
	Button4Mask	=1<<11,
	Button5Mask	=1<<12,
	AnyModifier	=1<<15/* used in GrabButton, GrabKey */
}

enum ButtonName:int {
	Button1	=1,
	Button2	=2,
	Button3	=3,
	Button4	=4,
	Button5	=5
}

/* Notify modes */
enum NotifyModes:int
{
	NotifyNormal		=0,
	NotifyGrab			=1,
	NotifyUngrab		=2,
	NotifyWhileGrabbed	=3
}
const int NotifyHint	=1;	/* for MotionNotify events */

/* Notify detail */
enum NotifyDetail:int
{
	NotifyAncestor			=0,
	NotifyVirtual			=1,
	NotifyInferior			=2,
	NotifyNonlinear			=3,
	NotifyNonlinearVirtual	=4,
	NotifyPointer			=5,
	NotifyPointerRoot		=6,
	NotifyDetailNone		=7
}

/* Visibility notify */

enum VisibilityNotify:int
{
VisibilityUnobscured		=0,
VisibilityPartiallyObscured	=1,
VisibilityFullyObscured		=2
}


enum WindowStackingMethod:int
{
	Above		=0,
	Below		=1,
	TopIf		=2,
	BottomIf	=3,
	Opposite	=4
}

/* Circulation request */
enum CirculationRequest:int
{
	PlaceOnTop		=0,
	PlaceOnBottom	=1
}

enum PropertyNotification:int
{
	PropertyNewValue	=0,
	PropertyDelete		=1
}

enum ColorMapNotification:int
{
	ColormapUninstalled	=0,
	ColormapInstalled		=1
}


	struct _XPrivate {}
	struct _XrmHashBucketRec {}

	alias void* XPointer;
	alias void* XExtData;

	version( X86_64 ) {
		alias ulong XID;
		alias ulong arch_ulong;
	} else {
		alias uint XID;
		alias uint arch_ulong;
	}

	alias XID Window;
	alias XID Drawable;
	alias XID Pixmap;

	alias arch_ulong Atom;
	alias bool Bool;
	alias Display XDisplay;

	alias int ByteOrder;
	alias arch_ulong Time;
	alias void ScreenFormat;

	struct XImage {
	    int width, height;			/* size of image */
	    int xoffset;				/* number of pixels offset in X direction */
	    ImageFormat format;		/* XYBitmap, XYPixmap, ZPixmap */
	    void *data;					/* pointer to image data */
	    ByteOrder byte_order;		/* data byte order, LSBFirst, MSBFirst */
	    int bitmap_unit;			/* quant. of scanline 8, 16, 32 */
	    int bitmap_bit_order;		/* LSBFirst, MSBFirst */
	    int bitmap_pad;			/* 8, 16, 32 either XY or ZPixmap */
	    int depth;					/* depth of image */
	    int bytes_per_line;			/* accelarator to next line */
	    int bits_per_pixel;			/* bits per pixel (ZPixmap) */
	    arch_ulong red_mask;	/* bits in z arrangment */
	    arch_ulong green_mask;
	    arch_ulong blue_mask;
	    XPointer obdata;			/* hook for the object routines to hang on */
	    struct F {				/* image manipulation routines */
			XImage* function(
				XDisplay* 			/* display */,
				Visual*				/* visual */,
				uint				/* depth */,
				int					/* format */,
				int					/* offset */,
				byte*				/* data */,
				uint				/* width */,
				uint				/* height */,
				int					/* bitmap_pad */,
				int					/* bytes_per_line */) create_image;
			int  function(XImage *)destroy_image;
			arch_ulong function(XImage *, int, int)get_pixel;
			int  function(XImage *, int, int, uint)put_pixel;
			XImage function(XImage *, int, int, uint, uint)sub_image;
			int function(XImage *, int)add_pixel;
		}

		F f;
	}
	version(X86_64) static assert(XImage.sizeof == 136);


/*
 * Definitions of specific events.
 */
struct XKeyEvent
{
	int type;			/* of event */
	arch_ulong serial;		/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window window;	        /* "event" window it is reported relative to */
	Window root;	        /* root window that the event occurred on */
	Window subwindow;	/* child window */
	Time time;		/* milliseconds */
	int x, y;		/* pointer x, y coordinates in event window */
	int x_root, y_root;	/* coordinates relative to root */
	KeyOrButtonMask state;	/* key or button mask */
	uint keycode;	/* detail */
	Bool same_screen;	/* same screen flag */
}
version(X86_64) static assert(XKeyEvent.sizeof == 96);
alias XKeyEvent XKeyPressedEvent;
alias XKeyEvent XKeyReleasedEvent;

struct XButtonEvent
{
	int type;		/* of event */
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window window;	        /* "event" window it is reported relative to */
	Window root;	        /* root window that the event occurred on */
	Window subwindow;	/* child window */
	Time time;		/* milliseconds */
	int x, y;		/* pointer x, y coordinates in event window */
	int x_root, y_root;	/* coordinates relative to root */
	KeyOrButtonMask state;	/* key or button mask */
	uint button;	/* detail */
	Bool same_screen;	/* same screen flag */
}
alias XButtonEvent XButtonPressedEvent;
alias XButtonEvent XButtonReleasedEvent;

struct XMotionEvent{
	int type;		/* of event */
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window window;	        /* "event" window reported relative to */
	Window root;	        /* root window that the event occurred on */
	Window subwindow;	/* child window */
	Time time;		/* milliseconds */
	int x, y;		/* pointer x, y coordinates in event window */
	int x_root, y_root;	/* coordinates relative to root */
	KeyOrButtonMask state;	/* key or button mask */
	byte is_hint;		/* detail */
	Bool same_screen;	/* same screen flag */
}
alias XMotionEvent XPointerMovedEvent;

struct XCrossingEvent{
	int type;		/* of event */
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window window;	        /* "event" window reported relative to */
	Window root;	        /* root window that the event occurred on */
	Window subwindow;	/* child window */
	Time time;		/* milliseconds */
	int x, y;		/* pointer x, y coordinates in event window */
	int x_root, y_root;	/* coordinates relative to root */
	NotifyModes mode;		/* NotifyNormal, NotifyGrab, NotifyUngrab */
	NotifyDetail detail;
	/*
	 * NotifyAncestor, NotifyVirtual, NotifyInferior,
	 * NotifyNonlinear,NotifyNonlinearVirtual
	 */
	Bool same_screen;	/* same screen flag */
	Bool focus;		/* Boolean focus */
	KeyOrButtonMask state;	/* key or button mask */
}
alias XCrossingEvent XEnterWindowEvent;
alias XCrossingEvent XLeaveWindowEvent;

struct XFocusChangeEvent{
	int type;		/* FocusIn or FocusOut */
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window window;		/* window of event */
	NotifyModes mode;		/* NotifyNormal, NotifyWhileGrabbed,
				   NotifyGrab, NotifyUngrab */
	NotifyDetail detail;
	/*
	 * NotifyAncestor, NotifyVirtual, NotifyInferior,
	 * NotifyNonlinear,NotifyNonlinearVirtual, NotifyPointer,
	 * NotifyPointerRoot, NotifyDetailNone
	 */
}
alias XFocusChangeEvent XFocusInEvent;
alias XFocusChangeEvent XFocusOutEvent;
Window XCreateSimpleWindow(
    Display*	/* display */,
    Window		/* parent */,
    int			/* x */,
    int			/* y */,
    uint		/* width */,
    uint		/* height */,
    uint		/* border_width */,
    uint		/* border */,
    uint		/* background */
);

XImage *XCreateImage(
    Display*		/* display */,
    Visual*		/* visual */,
    uint	/* depth */,
    int			/* format */,
    int			/* offset */,
    ubyte*		/* data */,
    uint	/* width */,
    uint	/* height */,
    int			/* bitmap_pad */,
    int			/* bytes_per_line */
);

Atom XInternAtom(
    Display*		/* display */,
    const char*	/* atom_name */,
    Bool		/* only_if_exists */
);

alias int Status;


enum EventMask:int
{
	NoEventMask				=0,
	KeyPressMask			=1<<0,
	KeyReleaseMask			=1<<1,
	ButtonPressMask			=1<<2,
	ButtonReleaseMask		=1<<3,
	EnterWindowMask			=1<<4,
	LeaveWindowMask			=1<<5,
	PointerMotionMask		=1<<6,
	PointerMotionHintMask	=1<<7,
	Button1MotionMask		=1<<8,
	Button2MotionMask		=1<<9,
	Button3MotionMask		=1<<10,
	Button4MotionMask		=1<<11,
	Button5MotionMask		=1<<12,
	ButtonMotionMask		=1<<13,
	KeymapStateMask		=1<<14,
	ExposureMask			=1<<15,
	VisibilityChangeMask	=1<<16,
	StructureNotifyMask		=1<<17,
	ResizeRedirectMask		=1<<18,
	SubstructureNotifyMask	=1<<19,
	SubstructureRedirectMask=1<<20,
	FocusChangeMask			=1<<21,
	PropertyChangeMask		=1<<22,
	ColormapChangeMask		=1<<23,
	OwnerGrabButtonMask		=1<<24
}

int XPutImage(
    Display*	/* display */,
    Drawable	/* d */,
    GC			/* gc */,
    XImage*	/* image */,
    int			/* src_x */,
    int			/* src_y */,
    int			/* dest_x */,
    int			/* dest_y */,
    uint		/* width */,
    uint		/* height */
);

int XDestroyWindow(
    Display*	/* display */,
    Window		/* w */
);

int XDestroyImage(
	XImage*);

int XSelectInput(
    Display*	/* display */,
    Window		/* w */,
    EventMask	/* event_mask */
);

int XMapWindow(
    Display*	/* display */,
    Window		/* w */
);

int XNextEvent(
    Display*	/* display */,
    XEvent*		/* event_return */
);

Status XSetWMProtocols(
    Display*	/* display */,
    Window		/* w */,
    Atom*		/* protocols */,
    int			/* count */
);

enum EventType:int
{
	KeyPress			=2,
	KeyRelease			=3,
	ButtonPress			=4,
	ButtonRelease		=5,
	MotionNotify		=6,
	EnterNotify			=7,
	LeaveNotify			=8,
	FocusIn				=9,
	FocusOut			=10,
	KeymapNotify		=11,
	Expose				=12,
	GraphicsExpose		=13,
	NoExpose			=14,
	VisibilityNotify	=15,
	CreateNotify		=16,
	DestroyNotify		=17,
	UnmapNotify		=18,
	MapNotify			=19,
	MapRequest			=20,
	ReparentNotify		=21,
	ConfigureNotify		=22,
	ConfigureRequest	=23,
	GravityNotify		=24,
	ResizeRequest		=25,
	CirculateNotify		=26,
	CirculateRequest	=27,
	PropertyNotify		=28,
	SelectionClear		=29,
	SelectionRequest	=30,
	SelectionNotify		=31,
	ColormapNotify		=32,
	ClientMessage		=33,
	MappingNotify		=34,
	LASTEvent			=35	/* must be bigger than any event # */
}
/* generated on EnterWindow and FocusIn  when KeyMapState selected */
struct XKeymapEvent
{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window window;
	byte key_vector[32];
}

struct XExposeEvent
{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window window;
	int x, y;
	int width, height;
	int count;		/* if non-zero, at least this many more */
}

struct XGraphicsExposeEvent{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Drawable drawable;
	int x, y;
	int width, height;
	int count;		/* if non-zero, at least this many more */
	int major_code;		/* core is CopyArea or CopyPlane */
	int minor_code;		/* not defined in the core */
}

struct XNoExposeEvent{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Drawable drawable;
	int major_code;		/* core is CopyArea or CopyPlane */
	int minor_code;		/* not defined in the core */
}

struct XVisibilityEvent{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window window;
	VisibilityNotify state;		/* Visibility state */
}

struct XCreateWindowEvent{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window parent;		/* parent of the window */
	Window window;		/* window id of window created */
	int x, y;		/* window location */
	int width, height;	/* size of window */
	int border_width;	/* border width */
	Bool override_redirect;	/* creation should be overridden */
}

struct XDestroyWindowEvent
{
	int type;
	arch_ulong serial;		/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window event;
	Window window;
}

struct XUnmapEvent
{
	int type;
	arch_ulong serial;		/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window event;
	Window window;
	Bool from_configure;
}

struct XMapEvent
{
	int type;
	arch_ulong serial;		/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window event;
	Window window;
	Bool override_redirect;	/* Boolean, is override set... */
}

struct XMapRequestEvent
{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window parent;
	Window window;
}

struct XReparentEvent
{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window event;
	Window window;
	Window parent;
	int x, y;
	Bool override_redirect;
}

struct XConfigureEvent
{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window event;
	Window window;
	int x, y;
	int width, height;
	int border_width;
	Window above;
	Bool override_redirect;
}

struct XGravityEvent
{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window event;
	Window window;
	int x, y;
}

struct XResizeRequestEvent
{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window window;
	int width, height;
}

struct  XConfigureRequestEvent
{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window parent;
	Window window;
	int x, y;
	int width, height;
	int border_width;
	Window above;
	WindowStackingMethod detail;		/* Above, Below, TopIf, BottomIf, Opposite */
	arch_ulong value_mask;
}

struct XCirculateEvent
{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window event;
	Window window;
	CirculationRequest place;		/* PlaceOnTop, PlaceOnBottom */
}

struct XCirculateRequestEvent
{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window parent;
	Window window;
	CirculationRequest place;		/* PlaceOnTop, PlaceOnBottom */
}

struct XPropertyEvent
{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window window;
	Atom atom;
	Time time;
	PropertyNotification state;		/* NewValue, Deleted */
}

struct XSelectionClearEvent
{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window window;
	Atom selection;
	Time time;
}

struct XSelectionRequestEvent
{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window owner;
	Window requestor;
	Atom selection;
	Atom target;
	Atom property;
	Time time;
}

struct XSelectionEvent
{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window requestor;
	Atom selection;
	Atom target;
	Atom property;		/* ATOM or None */
	Time time;
}
version(X86_64) static assert(XSelectionClearEvent.sizeof == 56);

struct XColormapEvent
{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window window;
	Colormap colormap;	/* COLORMAP or None */
	Bool new_;		/* C++ */
	ColorMapNotification state;		/* ColormapInstalled, ColormapUninstalled */
}
version(X86_64) static assert(XColormapEvent.sizeof == 56);

struct XClientMessageEvent
{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window window;
	Atom message_type;
	int format;
	union Data{
		byte b[20];
		short s[10];
		arch_ulong l[5];
	}
	Data data;
	
}
version(X86_64) static assert(XClientMessageEvent.sizeof == 96);

struct XMappingEvent
{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;	/* Display the event was read from */
	Window window;		/* unused */
	MappingType request;		/* one of MappingModifier, MappingKeyboard,
				   MappingPointer */
	int first_keycode;	/* first keycode */
	int count;		/* defines range of change w. first_keycode*/
}

struct XErrorEvent
{
	int type;
	Display *display;	/* Display the event was read from */
	XID resourceid;		/* resource id */
	arch_ulong serial;	/* serial number of failed request */
	ubyte error_code;	/* error code of failed request */
	ubyte request_code;	/* Major op-code of failed request */
	ubyte minor_code;	/* Minor op-code of failed request */
}

struct XAnyEvent
{
	int type;
	arch_ulong serial;	/* # of last request processed by server */
	Bool send_event;	/* true if this came from a SendEvent request */
	Display *display;/* Display the event was read from */
	Window window;	/* window on which event was requested in event mask */
}

union XEvent{
    int type;		/* must not be changed; first element */
	XAnyEvent xany;
	XKeyEvent xkey;
	XButtonEvent xbutton;
	XMotionEvent xmotion;
	XCrossingEvent xcrossing;
	XFocusChangeEvent xfocus;
	XExposeEvent xexpose;
	XGraphicsExposeEvent xgraphicsexpose;
	XNoExposeEvent xnoexpose;
	XVisibilityEvent xvisibility;
	XCreateWindowEvent xcreatewindow;
	XDestroyWindowEvent xdestroywindow;
	XUnmapEvent xunmap;
	XMapEvent xmap;
	XMapRequestEvent xmaprequest;
	XReparentEvent xreparent;
	XConfigureEvent xconfigure;
	XGravityEvent xgravity;
	XResizeRequestEvent xresizerequest;
	XConfigureRequestEvent xconfigurerequest;
	XCirculateEvent xcirculate;
	XCirculateRequestEvent xcirculaterequest;
	XPropertyEvent xproperty;
	XSelectionClearEvent xselectionclear;
	XSelectionRequestEvent xselectionrequest;
	XSelectionEvent xselection;
	XColormapEvent xcolormap;
	XClientMessageEvent xclient;
	XMappingEvent xmapping;
	XErrorEvent xerror;
	XKeymapEvent xkeymap;
	arch_ulong pad[24];
}


	struct Display {
		XExtData *ext_data;	/* hook for extension to hang data */
		_XPrivate *private1;
		int fd;			/* Network socket. */
		int private2;
		int proto_major_version;/* major version of server's X protocol */
		int proto_minor_version;/* minor version of servers X protocol */
		char *vendor;		/* vendor of the server hardware */
	    	XID private3;
		XID private4;
		XID private5;
		int private6;
		XID function(Display*)resource_alloc;/* allocator function */
		ByteOrder byte_order;		/* screen byte order, LSBFirst, MSBFirst */
		int bitmap_unit;	/* padding and data requirements */
		int bitmap_pad;		/* padding requirements on bitmaps */
		ByteOrder bitmap_bit_order;	/* LeastSignificant or MostSignificant */
		int nformats;		/* number of pixmap formats in list */
		ScreenFormat *pixmap_format;	/* pixmap format list */
		int private8;
		int release;		/* release of the server */
		_XPrivate *private9;
		_XPrivate *private10;
		int qlen;		/* Length of input event queue */
		arch_ulong last_request_read; /* seq number of last event read */
		arch_ulong request;	/* sequence number of last request. */
		XPointer private11;
		XPointer private12;
		XPointer private13;
		XPointer private14;
		uint max_request_size; /* maximum number 32 bit words in request*/
		_XrmHashBucketRec *db;
		int function  (Display*)private15;
		char *display_name;	/* "host:display" string used on this connect*/
		int default_screen;	/* default screen for operations */
		int nscreens;		/* number of screens on this server*/
		Screen *screens;	/* pointer to list of screens */
		arch_ulong motion_buffer;	/* size of motion buffer */
		arch_ulong private16;
		int min_keycode;	/* minimum defined keycode */
		int max_keycode;	/* maximum defined keycode */
		XPointer private17;
		XPointer private18;
		int private19;
		byte *xdefaults;	/* contents of defaults from server */
		/* there is more to this structure, but it is private to Xlib */
	}

	// I got these numbers from a C program as a sanity test
	version(X86_64) {
		static assert(Display.sizeof == 296);
		static assert(XPointer.sizeof == 8);
		static assert(XErrorEvent.sizeof == 40);
		static assert(XAnyEvent.sizeof == 40);
		static assert(XMappingEvent.sizeof == 56);
		static assert(XEvent.sizeof == 192);
	} else {
		static assert(Display.sizeof == 176);
		static assert(XPointer.sizeof == 4);
		static assert(XEvent.sizeof == 96);
	}

struct Depth
{
	int depth;		/* this depth (Z) of the depth */
	int nvisuals;		/* number of Visual types at this depth */
	Visual *visuals;	/* list of visuals possible at this depth */
}

alias void* GC;
alias int VisualID;
alias XID Colormap;
alias XID KeySym;
alias uint KeyCode;

struct Screen{
	XExtData *ext_data;		/* hook for extension to hang data */
	Display *display;		/* back pointer to display structure */
	Window root;			/* Root window id. */
	int width, height;		/* width and height of screen */
	int mwidth, mheight;	/* width and height of  in millimeters */
	int ndepths;			/* number of depths possible */
	Depth *depths;			/* list of allowable depths on the screen */
	int root_depth;			/* bits per pixel */
	Visual *root_visual;	/* root visual */
	GC default_gc;			/* GC for the root root visual */
	Colormap cmap;			/* default color map */
	uint white_pixel;
	uint black_pixel;		/* White and Black pixel values */
	int max_maps, min_maps;	/* max and min color maps */
	int backing_store;		/* Never, WhenMapped, Always */
	bool save_unders;
	int root_input_mask;	/* initial root input mask */
}

struct Visual
{
	XExtData *ext_data;	/* hook for extension to hang data */
	VisualID visualid;	/* visual id of this visual */
	int class_;			/* class of screen (monochrome, etc.) */
	uint red_mask, green_mask, blue_mask;	/* mask values */
	int bits_per_rgb;	/* log base 2 of distinct color values */
	int map_entries;	/* color map entries */
}

	alias Display* _XPrivDisplay;

	Screen* ScreenOfDisplay(Display* dpy, int scr) {
		assert(dpy !is null);
		return &dpy.screens[scr];
	}

	Window	RootWindow(Display *dpy,int scr) {
		return ScreenOfDisplay(dpy,scr).root;
	}

	int DefaultScreen(Display *dpy) {
		return dpy.default_screen;
	}

	Visual* DefaultVisual(Display *dpy,int scr) {
		return ScreenOfDisplay(dpy,scr).root_visual;
	}

	GC DefaultGC(Display *dpy,int scr) {
		return ScreenOfDisplay(dpy,scr).default_gc;
	}

	uint BlackPixel(Display *dpy,int scr) {
		return ScreenOfDisplay(dpy,scr).black_pixel;
	}

	uint WhitePixel(Display *dpy,int scr) {
		return ScreenOfDisplay(dpy,scr).white_pixel;
	}

	// check out Xft too: http://www.keithp.com/~keithp/render/Xft.tutorial
	int XDrawString(Display*, Drawable, GC, int, int, in char*, int);
	int XDrawLine(Display*, Drawable, GC, int, int, int, int);
	int XDrawRectangle(Display*, Drawable, GC, int, int, uint, uint);
	int XDrawArc(Display*, Drawable, GC, int, int, uint, uint, int, int);
	int XFillRectangle(Display*, Drawable, GC, int, int, uint, uint);
	int XFillArc(Display*, Drawable, GC, int, int, uint, uint, int, int);
	int XDrawPoint(Display*, Drawable, GC, int, int);
	int XSetForeground(Display*, GC, uint);
	int XSetBackground(Display*, GC, uint);

	GC XCreateGC(Display*, Drawable, uint, void*);
	int XCopyGC(Display*, GC, uint, GC);
	int XFreeGC(Display*, GC);

	bool XCheckWindowEvent(Display*, Window, int, XEvent*);
	bool XCheckMaskEvent(Display*, int, XEvent*);

	int XPending(Display*);

	Pixmap XCreatePixmap(Display*, Drawable, uint, uint, uint);
	int XFreePixmap(Display*, Pixmap);
	int XCopyArea(Display*, Drawable, Drawable, GC, int, int, uint, uint, int, int);
	int XFlush(Display*);
	int XSync(Display*, bool);

	struct XPoint {
		short x;
		short y;
	}

	int XDrawLines(Display*, Drawable, GC, XPoint*, int, CoordMode);
	int XFillPolygon(Display*, Drawable, GC, XPoint*, int, PolygonShape, CoordMode);

	enum CoordMode:int {
		CoordModeOrigin = 0,
		CoordModePrevious = 1
	}

	enum PolygonShape:int {
		Complex = 0,
		Nonconvex = 1,
		Convex = 2
	}

	struct XTextProperty {
		const(char)* value;		/* same as Property routines */
		Atom encoding;			/* prop type */
		int format;				/* prop data format: 8, 16, or 32 */
		arch_ulong nitems;		/* number of data items in value */
	}

	version( X86_64 ) {
		static assert(XTextProperty.sizeof == 32);
	}

	void XSetWMName(Display*, Window, XTextProperty*);

	enum Atom XA_STRING = 31;


 } else version (OSXCocoa) {
private:
    alias void* id;
    alias void* Class;
    alias void* SEL;
    alias void* IMP;
    alias void* Ivar;
    alias byte BOOL;
    alias const(void)* CFStringRef;
    alias const(void)* CFAllocatorRef;
    alias const(void)* CFTypeRef;
    alias const(void)* CGContextRef;
    alias const(void)* CGColorSpaceRef;
    alias const(void)* CGImageRef;
    alias uint CGBitmapInfo;
    
    struct objc_super {
        id self;
        Class superclass;
    }
    
    struct CFRange {
        int location, length;
    }

    struct NSPoint {
        float x, y;
        
        static fromTuple(T)(T tupl) {
            return NSPoint(tupl.tupleof);
        }
    }
    struct NSSize {
        float width, height;
    }
    struct NSRect {
        NSPoint origin;
        NSSize size;
    }
    alias NSPoint CGPoint;
    alias NSSize CGSize;
    alias NSRect CGRect;

    struct CGAffineTransform {
        float a, b, c, d, tx, ty;
    }

    enum NSApplicationActivationPolicyRegular = 0;
    enum NSBackingStoreBuffered = 2;
    enum kCFStringEncodingUTF8 = 0x08000100;

    enum : size_t {
        NSBorderlessWindowMask = 0,
        NSTitledWindowMask = 1 << 0,
        NSClosableWindowMask = 1 << 1,
        NSMiniaturizableWindowMask = 1 << 2,
        NSResizableWindowMask = 1 << 3,
        NSTexturedBackgroundWindowMask = 1 << 8
    }
    
    enum : uint {
        kCGImageAlphaNone,
        kCGImageAlphaPremultipliedLast,
        kCGImageAlphaPremultipliedFirst,
        kCGImageAlphaLast,
        kCGImageAlphaFirst,
        kCGImageAlphaNoneSkipLast,
        kCGImageAlphaNoneSkipFirst
    }
    enum : uint {
        kCGBitmapAlphaInfoMask = 0x1F,
        kCGBitmapFloatComponents = (1 << 8),
        kCGBitmapByteOrderMask = 0x7000,
        kCGBitmapByteOrderDefault = (0 << 12),
        kCGBitmapByteOrder16Little = (1 << 12),
        kCGBitmapByteOrder32Little = (2 << 12),
        kCGBitmapByteOrder16Big = (3 << 12),
        kCGBitmapByteOrder32Big = (4 << 12)
    }
    enum CGPathDrawingMode {
        kCGPathFill,
        kCGPathEOFill,
        kCGPathStroke,
        kCGPathFillStroke,
        kCGPathEOFillStroke
    }
    enum objc_AssociationPolicy : size_t {
        OBJC_ASSOCIATION_ASSIGN = 0,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC = 1,
        OBJC_ASSOCIATION_COPY_NONATOMIC = 3,
        OBJC_ASSOCIATION_RETAIN = 0x301, //01401,
        OBJC_ASSOCIATION_COPY = 0x303 //01403
    };

    extern(C) {
        id objc_msgSend(id receiver, SEL selector, ...);
        id objc_msgSendSuper(objc_super* superStruct, SEL selector, ...);
        id objc_getClass(const(char)* name);
        SEL sel_registerName(const(char)* str);
        Class objc_allocateClassPair(Class superclass, const(char)* name,
                                     size_t extra_bytes);
        void objc_registerClassPair(Class cls);
        BOOL class_addMethod(Class cls, SEL name, IMP imp, const(char)* types);
        id objc_getAssociatedObject(id object, void* key);
        void objc_setAssociatedObject(id object, void* key, id value,
                                      objc_AssociationPolicy policy);
        Ivar class_getInstanceVariable(Class cls, const(char)* name);
        id object_getIvar(id object, Ivar ivar);
        void object_setIvar(id object, Ivar ivar, id value);
        BOOL class_addIvar(Class cls, const(char)* name,
                           size_t size, ubyte alignment, const(char)* types);

        extern __gshared id NSApp;
            
        void CFRelease(CFTypeRef obj);
            
        CFStringRef CFStringCreateWithBytes(CFAllocatorRef allocator,
                                            const(char)* bytes, int numBytes,
                                            int encoding,
                                            BOOL isExternalRepresentation);
        int CFStringGetBytes(CFStringRef theString, CFRange range, int encoding,
                             char lossByte, bool isExternalRepresentation,
                             char* buffer, int maxBufLen, int* usedBufLen);
        int CFStringGetLength(CFStringRef theString);
        
        CGContextRef CGBitmapContextCreate(void* data,
                                           size_t width, size_t height,
                                           size_t bitsPerComponent,
                                           size_t bytesPerRow,
                                           CGColorSpaceRef colorspace,
                                           CGBitmapInfo bitmapInfo);
        void CGContextRelease(CGContextRef c);
        ubyte* CGBitmapContextGetData(CGContextRef c);
        CGImageRef CGBitmapContextCreateImage(CGContextRef c);
        size_t CGBitmapContextGetWidth(CGContextRef c);
        size_t CGBitmapContextGetHeight(CGContextRef c);
                
        CGColorSpaceRef CGColorSpaceCreateDeviceRGB();
        void CGColorSpaceRelease(CGColorSpaceRef cs);
        
        void CGContextSetRGBStrokeColor(CGContextRef c,
                                        float red, float green, float blue,
                                        float alpha);
        void CGContextSetRGBFillColor(CGContextRef c,
                                      float red, float green, float blue,
                                      float alpha);
        void CGContextDrawImage(CGContextRef c, CGRect rect, CGImageRef image);
        void CGContextShowTextAtPoint(CGContextRef c, float x, float y,
                                      const(char)* str, size_t length);
        void CGContextStrokeLineSegments(CGContextRef c,
                                         const(CGPoint)* points, size_t count);
        
        void CGContextBeginPath(CGContextRef c);
        void CGContextDrawPath(CGContextRef c, CGPathDrawingMode mode);
        void CGContextAddEllipseInRect(CGContextRef c, CGRect rect);
        void CGContextAddArc(CGContextRef c, float x, float y, float radius,
                             float startAngle, float endAngle, int clockwise);
        void CGContextAddRect(CGContextRef c, CGRect rect);
        void CGContextAddLines(CGContextRef c,
                               const(CGPoint)* points, size_t count);
        void CGContextSaveGState(CGContextRef c);
        void CGContextRestoreGState(CGContextRef c);
        void CGContextSelectFont(CGContextRef c, const(char)* name, float size,
                                 uint textEncoding);
        CGAffineTransform CGContextGetTextMatrix(CGContextRef c);
        void CGContextSetTextMatrix(CGContextRef c, CGAffineTransform t);
        
        void CGImageRelease(CGImageRef image);
    }
    
private:
    // A convenient method to create a CFString (=NSString) from a D string.
    CFStringRef createCFString(string str) {
        return CFStringCreateWithBytes(null, str.ptr, str.length,
                                             kCFStringEncodingUTF8, false);
    }
    
    // Objective-C calls.
    RetType objc_msgSend_specialized(string selector, RetType, T...)(id self, T args) {
        auto _cmd = sel_registerName(selector.ptr);
        alias extern(C) RetType function(id, SEL, T) ExpectedType;
        return (cast(ExpectedType)&objc_msgSend)(self, _cmd, args);
    }
    RetType objc_msgSend_classMethod(string selector, RetType, T...)(const(char)* className, T args) {
        auto _cmd = sel_registerName(selector.ptr);
        auto cls = objc_getClass(className);
        alias extern(C) RetType function(id, SEL, T) ExpectedType;
        return (cast(ExpectedType)&objc_msgSend)(cls, _cmd, args);
    }
    RetType objc_msgSend_classMethod(string className, string selector, RetType, T...)(T args) {
        return objc_msgSend_classMethod!(selector, RetType, T)(className.ptr, args);
    }
    
    alias objc_msgSend_specialized!("setNeedsDisplay:", void, BOOL) setNeedsDisplay;
    alias objc_msgSend_classMethod!("alloc", id) alloc;
    alias objc_msgSend_specialized!("initWithContentRect:styleMask:backing:defer:",
                                    id, NSRect, size_t, size_t, BOOL) initWithContentRect;
    alias objc_msgSend_specialized!("setTitle:", void, CFStringRef) setTitle;
    alias objc_msgSend_specialized!("center", void) center;
    alias objc_msgSend_specialized!("initWithFrame:", id, NSRect) initWithFrame;
    alias objc_msgSend_specialized!("setContentView:", void, id) setContentView;
    alias objc_msgSend_specialized!("release", void) release;
    alias objc_msgSend_classMethod!("NSColor", "whiteColor", id) whiteNSColor;
    alias objc_msgSend_specialized!("setBackgroundColor:", void, id) setBackgroundColor;
    alias objc_msgSend_specialized!("makeKeyAndOrderFront:", void, id) makeKeyAndOrderFront;
    alias objc_msgSend_specialized!("invalidate", void) invalidate;
    alias objc_msgSend_specialized!("close", void) close;
    alias objc_msgSend_classMethod!("NSTimer", "scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:",
                                    id, double, id, SEL, id, BOOL) scheduledTimer;
    alias objc_msgSend_specialized!("run", void) run;
    alias objc_msgSend_classMethod!("NSGraphicsContext", "currentContext",
                                    id) currentNSGraphicsContext;
    alias objc_msgSend_specialized!("graphicsPort", CGContextRef) graphicsPort;
    alias objc_msgSend_specialized!("characters", CFStringRef) characters;
    alias objc_msgSend_specialized!("superclass", Class) superclass;
    alias objc_msgSend_specialized!("init", id) init;
    alias objc_msgSend_specialized!("addItem:", void, id) addItem;
    alias objc_msgSend_specialized!("setMainMenu:", void, id) setMainMenu;
    alias objc_msgSend_specialized!("initWithTitle:action:keyEquivalent:",
                                    id, CFStringRef, SEL, CFStringRef) initWithTitle;
    alias objc_msgSend_specialized!("setSubmenu:", void, id) setSubmenu;
    alias objc_msgSend_specialized!("setDelegate:", void, id) setDelegate;
    alias objc_msgSend_specialized!("activateIgnoringOtherApps:",
                                    void, BOOL) activateIgnoringOtherApps;
    alias objc_msgSend_classMethod!("NSApplication", "sharedApplication",
                                    id) sharedNSApplication;
    alias objc_msgSend_specialized!("setActivationPolicy:", void, ptrdiff_t) setActivationPolicy;
} else version(html5) {} else static assert(0, "Unsupported operating system");


version(OSXCocoa) {
	// I don't know anything about the Mac, but a couple years ago, KennyTM on the newsgroup wrote this for me
	//
	// http://forum.dlang.org/thread/innr0v$1deh$1@digitalmars.com?page=4#post-int88l:24uaf:241:40digitalmars.com
	// https://github.com/kennytm/simpledisplay.d/blob/osx/simpledisplay.d
	//
	// and it is about time I merged it in here. It is available with -version=OSXCocoa until someone tests it for me!
	// Probably won't even fully compile right now

    import std.math : PI;
    import std.algorithm : map;
    import std.array : array;
    
    alias SimpleWindow NativeWindowHandle;
    alias void delegate(id) NativeEventHandler;

    static Ivar simpleWindowIvar;
    
    enum KEY_ESCAPE = 27;

    mixin template NativeImageImplementation() {
        CGContextRef context;
        ubyte* rawData;

	void convertToRgbaBytes(ubyte[] where) {
		assert(where.length == this.width * this.height * 4);

		// if rawData had a length....
		//assert(rawData.length == where.length);
		for(int idx = 0; idx < where.length; idx += 4) {
			auto alpha = rawData[idx + 3];
			if(alpha == 255) {
				where[idx + 0] = rawData[idx + 0]; // r
				where[idx + 1] = rawData[idx + 1]; // g
				where[idx + 2] = rawData[idx + 2]; // b
				where[idx + 3] = rawData[idx + 3]; // a
			} else {
				where[idx + 0] = cast(ubyte)(rawData[idx + 0] * 255 / alpha); // r
				where[idx + 1] = cast(ubyte)(rawData[idx + 1] * 255 / alpha); // g
				where[idx + 2] = cast(ubyte)(rawData[idx + 2] * 255 / alpha); // b
				where[idx + 3] = rawData[idx + 3]; // a

			}
		}
	}

	void setFromRgbaBytes(in ubyte[] where) {
		// FIXME: this is probably wrong
		assert(where.length == this.width * this.height * 4);

		// if rawData had a length....
		//assert(rawData.length == where.length);
		for(int idx = 0; idx < where.length; idx += 4) {
			auto alpha = rawData[idx + 3];
			if(alpha == 255) {
				rawData[idx + 0] = where[idx + 0]; // r
				rawData[idx + 1] = where[idx + 1]; // g
				rawData[idx + 2] = where[idx + 2]; // b
				rawData[idx + 3] = where[idx + 3]; // a
			} else {
				rawData[idx + 0] = cast(ubyte)(where[idx + 0] * 255 / alpha); // r
				rawData[idx + 1] = cast(ubyte)(where[idx + 1] * 255 / alpha); // g
				rawData[idx + 2] = cast(ubyte)(where[idx + 2] * 255 / alpha); // b
				rawData[idx + 3] = where[idx + 3]; // a

			}
		}
	}

        
        void createImage(int width, int height) {
            auto colorSpace = CGColorSpaceCreateDeviceRGB();
            context = CGBitmapContextCreate(null, width, height, 8, 4*width,
                                            colorSpace,
                                            kCGImageAlphaPremultipliedLast
                                                   |kCGBitmapByteOrder32Big);
            CGColorSpaceRelease(colorSpace);
            rawData = CGBitmapContextGetData(context);
        }
        void dispose() {
            CGContextRelease(context);
        }
        
        void setPixel(int x, int y, Color c) {
            auto offset = (y * width + x) * 4;
            if (c.a == 255) {
                rawData[offset + 0] = c.r;
                rawData[offset + 1] = c.g;
                rawData[offset + 2] = c.b;
                rawData[offset + 3] = c.a;
            } else {
                rawData[offset + 0] = cast(ubyte)(c.r*c.a/255);
                rawData[offset + 1] = cast(ubyte)(c.g*c.a/255);
                rawData[offset + 2] = cast(ubyte)(c.b*c.a/255);
                rawData[offset + 3] = c.a;
            }
        }
    }
    
    mixin template NativeScreenPainterImplementation() {
        CGContextRef context;
        ubyte[4] _outlineComponents;
        
        void create(NativeWindowHandle window) {
            context = window.drawingContext;
        }
        
        void dispose() {
        }
        
        @property void outlineColor(Color color) {
            float alphaComponent = color.a/255.0f;
            CGContextSetRGBStrokeColor(context,
                                       color.r/255.0f, color.g/255.0f, color.b/255.0f, alphaComponent);

            if (color.a != 255) {
                _outlineComponents[0] = cast(ubyte)(color.r*color.a/255);
                _outlineComponents[1] = cast(ubyte)(color.g*color.a/255);
                _outlineComponents[2] = cast(ubyte)(color.b*color.a/255);
                _outlineComponents[3] = color.a;
            } else {
                _outlineComponents[0] = color.r;
                _outlineComponents[1] = color.g;
                _outlineComponents[2] = color.b;
                _outlineComponents[3] = color.a;
            }
        }
        
        @property void fillColor(Color color) {
            CGContextSetRGBFillColor(context,
                                     color.r/255.0f, color.g/255.0f, color.b/255.0f, color.a/255.0f);
        }
        
        void drawImage(int x, int y, Image image) {
            auto cgImage = CGBitmapContextCreateImage(image.context);
            auto size = CGSize(CGBitmapContextGetWidth(image.context),
                               CGBitmapContextGetHeight(image.context));
            CGContextDrawImage(context, CGRect(CGPoint(x, y), size), cgImage);
            CGImageRelease(cgImage);
        }
 
        void drawPixmap(Sprite image, int x, int y) {
		// FIXME: is this efficient?
            auto cgImage = CGBitmapContextCreateImage(image.context);
            auto size = CGSize(CGBitmapContextGetWidth(image.context),
                               CGBitmapContextGetHeight(image.context));
            CGContextDrawImage(context, CGRect(CGPoint(x, y), size), cgImage);
            CGImageRelease(cgImage);
        }

        
        void drawText(int x, int y, int x2, int y2, string text) {
            if (_outlineComponents[3] != 0) {
                CGContextSaveGState(context);
                auto invAlpha = 1.0f/_outlineComponents[3];
                CGContextSetRGBFillColor(context, _outlineComponents[0]*invAlpha,
                                                  _outlineComponents[1]*invAlpha,
                                                  _outlineComponents[2]*invAlpha,
                                                  _outlineComponents[3]/255.0f);
                CGContextShowTextAtPoint(context, x, y, text.ptr, text.length);
// auto cfstr = cast(id)createCFString(text);
// objc_msgSend(cfstr, sel_registerName("drawAtPoint:withAttributes:"),
// NSPoint(x, y), null);
// CFRelease(cfstr);
                CGContextRestoreGState(context);
            }
        }

        void drawPixel(int x, int y) {
            auto rawData = CGBitmapContextGetData(context);
            auto width = CGBitmapContextGetWidth(context);
            auto height = CGBitmapContextGetHeight(context);
            auto offset = ((height - y - 1) * width + x) * 4;
            rawData[offset .. offset+4] = _outlineComponents;
        }
        
        void drawLine(int x1, int y1, int x2, int y2) {
            CGPoint[2] linePoints;
            linePoints[0] = CGPoint(x1, y1);
            linePoints[1] = CGPoint(x2, y2);
            CGContextStrokeLineSegments(context, linePoints.ptr, linePoints.length);
        }

        void drawRectangle(int x, int y, int width, int height) {
            CGContextBeginPath(context);
            auto rect = CGRect(CGPoint(x, y), CGSize(width, height));
            CGContextAddRect(context, rect);
            CGContextDrawPath(context, CGPathDrawingMode.kCGPathFillStroke);
        }
        
        void drawEllipse(int x1, int y1, int x2, int y2) {
            CGContextBeginPath(context);
            auto rect = CGRect(CGPoint(x1, y1), CGSize(x2-x1, y2-y1));
            CGContextAddEllipseInRect(context, rect);
            CGContextDrawPath(context, CGPathDrawingMode.kCGPathFillStroke);
        }
        
        void drawArc(int x1, int y1, int width, int height, int start, int finish) {
            // @@@BUG@@@ Does not support elliptic arc (width != height).
            CGContextBeginPath(context);
            CGContextAddArc(context, x1+width*0.5f, y1+height*0.5f, width,
                            start*PI/(180*64), finish*PI/(180*64), 0);
            CGContextDrawPath(context, CGPathDrawingMode.kCGPathFillStroke);
        }
        
        void drawPolygon(Point[] intPoints) {
            CGContextBeginPath(context);
            auto points = array(map!(CGPoint.fromTuple)(intPoints));
            CGContextAddLines(context, points.ptr, points.length);
            CGContextDrawPath(context, CGPathDrawingMode.kCGPathFillStroke);
        }
    }
    
    mixin template NativeSimpleWindowImplementation() {
        void createWindow(int width, int height, string title) {
            synchronized {
                if (NSApp == null) initializeApp();
            }
            
            auto contentRect = NSRect(NSPoint(0, 0), NSSize(width, height));
            
            // create the window.
            window = initWithContentRect(alloc("NSWindow"),
                                         contentRect,
                                         NSTitledWindowMask
                                            |NSClosableWindowMask
                                            |NSMiniaturizableWindowMask
                                            |NSResizableWindowMask,
                                         NSBackingStoreBuffered,
                                         true);

            // set the title & move the window to center.
            auto windowTitle = createCFString(title);
            setTitle(window, windowTitle);
            CFRelease(windowTitle);
            center(window);
            
            // create area to draw on.
            auto colorSpace = CGColorSpaceCreateDeviceRGB();
            drawingContext = CGBitmapContextCreate(null, width, height,
                                                   8, 4*width, colorSpace,
                                                   kCGImageAlphaPremultipliedLast
                                                      |kCGBitmapByteOrder32Big);
            CGColorSpaceRelease(colorSpace);
            CGContextSelectFont(drawingContext, "Lucida Grande", 12.0f, 1);
            auto matrix = CGContextGetTextMatrix(drawingContext);
            matrix.c = -matrix.c;
            matrix.d = -matrix.d;
            CGContextSetTextMatrix(drawingContext, matrix);
            
            // create the subview that things will be drawn on.
            view = initWithFrame(alloc("SDGraphicsView"), contentRect);
            setContentView(window, view);
            object_setIvar(view, simpleWindowIvar, cast(id)this);
            release(view);

            setBackgroundColor(window, whiteNSColor);
            makeKeyAndOrderFront(window, null);
        }
        void dispose() {
            closeWindow();
            release(window);
        }
        void closeWindow() {
            invalidate(timer);
            .close(window);
        }
        
        ScreenPainter getPainter() {
		return ScreenPainter(this, this);
	}
        
        int eventLoop(long pulseTimeout) {
            if (handlePulse !is null && pulseTimeout != 0) {
                timer = scheduledTimer(pulseTimeout*1e-3,
                                       view, sel_registerName("simpledisplay_pulse"),
                                       null, true);
            }
            
            setNeedsDisplay(view, true);
            run(NSApp);
            return 0;
        }
        
        id window;
        id timer;
        id view;
        CGContextRef drawingContext;
    }
    
    extern(C) {
    private:
        BOOL returnTrue3(id self, SEL _cmd, id app) {
            return true;
        }
        BOOL returnTrue2(id self, SEL _cmd) {
            return true;
        }
        
        void pulse(id self, SEL _cmd) {
            auto simpleWindow = cast(SimpleWindow)object_getIvar(self, simpleWindowIvar);
            simpleWindow.handlePulse();
            setNeedsDisplay(self, true);
        }
        void drawRect(id self, SEL _cmd, NSRect rect) {
            auto simpleWindow = cast(SimpleWindow)object_getIvar(self, simpleWindowIvar);
            auto curCtx = graphicsPort(currentNSGraphicsContext);
            auto cgImage = CGBitmapContextCreateImage(simpleWindow.drawingContext);
            auto size = CGSize(CGBitmapContextGetWidth(simpleWindow.drawingContext),
                               CGBitmapContextGetHeight(simpleWindow.drawingContext));
            CGContextDrawImage(curCtx, CGRect(CGPoint(0, 0), size), cgImage);
            CGImageRelease(cgImage);
        }
        void keyDown(id self, SEL _cmd, id event) {
            auto simpleWindow = cast(SimpleWindow)object_getIvar(self, simpleWindowIvar);

            // the event may have multiple characters, and we send them all at
            // once.
            if (simpleWindow.handleCharEvent || simpleWindow.handleKeyEvent) {
                auto chars = characters(event);
                auto range = CFRange(0, CFStringGetLength(chars));
                auto buffer = new char[range.length*3];
                int actualLength;
                CFStringGetBytes(chars, range, kCFStringEncodingUTF8, 0, false,
                                 buffer.ptr, buffer.length, &actualLength);
                foreach (dchar dc; buffer[0..actualLength]) {
                    if (simpleWindow.handleCharEvent)
                        simpleWindow.handleCharEvent(dc);
                    if (simpleWindow.handleKeyEvent)
                        simpleWindow.handleKeyEvent(dc, true); // FIXME: what about keyUp?
                }
            }
            
            // the event's 'keyCode' is hardware-dependent. I don't think people
            // will like it. Let's leave it to the native handler.
            
            // perform the default action.
            auto superData = objc_super(self, superclass(self));
            alias extern(C) void function(objc_super*, SEL, id) T;
            (cast(T)&objc_msgSendSuper)(&superData, _cmd, event);
        }
    }
    
    // initialize the app so that it can be interacted with the user.
    // based on http://cocoawithlove.com/2010/09/minimalist-cocoa-programming.html
    private void initializeApp() {
        // push an autorelease pool to avoid leaking.
        init(alloc("NSAutoreleasePool"));
        
        // create a new NSApp instance
        sharedNSApplication;
        setActivationPolicy(NSApp, NSApplicationActivationPolicyRegular);
        
        // create the "Quit" menu.
        auto menuBar = init(alloc("NSMenu"));
        auto appMenuItem = init(alloc("NSMenuItem"));
        addItem(menuBar, appMenuItem);
        setMainMenu(NSApp, menuBar);
        release(appMenuItem);
        release(menuBar);
        
        auto appMenu = init(alloc("NSMenu"));
        auto quitTitle = createCFString("Quit");
        auto q = createCFString("q");
        auto quitItem = initWithTitle(alloc("NSMenuItem"),
                                      quitTitle, sel_registerName("terminate:"), q);
        addItem(appMenu, quitItem);
        setSubmenu(appMenuItem, appMenu);
        release(quitItem);
        release(appMenu);
        CFRelease(q);
        CFRelease(quitTitle);

        // assign a delegate for the application, allow it to quit when the last
        // window is closed.
        auto delegateClass = objc_allocateClassPair(objc_getClass("NSObject"),
                                                    "SDWindowCloseDelegate", 0);
        class_addMethod(delegateClass,
                        sel_registerName("applicationShouldTerminateAfterLastWindowClosed:"),
                        &returnTrue3, "c@:@");
        objc_registerClassPair(delegateClass);
    
        auto appDelegate = init(alloc("SDWindowCloseDelegate"));
        setDelegate(NSApp, appDelegate);
        activateIgnoringOtherApps(NSApp, true);

        // create a new view that draws the graphics and respond to keyDown
        // events.
        auto viewClass = objc_allocateClassPair(objc_getClass("NSView"),
                                                "SDGraphicsView", (void*).sizeof);
        class_addIvar(viewClass, "simpledisplay_simpleWindow",
                      (void*).sizeof, (void*).alignof, "^v");
        class_addMethod(viewClass, sel_registerName("simpledisplay_pulse"),
                        &pulse, "v@:");
        class_addMethod(viewClass, sel_registerName("drawRect:"),
                        &drawRect, "v@:{NSRect={NSPoint=ff}{NSSize=ff}}");
        class_addMethod(viewClass, sel_registerName("isFlipped"),
                        &returnTrue2, "c@:");
        class_addMethod(viewClass, sel_registerName("acceptsFirstResponder"),
                        &returnTrue2, "c@:");
        class_addMethod(viewClass, sel_registerName("keyDown:"),
                        &keyDown, "v@:@");
        objc_registerClassPair(viewClass);
        simpleWindowIvar = class_getInstanceVariable(viewClass,
                                                     "simpledisplay_simpleWindow");
    }
}

version(html5) {
	import arsd.cgi;

	alias int NativeWindowHandle;
	alias void delegate() NativeEventHandler;

	mixin template NativeImageImplementation() {
		static import arsd.image;
		arsd.image.TrueColorImage handle;

		void createImage(int width, int height) {
			handle = new arsd.image.TrueColorImage(width, height);
		}

		void dispose() {
			handle = null;
		}

		void setPixel(int x, int y, Color c) {
			auto offset = (y * width + x) * 4;
			handle.data[offset + 0] = c.b;
			handle.data[offset + 1] = c.g;
			handle.data[offset + 2] = c.r;
			handle.data[offset + 3] = c.a;
		}

		void convertToRgbaBytes(ubyte[] where) {
			if(where is handle.data)
				return;
			assert(where.length == this.width * this.height * 4);

			where[] = handle.data[];
		}

		void setFromRgbaBytes(in ubyte[] where) {
			if(where is handle.data)
				return;
			assert(where.length == this.width * this.height * 4);

			handle.data[] = where[];
		}

	}

	mixin template NativeScreenPainterImplementation() {
		void create(NativeWindowHandle window) {
		}

		void dispose() {
		}
		@property void outlineColor(Color c) {
		}

		@property void fillColor(Color c) {
		}

		void drawImage(int x, int y, Image i) {
		}

		void drawPixmap(Sprite s, int x, int y) {
		}

		void drawText(int x, int y, int x2, int y2, string text) {
		}

		void drawPixel(int x, int y) {
		}

		void drawLine(int x1, int y1, int x2, int y2) {
		}

		void drawRectangle(int x, int y, int width, int height) {
		}

		/// Arguments are the points of the bounding rectangle
		void drawEllipse(int x1, int y1, int x2, int y2) {
		}

		void drawArc(int x1, int y1, int width, int height, int start, int finish) {
			// FIXME: start X, start Y, end X, end Y
			//Arc(hdc, x1, y1, x1 + width, y1 + height, 0, 0, 0, 0);
		}

		void drawPolygon(Point[] vertexes) {
		}

	}

	/// on html5 mode you MUST set this socket up
	WebSocket socket;

	mixin template NativeSimpleWindowImplementation() {
		ScreenPainter getPainter() {
			return ScreenPainter(this, 0);
		}

		void createWindow(int width, int height, string title) {
			Html5.createCanvas(width, height);
		}

		void closeWindow() { /* no need, can just leave it on the page */ }

		void dispose() { }

		bool destroyed = false;

		int eventLoop(long pulseTimeout) {
			bool done = false;
			import core.thread;

			while (!done) {
			while(!done &&
				(pulseTimeout == 0 || socket.recvAvailable()))
			{
				//done = doXNextEvent(this); // FIXME: what about multiple windows? This wasn't originally going to support them but maybe I should
			}
				if(!done && pulseTimeout !=0) {
					if(handlePulse !is null)
						handlePulse();
					Thread.sleep(dur!"msecs"(pulseTimeout));
				}
			}

			return 0;
		}
	}

	struct JsImpl { string code; }

	struct Html5 {
		@JsImpl(q{

		})
		static void createImage(int handle, Image i) {

		}

		static void freeImage(int handle) {

		}

		static void createCanvas(int width, int height) {

		}
	}
}

/*
 * screensaver_shield.c
 *
 * Fullscreen X11 shield used while a custom Kindle sleep image
 * is displayed directly through the framebuffer.
 *
 * The window uses override_redirect so the Kindle window manager
 * does not manage or reposition it.
 */

#include <X11/Xlib.h>

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static volatile sig_atomic_t running = 1;

static void handle_signal(int signal_number)
{
    (void)signal_number;
    running = 0;
}

static int install_signal_handlers(void)
{
    struct sigaction action;

    action.sa_handler = handle_signal;
    sigemptyset(&action.sa_mask);
    action.sa_flags = 0;

    if (sigaction(SIGTERM, &action, NULL) != 0)
        return -1;

    if (sigaction(SIGINT, &action, NULL) != 0)
        return -1;

    if (sigaction(SIGHUP, &action, NULL) != 0)
        return -1;

    return 0;
}

int main(void)
{
    Display *display;
    Window root;
    Window window;

    int screen;
    unsigned int width;
    unsigned int height;

    XSetWindowAttributes attributes;
    unsigned long attribute_mask;

    fprintf(stderr, "screensaver_shield: starting\n");

    if (install_signal_handlers() != 0) {
        fprintf(stderr,
                "screensaver_shield: failed to install signal handlers\n");
        return EXIT_FAILURE;
    }

    display = XOpenDisplay(NULL);

    if (display == NULL) {
        fprintf(stderr,
                "screensaver_shield: failed to open X display\n");
        return EXIT_FAILURE;
    }

    screen = DefaultScreen(display);
    root = RootWindow(display, screen);

    width = (unsigned int)DisplayWidth(display, screen);
    height = (unsigned int)DisplayHeight(display, screen);

    fprintf(stderr,
            "screensaver_shield: display opened, screen %d, size %ux%u\n",
            screen,
            width,
            height);

    attributes.override_redirect = True;

    /*
     * No background pixmap means X should not paint a background
     * into this window. FBInk is responsible for the actual
     * framebuffer contents.
     */
    attributes.background_pixmap = None;

    attribute_mask = CWOverrideRedirect | CWBackPixmap;

    window = XCreateWindow(
        display,
        root,
        0,
        0,
        width,
        height,
        0,
        CopyFromParent,
        InputOutput,
        CopyFromParent,
        attribute_mask,
        &attributes
    );

    if (window == 0) {
        fprintf(stderr,
                "screensaver_shield: failed to create window\n");
        XCloseDisplay(display);
        return EXIT_FAILURE;
    }

    XStoreName(display, window, "Kindle Custom Screensaver Shield");

    XMapRaised(display, window);
    XRaiseWindow(display, window);

    /*
     * Wait until the X server has processed everything above.
     */
    XSync(display, False);

    fprintf(stderr,
            "screensaver_shield: active, window=0x%lx\n",
            window);

    /*
     * The shield has no work to do after the window is mapped.
     * It simply remains alive until the screensaver daemon sends
     * SIGTERM when the Kindle wakes.
     */
    while (running) {
        pause();
    }

    fprintf(stderr, "screensaver_shield: shutting down\n");

    XUnmapWindow(display, window);
    XDestroyWindow(display, window);
    XSync(display, False);

    XCloseDisplay(display);

    return EXIT_SUCCESS;
}
/*
 * screensaver_shield.c
 *
 * Fullscreen X11 shield used while a custom Kindle sleep image
 * is displayed directly through the framebuffer.
 *
 * The window uses the stock screensaver layer so the Kindle window
 * manager can place its PIN dialog above the custom sleep image.
 */

#define _POSIX_C_SOURCE 200809L

#include <X11/Xlib.h>

#include <errno.h>
#include <poll.h>
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

    attributes.override_redirect = False;
    attributes.event_mask = StructureNotifyMask;

    /*
     * No background pixmap means X should not paint a background
     * into this window. FBInk is responsible for the actual
     * framebuffer contents.
     */
    attributes.background_pixmap = None;

    attribute_mask = CWOverrideRedirect | CWBackPixmap | CWEventMask;

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

    /* Match the stock screensaver role; passwdlg uses L:SS_N:dialog. */
    XStoreName(display, window,
               "L:SS_N:screenSaver_ID:custom-screensaver");

    XMapWindow(display, window);
    XFlush(display);

    /* Mapping is asynchronous when the window manager owns the window. */
    XEvent event;
    struct pollfd x_connection = {
        .fd = ConnectionNumber(display),
        .events = POLLIN,
    };

    while (running && !XCheckTypedWindowEvent(display, window, MapNotify, &event)) {
        int result = poll(&x_connection, 1, 5000);

        if (result < 0 && errno == EINTR)
            continue;

        if (result <= 0 || (x_connection.revents & (POLLERR | POLLHUP | POLLNVAL))) {
            fprintf(stderr, "screensaver_shield: window manager did not map window\n");
            XDestroyWindow(display, window);
            XCloseDisplay(display);
            return EXIT_FAILURE;
        }
    }

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
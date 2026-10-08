/*
 * screensaver_shield.c
 *
 * Fullscreen X11 shield used while a custom Kindle sleep image
 * is displayed directly through the framebuffer.
 *
 * The window bypasses window-manager refresh handling. It stays above
 * the reading interface but below the stock PIN dialog when one is mapped.
 */

#define _POSIX_C_SOURCE 200809L

#include <X11/Xlib.h>

#include <errno.h>
#include <sys/select.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static volatile sig_atomic_t running = 1;
static volatile sig_atomic_t pin_requested = 0;

static void handle_signal(int signal_number)
{
    if (signal_number == SIGUSR1)
        pin_requested = 1;
    else
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

    if (sigaction(SIGUSR1, &action, NULL) != 0)
        return -1;

    return 0;
}

/* Root-window snapshots can contain clients that have just disappeared. */
static int handle_x_error(Display *display, XErrorEvent *error)
{
    char message[128];

    if (error->error_code == BadWindow)
        return 0;

    XGetErrorText(display, error->error_code, message, sizeof(message));
    fprintf(stderr, "screensaver_shield: X11 error: %s\n", message);
    return 0;
}

static void place_shield_below_pin(Display *display, Window root, Window shield)
{
    Window returned_root, parent, *children = NULL;
    unsigned int count, shield_index;

    if (!XQueryTree(display, root, &returned_root, &parent, &children, &count))
        return;

    /* XQueryTree returns siblings in stacking order, bottom to top. */
    for (shield_index = 0; shield_index < count; ++shield_index) {
        if (children[shield_index] == shield)
            break;
    }

    for (unsigned int i = 0; i < count; ++i) {
        char *name = NULL;
        XWindowAttributes attributes;

        if (!XFetchName(display, children[i], &name) || name == NULL)
            continue;

        int is_pin = strstr(name, "_ID:passwdlg_") != NULL;
        XFree(name);

        if (!is_pin || !XGetWindowAttributes(display, children[i], &attributes)
                    || attributes.map_state != IsViewable)
            continue;

        /* Keep the book/menu below the shield even if PIN was just raised. */
        if (shield_index + 1 != i) {
            XWindowChanges changes = {
                .sibling = children[i],
                .stack_mode = Below,
            };
            XConfigureWindow(display, shield, CWSibling | CWStackMode, &changes);
            XFlush(display);
            fprintf(stderr, "screensaver_shield: placed below PIN dialog 0x%lx\n",
                    children[i]);
        }
        break;
    }

    if (children != NULL)
        XFree(children);
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

    XSetErrorHandler(handle_x_error);

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
    XSync(display, False);

    fprintf(stderr,
            "screensaver_shield: active, window=0x%lx\n",
            window);

    sigset_t stop_signals, previous_mask;

    sigemptyset(&stop_signals);
    sigaddset(&stop_signals, SIGTERM);
    sigaddset(&stop_signals, SIGINT);
    sigaddset(&stop_signals, SIGHUP);
    sigaddset(&stop_signals, SIGUSR1);
    sigprocmask(SIG_BLOCK, &stop_signals, &previous_mask);

    while (running) {
        /* Stay unsubscribed while asleep; the daemon signals PIN entry. */
        if (pin_requested) {
            pin_requested = 0;
            XSelectInput(display, root, SubstructureNotifyMask);
            place_shield_below_pin(display, root, window);
        }

        if (XPending(display)) {
            XEvent event;
            int stacking_changed = 0;

            /* Ignore unrelated events and notifications from our own restack. */
            while (XPending(display)) {
                XNextEvent(display, &event);

                if (event.type == MapNotify && event.xmap.window != window)
                    stacking_changed = 1;
                else if (event.type == ConfigureNotify && event.xconfigure.window != window)
                    stacking_changed = 1;
            }

            if (stacking_changed)
                place_shield_below_pin(display, root, window);
        }

        /* XQueryTree can buffer events while waiting for its reply. */
        if (XPending(display))
            continue;

        fd_set read_fds;
        FD_ZERO(&read_fds);
        FD_SET(ConnectionNumber(display), &read_fds);

        /* Atomically allow stop signals while waiting, with no sleep timer. */
        int result = pselect(ConnectionNumber(display) + 1, &read_fds,
                             NULL, NULL, NULL, &previous_mask);

        if (result < 0 && errno == EINTR)
            continue;

        if (result < 0) {
            fprintf(stderr, "screensaver_shield: X connection failed\n");
            break;
        }
    }

    sigprocmask(SIG_SETMASK, &previous_mask, NULL);

    fprintf(stderr, "screensaver_shield: shutting down\n");

    XUnmapWindow(display, window);
    XDestroyWindow(display, window);
    XSync(display, False);

    XCloseDisplay(display);

    return EXIT_SUCCESS;
}
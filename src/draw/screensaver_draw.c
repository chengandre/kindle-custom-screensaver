/*
 * screensaver_draw.c
 *
 * Draws one screensaver image stretched over the whole framebuffer,
 * always upright relative to the device's portrait orientation.
 *
 * When reading in landscape, the Kindle rotates the framebuffer itself, so
 * FBInk's viewport becomes landscape and a portrait image would be stretched
 * across the wrong axis. Like KOReader, we leave the framebuffer rotation
 * alone (the Kindle UI owns it) and rotate the decoded pixels instead.
 *
 * Usage: screensaver_draw IMAGE
 */

#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_STATIC
#define STBI_ONLY_PNG
#define STBI_ONLY_JPEG
#include "stb/stb_image.h"

#include "fbink.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * Rotate packed pixels (n bytes each) 90 degrees clockwise.
 * A w x h image becomes h x w, and its top row becomes the right column.
 */
static unsigned char *rotate_clockwise(const unsigned char *src, int w, int h, int n)
{
    unsigned char *dst = malloc((size_t)w * (size_t)h * (size_t)n);

    if (dst == NULL)
        return NULL;

    for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
            memcpy(dst + ((size_t)x * (size_t)h + (size_t)(h - 1 - y)) * (size_t)n,
                   src + ((size_t)y * (size_t)w + (size_t)x) * (size_t)n,
                   (size_t)n);
        }
    }

    return dst;
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        fprintf(stderr, "usage: screensaver_draw IMAGE\n");
        return EXIT_FAILURE;
    }

    const char *path = argv[1];
    int rv = EXIT_FAILURE;
    unsigned char *pixels = NULL;

    /* Same behavior as `fbink -g w=-1,h=-1 -f`: flash and stretch to fill. */
    FBInkConfig config = { 0 };
    config.is_flashing = true;
    config.scaled_width = -1;
    config.scaled_height = -1;

    int fbfd = fbink_open();

    if (fbfd < 0) {
        fprintf(stderr, "screensaver_draw: failed to open framebuffer\n");
        return EXIT_FAILURE;
    }

    if (fbink_init(fbfd, &config) != EXIT_SUCCESS) {
        fprintf(stderr, "screensaver_draw: failed to initialize FBInk\n");
        goto cleanup;
    }

    int width, height, components;
    pixels = stbi_load(path, &width, &height, &components, 0);

    if (pixels == NULL) {
        fprintf(stderr, "screensaver_draw: failed to decode %s: %s\n",
                path, stbi_failure_reason());
        goto cleanup;
    }

    FBInkState state;
    fbink_get_state(&config, &state);

    /*
     * Flashing AUTO refreshes resolve to GC16, which Kaleido panels (Colorsoft)
     * render in grayscale; their driver only uses the color waveforms when
     * asked for them explicitly.
     */
    if (state.has_color_panel) {
        config.wfm_mode = WFM_GCC16;

        fprintf(stderr, "screensaver_draw: color panel at %ubpp, using GCC16\n",
                state.bpp);
    }

    /*
     * Standard Kindles have a single landscape orientation, so one fixed
     * rotation direction keeps the image upright in portrait.
     */
    if (state.view_width > state.view_height) {
        unsigned char *rotated = rotate_clockwise(pixels, width, height, components);

        if (rotated == NULL) {
            fprintf(stderr, "screensaver_draw: out of memory rotating %s\n", path);
            goto cleanup;
        }

        stbi_image_free(pixels);
        pixels = rotated;

        int original_width = width;
        width = height;
        height = original_width;

        fprintf(stderr, "screensaver_draw: landscape %ux%u viewport, rotated image\n",
                state.view_width, state.view_height);
    }

    if (fbink_print_raw_data(fbfd, pixels, width, height,
                             (size_t)width * (size_t)height * (size_t)components,
                             0, 0, &config) != EXIT_SUCCESS) {
        fprintf(stderr, "screensaver_draw: failed to draw %s\n", path);
        goto cleanup;
    }

    rv = EXIT_SUCCESS;

cleanup:
    /* stbi_image_free is plain free(), so it also releases the rotated copy. */
    stbi_image_free(pixels);
    fbink_close(fbfd);

    return rv;
}

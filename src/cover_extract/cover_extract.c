/*
 * cover_extract.c
 *
 * Extracts the embedded cover image from a MOBI / AZW / AZW3 (KF8) book.
 *
 * Usage: cover_extract BOOK OUTPUT
 *
 * The cover is located through EXTH record 201 (cover offset), which is
 * relative to the MOBI header's first image record. The image record is
 * written to OUTPUT byte-for-byte (JPEG, PNG or GIF).
 *
 * Exit status:
 *   0  cover written
 *   2  book has no usable cover, or is not a MOBI-family book
 *   1  I/O or usage error
 */

#define _POSIX_C_SOURCE 200809L

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define EXIT_NO_COVER 2

#define PDB_HEADER_SIZE 78
#define PDB_RECORD_ENTRY_SIZE 8
#define PALMDOC_HEADER_SIZE 16

#define EXTH_FLAG 0x40
#define EXTH_COVER_OFFSET 201
#define NO_INDEX 0xFFFFFFFFu

static uint32_t be32(const unsigned char *p)
{
    return ((uint32_t)p[0] << 24) |
           ((uint32_t)p[1] << 16) |
           ((uint32_t)p[2] << 8) |
           (uint32_t)p[3];
}

static uint16_t be16(const unsigned char *p)
{
    return (uint16_t)(((uint16_t)p[0] << 8) | p[1]);
}

static int read_at(FILE *file, long offset, void *buffer, size_t length)
{
    if (fseek(file, offset, SEEK_SET) != 0)
        return -1;

    if (fread(buffer, 1, length, file) != length)
        return -1;

    return 0;
}

/*
 * Returns the start offset of record INDEX and its length.
 * The last record runs to the end of the file.
 */
static int record_bounds(FILE *file,
                         uint16_t record_count,
                         long file_size,
                         uint32_t index,
                         uint32_t *start,
                         uint32_t *length)
{
    unsigned char entry[PDB_RECORD_ENTRY_SIZE];
    uint32_t end;

    if (index >= record_count)
        return -1;

    if (read_at(file,
                PDB_HEADER_SIZE + (long)index * PDB_RECORD_ENTRY_SIZE,
                entry,
                sizeof(entry)) != 0)
        return -1;

    *start = be32(entry);

    if (index + 1 < record_count) {
        if (read_at(file,
                    PDB_HEADER_SIZE + (long)(index + 1) * PDB_RECORD_ENTRY_SIZE,
                    entry,
                    sizeof(entry)) != 0)
            return -1;

        end = be32(entry);
    } else {
        end = (uint32_t)file_size;
    }

    if (end <= *start || end > (uint32_t)file_size)
        return -1;

    *length = end - *start;

    return 0;
}

static int is_image(const unsigned char *data, uint32_t length)
{
    if (length >= 3 && data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF)
        return 1;

    if (length >= 8 && memcmp(data, "\x89PNG\r\n\x1a\n", 8) == 0)
        return 1;

    if (length >= 6 &&
        (memcmp(data, "GIF87a", 6) == 0 || memcmp(data, "GIF89a", 6) == 0))
        return 1;

    return 0;
}

/*
 * Walks the EXTH block in RECORD0 and returns the cover offset,
 * or NO_INDEX when there is none.
 */
static uint32_t find_cover_offset(const unsigned char *record0,
                                  uint32_t record0_length,
                                  uint32_t exth_start)
{
    uint32_t exth_length;
    uint32_t exth_count;
    uint32_t position;
    uint32_t i;

    if (exth_start + 12 > record0_length)
        return NO_INDEX;

    if (memcmp(record0 + exth_start, "EXTH", 4) != 0)
        return NO_INDEX;

    exth_length = be32(record0 + exth_start + 4);
    exth_count = be32(record0 + exth_start + 8);

    if (exth_length > record0_length - exth_start)
        exth_length = record0_length - exth_start;

    position = exth_start + 12;

    for (i = 0; i < exth_count; i++) {
        uint32_t type;
        uint32_t size;

        if (position + 8 > exth_start + exth_length)
            break;

        type = be32(record0 + position);
        size = be32(record0 + position + 4);

        if (size < 8 || size > exth_start + exth_length - position)
            break;

        if (type == EXTH_COVER_OFFSET && size >= 12)
            return be32(record0 + position + 8);

        position += size;
    }

    return NO_INDEX;
}

int main(int argc, char **argv)
{
    FILE *book;
    FILE *output;

    unsigned char header[PDB_HEADER_SIZE];
    unsigned char *record0 = NULL;
    unsigned char *image = NULL;

    uint16_t record_count;
    uint32_t record0_start;
    uint32_t record0_length;
    uint32_t mobi_header_length;
    uint32_t first_image;
    uint32_t exth_flags;
    uint32_t cover_offset;
    uint32_t image_start;
    uint32_t image_length;

    long file_size;
    int result = EXIT_NO_COVER;

    if (argc != 3) {
        fprintf(stderr, "Usage: %s BOOK OUTPUT\n", argv[0]);
        return EXIT_FAILURE;
    }

    book = fopen(argv[1], "rb");

    if (book == NULL) {
        perror("cover_extract: open book");
        return EXIT_FAILURE;
    }

    if (fseek(book, 0, SEEK_END) != 0 || (file_size = ftell(book)) < 0) {
        fclose(book);
        return EXIT_FAILURE;
    }

    if (read_at(book, 0, header, sizeof(header)) != 0 ||
        memcmp(header + 60, "BOOKMOBI", 8) != 0) {
        fprintf(stderr, "cover_extract: not a MOBI-family book\n");
        goto done;
    }

    record_count = be16(header + 76);

    if (record_bounds(book, record_count, file_size, 0,
                      &record0_start, &record0_length) != 0 ||
        record0_length < PALMDOC_HEADER_SIZE + 0x74) {
        fprintf(stderr, "cover_extract: bad record 0\n");
        goto done;
    }

    record0 = malloc(record0_length);

    if (record0 == NULL ||
        read_at(book, (long)record0_start, record0, record0_length) != 0) {
        result = EXIT_FAILURE;
        goto done;
    }

    if (memcmp(record0 + PALMDOC_HEADER_SIZE, "MOBI", 4) != 0) {
        fprintf(stderr, "cover_extract: missing MOBI header\n");
        goto done;
    }

    /* Offsets below are relative to the start of the MOBI header. */
    mobi_header_length = be32(record0 + PALMDOC_HEADER_SIZE + 0x04);
    first_image = be32(record0 + PALMDOC_HEADER_SIZE + 0x5C);
    exth_flags = be32(record0 + PALMDOC_HEADER_SIZE + 0x70);

    if (!(exth_flags & EXTH_FLAG) || first_image == NO_INDEX) {
        fprintf(stderr, "cover_extract: no EXTH or no images\n");
        goto done;
    }

    cover_offset = find_cover_offset(record0,
                                     record0_length,
                                     PALMDOC_HEADER_SIZE + mobi_header_length);

    if (cover_offset == NO_INDEX) {
        fprintf(stderr, "cover_extract: no cover record\n");
        goto done;
    }

    if (record_bounds(book, record_count, file_size,
                      first_image + cover_offset,
                      &image_start, &image_length) != 0) {
        fprintf(stderr, "cover_extract: cover record out of range\n");
        goto done;
    }

    image = malloc(image_length);

    if (image == NULL ||
        read_at(book, (long)image_start, image, image_length) != 0) {
        result = EXIT_FAILURE;
        goto done;
    }

    if (!is_image(image, image_length)) {
        fprintf(stderr, "cover_extract: cover record is not an image\n");
        goto done;
    }

    output = fopen(argv[2], "wb");

    if (output == NULL) {
        perror("cover_extract: open output");
        result = EXIT_FAILURE;
        goto done;
    }

    if (fwrite(image, 1, image_length, output) != image_length) {
        fclose(output);
        remove(argv[2]);
        result = EXIT_FAILURE;
        goto done;
    }

    if (fclose(output) != 0) {
        remove(argv[2]);
        result = EXIT_FAILURE;
        goto done;
    }

    result = EXIT_SUCCESS;

done:
    free(image);
    free(record0);
    fclose(book);

    return result;
}

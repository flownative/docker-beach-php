#!/usr/bin/env php
<?php
declare(strict_types=1);

/**
 * Checks that the image libraries shipped with this Docker image can read,
 * manipulate and write the common web image formats.
 *
 * Every library builds the same four-colour test pattern with its own API,
 * runs it through resize, rotate, flip and crop, writes it in each format and
 * reads the result back. The fixtures in tests/fixtures were produced by an
 * independent toolchain and cover reading, including formats which are only
 * ever read on a web server, such as SVG, TIFF and PDF. Files written
 * by one library are read by the others as well. Separate checks make sure
 * that transparency and animation frames survive a resize and a write.
 *
 * Usage: php tests/image-formats.php [--output-dir=DIR]
 *
 * With --output-dir the generated images are kept in DIR and a Markdown
 * summary is written to DIR/summary.md. The exit code is 1 if any check
 * failed. A library without an API for a format is reported as skipped, but
 * every format must still be readable, and writable where applicable, by at
 * least one library.
 */

const WRITABLE_FORMATS = ['jpeg', 'png', 'gif', 'webp', 'avif', 'heic'];
const READ_ONLY_FORMATS = ['svg', 'tiff', 'pdf'];
const ALPHA_FORMATS = ['png', 'gif', 'webp', 'avif', 'heic'];
const ANIMATION_FORMATS = ['gif', 'webp'];

// Quadrant colours of the test pattern: top left, top right, bottom left, bottom right
const PATTERN = [[220, 40, 40], [40, 200, 60], [40, 60, 220], [230, 210, 40]];

// Lossy formats shift colours slightly. The pattern colours differ by far more than this.
const TOLERANCE = 40;

set_error_handler(static function (int $severity, string $message, string $file, int $line): bool {
    throw new ErrorException($message, 0, $severity, $file, $line);
});

enum Status: string
{
    case Ok = 'OK';
    case Fail = 'FAIL';
    case Skip = 'SKIP';
}

final class SkippedException extends RuntimeException
{
}

final class Check
{
    public function __construct(
        public readonly string $library,
        public readonly string $category,
        public readonly string $format,
        public readonly Status $status,
        public readonly string $detail,
        public readonly string $source = '',
    ) {
    }
}

/**
 * The operations every library must provide for the checks. Image handles
 * are opaque to the caller; a method may return the handle it was given or a
 * new one. Methods throw SkippedException when the library has no API for
 * what is asked and RuntimeException when the operation failed.
 */
interface ImageLibrary
{
    public function name(): string;

    public function version(): string;

    public function isAvailable(): bool;

    public function createPattern(int $width, int $height): mixed;

    /**
     * Left half opaque in the first pattern colour, right half fully transparent.
     */
    public function createAlphaPattern(int $width, int $height): mixed;

    public function resize(mixed $image, int $width, int $height): mixed;

    public function rotate90(mixed $image): mixed;

    public function flipHorizontal(mixed $image): mixed;

    public function crop(mixed $image, int $x, int $y, int $width, int $height): mixed;

    public function write(mixed $image, string $format, string $path): void;

    public function read(string $path, string $format): mixed;

    public function width(mixed $image): int;

    public function height(mixed $image): int;

    /**
     * @return int[] red, green and blue of the pixel at the given position
     */
    public function pixel(mixed $image, int $x, int $y): array;

    /**
     * @return int opacity of the pixel from 0 (transparent) to 255 (opaque)
     */
    public function alpha(mixed $image, int $x, int $y): int;

    public function readFrames(string $path): mixed;

    public function frameCount(mixed $frames): int;

    /**
     * @return array{int, int} width and height of a single frame
     */
    public function frameSize(mixed $frames): array;

    public function resizeFrames(mixed $frames, int $width, int $height): mixed;

    public function writeFrames(mixed $frames, string $format, string $path): void;

    /**
     * @return int[] red, green and blue of the pixel in the given frame
     */
    public function framePixel(mixed $frames, int $frame, int $x, int $y): array;
}

final class GdLibrary implements ImageLibrary
{
    public function name(): string
    {
        return 'gd';
    }

    public function version(): string
    {
        return 'GD ' . gd_info()['GD Version'];
    }

    public function isAvailable(): bool
    {
        return extension_loaded('gd');
    }

    public function createPattern(int $width, int $height): mixed
    {
        $image = imagecreatetruecolor($width, $height);
        foreach (quadrants($width, $height) as $index => [$x, $y, $w, $h]) {
            $colour = imagecolorallocate($image, ...PATTERN[$index]);
            imagefilledrectangle($image, $x, $y, $x + $w - 1, $y + $h - 1, $colour);
        }
        return $image;
    }

    public function createAlphaPattern(int $width, int $height): mixed
    {
        $image = imagecreatetruecolor($width, $height);
        $this->keepAlpha($image);
        $half = intdiv($width, 2);
        imagefilledrectangle($image, 0, 0, $half - 1, $height - 1, imagecolorallocatealpha($image, ...[...PATTERN[0], 0]));
        imagefilledrectangle($image, $half, 0, $width - 1, $height - 1, imagecolorallocatealpha($image, 0, 0, 0, 127));
        return $image;
    }

    public function resize(mixed $image, int $width, int $height): mixed
    {
        return $this->keepAlpha(imagescale($image, $width, $height));
    }

    public function rotate90(mixed $image): mixed
    {
        return $this->keepAlpha(imagerotate($image, 90, 0));
    }

    public function flipHorizontal(mixed $image): mixed
    {
        imageflip($image, IMG_FLIP_HORIZONTAL);
        return $image;
    }

    public function crop(mixed $image, int $x, int $y, int $width, int $height): mixed
    {
        return $this->keepAlpha(imagecrop($image, ['x' => $x, 'y' => $y, 'width' => $width, 'height' => $height]));
    }

    public function write(mixed $image, string $format, string $path): void
    {
        $function = 'image' . $format;
        if (!function_exists($function)) {
            throw new SkippedException(sprintf('GD has no %s()', $function));
        }
        if ($format === 'gif') {
            // GIF has no alpha channel. GD only writes transparency for the colour declared transparent.
            imagecolortransparent($image, imagecolorallocatealpha($image, 0, 0, 0, 127));
        }
        $result = match ($format) {
            'jpeg', 'webp' => $function($image, $path, 90),
            'avif' => $function($image, $path, 60),
            default => $function($image, $path),
        };
        if ($result !== true) {
            throw new RuntimeException(sprintf('%s() returned false', $function));
        }
    }

    public function read(string $path, string $format): mixed
    {
        $function = 'imagecreatefrom' . $format;
        if (!function_exists($function)) {
            throw new SkippedException(sprintf('GD has no %s()', $function));
        }
        $image = $function($path);
        if ($image === false) {
            throw new RuntimeException(sprintf('%s() returned false', $function));
        }
        return $image;
    }

    public function width(mixed $image): int
    {
        return imagesx($image);
    }

    public function height(mixed $image): int
    {
        return imagesy($image);
    }

    public function pixel(mixed $image, int $x, int $y): array
    {
        $colour = imagecolorsforindex($image, imagecolorat($image, $x, $y));
        return [$colour['red'], $colour['green'], $colour['blue']];
    }

    public function alpha(mixed $image, int $x, int $y): int
    {
        // GD counts alpha from 0 (opaque) to 127 (transparent).
        $colour = imagecolorsforindex($image, imagecolorat($image, $x, $y));
        return 255 - (int)round($colour['alpha'] * 255 / 127);
    }

    public function readFrames(string $path): mixed
    {
        throw new SkippedException('GD reads only the first frame of an animation');
    }

    public function frameCount(mixed $frames): int
    {
        throw new SkippedException('GD has no animation support');
    }

    public function frameSize(mixed $frames): array
    {
        throw new SkippedException('GD has no animation support');
    }

    public function resizeFrames(mixed $frames, int $width, int $height): mixed
    {
        throw new SkippedException('GD has no animation support');
    }

    public function writeFrames(mixed $frames, string $format, string $path): void
    {
        throw new SkippedException('GD has no animation support');
    }

    public function framePixel(mixed $frames, int $frame, int $x, int $y): array
    {
        throw new SkippedException('GD has no animation support');
    }

    /**
     * Images returned by GD operations default to blending and dropping the
     * alpha channel on output, which would silently flatten transparency.
     */
    private function keepAlpha(mixed $image): mixed
    {
        imagealphablending($image, false);
        imagesavealpha($image, true);
        return $image;
    }
}

/**
 * Imagick is not skipped for a missing coder: ImageMagick supports every
 * format checked here, so a failure means a missing delegate or policy
 * restriction in the image, which is exactly what the check is meant to
 * reveal. The one exception is PDF, which ImageMagick hands to Ghostscript.
 * This image ships without it; images built on top install it when needed.
 */
final class ImagickLibrary implements ImageLibrary
{
    public function name(): string
    {
        return 'imagick';
    }

    public function version(): string
    {
        preg_match('/^ImageMagick \S+ \S+ \S+/', Imagick::getVersion()['versionString'], $matches);
        $version = $matches[0] ?? 'ImageMagick';
        // An extension built from a plain source archive reports the unsubstituted @PACKAGE_VERSION@ placeholder.
        if (preg_match('/^\d/', (string)phpversion('imagick'))) {
            $version .= ' (ext ' . phpversion('imagick') . ')';
        }
        return $version;
    }

    public function isAvailable(): bool
    {
        return extension_loaded('imagick');
    }

    public function createPattern(int $width, int $height): mixed
    {
        $image = new Imagick();
        $image->newImage($width, $height, new ImagickPixel('white'));
        $draw = new ImagickDraw();
        foreach (quadrants($width, $height) as $index => [$x, $y, $w, $h]) {
            $draw->setFillColor(new ImagickPixel(sprintf('rgb(%d,%d,%d)', ...PATTERN[$index])));
            $draw->rectangle($x, $y, $x + $w - 1, $y + $h - 1);
        }
        $image->drawImage($draw);
        return $image;
    }

    public function createAlphaPattern(int $width, int $height): mixed
    {
        $image = new Imagick();
        $image->newImage($width, $height, new ImagickPixel('none'));
        $draw = new ImagickDraw();
        $draw->setFillColor(new ImagickPixel(sprintf('rgb(%d,%d,%d)', ...PATTERN[0])));
        $draw->rectangle(0, 0, intdiv($width, 2) - 1, $height - 1);
        $image->drawImage($draw);
        return $image;
    }

    public function resize(mixed $image, int $width, int $height): mixed
    {
        $image->resizeImage($width, $height, Imagick::FILTER_LANCZOS, 1);
        return $image;
    }

    public function rotate90(mixed $image): mixed
    {
        $image->rotateImage(new ImagickPixel('none'), 90);
        return $image;
    }

    public function flipHorizontal(mixed $image): mixed
    {
        $image->flopImage();
        return $image;
    }

    public function crop(mixed $image, int $x, int $y, int $width, int $height): mixed
    {
        $image->cropImage($width, $height, $x, $y);
        $image->setImagePage(0, 0, 0, 0);
        return $image;
    }

    public function write(mixed $image, string $format, string $path): void
    {
        $image->setImageFormat($format);
        if (in_array($format, ['jpeg', 'webp'], true)) {
            $image->setImageCompressionQuality(90);
        }
        $image->writeImage($path);
    }

    public function read(string $path, string $format): mixed
    {
        $image = new Imagick();
        if ($format === 'pdf') {
            if (!$this->hasGhostscript()) {
                throw new SkippedException('Ghostscript is not installed');
            }
            // The resolution decides the raster size of a page. At 72 dpi one point is one pixel.
            $image->setResolution(72, 72);
            $image->readImage($path . '[0]');
        } else {
            $image->readImage($path);
        }
        $expected = strtoupper($format);
        if ($image->getImageFormat() !== $expected) {
            throw new RuntimeException(sprintf('ImageMagick identified the file as %s, expected %s', $image->getImageFormat(), $expected));
        }
        return $image;
    }

    public function width(mixed $image): int
    {
        return $image->getImageWidth();
    }

    public function height(mixed $image): int
    {
        return $image->getImageHeight();
    }

    public function pixel(mixed $image, int $x, int $y): array
    {
        $colour = $image->getImagePixelColor($x, $y)->getColor();
        return [$colour['r'], $colour['g'], $colour['b']];
    }

    public function alpha(mixed $image, int $x, int $y): int
    {
        return (int)round($image->getImagePixelColor($x, $y)->getColorValue(Imagick::COLOR_ALPHA) * 255);
    }

    public function readFrames(string $path): mixed
    {
        return new Imagick($path);
    }

    public function frameCount(mixed $frames): int
    {
        return $frames->getNumberImages();
    }

    public function frameSize(mixed $frames): array
    {
        $frames->setFirstIterator();
        return [$frames->getImageWidth(), $frames->getImageHeight()];
    }

    public function resizeFrames(mixed $frames, int $width, int $height): mixed
    {
        // Frames of a GIF may be partial updates; coalescing turns them into full images first.
        $frames = $frames->coalesceImages();
        foreach ($frames as $frame) {
            $frame->resizeImage($width, $height, Imagick::FILTER_LANCZOS, 1);
        }
        return $frames;
    }

    public function writeFrames(mixed $frames, string $format, string $path): void
    {
        foreach ($frames as $frame) {
            $frame->setImageFormat($format);
        }
        $frames->writeImages($path, true);
    }

    public function framePixel(mixed $frames, int $frame, int $x, int $y): array
    {
        $frames->setIteratorIndex($frame);
        return $this->pixel($frames, $x, $y);
    }

    private function hasGhostscript(): bool
    {
        foreach (explode(PATH_SEPARATOR, (string)getenv('PATH')) as $directory) {
            if (is_executable($directory . '/gs')) {
                return true;
            }
        }
        return false;
    }
}

/**
 * Uses the low-level functions of the vips extension directly, so the check
 * does not depend on the php-vips Composer package. vips_call() and friends
 * return -1 instead of throwing; the error text is then in vips_error_buffer().
 *
 * Animations are handled the way libvips does it: all frames are loaded as
 * one tall strip whose page-height metadata tells the savers where the
 * frames are.
 */
final class VipsLibrary implements ImageLibrary
{
    private const LOADERS = [
        'jpeg' => ['VipsForeignLoadJpegFile'],
        'png' => ['VipsForeignLoadPngFile', 'VipsForeignLoadSpngFile'],
        'gif' => ['VipsForeignLoadNsgifFile', 'VipsForeignLoadGifFile'],
        'webp' => ['VipsForeignLoadWebpFile'],
        'avif' => ['VipsForeignLoadHeifFile'],
        'svg' => ['VipsForeignLoadSvgFile'],
        'heic' => ['VipsForeignLoadHeifFile'],
        'tiff' => ['VipsForeignLoadTiffFile'],
        'pdf' => ['VipsForeignLoadPdfFile'],
    ];

    private const SAVERS = [
        'jpeg' => ['VipsForeignSaveJpegFile'],
        'png' => ['VipsForeignSavePngFile', 'VipsForeignSaveSpngFile'],
        'gif' => ['VipsForeignSaveCgifFile', 'VipsForeignSaveGifFile'],
        'webp' => ['VipsForeignSaveWebpFile'],
        'avif' => ['VipsForeignSaveHeifFile', 'VipsForeignSaveAvifFile'],
        'heic' => ['VipsForeignSaveHeifFile'],
    ];

    public function name(): string
    {
        return 'vips';
    }

    public function version(): string
    {
        return 'libvips ' . vips_version() . ' (ext ' . phpversion('vips') . ')';
    }

    public function isAvailable(): bool
    {
        return extension_loaded('vips');
    }

    public function createPattern(int $width, int $height): mixed
    {
        $tiles = [];
        foreach (quadrants($width, $height) as $index => [, , $w, $h]) {
            $tiles[] = $this->solid($w, $h, PATTERN[$index]);
        }
        $image = $this->call('arrayjoin', null, $tiles, ['across' => 2]);
        return $this->call('copy', $image, ['interpretation' => 'srgb']);
    }

    public function createAlphaPattern(int $width, int $height): mixed
    {
        $half = intdiv($width, 2);
        $tiles = [$this->solid($half, $height, [...PATTERN[0], 255]), $this->solid($width - $half, $height, [0, 0, 0, 0])];
        $image = $this->call('arrayjoin', null, $tiles, ['across' => 2]);
        return $this->call('copy', $image, ['interpretation' => 'srgb']);
    }

    public function resize(mixed $image, int $width, int $height): mixed
    {
        $scale = $width / $this->width($image);
        $verticalScale = $height / $this->height($image);
        return $this->call('resize', $image, $scale, ['vscale' => $verticalScale]);
    }

    public function rotate90(mixed $image): mixed
    {
        return $this->call('rot', $image, 'd90');
    }

    public function flipHorizontal(mixed $image): mixed
    {
        return $this->call('flip', $image, 'horizontal');
    }

    public function crop(mixed $image, int $x, int $y, int $width, int $height): mixed
    {
        return $this->call('extract_area', $image, $x, $y, $width, $height);
    }

    public function write(mixed $image, string $format, string $path): void
    {
        $this->requireOperation(self::SAVERS[$format], sprintf('this libvips build has no %s saver', $format));
        $options = match ($format) {
            'jpeg', 'webp' => ['Q' => 90],
            'avif', 'heic' => ['Q' => 60],
            default => [],
        };
        if (!is_array(vips_image_write_to_file($image, $path, $options))) {
            throw new RuntimeException(trim(vips_error_buffer()));
        }
    }

    public function read(string $path, string $format): mixed
    {
        $this->requireOperation(self::LOADERS[$format], sprintf('this libvips build has no %s loader', $format));
        $loader = vips_foreign_find_load($path);
        if (!is_string($loader)) {
            throw new RuntimeException(trim(vips_error_buffer()));
        }
        if (!in_array($loader, self::LOADERS[$format], true)) {
            throw new RuntimeException(sprintf('libvips picked %s for the file, expected a %s loader', $loader, $format));
        }
        $result = vips_image_new_from_file($path, []);
        if (!is_array($result)) {
            throw new RuntimeException(trim(vips_error_buffer()));
        }
        return $result['out'];
    }

    public function width(mixed $image): int
    {
        return $this->get($image, 'width');
    }

    public function height(mixed $image): int
    {
        return $this->get($image, 'height');
    }

    public function pixel(mixed $image, int $x, int $y): array
    {
        // An alpha band, if present, is not part of the colour comparison.
        return array_map('intval', array_slice($this->point($image, $x, $y), 0, 3));
    }

    public function alpha(mixed $image, int $x, int $y): int
    {
        $bands = $this->point($image, $x, $y);
        return match (count($bands)) {
            4 => (int)$bands[3],
            2 => (int)$bands[1],
            default => 255,
        };
    }

    public function readFrames(string $path): mixed
    {
        $result = vips_image_new_from_file($path, ['n' => -1]);
        if (!is_array($result)) {
            throw new RuntimeException(trim(vips_error_buffer()));
        }
        return $result['out'];
    }

    public function frameCount(mixed $frames): int
    {
        return vips_image_get_typeof($frames, 'n-pages') === 0 ? 1 : $this->get($frames, 'n-pages');
    }

    public function frameSize(mixed $frames): array
    {
        $height = vips_image_get_typeof($frames, 'page-height') === 0 ? $this->height($frames) : $this->get($frames, 'page-height');
        return [$this->width($frames), $height];
    }

    public function resizeFrames(mixed $frames, int $width, int $height): mixed
    {
        [$frameWidth, $frameHeight] = $this->frameSize($frames);
        $strip = $this->call('resize', $frames, $width / $frameWidth, ['vscale' => $height / $frameHeight]);
        // The resized strip still carries the old page height, which would misplace every frame on save.
        if (vips_image_set($strip, 'page-height', $height) !== 0) {
            throw new RuntimeException(trim(vips_error_buffer()));
        }
        return $strip;
    }

    public function writeFrames(mixed $frames, string $format, string $path): void
    {
        $this->write($frames, $format, $path);
    }

    public function framePixel(mixed $frames, int $frame, int $x, int $y): array
    {
        [, $frameHeight] = $this->frameSize($frames);
        return $this->pixel($frames, $x, $y + $frame * $frameHeight);
    }

    /**
     * @param int[] $colour red, green, blue and optionally alpha
     */
    private function solid(int $width, int $height, array $colour): mixed
    {
        $image = $this->call('black', null, $width, $height, ['bands' => count($colour)]);
        $image = $this->call('linear', $image, array_fill(0, count($colour), 1.0), array_map('floatval', $colour));
        return $this->call('cast', $image, 'uchar');
    }

    /**
     * @return float[] all band values of the pixel at the given position
     */
    private function point(mixed $image, int $x, int $y): array
    {
        $result = vips_call('getpoint', $image, $x, $y);
        if (!is_array($result)) {
            throw new RuntimeException(trim(vips_error_buffer()));
        }
        return $result['out-array'];
    }

    private function call(string $operation, mixed $instance, mixed ...$arguments): mixed
    {
        $result = vips_call($operation, $instance, ...$arguments);
        if (!is_array($result)) {
            throw new RuntimeException(sprintf('%s: %s', $operation, trim(vips_error_buffer())));
        }
        return $result['out'];
    }

    private function get(mixed $image, string $field): mixed
    {
        $result = vips_image_get($image, $field);
        if (!is_array($result)) {
            throw new RuntimeException(sprintf('get %s: %s', $field, trim(vips_error_buffer())));
        }
        return $result['out'];
    }

    /**
     * @param string[] $operations
     */
    private function requireOperation(array $operations, string $skipMessage): void
    {
        foreach ($operations as $operation) {
            if (vips_type_from_name($operation) !== 0) {
                return;
            }
        }
        throw new SkippedException($skipMessage);
    }
}

final class Report
{
    /** @var Check[] */
    private array $checks = [];

    public function add(string $library, string $category, string $format, Status $status, string $detail = '', string $source = ''): void
    {
        // ImageMagick errors can quote a whole delegate command line; the first part says what went wrong.
        if (strlen($detail) > 200) {
            $detail = substr($detail, 0, 200) . ' ...';
        }
        $this->checks[] = new Check($library, $category, $format, $status, $detail, $source);
        $subject = $source === '' ? $format : sprintf('%s from %s', $format, $source);
        printf("[%s] %-8s %-11s %-18s %s\n", str_pad($status->value, 4, ' ', STR_PAD_BOTH), $library, $category, $subject, $detail);
    }

    /**
     * Runs a check and records its outcome. The callable returns the detail
     * text for a passed check and throws SkippedException or any other
     * Throwable otherwise.
     */
    public function run(string $library, string $category, string $format, callable $check, string $source = ''): void
    {
        try {
            $this->add($library, $category, $format, Status::Ok, (string)$check(), $source);
        } catch (SkippedException $e) {
            $this->add($library, $category, $format, Status::Skip, $e->getMessage(), $source);
        } catch (Throwable $e) {
            $this->add($library, $category, $format, Status::Fail, $e->getMessage(), $source);
        }
    }

    public function status(string $library, string $category, string $format): ?Status
    {
        foreach ($this->checks as $check) {
            if ($check->library === $library && $check->category === $category && $check->format === $format && $check->source === '') {
                return $check->status;
            }
        }
        return null;
    }

    /**
     * @return string[] libraries whose check of the given kind passed
     */
    public function librariesWith(string $category, string $format): array
    {
        $libraries = [];
        foreach ($this->checks as $check) {
            if ($check->category === $category && $check->format === $format && $check->status === Status::Ok && $check->source === '') {
                $libraries[] = $check->library;
            }
        }
        return $libraries;
    }

    public function count(Status $status): int
    {
        return count(array_filter($this->checks, static fn(Check $check) => $check->status === $status));
    }

    /**
     * @return Check[]
     */
    public function failures(): array
    {
        return array_values(array_filter($this->checks, static fn(Check $check) => $check->status === Status::Fail));
    }

    public function hasFailures(): bool
    {
        return $this->failures() !== [];
    }

    /**
     * @param ImageLibrary[] $libraries
     * @param string[] $versions
     */
    public function markdown(array $libraries, array $versions): string
    {
        $lines = [];
        $lines[] = sprintf('### Image formats on PHP %s', PHP_VERSION);
        $lines[] = '';
        $lines[] = implode(', ', $versions);
        $lines[] = '';
        $lines[] = sprintf('Read and write per library (read / write, read only for the last %d):', count(READ_ONLY_FORMATS));
        $lines[] = '';
        $lines[] = '| Library | Manipulate | ' . implode(' | ', [...WRITABLE_FORMATS, ...READ_ONLY_FORMATS]) . ' |';
        $lines[] = '|---|---|' . str_repeat('---|', count(WRITABLE_FORMATS) + count(READ_ONLY_FORMATS));
        foreach ($libraries as $library) {
            $cells = [$library->name(), $this->cell($library->name(), 'manipulate', '-')];
            foreach (WRITABLE_FORMATS as $format) {
                $cells[] = $this->cell($library->name(), 'read', $format) . ' / ' . $this->cell($library->name(), 'write', $format);
            }
            foreach (READ_ONLY_FORMATS as $format) {
                $cells[] = $this->cell($library->name(), 'read', $format);
            }
            $lines[] = '| ' . implode(' | ', $cells) . ' |';
        }
        $lines[] = '';
        $lines[] = 'Transparency and animation frames kept through resize and write:';
        $lines[] = '';
        $alphaColumns = array_map(static fn(string $format) => 'alpha ' . $format, ALPHA_FORMATS);
        $animationColumns = array_map(static fn(string $format) => 'animated ' . $format, ANIMATION_FORMATS);
        $lines[] = '| Library | ' . implode(' | ', [...$alphaColumns, ...$animationColumns]) . ' |';
        $lines[] = '|---|' . str_repeat('---|', count(ALPHA_FORMATS) + count(ANIMATION_FORMATS));
        foreach ($libraries as $library) {
            $cells = [$library->name()];
            foreach (ALPHA_FORMATS as $format) {
                $cells[] = $this->cell($library->name(), 'alpha', $format);
            }
            foreach (ANIMATION_FORMATS as $format) {
                $cells[] = $this->cell($library->name(), 'animate', $format);
            }
            $lines[] = '| ' . implode(' | ', $cells) . ' |';
        }
        $lines[] = '';
        $lines[] = 'Files written by one library, read by the others:';
        $lines[] = '';
        $lines[] = '| Written by | ' . implode(' | ', WRITABLE_FORMATS) . ' |';
        $lines[] = '|---|' . str_repeat('---|', count(WRITABLE_FORMATS));
        foreach ($libraries as $writer) {
            $cells = [$writer->name()];
            foreach (WRITABLE_FORMATS as $format) {
                $cells[] = $this->interopCell($writer->name(), $format);
            }
            $lines[] = '| ' . implode(' | ', $cells) . ' |';
        }
        $lines[] = '';
        if ($this->hasFailures()) {
            $lines[] = '**Failures**';
            $lines[] = '';
            foreach ($this->failures() as $check) {
                $subject = $check->source === '' ? $check->format : sprintf('%s from %s', $check->format, $check->source);
                $lines[] = sprintf('- %s %s %s: %s', $check->library, $check->category, $subject, $check->detail);
            }
            $lines[] = '';
        }
        $lines[] = sprintf('**Result: %s** (%d ok, %d failed, %d skipped)', $this->hasFailures() ? 'FAILED' : 'PASSED', $this->count(Status::Ok), $this->count(Status::Fail), $this->count(Status::Skip));
        $lines[] = '';
        return implode("\n", $lines);
    }

    private function cell(string $library, string $category, string $format): string
    {
        return $this->status($library, $category, $format)?->value ?? 'n/a';
    }

    private function interopCell(string $writer, string $format): string
    {
        $ok = [];
        $failed = [];
        foreach ($this->checks as $check) {
            if ($check->category !== 'interop' || $check->source !== $writer || $check->format !== $format) {
                continue;
            }
            if ($check->status === Status::Ok) {
                $ok[] = $check->library;
            } elseif ($check->status === Status::Fail) {
                $failed[] = $check->library;
            }
        }
        if ($failed !== []) {
            return 'FAIL (' . implode(', ', $failed) . ')';
        }
        return $ok === [] ? 'n/a' : 'OK (' . implode(', ', $ok) . ')';
    }
}

/**
 * @return array<int, array{int, int, int, int}> x, y, width and height of the four quadrants
 */
function quadrants(int $width, int $height): array
{
    $w = intdiv($width, 2);
    $h = intdiv($height, 2);
    return [[0, 0, $w, $h], [$w, 0, $w, $h], [0, $h, $w, $h], [$w, $h, $w, $h]];
}

/**
 * @return array<int, array{int, int}> the centre of each quadrant
 */
function quadrantCentres(int $width, int $height): array
{
    return array_map(static fn(array $q) => [$q[0] + intdiv($q[2], 2), $q[1] + intdiv($q[3], 2)], quadrants($width, $height));
}

function coloursMatch(array $a, array $b): bool
{
    for ($i = 0; $i < 3; $i++) {
        if (abs($a[$i] - $b[$i]) > TOLERANCE) {
            return false;
        }
    }
    return true;
}

function describeColour(array $rgb): string
{
    return sprintf('rgb(%d,%d,%d)', ...$rgb);
}

function assertSize(ImageLibrary $library, mixed $image, int $width, int $height, string $step): void
{
    $actualWidth = $library->width($image);
    $actualHeight = $library->height($image);
    if ($actualWidth !== $width || $actualHeight !== $height) {
        throw new RuntimeException(sprintf('%s: size is %dx%d, expected %dx%d', $step, $actualWidth, $actualHeight, $width, $height));
    }
}

/**
 * Checks that each quadrant still shows its pattern colour.
 */
function assertPattern(ImageLibrary $library, mixed $image, string $step): void
{
    $centres = quadrantCentres($library->width($image), $library->height($image));
    foreach ($centres as $index => [$x, $y]) {
        $actual = $library->pixel($image, $x, $y);
        if (!coloursMatch($actual, PATTERN[$index])) {
            throw new RuntimeException(sprintf('%s: pixel at %d,%d is %s, expected %s', $step, $x, $y, describeColour($actual), describeColour(PATTERN[$index])));
        }
    }
}

/**
 * Checks that the four pattern colours are all still present, in any
 * arrangement. Rotation and flipping move the quadrants, and the direction
 * differs between libraries.
 */
function assertPatternColours(ImageLibrary $library, mixed $image, string $step): void
{
    $remaining = PATTERN;
    foreach (quadrantCentres($library->width($image), $library->height($image)) as [$x, $y]) {
        $actual = $library->pixel($image, $x, $y);
        foreach ($remaining as $index => $expected) {
            if (coloursMatch($actual, $expected)) {
                unset($remaining[$index]);
                continue 2;
            }
        }
        throw new RuntimeException(sprintf('%s: pixel at %d,%d is %s, which is none of the remaining pattern colours', $step, $x, $y, describeColour($actual)));
    }
}

/**
 * Checks that the image shows a single pattern colour.
 */
function assertSolid(ImageLibrary $library, mixed $image, string $step): void
{
    $centres = quadrantCentres($library->width($image), $library->height($image));
    $first = $library->pixel($image, ...$centres[0]);
    $known = array_filter(PATTERN, static fn(array $colour) => coloursMatch($first, $colour));
    if ($known === []) {
        throw new RuntimeException(sprintf('%s: colour %s is not a pattern colour', $step, describeColour($first)));
    }
    foreach ($centres as [$x, $y]) {
        $actual = $library->pixel($image, $x, $y);
        if (!coloursMatch($actual, $first)) {
            throw new RuntimeException(sprintf('%s: pixel at %d,%d is %s, expected %s everywhere', $step, $x, $y, describeColour($actual), describeColour($first)));
        }
    }
}

/**
 * Identifies the format from the file signature, independent of any library.
 */
function detectFormat(string $path): ?string
{
    $bytes = (string)file_get_contents($path, false, null, 0, 32);
    if (str_starts_with($bytes, "\xFF\xD8\xFF")) {
        return 'jpeg';
    }
    if (str_starts_with($bytes, "\x89PNG\r\n\x1a\n")) {
        return 'png';
    }
    if (str_starts_with($bytes, 'GIF87a') || str_starts_with($bytes, 'GIF89a')) {
        return 'gif';
    }
    if (str_starts_with($bytes, 'RIFF') && substr($bytes, 8, 4) === 'WEBP') {
        return 'webp';
    }
    if (substr($bytes, 4, 4) === 'ftyp' && in_array(substr($bytes, 8, 4), ['avif', 'avis'], true)) {
        return 'avif';
    }
    if (substr($bytes, 4, 4) === 'ftyp' && in_array(substr($bytes, 8, 4), ['heic', 'heix'], true)) {
        return 'heic';
    }
    return null;
}

/**
 * Writes through the callable and verifies the file signature. A failed save
 * can leave an empty file behind, which would otherwise end up in the kept
 * output, so it is removed.
 */
function writeAndVerify(callable $write, string $format, string $path): void
{
    try {
        $write();
    } catch (Throwable $e) {
        if (is_file($path)) {
            unlink($path);
        }
        throw $e;
    }
    if (!is_file($path) || filesize($path) === 0) {
        throw new RuntimeException('no file was written');
    }
    $detected = detectFormat($path);
    if ($detected !== $format) {
        throw new RuntimeException(sprintf('file signature says %s, expected %s', $detected ?? 'unknown format', $format));
    }
}

function runManipulation(ImageLibrary $library): string
{
    $image = $library->createPattern(64, 48);
    assertSize($library, $image, 64, 48, 'create');
    assertPattern($library, $image, 'create');

    $image = $library->resize($image, 32, 24);
    assertSize($library, $image, 32, 24, 'resize');
    assertPattern($library, $image, 'resize');

    $image = $library->rotate90($image);
    assertSize($library, $image, 24, 32, 'rotate');
    assertPatternColours($library, $image, 'rotate');

    $image = $library->flipHorizontal($image);
    assertSize($library, $image, 24, 32, 'flip');
    assertPatternColours($library, $image, 'flip');

    $image = $library->crop($image, 0, 0, 12, 16);
    assertSize($library, $image, 12, 16, 'crop');
    assertSolid($library, $image, 'crop');

    return 'create 64x48, resize 32x24, rotate 24x32, flip, crop 12x16';
}

function runRead(ImageLibrary $library, string $format, string $path): string
{
    if (!is_file($path)) {
        throw new RuntimeException(sprintf('fixture %s is missing', $path));
    }
    $image = $library->read($path, $format);
    assertSize($library, $image, 64, 48, 'read');
    assertPattern($library, $image, 'read');
    return sprintf('%s, %d bytes', basename($path), filesize($path));
}

function runWrite(ImageLibrary $library, string $format, string $path): string
{
    $image = $library->resize($library->createPattern(64, 48), 32, 24);
    writeAndVerify(static fn() => $library->write($image, $format, $path), $format, $path);
    $image = $library->read($path, $format);
    assertSize($library, $image, 32, 24, 'read back');
    assertPattern($library, $image, 'read back');
    return sprintf('%d bytes, read back 32x24', filesize($path));
}

function runInterop(ImageLibrary $reader, string $format, string $path): string
{
    $image = $reader->read($path, $format);
    assertSize($reader, $image, 32, 24, 'read');
    assertPattern($reader, $image, 'read');
    return 'OK';
}

function runAlpha(ImageLibrary $library, string $format, string $path): string
{
    $image = $library->resize($library->createAlphaPattern(64, 48), 32, 24);
    writeAndVerify(static fn() => $library->write($image, $format, $path), $format, $path);
    $image = $library->read($path, $format);
    assertSize($library, $image, 32, 24, 'read back');

    $opaque = $library->alpha($image, 8, 12);
    if ($opaque < 255 - TOLERANCE) {
        throw new RuntimeException(sprintf('left half is no longer opaque, alpha is %d', $opaque));
    }
    $colour = $library->pixel($image, 8, 12);
    if (!coloursMatch($colour, PATTERN[0])) {
        throw new RuntimeException(sprintf('left half is %s, expected %s', describeColour($colour), describeColour(PATTERN[0])));
    }
    $transparent = $library->alpha($image, 24, 12);
    if ($transparent > TOLERANCE) {
        throw new RuntimeException(sprintf('right half is no longer transparent, alpha is %d', $transparent));
    }
    return sprintf('%d bytes, alpha %d opaque and %d transparent', filesize($path), $opaque, $transparent);
}

function runAnimation(ImageLibrary $library, string $format, string $fixture, string $path): string
{
    if (!is_file($fixture)) {
        throw new RuntimeException(sprintf('fixture %s is missing', $fixture));
    }
    $frames = $library->readFrames($fixture);
    $count = $library->frameCount($frames);
    if ($count !== 2) {
        throw new RuntimeException(sprintf('fixture has %d frames, expected 2', $count));
    }
    [$width, $height] = $library->frameSize($frames);
    if ($width !== 64 || $height !== 48) {
        throw new RuntimeException(sprintf('fixture frames are %dx%d, expected 64x48', $width, $height));
    }

    $frames = $library->resizeFrames($frames, 32, 24);
    writeAndVerify(static fn() => $library->writeFrames($frames, $format, $path), $format, $path);

    $frames = $library->readFrames($path);
    $count = $library->frameCount($frames);
    if ($count !== 2) {
        throw new RuntimeException(sprintf('read back %d frames, expected 2', $count));
    }
    [$width, $height] = $library->frameSize($frames);
    if ($width !== 32 || $height !== 24) {
        throw new RuntimeException(sprintf('read back frames of %dx%d, expected 32x24', $width, $height));
    }
    foreach ([0, 1] as $frame) {
        $colour = $library->framePixel($frames, $frame, 16, 12);
        if (!coloursMatch($colour, PATTERN[$frame])) {
            throw new RuntimeException(sprintf('frame %d is %s, expected %s', $frame, describeColour($colour), describeColour(PATTERN[$frame])));
        }
    }
    return sprintf('%d bytes, 2 frames of 32x24', filesize($path));
}

function main(): int
{
    $options = getopt('', ['output-dir:']);
    $outputDir = isset($options['output-dir']) ? rtrim((string)$options['output-dir'], '/') : null;
    $workDir = $outputDir ?? sys_get_temp_dir() . '/image-formats-' . getmypid();
    if (!is_dir($workDir) && !mkdir($workDir, 0777, true)) {
        fwrite(STDERR, sprintf("Cannot create %s\n", $workDir));
        return 2;
    }
    if (!is_writable($workDir)) {
        fwrite(STDERR, sprintf("%s is not writable\n", $workDir));
        return 2;
    }
    $fixturesDir = __DIR__ . '/fixtures';

    /** @var ImageLibrary[] $libraries */
    $libraries = [new GdLibrary(), new ImagickLibrary(), new VipsLibrary()];
    $report = new Report();
    $versions = [];

    printf("Image format checks on PHP %s\n\n", PHP_VERSION);

    foreach ($libraries as $library) {
        $name = $library->name();
        if (!$library->isAvailable()) {
            $report->add($name, 'extension', '-', Status::Fail, 'extension is not loaded');
            continue;
        }
        $versions[] = $library->version();
        $report->add($name, 'extension', '-', Status::Ok, $library->version());
        $report->run($name, 'manipulate', '-', static fn() => runManipulation($library));
        foreach ([...WRITABLE_FORMATS, ...READ_ONLY_FORMATS] as $format) {
            $report->run($name, 'read', $format, static fn() => runRead($library, $format, sprintf('%s/sample.%s', $fixturesDir, $format)));
        }
        foreach (WRITABLE_FORMATS as $format) {
            $report->run($name, 'write', $format, static fn() => runWrite($library, $format, sprintf('%s/%s.%s', $workDir, $name, $format)));
        }
        foreach (ALPHA_FORMATS as $format) {
            $report->run($name, 'alpha', $format, static fn() => runAlpha($library, $format, sprintf('%s/%s-alpha.%s', $workDir, $name, $format)));
        }
        foreach (ANIMATION_FORMATS as $format) {
            $report->run($name, 'animate', $format, static fn() => runAnimation($library, $format, $fixturesDir . '/animated.gif', sprintf('%s/%s-animated.%s', $workDir, $name, $format)));
        }
    }

    foreach ($libraries as $writer) {
        foreach (WRITABLE_FORMATS as $format) {
            if ($report->status($writer->name(), 'write', $format) !== Status::Ok) {
                continue;
            }
            $path = sprintf('%s/%s.%s', $workDir, $writer->name(), $format);
            foreach ($libraries as $reader) {
                if ($reader === $writer || !$reader->isAvailable()) {
                    continue;
                }
                $report->run($reader->name(), 'interop', $format, static fn() => runInterop($reader, $format, $path), $writer->name());
            }
        }
    }

    foreach (WRITABLE_FORMATS as $format) {
        $readers = $report->librariesWith('read', $format);
        $writers = $report->librariesWith('write', $format);
        $detail = sprintf('read: %s; write: %s', $readers === [] ? 'none' : implode(', ', $readers), $writers === [] ? 'none' : implode(', ', $writers));
        $report->add('any', 'coverage', $format, $readers !== [] && $writers !== [] ? Status::Ok : Status::Fail, $detail);
    }
    foreach (READ_ONLY_FORMATS as $format) {
        $readers = $report->librariesWith('read', $format);
        $report->add('any', 'coverage', $format, $readers !== [] ? Status::Ok : Status::Fail, 'read: ' . ($readers === [] ? 'none' : implode(', ', $readers)));
    }

    printf("\n%d ok, %d failed, %d skipped\n", $report->count(Status::Ok), $report->count(Status::Fail), $report->count(Status::Skip));
    printf("%s\n", $report->hasFailures() ? 'FAILED' : 'PASSED');

    if ($outputDir !== null) {
        file_put_contents($outputDir . '/summary.md', $report->markdown($libraries, $versions));
    } else {
        foreach (glob($workDir . '/*') ?: [] as $file) {
            unlink($file);
        }
        rmdir($workDir);
    }

    return $report->hasFailures() ? 1 : 0;
}

exit(main());

"""Compose two already-generated artificial project figures, without paper pixels."""
from pathlib import Path
import argparse
from PIL import Image, ImageDraw, ImageFont


def build(root, font_path):
    font = ImageFont.truetype(str(font_path), 22)
    for item in ['FE-043', 'FE-018', 'FE-019', 'FE-041', 'FE-013', 'FE-047']:
        for journal in ['nature', 'cell']:
            sheet = Image.new('RGB', (2000, 560), 'white')
            draw = ImageDraw.Draw(sheet)
            for index, stage in enumerate(['before', 'after']):
                path = root / item / stage / journal / (stage + '.png')
                with Image.open(path) as original:
                    image = original.convert('RGB')
                image.thumbnail((990, 510))
                sheet.paste(image, (index * 1000, 45))
                draw.text((index * 1000 + 15, 8),
                          f'{item} {journal} / {stage} / same input and physical size',
                          fill='black', font=font)
            sheet.save(root / item / f'comparison-{journal}.png')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--font', type=Path,
                        default=Path('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'))
    args = parser.parse_args()
    build(args.root, args.font)

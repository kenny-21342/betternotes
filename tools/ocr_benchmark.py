#!/usr/bin/env python3
"""Offline OCR benchmark. Synthetic strokes are smoke tests, not owner accuracy.

  python3 tools/ocr_benchmark.py generate /tmp/ocr-fixtures
  swift tools/ocr_vision.swift /tmp/ocr-fixtures/manifest.json > /tmp/vision.json
  python3 tools/ocr_benchmark.py score /tmp/ocr-fixtures/manifest.json /tmp/vision.json

Any cloud/on-device adapter can supply the same JSON object {sample_id: text}.
No network calls, credentials, or note data are used by this script. For real
handwriting, create a manifest with manually checked text and local image paths.
"""
import argparse
import json
import random
import unicodedata
from pathlib import Path

# Single-line glyphs, not rendered fonts. Each slash lifts the virtual pen.
GLYPHS = {
    'a': '8,10 6,4 2,4 0,8 1,12 5,12 7,8/7,4 7,12 9,12',
    'c': '8,5 5,3 1,5 0,9 2,12 7,12',
    'd': '7,6 4,4 1,5 0,9 2,12 6,11 7,7/7,0 7,12 9,12',
    'e': '0,8 8,7 6,4 2,4 0,7 0,10 3,12 8,11',
    'f': '2,16 3,3 5,0 8,1/0,6 7,6',
    'g': '7,5 3,4 0,7 1,11 5,12 7,8/7,4 7,15 5,18 1,17',
    'h': '0,0 0,12/0,8 3,4 6,4 8,7 8,12',
    'i': '3,4 3,12/3,0 3,0.5',
    'l': '3,0 3,12 6,12',
    'm': '0,4 0,12/0,7 3,4 5,5 5,12/5,7 8,4 10,5 10,12',
    'n': '0,4 0,12/0,7 3,4 6,4 8,7 8,12',
    'o': '4,4 1,5 0,9 2,12 6,12 8,9 7,5 4,4',
    'p': '0,4 0,18/0,6 3,4 7,5 8,8 6,11 1,11',
    'q': '7,6 4,4 1,5 0,9 2,12 6,11 7,7/7,4 7,18',
    'r': '0,4 0,12/0,7 3,4 6,5',
    's': '8,5 5,4 1,5 1,7 7,9 7,11 4,12 0,11',
    't': '4,0 4,10 5,12 8,11/0,5 8,5',
    'u': '0,4 0,10 2,12 5,11 7,8/7,4 7,12 9,12',
    'v': '0,4 4,12 8,4',
    'w': '0,4 2,12 5,7 8,12 10,4',
    'x': '0,4 8,12/8,4 0,12',
    'y': '0,4 3,11 7,8/8,4 6,15 3,18 0,17',
    '?': '0,3 2,0 6,0 8,3 7,5 4,7 4,10/4,13 4,13.5',
}


def distance(a, b):
    row = list(range(len(b) + 1))
    for i, x in enumerate(a, 1):
        nxt = [i]
        for j, y in enumerate(b, 1):
            nxt.append(min(nxt[-1] + 1, row[j] + 1, row[j - 1] + (x != y)))
        row = nxt
    return row[-1]


def normalize(text):
    # Preserve case, punctuation and question marks; normalize only Unicode and whitespace.
    return ' '.join(unicodedata.normalize('NFC', text).split())


def generate(folder):
    from PIL import Image, ImageDraw
    folder.mkdir(parents=True, exist_ok=True)
    samples = []
    texts = ['what is force ??', '?? explain energy', 'speed equals distance over time ??']
    for index, text in enumerate(texts):
        rng = random.Random(index)
        scale = 4
        image = Image.new('RGB', (1700, 240), 'white')
        pen = ImageDraw.Draw(image)
        x = 30
        for ch in text:
            if ch == ' ':
                x += 34
                continue
            jitter = rng.uniform(-2, 2)
            for path in GLYPHS[ch].split('/'):
                points = [tuple(map(float, p.split(','))) for p in path.split()]
                points = [(x + px * scale + py * .18, 55 + py * scale + jitter) for px, py in points]
                pen.line(points, fill=(12, 12, 12), width=4, joint='curve')
            x += (12 if ch in 'mw' else 10) * scale
        name = f'stroke-{index + 1}.png'
        image.crop((0, 0, min(1700, int(x + 30)), 170)).save(folder / name)
        samples.append({'id': f'stroke-{index + 1}', 'image': name, 'text': text})
    manifest = {'kind': 'synthetic single-line stroke glyphs; not real handwriting', 'samples': samples}
    (folder / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')


def score(manifest, predictions):
    samples = json.loads(manifest.read_text())['samples']
    predicted = json.loads(predictions.read_text())
    rows = []
    char_errors = word_errors = chars = words = 0
    for sample in samples:
        if sample['id'] not in predicted:
            raise ValueError(f"Missing prediction: {sample['id']}")
        expected, actual = normalize(sample['text']), normalize(predicted[sample['id']])
        ce, we = distance(expected, actual), distance(expected.split(), actual.split())
        char_errors += ce
        word_errors += we
        chars += len(expected)
        words += len(expected.split())
        rows.append({'id': sample['id'], 'expected': expected, 'actual': actual,
                     'CER': ce / max(1, len(expected)), 'WER': we / max(1, len(expected.split())),
                     'marker_preserved': ('??' in actual or '？？' in actual) == ('??' in expected or '？？' in expected)})
    print(json.dumps({'CER': char_errors / max(1, chars), 'WER': word_errors / max(1, words),
                      'normalization': 'NFC + collapsed whitespace; case/punctuation preserved', 'samples': rows}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('generate').add_argument('folder', type=Path)
    scorer = commands.add_parser('score')
    scorer.add_argument('manifest', type=Path)
    scorer.add_argument('predictions', type=Path)
    args = parser.parse_args()
    if args.command == 'generate':
        generate(args.folder)
    else:
        score(args.manifest, args.predictions)
